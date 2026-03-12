import AppKit
import Foundation
import SwiftUI

enum RecognitionMode: String, CaseIterable, Identifiable {
    case mixed
    case chinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mixed:
            return "Auto"
        case .chinese:
            return "Chinese + English"
        case .english:
            return "English"
        }
    }

    var languageCode: String {
        switch self {
        case .mixed:
            return "auto"
        case .chinese:
            return "zh"
        case .english:
            return "en"
        }
    }

    var helperText: String {
        switch self {
        case .mixed:
            return "Lets whisper.cpp auto-detect the language. Good for quick tests, but Chinese may come back as pinyin in mixed speech."
        case .chinese:
            return "Best for Chinese-first mixed speech. English words still come through, and Chinese is more likely to stay as Hanzi instead of pinyin."
        case .english:
            return "Locks recognition to English. Use this when mixed mode keeps drifting into Chinese."
        }
    }
}

final class AudioChunkSender: @unchecked Sendable {
    private let client: GatewayWebSocketClient
    private let onError: @Sendable (Error) -> Void

    init(client: GatewayWebSocketClient, onError: @escaping @Sendable (Error) -> Void) {
        self.client = client
        self.onError = onError
    }

    func send(_ chunk: Data) {
        Task {
            do {
                try await client.sendAudioChunk(chunk)
            } catch {
                onError(error)
            }
        }
    }
}

@MainActor
final class ASRAppModel: ObservableObject {
    enum RunState: String {
        case idle = "Idle"
        case starting = "Starting"
        case live = "Live"
        case stopping = "Stopping"
        case error = "Error"
    }

    @Published var runState: RunState = .idle
    @Published var statusDetail = "Ready to connect to the local ASR gateway."
    @Published var partialTranscript = "Waiting for speech..."
    @Published var finalTranscript = ""
    @Published var gatewayBaseURL = "http://127.0.0.1:8765"
    @Published var recognitionMode: RecognitionMode = .chinese {
        didSet {
            preferredLanguage = recognitionMode.languageCode
        }
    }
    @Published private(set) var preferredLanguage = RecognitionMode.chinese.languageCode
    @Published var prompt = ""
    @Published var autoCopyFinalText = true
    @Published var overlayOpacity = 0.84 {
        didSet {
            captionWindowController?.updateAppearance(opacity: overlayOpacity)
        }
    }

    private let audioCapture = AudioCaptureService()
    private var gatewayClient: GatewayWebSocketClient?
    private var chunkSender: AudioChunkSender?
    private var captionWindowController: CaptionWindowController?

    func attachCaptionWindow(_ controller: CaptionWindowController) {
        captionWindowController = controller
        controller.updateAppearance(opacity: overlayOpacity)
        controller.show()
    }

    var isLive: Bool {
        runState == .live || runState == .starting || runState == .stopping
    }

    var recognitionModeHelpText: String {
        recognitionMode.helperText
    }

    func startASR() {
        guard !isLive else {
            return
        }

        runState = .starting
        statusDetail = "Connecting to \(gatewayBaseURL)..."
        partialTranscript = "Waiting for speech..."

        let client = GatewayWebSocketClient()
        client.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleGatewayEvent(event)
            }
        }
        client.onDisconnect = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.handleDisconnect(error)
            }
        }
        gatewayClient = client
        let chunkSender = AudioChunkSender(client: client) { [weak self] error in
            Task { @MainActor [weak self] in
                self?.presentError(error)
            }
        }
        self.chunkSender = chunkSender

        Task {
            do {
                try await client.connect(to: gatewayBaseURL)
                try await client.sendStart(language: preferredLanguage, prompt: prompt)
                try await audioCapture.start(onChunk: chunkSender.send)
            } catch {
                await MainActor.run {
                    self.presentError(error)
                }
            }
        }
    }

    func stopASR() {
        guard isLive else {
            return
        }

        runState = .stopping
        statusDetail = "Stopping microphone and finalizing transcript..."
        audioCapture.stop()

        Task {
            do {
                try await gatewayClient?.sendFinish()
            } catch {
                await MainActor.run {
                    self.presentError(error)
                }
            }
        }
    }

    func clearTranscript() {
        finalTranscript = ""
        partialTranscript = "Waiting for speech..."
    }

    func quitApp() {
        audioCapture.stop()
        teardownConnection()
        captionWindowController?.hide()
        NSApp.terminate(nil)
    }

    func toggleASRFromHotKey() {
        if isLive {
            stopASR()
        } else {
            startASR()
        }
    }

    private func handleGatewayEvent(_ event: GatewayEvent) {
        switch event.type {
        case "session_started":
            runState = .live
            statusDetail = "Listening through the local gateway."
        case "partial":
            partialTranscript = event.text?.isEmpty == false ? (event.text ?? "") : "Listening..."
        case "session_final":
            if let text = event.text, !text.isEmpty {
                finalTranscript = [finalTranscript.trimmingCharacters(in: .whitespacesAndNewlines), text]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                copyFinalTextToPasteboard(text)
            }
            partialTranscript = "Waiting for speech..."
            runState = .idle
            statusDetail = "Session finished."
            teardownConnection()
        case "error":
            let message = [event.code, event.message].compactMap { $0 }.joined(separator: ": ")
            presentError(NSError(domain: "GatewayError", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
        case "pong":
            break
        default:
            break
        }
    }

    private func handleDisconnect(_ error: Error?) {
        audioCapture.stop()

        if runState == .idle {
            teardownConnection()
            return
        }

        if let error {
            presentError(error)
            return
        }

        if runState == .stopping {
            runState = .idle
            statusDetail = "Session closed."
            partialTranscript = "Waiting for speech..."
        } else if runState != .error {
            runState = .idle
            statusDetail = "Gateway disconnected."
        }

        teardownConnection()
    }

    private func presentError(_ error: Error) {
        audioCapture.stop()
        runState = .error
        statusDetail = error.localizedDescription
        teardownConnection()
    }

    private func teardownConnection() {
        gatewayClient?.disconnect()
        gatewayClient = nil
        chunkSender = nil
    }

    private func copyFinalTextToPasteboard(_ text: String) {
        guard autoCopyFinalText else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
