import Testing
@testable import FoundationBridgeCore

@Test func proxyOverridesPointentVersLeBridgeLocal() {
    let env = ProxyEnvironment.overrides(host: "127.0.0.1", port: 11434)
    #expect(env["OPENAI_BASE_URL"] == "http://127.0.0.1:11434/v1")
    #expect(env["ANTHROPIC_BASE_URL"] == "http://127.0.0.1:11434")
    #expect(env["OPENAI_API_KEY"] == ProxyEnvironment.placeholderKey)
    #expect(env["ANTHROPIC_API_KEY"] == ProxyEnvironment.placeholderKey)
}

@Test func proxyOverridesRamenent0000VersLocalhost() {
    let env = ProxyEnvironment.overrides(host: "0.0.0.0", port: 8080)
    #expect(env["ANTHROPIC_BASE_URL"] == "http://127.0.0.1:8080")
    #expect(env["OPENAI_BASE_URL"] == "http://127.0.0.1:8080/v1")
}

@Test func proxyOverridesUtilisentLeTokenCommeCle() {
    let env = ProxyEnvironment.overrides(host: "127.0.0.1", port: 11434, token: "secret")
    #expect(env["OPENAI_API_KEY"] == "secret")
    #expect(env["ANTHROPIC_API_KEY"] == "secret")
}

@Test func proxyOverridesTokenVideRetombeSurLaCleFactice() {
    let env = ProxyEnvironment.overrides(host: "127.0.0.1", port: 11434, token: "")
    #expect(env["OPENAI_API_KEY"] == ProxyEnvironment.placeholderKey)
}
