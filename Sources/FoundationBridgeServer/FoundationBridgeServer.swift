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
    public init(host: String = "127.0.0.1", port: Int = 8080) {
        self.host = host
        self.port = port
    }
}

/// Serveur HTTP exposant le LLM on-device via des surfaces REST compatibles
/// OpenAI (`/v1/chat/completions`, `/v1/models`) et Anthropic (`/v1/messages`).
public enum FoundationBridgeServer {

    public static func makeApplication(config: ServerConfig = .init()) -> some ApplicationProtocol {
        let router = Router()

        router.get("/healthz") { _, _ in
            "ok"
        }

        router.get("/v1/models") { _, _ -> Response in
            let json = #"{"object":"list","data":[{"id":"apple-foundation","object":"model","owned_by":"apple"}]}"#
            return jsonResponse(Data(json.utf8))
        }

        router.post("/v1/chat/completions") { request, _ -> Response in
            let buffer = try await request.body.collect(upTo: 1 << 20)
            let data = Data(buffer.readableBytesView)
            do {
                let req = try JSONDecoder().decode(OpenAIChatRequest.self, from: data)
                let (prompt, options) = RequestConverter.extract(from: req)
                let text = try await generate(prompt: prompt, options: options)
                let resp = ResponseBuilder.openAI(text: text, model: req.model)
                return jsonResponse(try JSONEncoder().encode(resp))
            } catch let error as BridgeError {
                return jsonError(error)
            } catch {
                return jsonError(.invalidInput(field: "body"))
            }
        }

        router.post("/v1/messages") { request, _ -> Response in
            let buffer = try await request.body.collect(upTo: 1 << 20)
            let data = Data(buffer.readableBytesView)
            do {
                let req = try JSONDecoder().decode(AnthropicRequest.self, from: data)
                let (prompt, options) = RequestConverter.extract(from: req)
                let text = try await generate(prompt: prompt, options: options)
                let resp = ResponseBuilder.anthropic(text: text, model: req.model)
                return jsonResponse(try JSONEncoder().encode(resp))
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

    // MARK: - Helpers

    static func generate(prompt: String, options: GenerationOptions) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            return try await FoundationModelsGenerator().respond(to: prompt, options: options)
        }
        #endif
        throw BridgeError.modelUnavailable(reason: "FoundationModels indisponible sur cette plateforme")
    }

    static func jsonResponse(_ data: Data, status: HTTPResponse.Status = .ok) -> Response {
        var headers = HTTPFields()
        headers[.contentType] = "application/json"
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
