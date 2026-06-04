import Testing
@testable import FoundationBridgeCore

@Test func coreVersionIsExposed() {
    #expect(FoundationBridge.coreVersion == "0.0.1")
}
