/// État de disponibilité du modèle on-device, indépendant de FoundationModels.
/// Le backend réel (plan 02) traduit SystemLanguageModel.availability vers ce type.
public enum ModelAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown(String)

    public var isReady: Bool {
        if case .available = self { return true }
        return false
    }

    public var reason: String {
        switch self {
        case .available: return "disponible"
        case .deviceNotEligible: return "appareil non éligible à Apple Intelligence"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence non activé"
        case .modelNotReady: return "modèle en cours de téléchargement / non prêt"
        case .unknown(let s): return s
        }
    }

    /// Renvoie une `BridgeError` actionnable si le modèle n'est pas prêt, sinon nil.
    public func asErrorIfUnavailable() -> BridgeError? {
        isReady ? nil : .modelUnavailable(reason: reason)
    }
}
