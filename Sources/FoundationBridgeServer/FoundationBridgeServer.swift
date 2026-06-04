import Foundation
import Hummingbird
import HTTPTypes
import NIOCore
import FoundationBridgeCore
import ProtocolConversion
import FoundationModelsBackend

/// Configuration du serveur HTTP.
public struct ServerConfig: Sendable {
    public var host: String
    public var port: Int
    /// Token Bearer optionnel. Si défini, toutes les routes (sauf `/healthz`)
    /// exigent `Authorization: Bearer <token>` ou `x-api-key: <token>`.
    public var token: String?
    public init(host: String = "127.0.0.1", port: Int = 11434, token: String? = nil) {
        self.host = host
        self.port = port
        self.token = token
    }
}

/// Middleware d'authentification Bearer. Délègue la décision au helper pur
/// `BearerAuth` du cœur (comparaison à temps constant) ; ne s'enregistre que si
/// un token est configuré. `/healthz` est exempté pour les sondes de liveness.
struct BearerAuthMiddleware<Context: RequestContext>: RouterMiddleware {
    let token: String

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        // Les sondes de santé ne doivent pas exiger de secret.
        if request.uri.path == "/healthz" {
            return try await next(request, context)
        }
        let authorization = request.headers[.authorization]
        let apiKey = request.headers[HTTPField.Name("x-api-key")!]
        guard BearerAuth.isAuthorized(
            configuredToken: token,
            authorizationHeader: authorization,
            apiKeyHeader: apiKey
        ) else {
            throw HTTPError(.unauthorized, message: "Token invalide ou manquant")
        }
        return try await next(request, context)
    }
}

/// Backend de repli quand FoundationModels n'est pas disponible (CI, plateforme
/// non Apple, macOS < 26). Échoue proprement plutôt que de masquer le problème.
struct UnavailableGenerator: TextGenerating {
    func respond(to prompt: String, options: GenerationOptions) async throws -> String {
        throw BridgeError.modelUnavailable(reason: "FoundationModels indisponible sur cette plateforme")
    }
    func stream(to prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish(throwing: BridgeError.modelUnavailable(reason: "FoundationModels indisponible")) }
    }
}

/// Serveur HTTP exposant le LLM on-device via REST compatibles OpenAI et Anthropic,
/// avec streaming SSE (`stream: true`). Le backend `TextGenerating` est injectable
/// (tests d'intégration via `MockTextGenerator`) ; par défaut, le binding réel.
public enum FoundationBridgeServer {

    public static func makeApplication(
        config: ServerConfig = .init(),
        backend: (any TextGenerating)? = nil
    ) -> some ApplicationProtocol {
        let generator: any TextGenerating = backend ?? defaultBackend()
        let router = Router()

        // Authentification optionnelle : active uniquement si un token est configuré.
        if let token = config.token, !token.isEmpty {
            router.add(middleware: BearerAuthMiddleware(token: token))
        }

        router.get("/healthz") { _, _ in "ok" }

        router.get("/v1/models") { _, _ -> Response in
            let json = #"{"object":"list","data":[{"id":"apple-foundation","object":"model","owned_by":"apple"}]}"#
            return jsonResponse(Data(json.utf8))
        }

        router.post("/v1/chat/completions") { request, _ -> Response in
            let data = Data(try await request.body.collect(upTo: 1 << 20).readableBytesView)
            do {
                let req = try JSONDecoder().decode(OpenAIChatRequest.self, from: data)
                let (prompt, options) = RequestConverter.extract(from: req)
                try RequestValidator.validate(prompt: prompt, options: options)
                if req.stream == true {
                    return sse(prompt: prompt, options: options, model: req.model, dialect: .openAI, backend: generator)
                }
                let text = try await generator.respond(to: prompt, options: options)
                return jsonResponse(try JSONEncoder().encode(ResponseBuilder.openAI(text: text, model: req.model)))
            } catch let error as BridgeError {
                return jsonError(error)
            } catch let error as DecodingError {
                logError("chat/completions decode", error)
                return jsonError(.invalidInput(field: "body"))
            } catch {
                // Cause inattendue (sérialisation réponse, etc.) : journalisée plutôt qu'avalée.
                logError("chat/completions", error)
                return jsonError(.generic(message: "Erreur interne"))
            }
        }

        router.post("/v1/messages") { request, _ -> Response in
            let data = Data(try await request.body.collect(upTo: 1 << 20).readableBytesView)
            do {
                let req = try JSONDecoder().decode(AnthropicRequest.self, from: data)
                let (prompt, options) = RequestConverter.extract(from: req)
                try RequestValidator.validate(prompt: prompt, options: options)
                if req.stream == true {
                    return sse(prompt: prompt, options: options, model: req.model, dialect: .anthropic, backend: generator)
                }
                let text = try await generator.respond(to: prompt, options: options)
                return jsonResponse(try JSONEncoder().encode(ResponseBuilder.anthropic(text: text, model: req.model)))
            } catch let error as BridgeError {
                return jsonError(error)
            } catch let error as DecodingError {
                logError("messages decode", error)
                return jsonError(.invalidInput(field: "body"))
            } catch {
                logError("messages", error)
                return jsonError(.generic(message: "Erreur interne"))
            }
        }

        return Application(
            router: router,
            configuration: .init(address: .hostname(config.host, port: config.port))
        )
    }

