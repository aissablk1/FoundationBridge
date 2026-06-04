/// Options de génération indépendantes du backend.
public struct GenerationOptions: Sendable, Equatable {
    public var temperature: Double?
    public var maximumTokens: Int?
    public var instructions: String?

    public init(temperature: Double? = nil, maximumTokens: Int? = nil, instructions: String? = nil) {
        self.temperature = temperature
        self.maximumTokens = maximumTokens
        self.instructions = instructions
    }
}

/// Abstraction du moteur de génération. Le backend FoundationModels (plan 02)
/// et le mock (tests) la conforment. Tout le code transport dépend de CETTE
/// interface, jamais directement de FoundationModels.
public protocol TextGenerating: Sendable {
    /// Réponse complète (non-stream).
    func respond(to prompt: String, options: GenerationOptions) async throws -> String

    /// Flux de chunks (streaming). Pour FoundationModels : mappé sur les snapshots partiels.
    func stream(to prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error>
}
