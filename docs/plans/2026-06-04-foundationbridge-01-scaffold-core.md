# FoundationBridge — Plan 01 : Scaffold & Core foundations

> **Pour les workers agentiques :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development` (recommandé) ou `superpowers:executing-plans`. Étapes en cases à cocher (`- [ ]`).

**Goal :** poser le squelette SwiftPM et les types purs de `FoundationBridgeCore` (erreurs, codes de sortie, modèle de disponibilité, abstraction de génération) — 100 % compilable et testable **sans** Apple Silicon ni FoundationModels.

**Architecture :** un module bibliothèque `FoundationBridgeCore` sans aucune dépendance à FoundationModels. Toute la logique métier dépend d'abstractions (`AvailabilityChecking`, `TextGenerating`) ; le binding réel viendra dans un module séparé `FoundationModelsBackend` (plan 02). Cela rend ce plan exécutable et vérifiable sur n'importe quelle machine Swift.

**Tech Stack :** Swift 6.x (strict concurrency), swift-testing.

**Prérequis machine :** Swift 6.x (`swift --version`). Aucun device Apple Intelligence requis pour ce plan.

---

### Task 1 : Initialiser le package SwiftPM

**Files:**
- Create: `Package.swift`
- Create: `Sources/FoundationBridgeCore/FoundationBridgeCore.swift`
- Create: `Tests/FoundationBridgeCoreTests/SmokeTests.swift`

- [ ] **Step 1 : Écrire `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FoundationBridge",
    platforms: [.macOS(.v15)], // .v26 quand le toolchain le permet ; .v15 garde le Core portable
    products: [
        .library(name: "FoundationBridgeCore", targets: ["FoundationBridgeCore"]),
    ],
    targets: [
        .target(name: "FoundationBridgeCore"),
        .testTarget(
            name: "FoundationBridgeCoreTests",
            dependencies: ["FoundationBridgeCore"]
        ),
    ]
)
```

- [ ] **Step 2 : Écrire un fichier d'amorce du module**

```swift
// Sources/FoundationBridgeCore/FoundationBridgeCore.swift
/// Espace de noms public du cœur de FoundationBridge.
/// Ce module ne dépend PAS de FoundationModels : il reste portable et testable partout.
public enum FoundationBridge {
    /// Version sémantique du cœur.
    public static let coreVersion = "0.0.1"
}
```

- [ ] **Step 3 : Écrire le test de fumée (échec attendu : module pas encore construit)**

```swift
// Tests/FoundationBridgeCoreTests/SmokeTests.swift
import Testing
@testable import FoundationBridgeCore

@Test func coreVersionIsExposed() {
    #expect(FoundationBridge.coreVersion == "0.0.1")
}
```

- [ ] **Step 4 : Construire et tester**

Run: `swift test`
Expected: PASS (1 test). Si `swift test` échoue à résoudre, vérifier `swift --version` ≥ 6.0.

- [ ] **Step 5 : Commit**

```bash
git add Package.swift Sources/FoundationBridgeCore/FoundationBridgeCore.swift Tests/FoundationBridgeCoreTests/SmokeTests.swift
git commit -m "chore: scaffold SwiftPM package and FoundationBridgeCore module"
```

---

### Task 2 : Codes de sortie sémantiques (`ExitCode`)

Inspiré des codes 0–6 d'apfel : excellents pour le scripting et l'orchestration.

**Files:**
- Create: `Sources/FoundationBridgeCore/Errors/ExitCode.swift`
- Test: `Tests/FoundationBridgeCoreTests/ExitCodeTests.swift`

- [ ] **Step 1 : Écrire le test (échec attendu)**

```swift
// Tests/FoundationBridgeCoreTests/ExitCodeTests.swift
import Testing
@testable import FoundationBridgeCore

