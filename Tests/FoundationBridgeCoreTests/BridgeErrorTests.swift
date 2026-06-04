import Testing
@testable import FoundationBridgeCore

@Test func bridgeErrorMapsToExitCode() {
    #expect(BridgeError.modelUnavailable(reason: "x").exitCode == .modelUnavailable)
    #expect(BridgeError.contextOverflow(tokens: 5000, limit: 4096).exitCode == .contextOverflow)
    #expect(BridgeError.guardrailBlocked(reason: "x").exitCode == .guardrailBlocked)
    #expect(BridgeError.invalidInput(field: "prompt").exitCode == .invalidInput)
}

@Test func bridgeErrorMapsToHTTPStatus() {
    #expect(BridgeError.modelUnavailable(reason: "x").httpStatus == 503)
    #expect(BridgeError.contextOverflow(tokens: 5000, limit: 4096).httpStatus == 413)
    #expect(BridgeError.guardrailBlocked(reason: "x").httpStatus == 422)
    #expect(BridgeError.invalidInput(field: "prompt").httpStatus == 400)
}
