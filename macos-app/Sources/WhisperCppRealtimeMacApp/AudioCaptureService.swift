import AVFoundation
import Foundation

enum AudioCaptureError: LocalizedError {
    case permissionDenied
    case missingInputNode

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission was denied."
        case .missingInputNode:
            return "No microphone input node is available on this Mac."
        }
    }
}

final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private let chunkQueue = DispatchQueue(label: "WhisperCppRealtimeMacApp.AudioChunkQueue")
    private var isCapturing = false

    @MainActor
    func start(onChunk: @escaping @Sendable (Data) -> Void) async throws {
        guard await requestPermission() else {
            throw AudioCaptureError.permissionDenied
        }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.channelCount > 0 else {
            throw AudioCaptureError.missingInputNode
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(
            onBus: 0,
            bufferSize: 2048,
            format: inputFormat,
            block: Self.makeTapBlock(chunkQueue: chunkQueue, onChunk: onChunk)
        )

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    @MainActor
    func stop() {
        guard isCapturing else {
            return
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isCapturing = false
    }

    @MainActor
    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func makeTapBlock(
        chunkQueue: DispatchQueue,
        onChunk: @escaping @Sendable (Data) -> Void
    ) -> (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { buffer, _ in
            guard let chunk = Self.makePCMChunk(from: buffer) else {
                return
            }
            chunkQueue.async {
                onChunk(chunk)
            }
        }
    }

    private static func makePCMChunk(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channels = buffer.floatChannelData else {
            return nil
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else {
            return nil
        }

        var monoSamples = [Float](repeating: 0, count: frameCount)
        for frame in 0..<frameCount {
            var sample: Float = 0
            for channel in 0..<channelCount {
                sample += channels[channel][frame]
            }
            monoSamples[frame] = sample / Float(channelCount)
        }

        return downsampleToPCM16(samples: monoSamples, inputSampleRate: buffer.format.sampleRate, outputSampleRate: 16_000)
    }

    private static func downsampleToPCM16(samples: [Float], inputSampleRate: Double, outputSampleRate: Double) -> Data {
        guard !samples.isEmpty else {
            return Data()
        }

        let ratio = inputSampleRate / outputSampleRate
        let outputCount = max(1, Int(Double(samples.count) / ratio))
        var data = Data(capacity: outputCount * 2)
        var offsetBuffer = 0

        for outputIndex in 0..<outputCount {
            let nextOffset = min(samples.count, Int((Double(outputIndex + 1) * ratio).rounded()))
            let upperBound = max(offsetBuffer + 1, nextOffset)
            let slice = samples[offsetBuffer..<min(samples.count, upperBound)]
            let average = slice.reduce(0, +) / Float(slice.count)
            let clamped = max(-1, min(1, average))
            let scaled = clamped < 0 ? clamped * 32768.0 : clamped * 32767.0
            var sample = Int16(scaled).littleEndian
            withUnsafeBytes(of: &sample) { rawBytes in
                data.append(contentsOf: rawBytes)
            }
            offsetBuffer = nextOffset
        }

        return data
    }
}
