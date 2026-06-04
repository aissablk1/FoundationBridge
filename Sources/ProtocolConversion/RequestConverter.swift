import FoundationBridgeCore

/// Extrait un (prompt, options) neutre depuis une requête OpenAI ou Anthropic.
/// C'est le point d'entrée unifié vers `TextGenerating` du cœur.
public enum RequestConverter {

    public static func extract(from req: OpenAIChatRequest) -> (prompt: String, options: GenerationOptions) {
        let system = req.messages.filter { $0.role == "system" }.map(\.content).joined(separator: "\n")
        let turns = req.messages.filter { $0.role != "system" }
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        let options = GenerationOptions(
            temperature: req.temperature,
            maximumTokens: req.maxTokens,
            instructions: system.isEmpty ? nil : system
        )
        return (turns, options)
    }

    public static func extract(from req: AnthropicRequest) -> (prompt: String, options: GenerationOptions) {
        let turns = req.messages
            .map { "\($0.role): \($0.content)" }
            .joined(separator: "\n")
        let options = GenerationOptions(
            temperature: req.temperature,
            maximumTokens: req.maxTokens,
            instructions: req.system
        )
        return (turns, options)
    }
}
