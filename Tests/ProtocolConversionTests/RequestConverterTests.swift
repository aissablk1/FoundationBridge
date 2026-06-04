import Testing
import Foundation
@testable import ProtocolConversion
import FoundationBridgeCore

@Test func extractsPromptAndOptionsFromOpenAIRequest() throws {
    let json = """
    {"model":"local","messages":[{"role":"system","content":"Sois bref"},{"role":"user","content":"Bonjour"}],"max_tokens":128,"temperature":0.5}
    """.data(using: .utf8)!
    let req = try JSONDecoder().decode(OpenAIChatRequest.self, from: json)
    let (prompt, options) = RequestConverter.extract(from: req)
    #expect(prompt.contains("user: Bonjour"))
    #expect(!prompt.contains("system:"))
    #expect(options.instructions == "Sois bref")
    #expect(options.maximumTokens == 128)
    #expect(options.temperature == 0.5)
}

@Test func extractsPromptAndOptionsFromAnthropicRequest() throws {
    let json = """
    {"model":"local","system":"Tu es utile","messages":[{"role":"user","content":"Salut"}],"max_tokens":256}
    """.data(using: .utf8)!
    let req = try JSONDecoder().decode(AnthropicRequest.self, from: json)
    let (prompt, options) = RequestConverter.extract(from: req)
    #expect(prompt.contains("user: Salut"))
    #expect(options.instructions == "Tu es utile")
    #expect(options.maximumTokens == 256)
}
