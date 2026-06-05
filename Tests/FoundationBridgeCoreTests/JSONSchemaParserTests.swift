import Testing
@testable import FoundationBridgeCore

@Test func parseObjetAvecChampsScalairesEtRequired() throws {
    let json = """
    {"type":"object","properties":{
      "name":{"type":"string","description":"Nom complet"},
      "age":{"type":"integer"},
      "score":{"type":"number"},
      "active":{"type":"boolean"}
    },"required":["name","age"]}
    """
    let node = try JSONSchemaParser.parse(json: json, rootName: "Person")
    guard case let .object(name, props, _) = node else {
        Issue.record("racine devrait être un objet"); return
    }
    #expect(name == "Person")
    #expect(props.count == 4)
    // Ordre déterministe (tri par nom) : active, age, name, score.
    #expect(props.map(\.name) == ["active", "age", "name", "score"])
    let byName = Dictionary(uniqueKeysWithValues: props.map { ($0.name, $0) })
    #expect(byName["name"]?.required == true)
    #expect(byName["age"]?.required == true)
    #expect(byName["score"]?.required == false)
    #expect(byName["name"]?.schema == .string(description: "Nom complet"))
}

@Test func parseTableauEtEnumEtObjetImbrique() throws {
    let json = """
    {"type":"object","properties":{
      "tags":{"type":"array","items":{"type":"string"}},
      "status":{"enum":["ouvert","fermé"]},
      "owner":{"type":"object","properties":{"id":{"type":"integer"}},"required":["id"]}
    }}
    """
    let node = try JSONSchemaParser.parse(json: json)
    guard case let .object(_, props, _) = node else { Issue.record("objet attendu"); return }
    let byName = Dictionary(uniqueKeysWithValues: props.map { ($0.name, $0) })
    #expect(byName["tags"]?.schema == .array(items: .string(description: nil), description: nil))
    #expect(byName["status"]?.schema == .enumeration(values: ["ouvert", "fermé"], description: nil))
    if case let .object(_, ownerProps, _)? = byName["owner"]?.schema {
        #expect(ownerProps.first?.name == "id")
        #expect(ownerProps.first?.required == true)
    } else {
        Issue.record("owner devrait être un objet imbriqué")
    }
}

@Test func parseJSONInvalideLeveUneErreur() {
    #expect(throws: BridgeError.self) {
        try JSONSchemaParser.parse(json: "pas du json")
    }
}

@Test func parseTypeNonSupporteLeveUneErreur() {
    // `null` n'est pas dans le sous-ensemble supporté.
    #expect(throws: BridgeError.self) {
        try JSONSchemaParser.parse(json: #"{"type":"null"}"#)
    }
}

@Test func parseArraySansItemsLeveUneErreur() {
    #expect(throws: BridgeError.self) {
        try JSONSchemaParser.parse(json: #"{"type":"array"}"#)
    }
}