@Test func exitCodesAreStableIntegers() {
    #expect(ExitCode.success.rawValue == 0)
    #expect(ExitCode.genericError.rawValue == 1)
    #expect(ExitCode.modelUnavailable.rawValue == 2)
    #expect(ExitCode.guardrailBlocked.rawValue == 3)
    #expect(ExitCode.contextOverflow.rawValue == 4)
    #expect(ExitCode.invalidInput.rawValue == 5)
    #expect(ExitCode.rateLimited.rawValue == 6)
}
```

- [ ] **Step 2 : Lancer le test**

Run: `swift test --filter ExitCodeTests`
Expected: FAIL ("cannot find 'ExitCode' in scope")

- [ ] **Step 3 : Implémenter `ExitCode`**

```swift
// Sources/FoundationBridgeCore/Errors/ExitCode.swift
/// Codes de sortie sémantiques pour la CLI et l'orchestration.
/// Stables : ne JAMAIS réordonner les valeurs (contrat scripté).
public enum ExitCode: Int32, Sendable, CaseIterable {
    case success         = 0
    case genericError    = 1
    case modelUnavailable = 2
    case guardrailBlocked = 3
    case contextOverflow = 4
    case invalidInput    = 5
    case rateLimited     = 6
}
```

- [ ] **Step 4 : Lancer le test**

Run: `swift test --filter ExitCodeTests`
Expected: PASS

- [ ] **Step 5 : Commit**

```bash
git add Sources/FoundationBridgeCore/Errors/ExitCode.swift Tests/FoundationBridgeCoreTests/ExitCodeTests.swift
git commit -m "feat(core): add semantic ExitCode enum"
```

---

### Task 3 : Erreurs typées (`BridgeError`)

Chaque erreur porte un `ExitCode` ET un statut HTTP — c'est le pont entre CLI et serveur.

**Files:**
- Create: `Sources/FoundationBridgeCore/Errors/BridgeError.swift`
- Test: `Tests/FoundationBridgeCoreTests/BridgeErrorTests.swift`

- [ ] **Step 1 : Écrire le test (échec attendu)**

```swift
// Tests/FoundationBridgeCoreTests/BridgeErrorTests.swift
import Testing
@testable import FoundationBridgeCore

@Test func bridgeErrorMapsToExitCode() {
    #expect(BridgeError.modelUnavailable(reason: "x").exitCode == .modelUnavailable)
    #expect(BridgeError.contextOverflow(tokens: 5000, limit: 4096).exitCode == .contextOverflow)
    #expect(BridgeError.guardrailBlocked(reason: "x").exitCode == .guardrailBlocked)
    #expect(BridgeError.invalidInput(field: "prompt").exitCode == .invalidInput)
}

@Test func bridgeErrorMapsToHTTPStatus() {
    #expect(BridgeError.modelUnavailable(reason: "x").httpStatus == 503)
    #expect(BridgeError.contextOverflow(tokens: 5000, limit: 4096).httpStatus == 413)
    #expect(BridgeError.guardrailBlocked(reason: "x").httpStatus == 422)
    #expect(BridgeError.invalidInput(field: "prompt").httpStatus == 400)
}
```

- [ ] **Step 2 : Lancer le test**

Run: `swift test --filter BridgeErrorTests`
Expected: FAIL ("cannot find 'BridgeError' in scope")

- [ ] **Step 3 : Implémenter `BridgeError`**

```swift
// Sources/FoundationBridgeCore/Errors/BridgeError.swift
import Foundation

/// Erreur unifiée du cœur, traduisible en code de sortie CLI et en statut HTTP.
public enum BridgeError: Error, Sendable, Equatable {
    case modelUnavailable(reason: String)
    case contextOverflow(tokens: Int, limit: Int)
    case guardrailBlocked(reason: String)
    case invalidInput(field: String)
    case generic(message: String)

    public var exitCode: ExitCode {
        switch self {
        case .modelUnavailable: return .modelUnavailable
        case .contextOverflow:  return .contextOverflow
        case .guardrailBlocked: return .guardrailBlocked
        case .invalidInput:     return .invalidInput
        case .generic:          return .genericError
        }
    }

    /// Statut HTTP exploitable côté client (cf. spec §3 critère 6).
    public var httpStatus: Int {
        switch self {
        case .modelUnavailable: return 503
        case .contextOverflow:  return 413
        case .guardrailBlocked: return 422
        case .invalidInput:     return 400
        case .generic:          return 500
        }
    }

