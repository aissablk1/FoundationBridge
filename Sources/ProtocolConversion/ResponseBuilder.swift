import Foundation

/// Construit les réponses OpenAI et Anthropic à partir d'un texte généré par le cœur.
public enum ResponseBuilder {

    public static func openAI(text: String, model: String, id: String = "chatcmpl-\(UUID().uuidString)") -> OpenAIChatResponse {
        OpenAIChatResponse(
            id: id,
            object: "chat.completion",
            model: model,
            choices: [
                OpenAIChoice(
                    index: 0,
                    message: OpenAIChatMessage(role: "assistant", content: text),
                    finishReason: "stop"
                )
            ]
        )
    }

    public static func anthropic(text: String, model: String, id: String = "msg_\(UUID().uuidString)") -> AnthropicResponse {
        AnthropicResponse(
            id: id,
            type: "message",
            role: "assistant",
            model: model,
            content: [AnthropicContentBlock(type: "text", text: text)],
            stopReason: "end_turn"
        )
    }
}
