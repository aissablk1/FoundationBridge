import Testing
import Foundation
@testable import ProtocolConversion

@Test func buildsOpenAIResponseRoundTrip() throws {
    let resp = ResponseBuilder.openAI(text: "réponse", model: "local", id: "chatcmpl-fixed")
    let data = try JSONEncoder().encode(resp)
    let decoded = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
    #expect(decoded.object == "chat.completion")
    #expect(decoded.choices.first?.message.content == "réponse")
    #expect(decoded.choices.first?.finishReason == "stop")
    // Vérifie le snake_case dans le JSON brut
    let raw = String(data: data, encoding: .utf8)!
    #expect(raw.contains("finish_reason"))
}

@Test func buildsAnthropicResponseRoundTrip() throws {
    let resp = ResponseBuilder.anthropic(text: "salut", model: "local", id: "msg_fixed")
    let data = try JSONEncoder().encode(resp)
    let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
    #expect(decoded.type == "message")
    #expect(decoded.role == "assistant")
    #expect(decoded.content.first?.text == "salut")
    #expect(decoded.stopReason == "end_turn")
    let raw = String(data: data, encoding: .utf8)!
    #expect(raw.contains("stop_reason"))
}
