import Testing
import Foundation
@testable import FoundationBridgeACP
import FoundationBridgeCore

private func text(_ output: ACPServer.Output) -> String {
    String(data: output.response ?? Data(), encoding: .utf8) ?? ""
}

@Test func acpInitializeRenvoieProtocolVersionEtCapabilities() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: ""))
    let out = await server.process(Data(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"capabilities":{}}}"#.utf8))
    let json = text(out)
    #expect(json.contains("\"protocolVersion\":1"))
    #expect(json.contains("agentCapabilities"))
    #expect(json.contains("\"id\":1"))
    #expect(out.notifications.isEmpty)
}

@Test func acpSessionNewRenvoieUnSessionId() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: ""))
    let out = await server.process(Data(#"{"jsonrpc":"2.0","id":2,"method":"session/new","params":{}}"#.utf8))
    #expect(text(out).contains("\"sessionId\":\"sess_1\""))
}

@Test func acpPromptEmetUpdateEtEndTurn() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: "Bonjour le monde"))
    let out = await server.process(Data(#"{"jsonrpc":"2.0","id":3,"method":"session/prompt","params":{"sessionId":"s1","prompt":[{"type":"text","text":"Salut"}]}}"#.utf8))
    #expect(text(out).contains("\"stopReason\":\"end_turn\""))
    #expect(out.notifications.count == 1)
    let note = String(data: out.notifications[0], encoding: .utf8) ?? ""
    #expect(note.contains("\"sessionUpdate\":\"agent_message_chunk\""))
    #expect(note.contains("Bonjour le monde"))
    #expect(note.contains("session/update"))
}

@Test func acpPromptMultiToursConserveLeContexte() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: "ok"))
    let r1 = await server.process(Data(#"{"jsonrpc":"2.0","id":1,"method":"session/prompt","params":{"sessionId":"s9","prompt":[{"type":"text","text":"A"}]}}"#.utf8))
    let r2 = await server.process(Data(#"{"jsonrpc":"2.0","id":2,"method":"session/prompt","params":{"sessionId":"s9","prompt":[{"type":"text","text":"B"}]}}"#.utf8))
    #expect(text(r1).contains("end_turn"))
    #expect(text(r2).contains("end_turn"))
}

@Test func acpPromptVideEstUneErreur() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: "x"))
    let out = await server.process(Data(#"{"jsonrpc":"2.0","id":4,"method":"session/prompt","params":{"sessionId":"s1","prompt":[{"type":"text","text":"   "}]}}"#.utf8))
    #expect(text(out).contains("error"))
    #expect(out.notifications.isEmpty)
}

@Test func acpMethodeInconnueEstUneErreur() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: ""))
    let out = await server.process(Data(#"{"jsonrpc":"2.0","id":5,"method":"inconnu"}"#.utf8))
    #expect(text(out).contains("-32601"))
}

@Test func acpNotificationEntranteSansIdEstIgnoree() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: ""))
    let out = await server.process(Data(#"{"jsonrpc":"2.0","method":"inconnu"}"#.utf8))
    #expect(out.response == nil)
    #expect(out.notifications.isEmpty)
}

@Test func acpJSONInvalideRenvoieParseError() async {
    let server = ACPServer(backend: MockTextGenerator(scriptedResponse: ""))
    let out = await server.process(Data("pas du json".utf8))
    #expect(text(out).contains("-32700"))
}
