import Foundation
import MCP

/// Câblage du serveur MCP **stdio** (JSON-RPC) au-dessus du SDK officiel
/// `modelcontextprotocol/swift-sdk`. Ne contient aucune logique métier : il traduit
/// les appels d'outils du SDK vers `MCPToolRouter` et inversement.
///
/// IMPORTANT : en mode MCP, `stdout` est réservé au protocole JSON-RPC. Ne jamais y
/// écrire de texte humain (utiliser `stderr` pour les diagnostics).
public enum MCPServerRunner {

    /// Démarre le serveur MCP sur stdio et bloque jusqu'à fermeture du transport.
    public static func run(
        router: MCPToolRouter,
        name: String = "foundationbridge",
        version: String
    ) async throws {
        let server = Server(
            name: name,
            version: version,
            capabilities: .init(tools: .init(listChanged: false))
        )

        // Liste des outils.
        await server.withMethodHandler(ListTools.self) { _ in
            let tools: [Tool] = router.listTools().map { descriptor in
                if descriptor.name == "generate" {
                    return Tool(
                        name: descriptor.name,
                        description: descriptor.description,
                        inputSchema: .object([
                            "type": .string("object"),
                            "properties": .object([
                                "prompt": .object([
                                    "type": .string("string"),
                                    "description": .string("Le texte à soumettre au modèle on-device."),
                                ]),
                                "session": .object([
                                    "type": .string("string"),
                                    "description": .string("Identifiant de session pour le multi-tours (optionnel)."),
                                ]),
                            ]),
                            "required": .array([.string("prompt")]),
                        ])
                    )
                } else {
                    return Tool(
                        name: descriptor.name,
                        description: descriptor.description,
                        inputSchema: .object([
                            "type": .string("object"),
                            "properties": .object([:]),
                        ])
                    )
                }
            }
            return .init(tools: tools)
        }

        // Appel d'outil : aplatit les arguments en chaînes puis délègue au routeur.
        await server.withMethodHandler(CallTool.self) { params in
            var arguments: [String: String] = [:]
            for (key, value) in params.arguments ?? [:] {
                if let string = value.stringValue {
                    arguments[key] = string
                }
            }
            let result = await router.callTool(name: params.name, arguments: arguments)
            return .init(content: [.text(text: result.text, annotations: nil, _meta: nil)], isError: result.isError)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)
        await server.waitUntilCompleted()
    }
}
