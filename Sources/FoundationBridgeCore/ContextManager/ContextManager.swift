/// Stratégie de gestion de la fenêtre de contexte (cf. apfel).
public enum ContextStrategy: Sendable, Equatable {
    /// Refuse si le total estimé dépasse la limite (le plus sûr ; défaut v1).
    case strict
}

/// Gère la fenêtre de contexte ~4096 tokens du modèle on-device.
/// Lève `BridgeError.contextOverflow` (→ HTTP 413) quand le total dépasse la limite.
public struct ContextManager: Sendable {
    public let limit: Int
    public let strategy: ContextStrategy
    private let estimator: any TokenEstimating

    public init(limit: Int = 4096, strategy: ContextStrategy = .strict, estimator: any TokenEstimating = HeuristicTokenEstimator()) {
        self.limit = limit
        self.strategy = strategy
        self.estimator = estimator
    }

    /// Estime le coût (instructions + prompt) et lève une erreur exploitable si dépassement.
    public func validate(prompt: String, instructions: String?) throws {
        let total = estimator.estimatedTokens(prompt) + estimator.estimatedTokens(instructions ?? "")
        switch strategy {
        case .strict:
            if total > limit {
                throw BridgeError.contextOverflow(tokens: total, limit: limit)
            }
        }
    }
}
