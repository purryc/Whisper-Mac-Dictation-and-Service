from __future__ import annotations

import asyncio
import base64
import json
import sys
from pathlib import Path

import websockets


async def main() -> None:
    if len(sys.argv) < 2:
        raise SystemExit("Usage: python python_stream_client.py /absolute/path/to/audio.pcm [ws_url]")

    pcm_path = Path(sys.argv[1]).expanduser().resolve()
    ws_url = sys.argv[2] if len(sys.argv) > 2 else "ws://127.0.0.1:8765/v1/asr/stream"

    async with websockets.connect(ws_url, max_size=8 * 1024 * 1024) as websocket:
        await websocket.send(json.dumps({"type": "start", "language": "auto"}))
        print(await websocket.recv())

        chunk_size = 3200
        with pcm_path.open("rb") as handle:
            while True:
                chunk = handle.read(chunk_size)
                if not chunk:
                    break
                await websocket.send(
                    json.dumps(
                        {
                            "type": "audio_chunk",
                            "audio": base64.b64encode(chunk).decode("ascii"),
                        }
                    )
                )
                try:
                    message = await asyncio.wait_for(websocket.recv(), timeout=0.15)
                    print(message)
                except TimeoutError:
                    pass

        await websocket.send(json.dumps({"type": "finish"}))
        try:
            while True:
                print(await websocket.recv())
        except websockets.ConnectionClosed:
            return


if __name__ == "__main__":
    asyncio.run(main())
