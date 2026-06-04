/// Modèles Codable de l'API Anthropic Messages (sous-ensemble v1, contenu texte).
public struct AnthropicMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AnthropicRequest: Codable, Sendable, Equatable {
    public let model: String
    public let messages: [AnthropicMessage]
    public let maxTokens: Int
    public let system: String?
    public let temperature: Double?
    public let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature, stream
        case maxTokens = "max_tokens"
    }
}

public struct AnthropicContentBlock: Codable, Sendable, Equatable {
    public let type: String
    public let text: String
}

public struct AnthropicResponse: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let role: String
    public let model: String
    public let content: [AnthropicContentBlock]
    public let stopReason: String
    enum CodingKeys: String, CodingKey {
        case id, type, role, model, content
        case stopReason = "stop_reason"
    }
}
