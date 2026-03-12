from __future__ import annotations

import json
import tempfile
import wave
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from .config import Settings
from .engine import WhisperCliEngine
from .models import (
    ErrorEvent,
    PartialEvent,
    SessionFinalEvent,
    SessionStartedEvent,
    TranscriptResponse,
)
from .streaming import RealtimeSession


def create_app(settings: Optional[Settings] = None) -> FastAPI:
    settings = settings or Settings.from_env()
    engine = WhisperCliEngine(settings)
    ui_dir = Path(__file__).parent / "ui"

    app = FastAPI(
        title="Whisper.cpp Realtime ASR Gateway",
        version="0.1.0",
        summary="Reusable local HTTP and WebSocket ASR wrapper for whisper.cpp",
    )
    app.mount("/ui", StaticFiles(directory=ui_dir), name="ui")

    @app.get("/")
    async def home() -> FileResponse:
        return FileResponse(ui_dir / "index.html")

    @app.get("/healthz")
    async def healthz() -> dict[str, object]:
        return {
            "ok": True,
            "configured": settings.configured,
            "sample_rate": settings.sample_rate,
            "channels": settings.channels,
        }

    @app.get("/v1/asr/capabilities")
    async def capabilities() -> dict[str, object]:
        return {
            "transport": {"http": True, "websocket": True},
            "ui": {"enabled": True, "path": "/"},
            "streaming_audio": {
                "encoding": "pcm_s16le_base64",
                "sample_rate": settings.sample_rate,
                "channels": settings.channels,
            },
            "engine": {"configured": settings.configured, "name": "whisper-cli"},
        }

    @app.post("/v1/asr/transcribe", response_model=TranscriptResponse)
    async def transcribe(
        file: UploadFile = File(...),
        language: Optional[str] = Form(default=None),
        prompt: Optional[str] = Form(default=None),
    ) -> TranscriptResponse:
        suffix = Path(file.filename or "upload.wav").suffix or ".wav"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as handle:
            temp_path = Path(handle.name)
            while True:
                chunk = await file.read(1024 * 1024)
                if not chunk:
                    break
                handle.write(chunk)

        try:
            duration_ms = _try_read_wav_duration_ms(temp_path)
            result = await engine.transcribe(
                temp_path,
                language=language,
                prompt=prompt,
                duration_ms=duration_ms,
            )
        except Exception as exc:  # pragma: no cover - FastAPI runtime path
            return JSONResponse(
                status_code=400,
                content=ErrorEvent(code="TRANSCRIBE_FAILED", message=str(exc)).model_dump(),
            )
        finally:
            temp_path.unlink(missing_ok=True)

        return TranscriptResponse(
            text=result.text,
            language=result.language,
            duration_ms=result.duration_ms,
            engine=result.engine,
            metadata=result.metadata,
        )

    @app.websocket("/v1/asr/stream")
    async def stream(websocket: WebSocket) -> None:
        await websocket.accept()
        session: Optional[RealtimeSession] = None
        try:
            while True:
                payload = await websocket.receive_text()
                try:
                    message = json.loads(payload)
                except json.JSONDecodeError:
                    await websocket.send_json(
                        ErrorEvent(code="BAD_JSON", message="Message body must be valid JSON.").model_dump()
                    )
                    continue

                message_type = message.get("type")

                if message_type == "start":
                    session = RealtimeSession(
                        engine,
                        settings,
                        language=message.get("language"),
                        prompt=message.get("prompt"),
                    )
                    await websocket.send_json(
                        SessionStartedEvent(
                            sample_rate=settings.sample_rate,
                            channels=settings.channels,
                        ).model_dump()
                    )
                    continue

                if message_type == "ping":
                    await websocket.send_json({"type": "pong"})
                    continue

                if session is None:
                    await websocket.send_json(
                        ErrorEvent(
                            code="SESSION_NOT_STARTED",
                            message="Send a start message before streaming audio.",
                        ).model_dump()
                    )
                    continue

                if message_type == "audio_chunk":
                    encoded_audio = message.get("audio")
                    if not encoded_audio:
                        await websocket.send_json(
                            ErrorEvent(
                                code="MISSING_AUDIO",
                                message="audio_chunk messages require a base64 audio field.",
                            ).model_dump()
                        )
                        continue
                    try:
                        session.append_base64_pcm(encoded_audio)
                    except Exception as exc:
                        await websocket.send_json(
                            ErrorEvent(code="BAD_AUDIO_CHUNK", message=str(exc)).model_dump()
                        )
                        continue

                    if session.should_emit_partial():
                        try:
                            partial = await session.transcribe_partial()
                        except Exception as exc:
                            await websocket.send_json(
                                ErrorEvent(code="PARTIAL_FAILED", message=str(exc)).model_dump()
                            )
                            continue
                        if partial is not None:
                            await websocket.send_json(
                                PartialEvent(text=partial.text).model_dump()
                            )
                    continue

                if message_type == "finish":
                    try:
                        final_result = await session.transcribe_final()
                    except Exception as exc:
                        await websocket.send_json(
                            ErrorEvent(code="FINAL_FAILED", message=str(exc)).model_dump()
                        )
                        await websocket.close(code=1011)
                        return

                    await websocket.send_json(
                        SessionFinalEvent(
                            text=final_result.text,
                            duration_ms=final_result.duration_ms,
                            language=final_result.language,
                            engine=final_result.engine,
                        ).model_dump()
                    )
                    await websocket.close()
                    return

                await websocket.send_json(
                    ErrorEvent(
                        code="BAD_MESSAGE",
                        message=f"Unsupported message type: {message_type!r}",
                    ).model_dump()
                )
        except WebSocketDisconnect:
            return

    return app


def _try_read_wav_duration_ms(audio_path: Path) -> int:
    try:
        with wave.open(str(audio_path), "rb") as wav_file:
            frame_count = wav_file.getnframes()
            frame_rate = wav_file.getframerate()
            if frame_rate <= 0:
                return 0
            return int((frame_count / frame_rate) * 1000)
    except wave.Error:
        return 0