    /// Backend réel quand FoundationModels est disponible, sinon repli explicite.
    static func defaultBackend() -> any TextGenerating {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return FoundationModelsGenerator()
        }
        #endif
        return UnavailableGenerator()
    }

    // MARK: - SSE

    enum Dialect { case openAI, anthropic }

    static func sse(
        prompt: String,
        options: GenerationOptions,
        model: String,
        dialect: Dialect,
        backend: any TextGenerating
    ) -> Response {
        let body = ResponseBody { writer in
            var writer = writer
            func send(_ s: String) async throws {
                try await writer.write(ByteBuffer(bytes: Data(s.utf8)))
            }
            do {
                if dialect == .anthropic {
                    try await send("event: message_start\ndata: {\"type\":\"message_start\"}\n\n")
                }
                for try await chunk in backend.stream(to: prompt, options: options) {
                    switch dialect {
                    case .openAI:
                        let payload = ["choices": [["index": 0, "delta": ["content": chunk]]]] as [String: Any]
                        try await send("data: \(jsonString(payload))\n\n")
                    case .anthropic:
                        let payload = ["type": "content_block_delta", "index": 0,
                                       "delta": ["type": "text_delta", "text": chunk]] as [String: Any]
                        try await send("event: content_block_delta\ndata: \(jsonString(payload))\n\n")
                    }
                }
                if dialect == .openAI {
                    try await send("data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n")
                    try await send("data: [DONE]\n\n")
                } else {
                    try await send("event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n")
                }
            } catch {
                // L'erreur est journalisée (stderr) ; on n'envoie PAS `\(error)` brut au
                // client (évite la fuite de détails internes). Si l'écriture échoue
                // elle-même (client déconnecté), on le note aussi.
                logError("sse \(dialect)", error)
                do {
                    try await send("data: {\"error\":\"erreur interne\"}\n\n")
                } catch {
                    logError("sse write-after-error", error)
                }
            }
            try await writer.finish(nil)
        }
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        return Response(status: .ok, headers: headers, body: body)
    }

    // MARK: - Helpers

    /// Journalise une erreur sur stderr (stdout reste propre pour d'éventuels usages pipe).
    static func logError(_ context: String, _ error: Error) {
        FileHandle.standardError.write(Data("[FoundationBridge] \(context): \(error)\n".utf8))
    }

    static func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let s = String(data: data, encoding: .utf8) else {
            logError("jsonString", BridgeError.generic(message: "serialisation SSE echouee"))
            return "{}"
        }
        return s
    }

    static func jsonResponse(
        _ data: Data,
        status: HTTPResponse.Status = .ok,
        extraHeaders: [(HTTPField.Name, String)] = []
    ) -> Response {
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        // Header de sécurité : empêche le MIME-sniffing côté navigateur.
        headers[HTTPField.Name("X-Content-Type-Options")!] = "nosniff"
        for (name, value) in extraHeaders {
            headers[name] = value
        }
        return Response(status: status, headers: headers, body: ResponseBody(byteBuffer: ByteBuffer(bytes: data)))
    }

    static func jsonError(_ error: BridgeError) -> Response {
        let status: HTTPResponse.Status
        switch error.httpStatus {
        case 400: status = .badRequest
        case 413: status = .contentTooLarge
        case 422: status = .unprocessableContent
        case 503: status = .serviceUnavailable
        default:  status = .internalServerError
        }
        // Modèle en cours de téléchargement / indisponible transitoirement : indiquer un délai.
        var extra: [(HTTPField.Name, String)] = []
        if error.httpStatus == 503 {
            extra.append((HTTPField.Name("Retry-After")!, "2"))
        }
        let payload: [String: [String: String]] = [
            "error": ["message": error.message, "code": String(error.exitCode.rawValue)]
        ]
        let data = (try? JSONEncoder().encode(payload)) ?? Data(#"{"error":{"message":"erreur"}}"#.utf8)
        return jsonResponse(data, status: status, extraHeaders: extra)
    }
}
