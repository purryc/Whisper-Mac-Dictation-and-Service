from __future__ import annotations

import base64
import json
from pathlib import Path
from typing import Any

import httpx
import websockets


class ASRClient:
    def __init__(self, base_url: str = "http://127.0.0.1:8765", *, timeout: float = 60.0) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def capabilities(self) -> dict[str, Any]:
        response = httpx.get(f"{self.base_url}/v1/asr/capabilities", timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def transcribe_file(
        self,
        file_path: str | Path,
        *,
        language: str | None = None,
        prompt: str | None = None,
    ) -> dict[str, Any]:
        audio_path = Path(file_path).expanduser().resolve()
        data = {}
        if language:
            data["language"] = language
        if prompt:
            data["prompt"] = prompt

        with audio_path.open("rb") as audio_file:
            files = {"file": (audio_path.name, audio_file, "application/octet-stream")}
            response = httpx.post(
                f"{self.base_url}/v1/asr/transcribe",
                data=data,
                files=files,
                timeout=self.timeout,
            )
        response.raise_for_status()
        return response.json()


class RealtimeASRSession:
    def __init__(self, ws_url: str = "ws://127.0.0.1:8765/v1/asr/stream") -> None:
        self.ws_url = ws_url
        self._websocket: websockets.ClientConnection | None = None

    async def __aenter__(self) -> "RealtimeASRSession":
        self._websocket = await websockets.connect(self.ws_url, max_size=8 * 1024 * 1024)
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        await self.close()

    async def start(self, *, language: str | None = None, prompt: str | None = None) -> None:
        await self._send_json({"type": "start", "language": language, "prompt": prompt})

    async def send_audio_chunk(self, chunk: bytes) -> None:
        await self._send_json(
            {
                "type": "audio_chunk",
                "audio": base64.b64encode(chunk).decode("ascii"),
            }
        )

    async def ping(self) -> None:
        await self._send_json({"type": "ping"})

    async def finish(self) -> None:
        await self._send_json({"type": "finish"})

    async def receive_event(self) -> dict[str, Any]:
        websocket = self._require_socket()
        payload = await websocket.recv()
        return json.loads(payload)

    async def close(self) -> None:
        if self._websocket is not None:
            await self._websocket.close()
            self._websocket = None

    async def _send_json(self, payload: dict[str, Any]) -> None:
        websocket = self._require_socket()
        clean_payload = {key: value for key, value in payload.items() if value is not None}
        await websocket.send(json.dumps(clean_payload))

    def _require_socket(self) -> websockets.ClientConnection:
        if self._websocket is None:
            raise RuntimeError("Open the realtime session with 'async with' before using it.")
        return self._websocket
