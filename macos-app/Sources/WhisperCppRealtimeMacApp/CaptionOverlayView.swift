import SwiftUI

struct CaptionOverlayView: View {
    @ObservedObject var model: ASRAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Realtime Captions")
                        .font(.headline)
                    Text(model.runState.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                }

                Spacer()
            }

            if !model.finalTranscript.isEmpty {
                ScrollView {
                    Text(model.finalTranscript)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 88)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(model.partialTranscript)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Text("Top Pinned")
                    Text("Mode \(model.recognitionModeTitle)")
                    Text("Opacity \(Int(model.overlayOpacity * 100))%")
                    if model.autoCopyFinalText {
                        Text("Auto Copy On")
                    }
                    Text("Hotkey: Ctrl+Option+C starts/stops ASR")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(26)
        .frame(minWidth: 640, maxWidth: 860, minHeight: 170, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.78),
                    Color(red: 0.06, green: 0.19, blue: 0.2).opacity(0.72),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.32), radius: 26, y: 14)
        .padding(10)
    }

    private var statusColor: Color {
        switch model.runState {
        case .idle:
            return .white.opacity(0.7)
        case .starting, .stopping:
            return .orange
        case .live:
            return .mint
        case .error:
            return .red
        }
    }
}