    public var message: String {
        switch self {
        case .modelUnavailable(let r): return "Modèle indisponible : \(r)"
        case .contextOverflow(let t, let l): return "Dépassement de contexte : \(t) tokens > \(l)"
        case .guardrailBlocked(let r): return "Bloqué par les garde-fous : \(r)"
        case .invalidInput(let f): return "Entrée invalide : champ '\(f)'"
        case .generic(let m): return m
        }
    }
}
```

- [ ] **Step 4 : Lancer le test**

Run: `swift test --filter BridgeErrorTests`
Expected: PASS

- [ ] **Step 5 : Commit**

```bash
git add Sources/FoundationBridgeCore/Errors/BridgeError.swift Tests/FoundationBridgeCoreTests/BridgeErrorTests.swift
git commit -m "feat(core): add BridgeError with exit-code and HTTP mapping"
```

---

### Task 4 : Modèle de disponibilité (`ModelAvailability`)

Reprend les états détaillés de deckameron, mappés sur HTTP/ExitCode.

**Files:**
- Create: `Sources/FoundationBridgeCore/ModelService/ModelAvailability.swift`
- Test: `Tests/FoundationBridgeCoreTests/ModelAvailabilityTests.swift`

- [ ] **Step 1 : Écrire le test (échec attendu)**

```swift
// Tests/FoundationBridgeCoreTests/ModelAvailabilityTests.swift
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
```

- [ ] **Step 2 : Lancer le test**

Run: `swift test --filter ModelAvailabilityTests`
Expected: FAIL ("cannot find 'ModelAvailability' in scope")

- [ ] **Step 3 : Implémenter `ModelAvailability`**

```swift
// Sources/FoundationBridgeCore/ModelService/ModelAvailability.swift
/// État de disponibilité du modèle on-device, indépendant de FoundationModels.
/// Le backend réel (plan 02) traduit SystemLanguageModel.availability vers ce type.
public enum ModelAvailability: Sendable, Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unknown(String)

    public var isReady: Bool {
        if case .available = self { return true }
        return false
    }

    public var reason: String {
        switch self {
        case .available: return "disponible"
        case .deviceNotEligible: return "appareil non éligible à Apple Intelligence"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence non activé"
        case .modelNotReady: return "modèle en cours de téléchargement / non prêt"
        case .unknown(let s): return s
        }
    }

    /// Renvoie une `BridgeError` actionnable si le modèle n'est pas prêt, sinon nil.
    public func asErrorIfUnavailable() -> BridgeError? {
        isReady ? nil : .modelUnavailable(reason: reason)
    }
}
```

- [ ] **Step 4 : Lancer le test**

Run: `swift test --filter ModelAvailabilityTests`
Expected: PASS

- [ ] **Step 5 : Commit**

```bash
git add Sources/FoundationBridgeCore/ModelService/ModelAvailability.swift Tests/FoundationBridgeCoreTests/ModelAvailabilityTests.swift
git commit -m "feat(core): add ModelAvailability state with actionable error mapping"
```

---

### Task 5 : Abstraction de génération (`TextGenerating`) + mock

C'est le point qui rend tout le reste testable sans device (pattern `TextGenerationService` de phimage, généralisé).

**Files:**
- Create: `Sources/FoundationBridgeCore/ModelService/TextGenerating.swift`
- Create: `Sources/FoundationBridgeCore/Testing/MockTextGenerator.swift`
- Test: `Tests/FoundationBridgeCoreTests/TextGeneratingTests.swift`

- [ ] **Step 1 : Écrire le test (échec attendu)**

```swift
// Tests/FoundationBridgeCoreTests/TextGeneratingTests.swift
import Testing
@testable import FoundationBridgeCore

@Test func mockGeneratorReturnsConfiguredText() async throws {
    let gen = MockTextGenerator(scriptedResponse: "bonjour")
    let out = try await gen.respond(to: "salut", options: .init())
    #expect(out == "bonjour")
}

@Test func mockGeneratorStreamsChunks() async throws {
    let gen = MockTextGenerator(scriptedChunks: ["a", "b", "c"])
    var received: [String] = []
    for try await chunk in gen.stream(to: "x", options: .init()) {
        received.append(chunk)
    }
    #expect(received == ["a", "b", "c"])
}

@Test func mockGeneratorCanThrowBridgeError() async {
    let gen = MockTextGenerator(error: .guardrailBlocked(reason: "test"))
    await #expect(throws: BridgeError.self) {
        _ = try await gen.respond(to: "x", options: .init())
    }
}
```

- [ ] **Step 2 : Lancer le test**

Run: `swift test --filter TextGeneratingTests`
Expected: FAIL ("cannot find 'MockTextGenerator' in scope")

- [ ] **Step 3 : Implémenter le protocole et les options**

```swift
// Sources/FoundationBridgeCore/ModelService/TextGenerating.swift

