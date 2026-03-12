import Foundation

enum GatewayClientError: LocalizedError {
    case invalidURL(String)
    case missingSocket
    case unsupportedMessage

    var errorDescription: String? {
        switch self {
        case let .invalidURL(value):
            return "Invalid gateway URL: \(value)"
        case .missingSocket:
            return "Realtime socket is not connected."
        case .unsupportedMessage:
            return "The gateway returned a non-text WebSocket message."
        }
    }
}

final class GatewayWebSocketClient: @unchecked Sendable {
    var onEvent: (@Sendable (GatewayEvent) -> Void)?
    var onDisconnect: (@Sendable (Error?) -> Void)?

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?

    func connect(to baseURL: String) async throws {
        let socketURL = try websocketURL(from: baseURL)
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: socketURL)
        self.session = session
        self.task = task
        task.resume()
        receiveNextMessage()
    }

    func sendStart(language: String?, prompt: String?) async throws {
        try await send(StartMessage(language: emptyToNil(language), prompt: emptyToNil(prompt)))
    }

    func sendAudioChunk(_ chunk: Data) async throws {
        try await send(AudioChunkMessage(audio: chunk.base64EncodedString()))
    }

    func sendFinish() async throws {
        try await send(FinishMessage())
    }

    func ping() async throws {
        try await send(PingMessage())
    }

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    private func send<T: Encodable>(_ message: T) async throws {
        guard let task else {
            throw GatewayClientError.missingSocket
        }
        let payload = try encoder.encode(message)
        guard let text = String(data: payload, encoding: .utf8) else {
            throw GatewayClientError.unsupportedMessage
        }
        try await task.send(.string(text))
    }

    private func receiveNextMessage() {
        guard let task else {
            return
        }

        task.receive { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case let .success(message):
                do {
                    let text: String
                    switch message {
                    case let .string(value):
                        text = value
                    case let .data(data):
                        guard let value = String(data: data, encoding: .utf8) else {
                            throw GatewayClientError.unsupportedMessage
                        }
                        text = value
                    @unknown default:
                        throw GatewayClientError.unsupportedMessage
                    }

                    let event = try self.decoder.decode(GatewayEvent.self, from: Data(text.utf8))
                    self.onEvent?(event)
                    self.receiveNextMessage()
                } catch {
                    self.onDisconnect?(error)
                }
            case let .failure(error):
                self.onDisconnect?(error)
            }
        }
    }

    private func websocketURL(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            throw GatewayClientError.invalidURL(baseURL)
        }

        switch components.scheme?.lowercased() {
        case "https":
            components.scheme = "wss"
        case "http":
            components.scheme = "ws"
        case "wss", "ws":
            break
        default:
            throw GatewayClientError.invalidURL(baseURL)
        }

        components.path = "/v1/asr/stream"
        guard let url = components.url else {
            throw GatewayClientError.invalidURL(baseURL)
        }
        return url
    }

    private func emptyToNil(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
