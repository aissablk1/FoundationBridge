import FoundationBridgeCore

/// Gestionnaire de sessions de conversation **nommées et multi-tours**, en mémoire
/// (durée de vie du process). Indépendant de FoundationModels : il s'appuie sur
/// l'abstraction `TextGenerating` du cœur, donc testable avec `MockTextGenerator`.
///
/// Mécanisme : « rejeu de transcript ». Le manager conserve l'historique
/// `(rôle, texte)` par session et recompose le contexte à chaque tour avant
/// d'appeler le backend. La réutilisation native d'une `LanguageModelSession`
/// d'Apple (plus efficace) est une optimisation v2.1 documentée — non requise ici.
///
/// Concurrence : **une seule requête en vol par session** (miroir de `isResponding`
/// de FoundationModels). Une requête concurrente sur une session déjà occupée est
/// **rejetée** avec une `BridgeError` claire (politique « reject » ; la mise en file
/// est une option v2.1).
public actor SessionManager {

    /// Rôle d'un tour de conversation.
    public enum Role: String, Sendable, Equatable {
        case user
        case assistant
    }

    /// Un tour de conversation enregistré dans l'historique.
    public struct Turn: Sendable, Equatable {
        public let role: Role
        public let text: String
        public init(role: Role, text: String) {
            self.role = role
            self.text = text
        }
    }

    /// Vue immuable de l'état d'une session (pour `list()` / introspection).
    public struct Snapshot: Sendable, Equatable {
        public let id: String
        public let turnCount: Int
        public let instructions: String?
    }

    /// État interne mutable d'une session.
    private struct State {
        var instructions: String?
        var history: [Turn]
        var busy: Bool
    }

    private let backend: any TextGenerating
    private let contextManager: ContextManager
    private var sessions: [String: State] = [:]

    public init(backend: any TextGenerating, contextManager: ContextManager = .init()) {
        self.backend = backend
        self.contextManager = contextManager
    }

    /// Répond dans le contexte de la session `id` (création implicite au premier tour).
    /// Les `instructions` ne sont prises en compte qu'à la **création** de la session.
    @discardableResult
    public func respond(
        session id: String,
        prompt: String,
        options: GenerationOptions = .init()
    ) async throws -> String {
        // Garde « une requête en vol par session » (effective car `busy` est posé
        // avant tout `await`, donc avant tout point de réentrance de l'acteur).
        if sessions[id]?.busy == true {
            throw BridgeError.generic(message: "Session '\(id)' occupée : une requête est déjà en cours.")
        }

        var state = sessions[id] ?? State(instructions: options.instructions, history: [], busy: false)
        state.busy = true
        sessions[id] = state
        defer { sessions[id]?.busy = false }

        let composed = Self.compose(history: state.history, prompt: prompt)

        // Garde-fou fenêtre de contexte (~4096 tokens) sur le contexte recomposé.
        try contextManager.validate(prompt: composed, instructions: state.instructions)

        let effectiveOptions = GenerationOptions(
            temperature: options.temperature,
            maximumTokens: options.maximumTokens,
            instructions: state.instructions
        )
        let answer = try await backend.respond(to: composed, options: effectiveOptions)

        // N'enregistre le tour qu'en cas de succès (un échec ne pollue pas l'historique).
        sessions[id]?.history.append(Turn(role: .user, text: prompt))
        sessions[id]?.history.append(Turn(role: .assistant, text: answer))
        return answer
    }

    /// Nombre de tours enregistrés pour une session (0 si inconnue).
    public func turnCount(session id: String) -> Int {
        sessions[id]?.history.count ?? 0
    }

    /// Historique complet d'une session (vide si inconnue).
    public func history(session id: String) -> [Turn] {
        sessions[id]?.history ?? []
    }

    /// Liste les sessions actives.
    public func list() -> [Snapshot] {
        sessions.map { id, state in
            Snapshot(id: id, turnCount: state.history.count, instructions: state.instructions)
        }
    }

    /// Supprime une session et son historique.
    public func delete(session id: String) {
        sessions[id] = nil
    }

    /// Réinitialise l'historique d'une session sans la supprimer (conserve les instructions).
    public func reset(session id: String) {
        sessions[id]?.history.removeAll()
    }

    // MARK: - Composition du contexte

    /// Recompose le prompt envoyé au backend à partir de l'historique + du nouveau tour.
    /// Premier tour (historique vide) : on transmet le prompt brut, sans balisage.
    static func compose(history: [Turn], prompt: String) -> String {
        guard !history.isEmpty else { return prompt }
        var lines: [String] = []
        for turn in history {
            let tag = (turn.role == .user) ? "Utilisateur" : "Assistant"
            lines.append("\(tag): \(turn.text)")
        }
        lines.append("Utilisateur: \(prompt)")
        lines.append("Assistant:")
        return lines.joined(separator: "\n")
    }
}
