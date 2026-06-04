import Testing
@testable import FoundationBridgeMCP
import FoundationBridgeCore

@Test func listToolsExposeGenerateEtListModels() async {
    let router = MCPToolRouter(backend: MockTextGenerator(scriptedResponse: ""))
    let names = router.listTools().map(\.name)
    #expect(names.contains("generate"))
    #expect(names.contains("list_models"))
}

@Test func generateRenvoieLaReponseDuBackend() async {
    let router = MCPToolRouter(backend: MockTextGenerator(scriptedResponse: "Réponse on-device"))
    let result = await router.callTool(name: "generate", arguments: ["prompt": "Bonjour"])
    #expect(result.text == "Réponse on-device")
    #expect(result.isError == false)
}

@Test func generatePromptVideEstUneErreur() async {
    let router = MCPToolRouter(backend: MockTextGenerator(scriptedResponse: "x"))
    let result = await router.callTool(name: "generate", arguments: ["prompt": "   "])
    #expect(result.isError == true)
}

@Test func generateAvecSessionFonctionneSurDeuxTours() async {
    let router = MCPToolRouter(backend: MockTextGenerator(scriptedResponse: "ok"))
    let r1 = await router.callTool(name: "generate", arguments: ["prompt": "A", "session": "s1"])
    let r2 = await router.callTool(name: "generate", arguments: ["prompt": "B", "session": "s1"])
    #expect(r1.isError == false)
    #expect(r2.isError == false)
    #expect(r2.text == "ok")
}

@Test func generateRemonteLerreurBackendCommeIsError() async {
    let router = MCPToolRouter(
        backend: MockTextGenerator(error: .modelUnavailable(reason: "Apple Intelligence non activé"))
    )
    let result = await router.callTool(name: "generate", arguments: ["prompt": "Salut"])
    #expect(result.isError == true)
    #expect(result.text.contains("indisponible"))
}

@Test func listModelsRenvoieLIdentifiantEtDisponibilite() async {
    // Disponibilité par défaut (.available) → ready=true.
    let router = MCPToolRouter(backend: MockTextGenerator(scriptedResponse: ""), modelId: "apple-foundation")
    let result = await router.callTool(name: "list_models", arguments: [:])
    #expect(result.isError == false)
    #expect(result.text.contains("\"id\":\"apple-foundation\""))
    #expect(result.text.contains("\"ready\":true"))
    #expect(result.text.contains("\"object\":\"list\""))
}

@Test func listModelsRefleteIndisponibilite() async {
    // Modèle non prêt (Apple Intelligence désactivé) → ready=false + raison exposée.
    let router = MCPToolRouter(
        backend: MockTextGenerator(scriptedResponse: ""),
        modelId: "apple-foundation",
        availability: { .appleIntelligenceNotEnabled }
    )
    let result = await router.callTool(name: "list_models", arguments: [:])
    #expect(result.isError == false)
    #expect(result.text.contains("\"ready\":false"))
    #expect(result.text.contains("Apple Intelligence"))
}

@Test func outilInconnuEstUneErreur() async {
    let router = MCPToolRouter(backend: MockTextGenerator(scriptedResponse: ""))
    let result = await router.callTool(name: "inexistant", arguments: [:])
    #expect(result.isError == true)
}
