/// Codes de sortie sémantiques pour la CLI et l'orchestration.
/// Stables : ne JAMAIS réordonner les valeurs (contrat scripté).
public enum ExitCode: Int32, Sendable, CaseIterable {
    case success          = 0
    case genericError     = 1
    case modelUnavailable = 2
    case guardrailBlocked = 3
    case contextOverflow  = 4
    case invalidInput     = 5
    case rateLimited      = 6
}
