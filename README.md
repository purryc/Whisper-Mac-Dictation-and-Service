# Whisper Mac Dictation and Service

Local WhisperCPP dictation for macOS, plus a reusable local ASR service for other apps on the same machine.

Current stable release: `v0.2.0`

## Highlights

- Native macOS menu bar app with floating live captions
- One local gateway at `http://127.0.0.1:8765` for reuse across Mac apps
- `HTTP` file transcription and `WebSocket` realtime streaming
- Python SDK and JavaScript SDK for other projects
- Dedicated `start` and `stop` launchers for the local gateway
- Mixed Chinese and English support with explicit recognition modes

## Best For

- Personal Mac dictation
- Internal tools that need local speech-to-text
- Reusing one local ASR service across multiple desktop or browser apps
- Chinese-first mixed speech with English terms

## Fast Start

1. Run `WhisperCPP_install_runtime.command` once.
2. Run `WhisperCPP_start_gateway.command`.
3. Open `WhisperCppRealtimeMacApp.app`.
4. Pick `Chinese + English` for Chinese-first mixed dictation.

This project is built around a simple boundary: every app talks to one local service instead of embedding whisper.cpp integration details separately.

Formal release notes live at [RELEASE.md](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/RELEASE.md) and [docs/releases/v0.2.0.md](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/docs/releases/v0.2.0.md), and the running change history lives at [CHANGELOG.md](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/CHANGELOG.md).

## Why this shape

For multi-project reuse, the most stable boundary is:

1. one local service process
2. one normalized protocol
3. zero direct whisper.cpp coupling in product code

That lets web apps, desktop apps, mobile clients, scripts, and agent workflows all share the same contract.

## What is included

- `POST /v1/asr/transcribe` for full audio files
- `WS /v1/asr/stream` for realtime partial and final events
- `GET /v1/asr/capabilities` and `GET /healthz`
- `WhisperCliEngine` as the default adapter

## Constraints of the initial implementation

The realtime path is intentionally simple:

- it buffers PCM16 mono 16k chunks
- it uses a lightweight pause detector so each utterance is committed separately
- it periodically retranscribes only the current in-flight utterance
- it emits `partial` only when text changes

That means it is good for "speaking while text appears" local prototypes and internal tools. The pause-based segmentation also helps mixed Chinese and English because the language detector gets a shorter utterance instead of one giant session buffer. If you later want lower latency or better long-session behavior, you can keep the same API and replace the engine/session strategy.

## Install

```bash
cd /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
```

If your local `pip` is older and editable install fails, use:

```bash
pip install .
```

If you want the fastest local Mac setup, use the bundled runtime installer instead:

```bash
bash /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr/WhisperCPP_install_runtime.command
```

That installs `whisper-cpp`, downloads a multilingual `ggml-small.bin` model into this project, and updates `WhisperCPP_gateway.env` for you.

## Required environment

```bash
export WHISPER_CPP_BINARY=/absolute/path/to/whisper-cli
export WHISPER_CPP_MODEL=/absolute/path/to/a-multilingual-ggml-model.bin
```

Optional:

```bash
export WHISPER_CPP_DEFAULT_LANGUAGE=auto
export WHISPER_CPP_HOST=127.0.0.1
export WHISPER_CPP_PORT=8765
export WHISPER_CPP_PARTIAL_STEP_MS=700
export WHISPER_CPP_MIN_PARTIAL_MS=1600
```

For mixed Chinese and English:

- use a multilingual Whisper model, not an English-only `.en` model
- prefer `ggml-small.bin` or larger for mixed Chinese and English; `base` is often too biased on short phrases
- `auto` is the most flexible, but it may render Chinese as pinyin in mixed speech
- in the native Mac app, `Chinese + English` is the best default for Chinese-first mixed speech because English terms still come through while Chinese is more likely to stay as Hanzi
- if you mostly speak English, switch the app to `English`

## Run

```bash
whispercpp-asr
```

