import Testing
@testable import FoundationBridgeCore

@Test func heuristicEstimatorIsRoughlyCharsOverFour() {
    let est = HeuristicTokenEstimator()
    #expect(est.estimatedTokens("12345678") == 2) // 8/4
    #expect(est.estimatedTokens("") == 1)         // plancher
}

@Test func contextManagerPassesUnderLimit() throws {
    let mgr = ContextManager(limit: 100)
    try mgr.validate(prompt: "court", instructions: nil) // ne lève pas
}

@Test func contextManagerThrowsOverflowOverLimit() {
    let mgr = ContextManager(limit: 10)
    let bigPrompt = String(repeating: "x", count: 80) // ~20 tokens > 10
    #expect(throws: BridgeError.self) {
        try mgr.validate(prompt: bigPrompt, instructions: nil)
    }
}
