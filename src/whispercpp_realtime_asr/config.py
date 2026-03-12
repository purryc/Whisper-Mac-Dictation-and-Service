from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass
class Settings:
    host: str = "127.0.0.1"
    port: int = 8765
    whisper_binary: str = ""
    whisper_model: str = ""
    default_language: str = "auto"
    sample_rate: int = 16000
    channels: int = 1
    partial_step_ms: int = 700
    min_partial_ms: int = 1600
    vad_energy_threshold: int = 260
    vad_end_silence_ms: int = 900
    vad_min_speech_ms: int = 350
    command_template: str = "{bin} -m {model} -f {input} {language_flag} {prompt_flag} -np -nt"

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            host=os.getenv("WHISPER_CPP_HOST", "127.0.0.1"),
            port=int(os.getenv("WHISPER_CPP_PORT", "8765")),
            whisper_binary=os.getenv("WHISPER_CPP_BINARY", ""),
            whisper_model=os.getenv("WHISPER_CPP_MODEL", ""),
            default_language=os.getenv("WHISPER_CPP_DEFAULT_LANGUAGE", "auto"),
            sample_rate=int(os.getenv("WHISPER_CPP_SAMPLE_RATE", "16000")),
            channels=int(os.getenv("WHISPER_CPP_CHANNELS", "1")),
            partial_step_ms=int(os.getenv("WHISPER_CPP_PARTIAL_STEP_MS", "700")),
            min_partial_ms=int(os.getenv("WHISPER_CPP_MIN_PARTIAL_MS", "1600")),
            vad_energy_threshold=int(os.getenv("WHISPER_CPP_VAD_ENERGY_THRESHOLD", "260")),
            vad_end_silence_ms=int(os.getenv("WHISPER_CPP_VAD_END_SILENCE_MS", "900")),
            vad_min_speech_ms=int(os.getenv("WHISPER_CPP_VAD_MIN_SPEECH_MS", "350")),
            command_template=os.getenv(
                "WHISPER_CPP_COMMAND_TEMPLATE",
                "{bin} -m {model} -f {input} {language_flag} {prompt_flag} -np -nt",
            ),
        )

    @property
    def configured(self) -> bool:
        return bool(self.whisper_binary and self.whisper_model)
