import SwiftUI

struct ControlCenterView: View {
    @ObservedObject var model: ASRAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Local ASR Companion")
                    .font(.title3.weight(.semibold))
                Text(model.statusDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Gateway URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("http://127.0.0.1:8765", text: $model.gatewayBaseURL)
                    .textFieldStyle(.roundedBorder)

                Text("Recognition Mode")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Recognition Mode", selection: $model.recognitionMode) {
                    ForEach(RecognitionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(model.recognitionModeHelpText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Prompt (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Leave empty unless you need a bias prompt", text: $model.prompt)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 12) {
                Button(model.isLive ? "Listening..." : "Start ASR") {
                    model.startASR()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isLive)

                Button("Stop") {
                    model.stopASR()
                }
                .buttonStyle(.bordered)
                .disabled(!model.isLive)
            }

            Button("Clear Transcript") {
                model.clearTranscript()
            }
            .buttonStyle(.link)

            Button("Quit App") {
                model.quitApp()
            }
            .buttonStyle(.bordered)

            Toggle("Auto copy final text", isOn: $model.autoCopyFinalText)

            VStack(alignment: .leading, spacing: 6) {
                Text("Caption opacity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $model.overlayOpacity, in: 0.35...1.0)
                Text("Global hotkey: Control + Option + C starts or stops ASR")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Current Partial")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.partialTranscript)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.teal)
                    .fixedSize(horizontal: false, vertical: true)

                if !model.finalTranscript.isEmpty {
                    Text("Final Transcript")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(model.finalTranscript)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
        .padding(18)
        .frame(width: 360)
    }
}
