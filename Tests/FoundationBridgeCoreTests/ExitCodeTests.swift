import Testing
@testable import FoundationBridgeCore

@Test func exitCodesAreStableIntegers() {
    #expect(ExitCode.success.rawValue == 0)
    #expect(ExitCode.genericError.rawValue == 1)
    #expect(ExitCode.modelUnavailable.rawValue == 2)
    #expect(ExitCode.guardrailBlocked.rawValue == 3)
    #expect(ExitCode.contextOverflow.rawValue == 4)
    #expect(ExitCode.invalidInput.rawValue == 5)
    #expect(ExitCode.rateLimited.rawValue == 6)
}
