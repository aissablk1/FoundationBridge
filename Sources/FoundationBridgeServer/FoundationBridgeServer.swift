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
    public init(host: String = "127.0.0.1", port: Int = 11434) {
        self.host = host
        self.port = port
    }
}

/// Serveur HTTP exposant le LLM on-device via REST compatibles OpenAI et Anthropic,
/// avec streaming SSE (`stream: true`).
public enum FoundationBridgeServer {

    public static func makeApplication(config: ServerConfig = .init()) -> some ApplicationProtocol {
        let router = Router()

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
                    return sse(prompt: prompt, options: options, model: req.model, dialect: .openAI)
                }
                let text = try await generate(prompt: prompt, options: options)
                return jsonResponse(try JSONEncoder().encode(ResponseBuilder.openAI(text: text, model: req.model)))
            } catch let error as BridgeError {
                return jsonError(error)
            } catch {
                return jsonError(.invalidInput(field: "body"))
            }
        }

        router.post("/v1/messages") { request, _ -> Response in
            let data = Data(try await request.body.collect(upTo: 1 << 20).readableBytesView)
            do {
                let req = try JSONDecoder().decode(AnthropicRequest.self, from: data)
                let (prompt, options) = RequestConverter.extract(from: req)
                try RequestValidator.validate(prompt: prompt, options: options)
                if req.stream == true {
                    return sse(prompt: prompt, options: options, model: req.model, dialect: .anthropic)
                }
                let text = try await generate(prompt: prompt, options: options)
                return jsonResponse(try JSONEncoder().encode(ResponseBuilder.anthropic(text: text, model: req.model)))
            } catch let error as BridgeError {
                return jsonError(error)
            } catch {
                return jsonError(.invalidInput(field: "body"))
            }
        }

        return Application(
            router: router,
            configuration: .init(address: .hostname(config.host, port: config.port))
        )
    }

    // MARK: - Génération

    static func generate(prompt: String, options: GenerationOptions) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await FoundationModelsGenerator().respond(to: prompt, options: options)
        }
        #endif
        throw BridgeError.modelUnavailable(reason: "FoundationModels indisponible sur cette plateforme")
    }

    static func generateStream(prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error> {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return FoundationModelsGenerator().stream(to: prompt, options: options)
        }
        #endif
        return AsyncThrowingStream { $0.finish(throwing: BridgeError.modelUnavailable(reason: "FoundationModels indisponible")) }
    }

    // MARK: - SSE

    enum Dialect { case openAI, anthropic }

    static func sse(prompt: String, options: GenerationOptions, model: String, dialect: Dialect) -> Response {
        let body = ResponseBody { writer in
            var writer = writer
            func send(_ s: String) async throws {
                try await writer.write(ByteBuffer(bytes: Data(s.utf8)))
            }
            do {
                if dialect == .anthropic {
                    try await send("event: message_start\ndata: {\"type\":\"message_start\"}\n\n")
                }
                for try await chunk in generateStream(prompt: prompt, options: options) {
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
                try? await send("data: {\"error\":\"\(error)\"}\n\n")
            }
            try await writer.finish(nil)
        }
        var headers = HTTPFields()
        headers[.contentType] = "text/event-stream"
        headers[.cacheControl] = "no-cache"
        return Response(status: .ok, headers: headers, body: body)
    }

    // MARK: - Helpers

    static func jsonString(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func jsonResponse(_ data: Data, status: HTTPResponse.Status = .ok) -> Response {
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
        // Header de sécurité : empêche le MIME-sniffing côté navigateur
        headers[HTTPField.Name("X-Content-Type-Options")!] = "nosniff"
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
        let payload: [String: [String: String]] = [
            "error": ["message": error.message, "code": String(error.exitCode.rawValue)]
        ]
        let data = (try? JSONEncoder().encode(payload)) ?? Data(#"{"error":{"message":"erreur"}}"#.utf8)
        return jsonResponse(data, status: status)
    }
}