/// Options de génération indépendantes du backend.
public struct GenerationOptions: Sendable, Equatable {
    public var temperature: Double?
    public var maximumTokens: Int?
    public var instructions: String?

    public init(temperature: Double? = nil, maximumTokens: Int? = nil, instructions: String? = nil) {
        self.temperature = temperature
        self.maximumTokens = maximumTokens
        self.instructions = instructions
    }
}

/// Abstraction du moteur de génération. Le backend FoundationModels (plan 02)
/// et le mock (tests) la conforment. Tout le code transport dépend de CETTE
/// interface, jamais directement de FoundationModels.
public protocol TextGenerating: Sendable {
    /// Réponse complète (non-stream).
    func respond(to prompt: String, options: GenerationOptions) async throws -> String

    /// Flux de chunks (streaming). Pour FoundationModels : mappé sur les snapshots partiels.
    func stream(to prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error>
}
```

- [ ] **Step 4 : Implémenter le mock**

```swift
// Sources/FoundationBridgeCore/Testing/MockTextGenerator.swift

/// Générateur factice pour les tests : aucune dépendance à FoundationModels.
public struct MockTextGenerator: TextGenerating {
    private let scriptedResponse: String
    private let scriptedChunks: [String]
    private let error: BridgeError?

    public init(scriptedResponse: String = "", scriptedChunks: [String] = [], error: BridgeError? = nil) {
        self.scriptedResponse = scriptedResponse
        self.scriptedChunks = scriptedChunks
        self.error = error
    }

    public func respond(to prompt: String, options: GenerationOptions) async throws -> String {
        if let error { throw error }
        return scriptedResponse
    }

    public func stream(to prompt: String, options: GenerationOptions) -> AsyncThrowingStream<String, Error> {
        let chunks = scriptedChunks
        let error = error
        return AsyncThrowingStream { continuation in
            if let error { continuation.finish(throwing: error); return }
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}
```

- [ ] **Step 5 : Lancer le test**

Run: `swift test --filter TextGeneratingTests`
Expected: PASS (3 tests)

- [ ] **Step 6 : Commit**

```bash
git add Sources/FoundationBridgeCore/ModelService/TextGenerating.swift Sources/FoundationBridgeCore/Testing/MockTextGenerator.swift Tests/FoundationBridgeCoreTests/TextGeneratingTests.swift
git commit -m "feat(core): add TextGenerating abstraction and MockTextGenerator"
```

---

### Task 6 : Suite complète verte + jalon

- [ ] **Step 1 : Lancer toute la suite**

Run: `swift test`
Expected: PASS (tous les tests des tâches 1–5).

- [ ] **Step 2 : Vérifier le build release**

Run: `swift build -c release`
Expected: succès, aucun warning de concurrence stricte.

- [ ] **Step 3 : Commit du jalon**

```bash
git add -A docs/
git commit -m "docs: mark plan 01 (scaffold & core) complete — core compiles and tests green"
```

> ⚠️ Si `swift build` échoue parce que le toolchain Swift 6 n'est pas installé : c'est l'unique prérequis machine de ce plan. Aucun device Apple Intelligence n'est nécessaire ici (tout est testé contre `MockTextGenerator`).

---

## Self-review (writing-plans)

- **Couverture spec** : ce plan couvre les fondations des critères §3.4 (codes de sortie), §3.5 (availability actionnable), §3.6 (overflow→HTTP via `BridgeError`), et l'abstraction testable (§8.1). Les critères 1–3, 7 sont couverts par les plans 02, 05–07.
- **Placeholders** : aucun — chaque étape contient le code réel.
- **Cohérence des types** : `ExitCode`, `BridgeError`, `ModelAvailability`, `GenerationOptions`, `TextGenerating`, `MockTextGenerator` sont définis ici et réutilisés tels quels par les plans suivants. `BridgeError.contextOverflow` sera levé par le `ContextManager` (plan 03) ; `ModelAvailability` sera produit par `FoundationModelsBackend` (plan 02).

## Handoff

Plan 01 prêt. Exécuter via `superpowers:subagent-driven-development` (subagent frais par tâche, revue entre tâches), puis enchaîner sur le plan 02 (binding FoundationModels) — à détailler avant exécution.
