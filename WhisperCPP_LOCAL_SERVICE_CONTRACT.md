# WhisperCPP Local Service Contract

This file records the intended single-machine local mode for the Mac-hosted gateway.

## Scope

- One Mac runs one local gateway process.
- Other apps on the same Mac reuse that gateway instead of embedding their own local ASR server.
- iPhone and iPad do **not** use this gateway in the chosen setup.
- iPhone and iPad keep using their own on-device transcription.

## Fixed Local Address

- Base URL: `http://127.0.0.1:8765`
- Health URL: `http://127.0.0.1:8765/healthz`
- Capabilities URL: `http://127.0.0.1:8765/v1/asr/capabilities`
- File transcription URL: `http://127.0.0.1:8765/v1/asr/transcribe`
- Realtime WebSocket URL: `ws://127.0.0.1:8765/v1/asr/stream`

## Discovery File

Other Mac apps should first try to read:

`~/Library/Application Support/WhisperCPP/service.json`

Expected fields:

- `status`: one of `running`, `stopped`, `needs_configuration`, or `error`
- `configured`: whether the local gateway is configured well enough to start
- `base_url`
- `health_url`
- `capabilities_url`
- `transcribe_url`
- `stream_url`
- `pid`
- `env_file`
- `log_file`
- `updated_at`

## Recommended Client Flow

1. Read `~/Library/Application Support/WhisperCPP/service.json` if it exists.
2. If `status` is `running`, call `health_url`.
3. If `status` is `stopped` or `needs_configuration`, prompt the user to launch [WhisperCPP_gateway_control.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_gateway_control.command).
4. Use `base_url` and `stream_url` from the discovery file instead of hard-coding different ports.

For day-to-day use, prefer the dedicated launchers:

- [WhisperCPP_start_gateway.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_start_gateway.command)
- [WhisperCPP_stop_gateway.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_stop_gateway.command)

## Human Control Surface

- Launcher: [WhisperCPP_gateway_control.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_gateway_control.command)
- Start launcher: [WhisperCPP_start_gateway.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_start_gateway.command)
- Stop launcher: [WhisperCPP_stop_gateway.command](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_stop_gateway.command)
- Config file: [WhisperCPP_gateway.env](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_gateway.env)
- Config template: [WhisperCPP_gateway.env.example](/Users/hmi/Documents/my%20skills/whispercpp-realtime-asr/WhisperCPP_gateway.env.example)

## Runtime Notes

- This mode listens on `127.0.0.1`, so it does not affect normal web browsing.
- Runtime state is stored in `.gateway-runtime/`.
- The discovery file lives under `~/Library/Application Support/WhisperCPP/` because that is a stable per-user location other Mac apps can inspect.
