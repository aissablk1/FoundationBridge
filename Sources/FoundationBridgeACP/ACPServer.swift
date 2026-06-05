import Foundation
import FoundationBridgeCore
import FoundationBridgeSession

/// Serveur **ACP** (Agent Client Protocol de Zed) sur stdio : JSON-RPC 2.0 délimité par
/// lignes (ndjson). Implémente le rôle « agent » : `initialize`, `session/new`,
/// `session/prompt` (avec notifications `session/update` streamées).
///
/// Spec : https://agentclientprotocol.com — clés `camelCase`, valeurs de discriminateur
/// `snake_case`, `protocolVersion` entier. Aucun SDK Swift n'existe : la couche JSON-RPC
/// est écrite à la main. La logique de routage (`process`) est **pure et testable** (mock) ;
/// seule `runStdio()` touche les flux.
public actor ACPServer {

    /// Sortie d'un message traité : notifications à émettre (avant la réponse), puis la
    /// réponse (nil pour une notification entrante ou un message ignoré).
    public struct Output: Sendable, Equatable {
        public let notifications: [Data]
        public let response: Data?
        public init(notifications: [Data], response: Data?) {
            self.notifications = notifications
            self.response = response
        }
    }

    private let backend: any TextGenerating
    private let sessions: SessionManager
    private let protocolVersion: Int
    private var sessionCounter = 0

    public init(backend: any TextGenerating, protocolVersion: Int = 1) {
        self.backend = backend
        self.sessions = SessionManager(backend: backend)
        self.protocolVersion = protocolVersion
    }

    /// Traite une ligne JSON-RPC et renvoie les notifications + la réponse éventuelle.
    public func process(_ line: Data) async -> Output {
        guard let object = try? JSONSerialization.jsonObject(with: line),
              let dict = object as? [String: Any] else {
            return Output(notifications: [], response: Self.errorResponse(id: nil, code: -32700, message: "Parse error"))
        }
        let id = dict["id"]
        guard let method = dict["method"] as? String else {
            return Output(notifications: [], response: nil)
        }
        let params = dict["params"] as? [String: Any] ?? [:]

        switch method {
        case "initialize":
            let result: [String: Any] = [
                "protocolVersion": protocolVersion,
                "agentCapabilities": [
                    "promptCapabilities": ["image": false, "audio": false, "embeddedContext": false]
                ],
            ]
            return Output(notifications: [], response: Self.resultResponse(id: id, result: result))

        case "session/new":
            sessionCounter += 1
            let sessionId = "sess_\(sessionCounter)"
            return Output(notifications: [], response: Self.resultResponse(id: id, result: ["sessionId": sessionId]))

        case "session/prompt":
            guard let sessionId = params["sessionId"] as? String, !sessionId.isEmpty else {
                return Output(notifications: [], response: Self.errorResponse(id: id, code: -32602, message: "sessionId requis"))
            }
            let blocks = params["prompt"] as? [[String: Any]] ?? []
            let text = blocks
                .compactMap { ($0["type"] as? String) == "text" ? $0["text"] as? String : nil }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return Output(notifications: [], response: Self.errorResponse(id: id, code: -32602, message: "prompt vide"))
            }
            do {
                // Contexte multi-tours via SessionManager (rejeu de transcript).
                let answer = try await sessions.respond(session: sessionId, prompt: text)
                let note = Self.updateNotification(sessionId: sessionId, text: answer)
                return Output(
                    notifications: [note],
                    response: Self.resultResponse(id: id, result: ["stopReason": "end_turn"])
                )
            } catch let error as BridgeError {
                return Output(notifications: [], response: Self.errorResponse(id: id, code: -32000, message: error.message))
            } catch {
                return Output(notifications: [], response: Self.errorResponse(id: id, code: -32000, message: "Erreur interne"))
            }

        default:
            // Requête → erreur « méthode inconnue » ; notification entrante → ignorée.
            if id == nil { return Output(notifications: [], response: nil) }
            return Output(notifications: [], response: Self.errorResponse(id: id, code: -32601, message: "Méthode inconnue : \(method)"))
        }
    }

    /// Boucle stdio : lit des lignes JSON-RPC sur stdin, écrit notifications + réponses
    /// sur stdout (ndjson). stderr reste libre pour les diagnostics.
    public func runStdio() async {
        let input = FileHandle.standardInput
        var buffer = Data()
        while true {
            let chunk = input.availableData
            if chunk.isEmpty { break } // EOF
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<newline)
                buffer.removeSubrange(buffer.startIndex...newline)
                let trimmed = line.filter { $0 != 0x0D } // retire \r éventuel
                if trimmed.isEmpty { continue }
                let output = await process(trimmed)
                for notification in output.notifications { Self.writeLine(notification) }
                if let response = output.response { Self.writeLine(response) }
            }
        }
    }

    // MARK: - Sérialisation JSON-RPC

    static func resultResponse(id: Any?, result: [String: Any]) -> Data {
        var object: [String: Any] = ["jsonrpc": "2.0", "result": result]
        object["id"] = id ?? NSNull()
        return serialize(object)
    }

    static func errorResponse(id: Any?, code: Int, message: String) -> Data {
        let object: [String: Any] = [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": ["code": code, "message": message],
        ]
        return serialize(object)
    }

    static func updateNotification(sessionId: String, text: String) -> Data {
        serialize([
            "jsonrpc": "2.0",
            "method": "session/update",
            "params": [
                "sessionId": sessionId,
                "update": [
                    "sessionUpdate": "agent_message_chunk",
                    "content": ["type": "text", "text": text],
                ],
            ],
        ])
    }

    static func serialize(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]))
            ?? Data(#"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"serialize"}}"#.utf8)
    }

    static func writeLine(_ data: Data) {
        var line = data
        line.append(0x0A)
        FileHandle.standardOutput.write(line)
    }
}
