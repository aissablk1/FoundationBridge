import Testing
@testable import ProtocolConversion
import FoundationBridgeCore

// MARK: - Cas valide

@Test func validRequestNeThrowsPas() throws {
    let options = GenerationOptions(temperature: 1.0, maximumTokens: 256)
    try RequestValidator.validate(prompt: "Bonjour le monde", options: options)
    // Aucune exception levée → test réussi
}

// MARK: - Prompt vide

@Test func promptVideLèveInvalidInput() {
    let options = GenerationOptions()
    #expect(throws: BridgeError.self) {
        try RequestValidator.validate(prompt: "", options: options)
    }
}

@Test func promptEspacesSeulsLèveInvalidInput() {
    let options = GenerationOptions()
    #expect(throws: BridgeError.self) {
        try RequestValidator.validate(prompt: "   \n\t  ", options: options)
    }
}

// MARK: - maxTokens invalide

@Test func maxTokensZéroLèveInvalidInput() {
    let options = GenerationOptions(maximumTokens: 0)
    #expect(throws: BridgeError.self) {
        try RequestValidator.validate(prompt: "Question", options: options)
    }
}

@Test func maxTokensNégatifLèveInvalidInput() {
    let options = GenerationOptions(maximumTokens: -1)
    #expect(throws: BridgeError.self) {
        try RequestValidator.validate(prompt: "Question", options: options)
    }
}

// MARK: - temperature invalide

@Test func temperatureTropHauteLèveInvalidInput() {
    let options = GenerationOptions(temperature: 3.0)
    #expect(throws: BridgeError.self) {
        try RequestValidator.validate(prompt: "Question", options: options)
    }
}

@Test func temperatureNégativeLèveInvalidInput() {
    let options = GenerationOptions(temperature: -0.1)
    #expect(throws: BridgeError.self) {
        try RequestValidator.validate(prompt: "Question", options: options)
    }
}

// MARK: - Bornes acceptées pour temperature

@Test func temperatureZéroEstValide() throws {
    let options = GenerationOptions(temperature: 0.0)
    try RequestValidator.validate(prompt: "Question", options: options)
}

@Test func temperatureDeuxEstValide() throws {
    let options = GenerationOptions(temperature: 2.0)
    try RequestValidator.validate(prompt: "Question", options: options)
}

// MARK: - Options absentes (nil) → pas d'erreur

@Test func optionsNilSontValides() throws {
    let options = GenerationOptions()
    try RequestValidator.validate(prompt: "Question", options: options)
}
