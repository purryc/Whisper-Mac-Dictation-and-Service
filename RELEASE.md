# WhisperCPP Dictation and Local ASR Service

## Release `v0.2.0`

`v0.2.0` is the first stable backup release of this project.

It packages the working local speech-to-text stack into a form that is practical to reuse across apps on the same Mac:

- a local WhisperCPP gateway with `HTTP` and `WebSocket` APIs
- a native macOS menu bar companion app with floating live captions
- Python and JavaScript SDKs for other projects
- double-clickable local runtime and gateway launchers
- machine-readable local service discovery

## What This Release Delivers

### 1. One local ASR service for many Mac apps

The gateway runs on:

- `http://127.0.0.1:8765`

Other local apps can reuse the same service instead of embedding their own whisper.cpp setup.

Available endpoints:

- `GET /healthz`
- `GET /v1/asr/capabilities`
- `POST /v1/asr/transcribe`
- `WS /v1/asr/stream`

### 2. A native macOS dictation app

The repository includes a SwiftUI menu bar app that can:

- start and stop live dictation
- keep a floating caption overlay visible
- use a global `Control + Option + C` hotkey
- auto-copy finalized transcript text
- talk to the same local gateway used by other apps

### 3. Better mixed-language handling

This release improves Chinese and English dictation in two ways:

- the recommended bundled model moved from `ggml-base.bin` to `ggml-small.bin`
- the realtime path now segments speech on pauses instead of repeatedly retranscribing one growing session buffer

The macOS app also exposes explicit recognition modes:

- `Auto`
- `Chinese + English`
- `English`

`Chinese + English` is the default mode for this release because it performs better than full auto for Chinese-first mixed speech.

## Recommended Local Workflow

1. Run `WhisperCPP_install_runtime.command` once.
2. Run `WhisperCPP_start_gateway.command`.
3. Open `WhisperCppRealtimeMacApp.app`.
4. Choose `Chinese + English` for Chinese-first mixed dictation.
5. Use `WhisperCPP_stop_gateway.command` when you want to shut the local service down.

## Stability Notes

This release includes fixes for:

- macOS app crashes caused by Swift actor isolation crossing Core Audio realtime callbacks
- gateway lifetime problems where the service died with the launcher shell
- local WebSocket runtime support issues
- naming and documentation drift from earlier drafts

## Known Limits

- `Auto` mode may still render Chinese as pinyin in some mixed-language sessions. That is a whisper.cpp behavior, not just a UI issue.
- The realtime path is intentionally lightweight and pause-based. It is not a full token-streaming decoder.
- Local models, virtual environments, runtime logs, and exported `.app` bundles are intentionally not committed to the repository.

## Important Files

- `README.md`
- `CHANGELOG.md`
- `WhisperCPP_LOCAL_SERVICE_CONTRACT.md`
- `docs/releases/v0.2.0.md`
- `macos-app/README.md`

## Repository State For This Release

- Git commit: `a2b6009`
- Git tag: `v0.2.0`

This release is intended to be the first clean, documented, reproducible backup point for the project.
