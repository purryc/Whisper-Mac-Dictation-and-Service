# whispercpp-asr-client

Python SDK for the local ASR gateway.

## Install

```bash
cd /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr/clients/python
pip install -e .
```

If your `pip` is old and editable install fails, use `pip install .`.

## File transcription

```python
from whispercpp_asr_client import ASRClient

client = ASRClient("http://127.0.0.1:8765")
result = client.transcribe_file("/absolute/path/to/sample.wav", language="auto")
print(result["text"])
```

## Realtime streaming

```python
import asyncio
from whispercpp_asr_client import RealtimeASRSession


async def main() -> None:
    async with RealtimeASRSession("ws://127.0.0.1:8765/v1/asr/stream") as session:
        await session.start(language="auto")
        await session.send_audio_chunk(b"...pcm16le bytes...")
        print(await session.receive_event())
        await session.finish()
        print(await session.receive_event())


asyncio.run(main())
```
