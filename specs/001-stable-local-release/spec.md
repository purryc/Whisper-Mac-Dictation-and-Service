# Feature Specification: Stable Local WhisperCPP Dictation Release

**Feature Branch**: `[001-stable-local-release]`  
**Created**: 2026-03-12  
**Status**: Implemented  
**Input**: User description: "Record all updates as a formal version and back up the final working project to GitHub."

## User Scenarios & Testing

### User Story 1 - Reuse One Local Service Across Mac Apps (Priority: P1)

A Mac user wants one local ASR service that multiple applications on the same machine can reuse.

**Independent Test**: Start the gateway, call `GET /healthz`, and connect a client over `ws://127.0.0.1:8765/v1/asr/stream`.

**Acceptance Scenarios**:

1. **Given** the runtime is installed, **When** the user launches the start command, **Then** the gateway stays alive in its own Terminal window.
2. **Given** another local app wants speech-to-text, **When** it reads the discovery file and then calls the gateway, **Then** it does not need to embed whisper.cpp setup directly.

### User Story 2 - Dictate From A Native macOS App (Priority: P1)

A Mac user wants a menu bar app that can start dictation, keep captions visible, and avoid crashing during live microphone capture.

**Independent Test**: Open the exported `.app`, start ASR, speak, and observe captions updating without a crash.

**Acceptance Scenarios**:

1. **Given** the gateway is healthy, **When** the user presses `Start ASR`, **Then** the app begins streaming microphone audio and shows live captions.
2. **Given** the app is live, **When** the user presses `Stop`, **Then** the current utterance is finalized and the app stays running.

### User Story 3 - Handle Chinese And English Better (Priority: P2)

A mixed-language speaker wants Chinese and English dictation to behave better than a single auto-detected session buffer.

**Independent Test**: Speak Chinese and English phrases with short pauses and verify the partial and final transcript can preserve both languages more reliably than the earlier whole-buffer approach.

**Acceptance Scenarios**:

1. **Given** the user selects `Chinese + English`, **When** they speak Chinese-first mixed speech, **Then** Chinese is more likely to remain Hanzi while English phrases still come through.
2. **Given** the user selects `Auto`, **When** whisper.cpp auto-detects language, **Then** the project documentation warns that mixed speech may still produce pinyin.

## Requirements

### Functional Requirements

- **FR-001**: The project MUST expose a reusable local gateway on `127.0.0.1:8765`.
- **FR-002**: The project MUST include dedicated start and stop launchers for the local gateway.
- **FR-003**: The project MUST include a machine-readable discovery file for other Mac apps.
- **FR-004**: The project MUST include a native macOS companion app with live captions and start or stop controls.
- **FR-005**: The native app MUST support explicit recognition modes for `Auto`, `Chinese + English`, and `English`.
- **FR-006**: The realtime session strategy MUST segment speech on pauses to reduce mixed-language drift.
- **FR-007**: The repository MUST include a formal changelog and release notes for the first stabilized backup version.
- **FR-008**: The repository MUST not require committing local models, virtual environments, or generated `.app` bundles.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A user can install, start, and use the local service without command-line-only workflow.
- **SC-002**: The native macOS app can dictate live speech without crashing on the target machine.
- **SC-003**: Chinese-first mixed speech performs better in `Chinese + English` mode than in the earlier all-auto whole-buffer setup.
- **SC-004**: The repository can be pushed as a clean backup without machine-specific runtime artifacts.
