# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-03-12

This is the first formalized working backup release of the project.

### Added

- Local WhisperCPP gateway with stable `HTTP` and `WebSocket` endpoints.
- Single-machine Mac launcher flow with dedicated `start` and `stop` command files.
- Machine-readable local service discovery via `~/Library/Application Support/WhisperCPP/service.json`.
- Python SDK and JavaScript SDK packages for reuse from other apps.
- Native macOS SwiftUI menu bar app with floating live captions.
- Global hotkey `Control + Option + C` for starting and stopping ASR.
- Auto-copy of finalized transcript text to the clipboard.
- Formal project scaffolding via `.specify/`.

### Changed

- Standardized project naming around `WhisperCPP`.
- Switched the bundled local model guidance from `ggml-base.bin` to `ggml-small.bin`.
- Added explicit recognition modes in the macOS app: `Auto`, `Chinese + English`, and `English`.
- Made `Chinese + English` the default app mode because it performs better for Chinese-first mixed speech.
- Updated the realtime path to segment speech on pauses so mixed-language sessions are less likely to be dominated by the first detected language.

### Fixed

- Fixed multiple macOS app crashes caused by actor isolation on Core Audio realtime threads.
- Fixed local gateway startup so the service stays alive in its own Terminal window instead of dying with the launcher shell.
- Fixed WebSocket support for the local gateway environment.
- Fixed stale user-facing naming and documentation drift between earlier FunASR discussion and the actual whisper.cpp implementation.

### Documented

- Local service contract for same-machine app reuse.
- Native macOS app run, export, and operating notes.
- Mixed-language guidance for `Auto` versus `Chinese + English` versus `English`.
- Formal release notes for the stabilized backup version.
