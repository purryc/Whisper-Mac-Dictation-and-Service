from __future__ import annotations

import asyncio
import base64
import tempfile
import time
import wave
from array import array
from pathlib import Path

from .config import Settings
from .engine import TranscriptionEngine
from .models import EngineTranscript


class RealtimeSession:
    """Naive rolling retranscription session.

    This trades efficiency for simplicity so multiple projects can share one
    stable API immediately. It can later be replaced with a stronger streaming
    implementation without changing the external contract.
    """

    def __init__(
        self,
        engine: TranscriptionEngine,
        settings: Settings,
        *,
        language: str | None = None,
        prompt: str | None = None,
    ) -> None:
        self.engine = engine
        self.settings = settings
        self.language = language
        self.prompt = prompt
        self.active_buffer = bytearray()
        self._last_emit_at = 0.0
        self._last_partial_text = ""
        self._current_speech_ms = 0
        self._current_silence_ms = 0
        self._ready_utterance: bytes | None = None
        self._committed_texts: list[str] = []
        self._committed_audio_ms = 0

    def append_base64_pcm(self, encoded_audio: str) -> None:
        self._append_pcm(base64.b64decode(encoded_audio))

    def duration_ms(self) -> int:
        bytes_per_sample = 2 * self.settings.channels
        if bytes_per_sample <= 0:
            return 0
        total_samples = len(self.active_buffer) / bytes_per_sample
        return int((total_samples / self.settings.sample_rate) * 1000)

    def should_emit_partial(self) -> bool:
        now = time.monotonic()
        if self._ready_utterance is not None:
            self._last_emit_at = now
            return True
        if self.duration_ms() < self.settings.min_partial_ms:
            return False
        if (now - self._last_emit_at) * 1000 < self.settings.partial_step_ms:
            return False
        self._last_emit_at = now
        return True

    async def transcribe_partial(self) -> EngineTranscript | None:
        if self._ready_utterance is not None:
            committed = await self._transcribe_bytes(self._ready_utterance)
            self._committed_audio_ms += self._duration_ms_for_bytes(len(self._ready_utterance))
            self._ready_utterance = None
            if committed.text:
                self._committed_texts.append(committed.text)

        live_text = ""
        live_duration_ms = self.duration_ms()
        if self.active_buffer:
            live = await self._transcribe_bytes(bytes(self.active_buffer), duration_ms=live_duration_ms)
            live_text = live.text

        # Keep live partials scoped to the current in-flight utterance.
        # The committed utterances are reserved for the final transcript so the
        # overlay does not look "polluted" by earlier phrases in the session.
        if live_text != self._last_partial_text:
            self._last_partial_text = live_text
            return EngineTranscript(
                text=live_text,
                language=self.language or self.settings.default_language,
                duration_ms=self._total_duration_ms(),
                engine="whisper-cli",
            )
        return None

    async def transcribe_final(self) -> EngineTranscript:
        if self._ready_utterance is not None:
            committed = await self._transcribe_bytes(self._ready_utterance)
            self._committed_audio_ms += self._duration_ms_for_bytes(len(self._ready_utterance))
            self._ready_utterance = None
            if committed.text:
                self._committed_texts.append(committed.text)

        if self.active_buffer:
            trailing = await self._transcribe_bytes(bytes(self.active_buffer), duration_ms=self.duration_ms())
            if trailing.text:
                self._committed_texts.append(trailing.text)
            self._committed_audio_ms += self.duration_ms()
            self.active_buffer.clear()

        final_text = self._join_texts(*self._committed_texts)
        return EngineTranscript(
            text=final_text,
            language=self.language or self.settings.default_language,
            duration_ms=self._total_duration_ms(),
            engine="whisper-cli",
        )

    async def _transcribe_buffer(self) -> EngineTranscript:
        if not self.active_buffer:
            return EngineTranscript(
                text="",
                language=self.language or self.settings.default_language,
                duration_ms=0,
                engine="whisper-cli",
            )

        return await self._transcribe_bytes(bytes(self.active_buffer), duration_ms=self.duration_ms())

    async def _transcribe_bytes(self, pcm_bytes: bytes, *, duration_ms: int | None = None) -> EngineTranscript:
        if not pcm_bytes:
            return EngineTranscript(
                text="",
                language=self.language or self.settings.default_language,
                duration_ms=0,
                engine="whisper-cli",
            )

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as handle:
            wav_path = Path(handle.name)

        try:
            await asyncio.to_thread(self._write_wav, wav_path, pcm_bytes)
            return await self.engine.transcribe(
                wav_path,
                language=self.language,
                prompt=self.prompt,
                duration_ms=duration_ms or self._duration_ms_for_bytes(len(pcm_bytes)),
            )
        finally:
            wav_path.unlink(missing_ok=True)

    def _write_wav(self, wav_path: Path, pcm_bytes: bytes) -> None:
        with wave.open(str(wav_path), "wb") as wav_file:
            wav_file.setnchannels(self.settings.channels)
            wav_file.setsampwidth(2)
            wav_file.setframerate(self.settings.sample_rate)
            wav_file.writeframes(pcm_bytes)

    def _append_pcm(self, pcm_bytes: bytes) -> None:
        if not pcm_bytes:
            return

        chunk_ms = self._duration_ms_for_bytes(len(pcm_bytes))
        if self._has_speech(pcm_bytes):
            self.active_buffer.extend(pcm_bytes)
            self._current_speech_ms += chunk_ms
            self._current_silence_ms = 0
            return

        if not self.active_buffer:
            return

        self.active_buffer.extend(pcm_bytes)
        self._current_silence_ms += chunk_ms
        if (
            self._current_speech_ms >= self.settings.vad_min_speech_ms
            and self._current_silence_ms >= self.settings.vad_end_silence_ms
        ):
            self._ready_utterance = bytes(self.active_buffer)
            self.active_buffer.clear()
            self._current_speech_ms = 0
            self._current_silence_ms = 0

    def _has_speech(self, pcm_bytes: bytes) -> bool:
        try:
            samples = array("h")
            samples.frombytes(pcm_bytes)
        except ValueError:
            return False

        if not samples:
            return False

        energy = sum(abs(sample) for sample in samples) / len(samples)
        return energy >= self.settings.vad_energy_threshold

    def _duration_ms_for_bytes(self, byte_count: int) -> int:
        bytes_per_sample = 2 * self.settings.channels
        if bytes_per_sample <= 0:
            return 0
        total_samples = byte_count / bytes_per_sample
        return int((total_samples / self.settings.sample_rate) * 1000)

    def _total_duration_ms(self) -> int:
        committed_duration = self._committed_audio_ms
        if self._ready_utterance is not None:
            committed_duration += self._duration_ms_for_bytes(len(self._ready_utterance))
        committed_duration += self.duration_ms()
        return committed_duration

    def _join_texts(self, *parts: str) -> str:
        cleaned = [part.strip() for part in parts if part and part.strip()]
        return " ".join(cleaned)
