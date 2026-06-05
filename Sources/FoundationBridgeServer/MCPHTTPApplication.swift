import Foundation
import Hummingbird
import HTTPTypes
import NIOCore
import MCP
import FoundationBridgeCore
import FoundationBridgeMCP

/// Hébergement du serveur MCP via le transport **Streamable-HTTP** (`POST`/`GET`/`DELETE`
/// sur `/mcp`). Le transport du SDK est *framework-agnostique* : on convertit les requêtes
/// Hummingbird vers `MCP.HTTPRequest`, on délègue à `transport.handleRequest`, puis on
/// reconvertit la `MCP.HTTPResponse` (y compris le flux SSE) vers Hummingbird.
///
/// Note de nommage : `MCP` et `HTTPTypes` déclarent tous deux `HTTPRequest`/`HTTPResponse` ;
/// les types du SDK sont donc qualifiés `MCP.…` pour lever l'ambiguïté.
extension FoundationBridgeServer {

    /// Construit l'application Hummingbird exposant `/mcp`. L'appelant doit avoir démarré
    /// le serveur MCP (`server.start(transport:)`) avant `runService()`.
    public static func makeMCPHTTPApplication(
        transport: StatefulHTTPServerTransport,
        config: ServerConfig = .init()
    ) -> some ApplicationProtocol {
        let router = Router()
        if let token = config.token, !token.isEmpty {
            router.add(middleware: BearerAuthMiddleware(token: token))
        }
        router.get("/healthz") { _, _ in "ok" }

        @Sendable func handle(_ request: Request) async throws -> Response {
            let collected = try await request.body.collect(upTo: 4 << 20)
            let data = Data(collected.readableBytesView)
            var headers: [String: String] = [:]
            for field in request.headers {
                headers[field.name.rawName] = field.value
            }
            let mcpRequest = MCP.HTTPRequest(
                method: request.method.rawValue,
                headers: headers,
                body: data.isEmpty ? nil : data,
                path: request.uri.path
            )
            let mcpResponse = await transport.handleRequest(mcpRequest)
            return convert(mcpResponse)
        }

        router.post("/mcp") { request, _ in try await handle(request) }
        router.get("/mcp") { request, _ in try await handle(request) }
        router.delete("/mcp") { request, _ in try await handle(request) }

        return Application(
            router: router,
            configuration: .init(address: .hostname(config.host, port: config.port))
        )
    }

    /// Démarre le serveur MCP sur le transport Streamable-HTTP et bloque (runService).
    /// Point d'entrée unique pour la CLI : encapsule la création du serveur MCP, du
    /// transport et de l'application Hummingbird.
    public static func runMCPHTTP(
        router: MCPToolRouter,
        config: ServerConfig = .init(),
        version: String
    ) async throws {
        let server = await MCPServerRunner.makeServer(router: router, version: version)
        let transport = StatefulHTTPServerTransport()
        try await server.start(transport: transport)
        try await makeMCPHTTPApplication(transport: transport, config: config).runService()
    }

    /// Convertit une réponse neutre du SDK MCP en réponse Hummingbird.
    static func convert(_ response: MCP.HTTPResponse) -> Response {
        var headers = HTTPFields()
        for (key, value) in response.headers {
            if let name = HTTPField.Name(key) { headers[name] = value }
        }

        if case let .stream(sseStream, _) = response {
            // Flux SSE : on relaie chaque bloc de données tel quel.
            if headers[.contentType] == nil { headers[.contentType] = "text/event-stream" }
            headers[HTTPField.Name("X-Accel-Buffering")!] = "no"
            let body = ResponseBody { writer in
                var writer = writer
                do {
                    for try await chunk in sseStream {
                        try await writer.write(ByteBuffer(bytes: chunk))
                    }
                } catch {
                    logError("mcp-http sse", error)
                }
                try await writer.finish(nil)
            }
            return Response(status: .ok, headers: headers, body: body)
        }

        let status = HTTPTypes.HTTPResponse.Status(code: response.statusCode)
        let data = response.bodyData ?? Data()
        return Response(status: status, headers: headers, body: ResponseBody(byteBuffer: ByteBuffer(bytes: data)))
    }
}
