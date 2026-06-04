import Testing
import Hummingbird
import HummingbirdTesting
import HTTPTypes
@testable import FoundationBridgeServer
import FoundationBridgeCore

// MARK: - Routes de base

@Test func healthzRepondOk() async throws {
    let app = FoundationBridgeServer.makeApplication(backend: MockTextGenerator(scriptedResponse: ""))
    try await app.test(.router) { client in
        try await client.execute(uri: "/healthz", method: .get) { response in
            #expect(response.status == .ok)
            #expect(String(buffer: response.body) == "ok")
        }
    }
}

@Test func modelsListeLeModele() async throws {
    let app = FoundationBridgeServer.makeApplication(backend: MockTextGenerator(scriptedResponse: ""))
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/models", method: .get) { response in
            #expect(response.status == .ok)
            #expect(String(buffer: response.body).contains("apple-foundation"))
        }
    }
}

// MARK: - Génération non-stream

@Test func chatCompletionsRenvoieLaReponseDuBackend() async throws {
    let app = FoundationBridgeServer.makeApplication(backend: MockTextGenerator(scriptedResponse: "Bonjour le monde"))
    let body = ByteBuffer(string: #"{"model":"apple/on-device","messages":[{"role":"user","content":"Salut"}]}"#)
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/chat/completions", method: .post,
                                 headers: [.contentType: "application/json"], body: body) { response in
            #expect(response.status == .ok)
            #expect(String(buffer: response.body).contains("Bonjour le monde"))
        }
    }
}

@Test func messagesAnthropicRenvoieLaReponse() async throws {
    let app = FoundationBridgeServer.makeApplication(backend: MockTextGenerator(scriptedResponse: "Réponse Anthropic"))
    let body = ByteBuffer(string: #"{"model":"claude-3-haiku-20240307","max_tokens":64,"messages":[{"role":"user","content":"Salut"}]}"#)
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/messages", method: .post,
                                 headers: [.contentType: "application/json"], body: body) { response in
            #expect(response.status == .ok)
            #expect(String(buffer: response.body).contains("Réponse Anthropic"))
        }
    }
}

@Test func corpsInvalideRenvoie400() async throws {
    let app = FoundationBridgeServer.makeApplication(backend: MockTextGenerator(scriptedResponse: "x"))
    let body = ByteBuffer(string: "ceci n'est pas du json")
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/chat/completions", method: .post,
                                 headers: [.contentType: "application/json"], body: body) { response in
            #expect(response.status == .badRequest)
        }
    }
}

@Test func modeleIndisponibleRenvoie503AvecRetryAfter() async throws {
    let app = FoundationBridgeServer.makeApplication(
        backend: MockTextGenerator(error: .modelUnavailable(reason: "Apple Intelligence non activé"))
    )
    let body = ByteBuffer(string: #"{"model":"apple/on-device","messages":[{"role":"user","content":"Salut"}]}"#)
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/chat/completions", method: .post,
                                 headers: [.contentType: "application/json"], body: body) { response in
            #expect(response.status == .serviceUnavailable)
            #expect(response.headers[HTTPField.Name("Retry-After")!] != nil)
        }
    }
}

// MARK: - Golden SSE

@Test func sseOpenAIEmetDeltasEtDONE() async throws {
    let app = FoundationBridgeServer.makeApplication(
        backend: MockTextGenerator(scriptedChunks: ["Hel", "lo"])
    )
    let body = ByteBuffer(string: #"{"model":"apple/on-device","stream":true,"messages":[{"role":"user","content":"Salut"}]}"#)
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/chat/completions", method: .post,
                                 headers: [.contentType: "application/json"], body: body) { response in
            let text = String(buffer: response.body)
            #expect(text.contains("\"content\":\"Hel\""))
            #expect(text.contains("\"content\":\"lo\""))
            #expect(text.contains("\"finish_reason\":\"stop\""))
            #expect(text.contains("data: [DONE]"))
        }
    }
}

@Test func sseAnthropicEmetLesEvenements() async throws {
    let app = FoundationBridgeServer.makeApplication(
        backend: MockTextGenerator(scriptedChunks: ["Bon", "jour"])
    )
    let body = ByteBuffer(string: #"{"model":"claude-3-haiku-20240307","max_tokens":64,"stream":true,"messages":[{"role":"user","content":"Salut"}]}"#)
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/messages", method: .post,
                                 headers: [.contentType: "application/json"], body: body) { response in
            let text = String(buffer: response.body)
            #expect(text.contains("event: message_start"))
            #expect(text.contains("event: content_block_delta"))
            #expect(text.contains("\"text\":\"Bon\""))
            #expect(text.contains("event: message_stop"))
        }
    }
}

// MARK: - Authentification

@Test func authActiveRefuseSansToken() async throws {
    let app = FoundationBridgeServer.makeApplication(
        config: .init(token: "secret"),
        backend: MockTextGenerator(scriptedResponse: "x")
    )
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/models", method: .get) { response in
            #expect(response.status == .unauthorized)
        }
    }
}

@Test func authActiveAccepteBonToken() async throws {
    let app = FoundationBridgeServer.makeApplication(
        config: .init(token: "secret"),
        backend: MockTextGenerator(scriptedResponse: "x")
    )
    try await app.test(.router) { client in
        try await client.execute(uri: "/v1/models", method: .get,
                                 headers: [.authorization: "Bearer secret"]) { response in
            #expect(response.status == .ok)
        }
    }
}

@Test func healthzResteAccessibleMalgreAuth() async throws {
    let app = FoundationBridgeServer.makeApplication(
        config: .init(token: "secret"),
        backend: MockTextGenerator(scriptedResponse: "x")
    )
    try await app.test(.router) { client in
        try await client.execute(uri: "/healthz", method: .get) { response in
            #expect(response.status == .ok)
        }
    }
}
