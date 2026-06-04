import Testing
@testable import FoundationBridgeCore

@Test func availabilityKnowsWhenReady() {
    #expect(ModelAvailability.available.isReady)
    #expect(!ModelAvailability.appleIntelligenceNotEnabled.isReady)
}

@Test func unavailableMapsToBridgeError() {
    let err = ModelAvailability.deviceNotEligible.asErrorIfUnavailable()
    #expect(err?.httpStatus == 503)
    #expect(ModelAvailability.available.asErrorIfUnavailable() == nil)
}
