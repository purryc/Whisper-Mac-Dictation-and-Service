import Foundation

struct GatewayEvent: Decodable {
    let type: String
    let text: String?
    let isFinal: Bool?
    let durationMs: Int?
    let language: String?
    let engine: String?
    let code: String?
    let message: String?
    let sampleRate: Int?
    let channels: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case isFinal = "is_final"
        case durationMs = "duration_ms"
        case language
        case engine
        case code
        case message
        case sampleRate = "sample_rate"
        case channels
    }
}

struct StartMessage: Encodable {
    let type = "start"
    let language: String?
    let prompt: String?
}

struct AudioChunkMessage: Encodable {
    let type = "audio_chunk"
    let audio: String
}

struct FinishMessage: Encodable {
    let type = "finish"
}

struct PingMessage: Encodable {
    let type = "ping"
}
