import Testing
@testable import FoundationBridgeCore

@Test func tokenNonConfigureAutoriseToujours() {
    #expect(BearerAuth.isAuthorized(configuredToken: nil, authorizationHeader: nil, apiKeyHeader: nil))
    #expect(BearerAuth.isAuthorized(configuredToken: "", authorizationHeader: nil, apiKeyHeader: nil))
}

@Test func bearerCorrectAutorise() {
    #expect(BearerAuth.isAuthorized(
        configuredToken: "secret",
        authorizationHeader: "Bearer secret",
        apiKeyHeader: nil
    ))
}

@Test func apiKeyCorrectAutorise() {
    #expect(BearerAuth.isAuthorized(
        configuredToken: "secret",
        authorizationHeader: nil,
        apiKeyHeader: "secret"
    ))
}

@Test func tokenManquantRefuse() {
    #expect(!BearerAuth.isAuthorized(
        configuredToken: "secret",
        authorizationHeader: nil,
        apiKeyHeader: nil
    ))
}

@Test func bearerIncorrectRefuse() {
    #expect(!BearerAuth.isAuthorized(
        configuredToken: "secret",
        authorizationHeader: "Bearer mauvais",
        apiKeyHeader: nil
    ))
    // Token brut sans le préfixe "Bearer " doit être refusé.
    #expect(!BearerAuth.isAuthorized(
        configuredToken: "secret",
        authorizationHeader: "secret",
        apiKeyHeader: nil
    ))
}
