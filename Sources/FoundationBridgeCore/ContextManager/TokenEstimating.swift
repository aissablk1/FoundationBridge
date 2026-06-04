/// Abstraction du comptage de tokens. Le backend réel (plan 02) utilisera
/// `tokenCount(for:)` d'Apple ; ici un estimateur heuristique portable sert
/// aux tests et de repli hors device.
public protocol TokenEstimating: Sendable {
    func estimatedTokens(_ text: String) -> Int
}

/// Heuristique simple : ~4 caractères par token (ordre de grandeur de l'anglais/français).
/// À remplacer par le tokenizer EXACT d'Apple côté backend (cf. risque R4 du spec).
public struct HeuristicTokenEstimator: TokenEstimating {
    public init() {}
    public func estimatedTokens(_ text: String) -> Int {
        max(1, Int((Double(text.count) / 4.0).rounded(.up)))
    }
}
