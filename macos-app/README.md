# WhisperCppRealtimeMacApp

Native macOS SwiftUI companion app for the local ASR gateway.

## What it does

- lives in the macOS menu bar
- starts and stops microphone streaming
- shows a floating live-caption overlay
- pins the caption overlay to the top of the screen
- keeps the caption overlay always visible as part of the app experience
- supports a global `Control + Option + C` shortcut to start or stop ASR
- auto-copies finalized transcript chunks to the clipboard
- includes a `Quit App` control in the menu bar panel so the overlay can be dismissed cleanly
- reuses the existing `ws://127.0.0.1:8765/v1/asr/stream` protocol

## Run

1. Install the local Whisper runtime once with `/Users/hmi/Documents/my skills/whispercpp-realtime-asr/WhisperCPP_install_runtime.command`
2. Start the gateway from `/Users/hmi/Documents/my skills/whispercpp-realtime-asr/WhisperCPP_gateway_control.command`
3. Open this package in Xcode or run it with Swift tooling

### From Xcode

- Open `/Users/hmi/Documents/my skills/whispercpp-realtime-asr/macos-app/Package.swift`
- Choose the `WhisperCppRealtimeMacApp` scheme
- Run the app

### From Terminal

```bash
cd /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr/macos-app
swift run
```

## Export A Double-Clickable `.app`

```bash
cd /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr/macos-app
bash scripts/export_app.sh
```

Export output:

- `dist/WhisperCppRealtimeMacApp.app`
- `dist/WhisperCppRealtimeMacApp.zip`

The generated `.app` bundle includes the menu-bar app metadata and microphone usage text required for native launch.

## Notes

- The app defaults to `http://127.0.0.1:8765`
- You can change the gateway URL and recognition mode in the menu bar control panel
- The app uses `NSApplication.setActivationPolicy(.accessory)` so it behaves like a menu bar utility instead of a dock app
- If you run with `swift run`, macOS microphone permission is usually granted to `Terminal`
- If you run from Xcode, make sure `Xcode` has microphone access in System Settings
- The default global shortcut is `Control + Option + C` for starting or stopping ASR
- Finalized transcript chunks are copied to the clipboard by default and can be disabled in the menu panel
- `Chinese + English` is the default mode because it works better than full auto for Chinese-first mixed speech on the bundled small multilingual model
