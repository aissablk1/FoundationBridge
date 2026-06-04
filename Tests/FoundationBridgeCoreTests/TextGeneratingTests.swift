import Testing
@testable import FoundationBridgeCore

@Test func mockGeneratorReturnsConfiguredText() async throws {
    let gen = MockTextGenerator(scriptedResponse: "bonjour")
    let out = try await gen.respond(to: "salut", options: .init())
    #expect(out == "bonjour")
}

@Test func mockGeneratorStreamsChunks() async throws {
    let gen = MockTextGenerator(scriptedChunks: ["a", "b", "c"])
    var received: [String] = []
    for try await chunk in gen.stream(to: "x", options: .init()) {
        received.append(chunk)
    }
    #expect(received == ["a", "b", "c"])
}

@Test func mockGeneratorCanThrowBridgeError() async {
    let gen = MockTextGenerator(error: .guardrailBlocked(reason: "test"))
    await #expect(throws: BridgeError.self) {
        _ = try await gen.respond(to: "x", options: .init())
    }
}
