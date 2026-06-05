import Foundation
import Hummingbird
import HummingbirdWebSocket
import FoundationBridgeCore

/// Application Hummingbird **REST + WebSocket**. Ajoute un endpoint full-duplex `/ws` :
/// chaque message texte entrant est traité comme un prompt, et la réponse est streamée
/// token par token en messages texte, terminée par le sentinel `[DONE]`.
extension FoundationBridgeServer {

    public static func makeWebSocketApplication(
        config: ServerConfig = .init(),
        backend: (any TextGenerating)? = nil
    ) -> some ApplicationProtocol {
        let generator: any TextGenerating = backend ?? defaultBackend()
        let router = buildRouter(generator: generator, token: config.token)

        let wsRouter = Router(context: BasicWebSocketRequestContext.self)
        // Auth Bearer sur l'upgrade WebSocket si un token est configuré.
        if let token = config.token, !token.isEmpty {
            wsRouter.add(middleware: BearerAuthMiddleware(token: token))
        }

        wsRouter.ws("/ws") { inbound, outbound, _ in
            for try await message in inbound.messages(maxSize: 1 << 20) {
                guard case .text(let prompt) = message else { continue }
                let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    try await outbound.write(.text(#"{"error":"prompt vide"}"#))
                    continue
                }
                do {
                    for try await chunk in generator.stream(to: trimmed, options: .init()) {
                        try await outbound.write(.text(chunk))
                    }
                    try await outbound.write(.text("[DONE]"))
                } catch {
                    // Détails journalisés sur stderr ; message générique au client.
                    logError("ws", error)
                    try await outbound.write(.text(#"{"error":"erreur interne"}"#))
                }
            }
        }

        return Application(
            router: router,
            server: .http1WebSocketUpgrade(webSocketRouter: wsRouter),
            configuration: .init(address: .hostname(config.host, port: config.port))
        )
    }
}
