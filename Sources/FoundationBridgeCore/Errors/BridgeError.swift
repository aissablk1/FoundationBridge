import Foundation

/// Erreur unifiée du cœur, traduisible en code de sortie CLI et en statut HTTP.
public enum BridgeError: Error, Sendable, Equatable {
    case modelUnavailable(reason: String)
    case contextOverflow(tokens: Int, limit: Int)
    case guardrailBlocked(reason: String)
    case invalidInput(field: String)
    case generic(message: String)

    public var exitCode: ExitCode {
        switch self {
        case .modelUnavailable: return .modelUnavailable
        case .contextOverflow:  return .contextOverflow
        case .guardrailBlocked: return .guardrailBlocked
        case .invalidInput:     return .invalidInput
        case .generic:          return .genericError
        }
    }

    /// Statut HTTP exploitable côté client (cf. spec §3 critère 6).
    public var httpStatus: Int {
        switch self {
        case .modelUnavailable: return 503
        case .contextOverflow:  return 413
        case .guardrailBlocked: return 422
        case .invalidInput:     return 400
        case .generic:          return 500
        }
    }

    public var message: String {
        switch self {
        case .modelUnavailable(let r): return "Modèle indisponible : \(r)"
        case .contextOverflow(let t, let l): return "Dépassement de contexte : \(t) tokens > \(l)"
        case .guardrailBlocked(let r): return "Bloqué par les garde-fous : \(r)"
        case .invalidInput(let f): return "Entrée invalide : champ '\(f)'"
        case .generic(let m): return m
        }
    }
}
