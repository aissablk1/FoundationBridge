/// Générateur factice pour les tests : aucune dépendance à FoundationModels.
public struct MockTextGenerator: TextGenerating {
    private let scriptedResponse: String
    private let scriptedChunks: [String]
    private let error: BridgeError?

    public init(scriptedResponse: String = "", scriptedChunks: [String] = [], error: BridgeError? = nil) {
        self.scriptedResponse = scriptedResponse
        self.scriptedChunks = scriptedChunks
        self.error = error
    }

    public func respond(to prompt: String, options: GenerationOptions) async throws -> String {
        if let error { throw error }
        return scriptedResponse
    }

    public func stream(to prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error> {
        let chunks = scriptedChunks
        let error = error
        return AsyncThrowingStream { continuation in
            if let error { continuation.finish(throwing: error); return }
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}
