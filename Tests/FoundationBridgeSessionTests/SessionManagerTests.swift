import Testing
@testable import FoundationBridgeSession
import FoundationBridgeCore

/// Doublure capturant le prompt recomposé transmis au backend, pour vérifier
/// le rejeu de transcript multi-tours. Séquentiel en test → `@unchecked Sendable` ok.
private final class CapturingGenerator: TextGenerating, @unchecked Sendable {
    private(set) var lastPrompt: String = ""
    private(set) var lastInstructions: String?
    private let reply: String

    init(reply: String) { self.reply = reply }

    func respond(to prompt: String, options: GenerationOptions) async throws -> String {
        lastPrompt = prompt
        lastInstructions = options.instructions
        return reply
    }

    func stream(to prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(reply)
            continuation.finish()
        }
    }
}

@Test func premierTourRenvoieLaReponseEtEnregistreDeuxTours() async throws {
    let manager = SessionManager(backend: MockTextGenerator(scriptedResponse: "Bonjour"))
    let answer = try await manager.respond(session: "s1", prompt: "Salut")
    #expect(answer == "Bonjour")
    #expect(await manager.turnCount(session: "s1") == 2) // user + assistant
}

@Test func premierTourTransmetLePromptBrutSansBalisage() async throws {
    let capture = CapturingGenerator(reply: "ok")
    let manager = SessionManager(backend: capture)
    _ = try await manager.respond(session: "s1", prompt: "Question initiale")
    #expect(capture.lastPrompt == "Question initiale")
}

@Test func deuxiemeTourRecomposeLeContexteAvecLHistorique() async throws {
    let capture = CapturingGenerator(reply: "Réponse")
    let manager = SessionManager(backend: capture)
    _ = try await manager.respond(session: "s1", prompt: "Première")
    _ = try await manager.respond(session: "s1", prompt: "Deuxième")
    // Le contexte recomposé doit contenir le tour précédent et le nouveau prompt.
    #expect(capture.lastPrompt.contains("Utilisateur: Première"))
    #expect(capture.lastPrompt.contains("Assistant: Réponse"))
    #expect(capture.lastPrompt.contains("Utilisateur: Deuxième"))
}

@Test func lesInstructionsSontFigeesALaCreationDeLaSession() async throws {
    let capture = CapturingGenerator(reply: "ok")
    let manager = SessionManager(backend: capture)
    _ = try await manager.respond(session: "s1", prompt: "A", options: .init(instructions: "Sois bref"))
    // Un second tour sans instructions doit conserver celles de la création.
    _ = try await manager.respond(session: "s1", prompt: "B")
    #expect(capture.lastInstructions == "Sois bref")
}

@Test func sessionsDistinctesNePartagentPasLeurHistorique() async throws {
    let manager = SessionManager(backend: MockTextGenerator(scriptedResponse: "x"))
    _ = try await manager.respond(session: "a", prompt: "1")
    _ = try await manager.respond(session: "b", prompt: "2")
    #expect(await manager.turnCount(session: "a") == 2)
    #expect(await manager.turnCount(session: "b") == 2)
    #expect(await manager.list().count == 2)
}

@Test func deleteSupprimeLaSession() async throws {
    let manager = SessionManager(backend: MockTextGenerator(scriptedResponse: "x"))
    _ = try await manager.respond(session: "a", prompt: "1")
    await manager.delete(session: "a")
    #expect(await manager.turnCount(session: "a") == 0)
    #expect(await manager.list().isEmpty)
}

@Test func resetVideLHistoriqueMaisGardeLaSession() async throws {
    let capture = CapturingGenerator(reply: "ok")
    let manager = SessionManager(backend: capture)
    _ = try await manager.respond(session: "a", prompt: "1", options: .init(instructions: "Garde"))
    await manager.reset(session: "a")
    #expect(await manager.turnCount(session: "a") == 0)
    // Après reset, le tour suivant repart d'un contexte vierge (prompt brut).
    _ = try await manager.respond(session: "a", prompt: "2")
    #expect(capture.lastPrompt == "2")
}

@Test func depassementDeContexteLeveUneErreur() async throws {
    let manager = SessionManager(
        backend: MockTextGenerator(scriptedResponse: "x"),
        contextManager: ContextManager(limit: 5)
    )
    let bigPrompt = String(repeating: "a", count: 80) // ~20 tokens > 5
    await #expect(throws: BridgeError.self) {
        try await manager.respond(session: "a", prompt: bigPrompt)
    }
    // L'échec ne doit pas créer/peupler la session.
    #expect(await manager.turnCount(session: "a") == 0)
}
