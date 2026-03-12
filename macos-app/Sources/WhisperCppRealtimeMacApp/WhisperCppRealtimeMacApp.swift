import AppKit
import SwiftUI

@main
struct WhisperCppRealtimeMacApp: App {
    @StateObject private var model: ASRAppModel
    private let captionWindowController: CaptionWindowController
    private let hotKeyManager: GlobalHotKeyManager

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)

        let model = ASRAppModel()
        let captionWindowController = CaptionWindowController(model: model)
        let hotKeyManager = GlobalHotKeyManager()
        model.attachCaptionWindow(captionWindowController)
        captionWindowController.show()
        hotKeyManager.registerStartStopHotKey {
            model.toggleASRFromHotKey()
        }

        _model = StateObject(wrappedValue: model)
        self.captionWindowController = captionWindowController
        self.hotKeyManager = hotKeyManager
    }

    var body: some Scene {
        MenuBarExtra("Local ASR", systemImage: model.isLive ? "waveform.circle.fill" : "waveform.circle") {
            ControlCenterView(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("WhisperCppRealtimeMacApp")
                    .font(.headline)
                Text("This app reuses the local ASR gateway running on your Mac.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 320)
        }
    }
}
