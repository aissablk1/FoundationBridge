import Foundation
import FoundationBridgeCore
import FoundationBridgeSession

/// Descripteur d'outil MCP, indépendant du SDK (pour la liste + les tests).
public struct MCPToolDescriptor: Sendable, Equatable {
    public let name: String
    public let description: String
    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// Résultat neutre d'un appel d'outil, mappé ensuite sur `CallTool.Result` du SDK.
public struct MCPToolResult: Sendable, Equatable {
    public let text: String
    public let isError: Bool
    public init(text: String, isError: Bool) {
        self.text = text
        self.isError = isError
    }
}

/// Routeur d'outils MCP : **logique pure**, sans dépendance au transport ni au SDK MCP.
/// Testable de bout en bout avec `MockTextGenerator`. Le câblage stdio JSON-RPC vit
/// dans `MCPServerRunner`, qui se contente de traduire les types du SDK vers/depuis ce routeur.
public actor MCPToolRouter {
    private let backend: any TextGenerating
    private let sessions: SessionManager
    private let modelId: String
    /// Fournit l'état de disponibilité courant du modèle on-device. Injecté car le
    /// module MCP n'importe PAS FoundationModels (testable sur mock) ; la CLI passe
    /// `FoundationModelsGenerator.modelAvailability`. Défaut : `.available`.
    private let availabilityProvider: @Sendable () -> ModelAvailability

    public init(
        backend: any TextGenerating,
        modelId: String = "apple-foundation",
        availability: @escaping @Sendable () -> ModelAvailability = { .available }
    ) {
        self.backend = backend
        self.sessions = SessionManager(backend: backend)
        self.modelId = modelId
        self.availabilityProvider = availability
    }

    /// Outils exposés. `nonisolated` car purement statique (utilisable depuis le handler ListTools).
    public nonisolated func listTools() -> [MCPToolDescriptor] {
        [
            MCPToolDescriptor(
                name: "generate",
                description: "Génère une réponse on-device via le LLM d'Apple (FoundationModels). "
                    + "Argument 'prompt' requis ; 'session' optionnel pour une conversation multi-tours."
            ),
            MCPToolDescriptor(
                name: "list_models",
                description: "Liste le modèle on-device : identifiant, état de disponibilité "
                    + "(`ready`) et raison (`status`). JSON forme liste OpenAI."
            ),
        ]
    }

    /// Exécute un outil par son nom à partir d'arguments déjà aplatis en chaînes.
    public func callTool(name: String, arguments: [String: String]) async -> MCPToolResult {
        switch name {
        case "generate":
            let prompt = (arguments["prompt"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else {
                return MCPToolResult(text: "Argument 'prompt' requis et non vide.", isError: true)
            }
            do {
                let text: String
                if let session = arguments["session"], !session.isEmpty {
                    text = try await sessions.respond(session: session, prompt: prompt)
                } else {
                    text = try await backend.respond(to: prompt, options: .init())
                }
                return MCPToolResult(text: text, isError: false)
            } catch let error as BridgeError {
                return MCPToolResult(text: error.message, isError: true)
            } catch {
                return MCPToolResult(text: String(describing: error), isError: true)
            }

        case "list_models":
            // Expose l'id du modèle ET son état de disponibilité réel, afin qu'un
            // client MCP (Claude Desktop/Code, Cursor, Zed) sache si le modèle
            // on-device est prêt (`ready`) ou pourquoi il ne l'est pas (`status`).
            let availability = availabilityProvider()
            let info = ModelListPayload(
                data: [ModelInfo(id: modelId, ready: availability.isReady, status: availability.reason)]
            )
            return MCPToolResult(text: Self.encode(info), isError: false)

        default:
            return MCPToolResult(text: "Outil inconnu : \(name)", isError: true)
        }
    }

    // MARK: - Sérialisation `list_models`

    /// Un modèle exposé par `list_models` (id + état de disponibilité on-device).
    struct ModelInfo: Codable, Equatable {
        let id: String
        let ready: Bool
        let status: String
    }

    /// Enveloppe `list_models` (forme « liste » familière des clients OpenAI).
    struct ModelListPayload: Codable, Equatable {
        let object: String
        let data: [ModelInfo]
        init(data: [ModelInfo]) {
            self.object = "list"
            self.data = data
        }
    }

    /// Encode en JSON compact et déterministe (clés triées) pour des tests stables.
    static func encode(_ payload: ModelListPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else {
            return #"{"object":"list","data":[]}"#
        }
        return text
    }
}
