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

    public init(backend: any TextGenerating, modelId: String = "apple-foundation") {
        self.backend = backend
        self.sessions = SessionManager(backend: backend)
        self.modelId = modelId
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
                description: "Liste l'identifiant du modèle on-device disponible."
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
            return MCPToolResult(text: modelId, isError: false)

        default:
            return MCPToolResult(text: "Outil inconnu : \(name)", isError: true)
        }
    }
}