Open docs at [http://127.0.0.1:8765/docs](http://127.0.0.1:8765/docs).
Open the local UI at [http://127.0.0.1:8765/](http://127.0.0.1:8765/).

## Single-Machine Mac Mode

If you want the simplest local setup, run one gateway on your Mac and let other apps on the same Mac call it at `http://127.0.0.1:8765`.

There is a double-clickable launcher here:

- [WhisperCPP_start_gateway.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_start_gateway.command)
- [WhisperCPP_stop_gateway.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_stop_gateway.command)
- [WhisperCPP_gateway_control.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_gateway_control.command)
- [WhisperCPP_install_runtime.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_install_runtime.command)

Local config template:

- [WhisperCPP_gateway.env.example](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_gateway.env.example)
- Local service contract: [WhisperCPP_LOCAL_SERVICE_CONTRACT.md](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_LOCAL_SERVICE_CONTRACT.md)

Recommended everyday use:

- run `WhisperCPP_install_runtime.command` once if you want the runtime and model set up automatically
- start the gateway with `WhisperCPP_start_gateway.command`
- stop the gateway with `WhisperCPP_stop_gateway.command`
- the start script opens a dedicated Terminal window that keeps the local gateway alive
- `WhisperCPP_gateway_control.command` still exists as a toggle, but the separate start and stop launchers are safer

How it works:

- the first launch creates `WhisperCPP_gateway.env` if it does not exist
- the start launcher keeps the gateway running in its own Terminal window so the app can connect reliably

Runtime files stay local to this project:

- `.gateway-runtime/gateway.pid`
- `.gateway-runtime/gateway.log`

This local-Mac mode does not affect your normal web browsing, because it only listens on `127.0.0.1`.

Recommended split:

- Mac apps on this machine use `http://127.0.0.1:8765`
- iPhone and iPad use their own on-device transcription instead of this local gateway

Machine-readable discovery file:

- `~/Library/Application Support/WhisperCPP/service.json`

Other Mac apps should read that file first to learn:

- current status
- whether the gateway is configured
- base URL and endpoint URLs
- PID, log file, and config file paths

## HTTP example

```bash
curl -X POST http://127.0.0.1:8765/v1/asr/transcribe \
  -F "file=@/absolute/path/to/sample.wav" \
  -F "language=auto"
```

Sample response:

```json
{
  "text": "hello world",
  "language": "auto",
  "duration_ms": 2150,
  "engine": "whisper-cli"
}
```

## WebSocket protocol

Connect to `ws://127.0.0.1:8765/v1/asr/stream`.

Client messages:

```json
{ "type": "start", "language": "auto", "prompt": "meeting notes" }
{ "type": "audio_chunk", "audio": "<base64 pcm16le mono 16k>" }
{ "type": "ping" }
{ "type": "finish" }
```

Server messages:

```json
{ "type": "session_started", "sample_rate": 16000, "channels": 1 }
{ "type": "partial", "text": "hello", "is_final": false }
{ "type": "session_final", "text": "hello world", "is_final": true, "duration_ms": 2150 }
{ "type": "error", "code": "BAD_MESSAGE", "message": "..." }
```

There is also a tiny test client at `examples/python_stream_client.py` that sends
PCM16LE chunks from a local `.pcm` file.

## Local Mac UI

Once the service is running, open `http://127.0.0.1:8765/` in Chrome or Safari on your Mac:

- click `Start ASR`
- allow microphone access
- speak naturally
- watch partial and final transcript text appear in the UI

This is intentionally a browser-served local app so you can use it immediately without creating an Xcode project.

## Native macOS App

There is also a native SwiftUI companion app at `macos-app/`.

Open [macos-app/README.md](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/macos-app/README.md) for the run flow. It gives you:

- a menu bar utility
- start and stop controls
- a floating live-caption overlay
- the same gateway protocol as the browser UI and SDKs
- a packaging script that exports a real double-clickable `.app` bundle

## Python SDK

There is a pip-installable client package at `clients/python`.

```bash
cd /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr/clients/python
pip install -e .
```

If your `pip` is older, `pip install .` is the safer fallback.

```python
from whispercpp_asr_client import ASRClient

client = ASRClient("http://127.0.0.1:8765")
print(client.transcribe_file("/absolute/path/to/sample.wav", language="auto"))
```

## npm SDK

There is an npm package at `clients/js`.

```bash
cd /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr/clients/js
npm install
npm run build
```

```ts
import { WhisperCppASRClient } from "whispercpp-asr-client";

const client = new WhisperCppASRClient("http://127.0.0.1:8765");
const result = await client.transcribe({
  audio: new Blob([audioBytes]),
  filename: "sample.wav",
  language: "auto",
});
console.log(result);
```

## Integration pattern for other projects

- Browser or desktop app: capture microphone audio, downsample to PCM16 mono 16k, stream chunks over WebSocket
- Backend or agent: upload audio files with HTTP
- Mobile app: either call this local service on the same machine or expose it on a trusted LAN machine

## Swap the engine later

If you later want to:

- call `whisper-server`
- use a custom native binding
- switch to another engine entirely

keep the same API and replace `WhisperCliEngine` plus the session strategy in `streaming.py`.
