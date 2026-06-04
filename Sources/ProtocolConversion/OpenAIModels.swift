/// Modèles Codable de l'API OpenAI Chat Completions (sous-ensemble v1).
public struct OpenAIChatMessage: Codable, Sendable, Equatable {
    public let role: String
    public let content: String
    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct OpenAIChatRequest: Codable, Sendable, Equatable {
    public let model: String
    public let messages: [OpenAIChatMessage]
    public let maxTokens: Int?
    public let temperature: Double?
    public let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

public struct OpenAIChoice: Codable, Sendable, Equatable {
    public let index: Int
    public let message: OpenAIChatMessage
    public let finishReason: String
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

public struct OpenAIChatResponse: Codable, Sendable, Equatable {
    public let id: String
    public let object: String
    public let model: String
    public let choices: [OpenAIChoice]
}
