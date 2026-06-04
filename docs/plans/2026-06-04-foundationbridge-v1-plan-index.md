# FoundationBridge v1 — Index des plans d'implémentation

> **Pour les workers agentiques :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development` (recommandé) ou `superpowers:executing-plans` pour exécuter chaque sous-plan tâche par tâche. Étapes en cases à cocher (`- [ ]`).

**Goal :** livrer FoundationBridge v1 — passerelle Swift mono-binaire exposant le LLM on-device d'Apple via REST OpenAI/Anthropic, proxy, MCP et CLI — en incréments compilables et testés.

**Architecture :** « un cœur, plusieurs façades ». `FoundationBridgeCore` (types purs, n'importe PAS FoundationModels) + `FoundationModelsBackend` (gardé `#if canImport(FoundationModels)`) + adaptateurs de protocole fins + serveur Hummingbird 2. Contrat OpenAPI = source de vérité.

**Tech Stack :** Swift 6.x (strict concurrency), Hummingbird 2, swift-openapi-generator 1.0, modelcontextprotocol/swift-sdk, swift-service-lifecycle, swift-argument-parser, swift-testing.

---

## Pourquoi cette décomposition

Le spec (`docs/specs/2026-06-04-foundationbridge-design.md`) couvre plusieurs sous-systèmes indépendants. Chacun devient un **sous-plan** produisant un logiciel fonctionnel et testable seul. Ordre choisi pour **maximiser ce qui est testable sans device** d'abord, puis brancher le binding réel, puis les façades.

| # | Sous-plan | Produit | Testable sans device ? | Dépend de |
|---|---|---|---|---|
| **01** | **Scaffold & Core foundations** | `Package.swift`, `FoundationBridgeCore` : `BridgeError`, `ExitCode`, `ModelAvailability`, protocoles `AvailabilityChecking` / `TextGenerating` + mocks, tests | ✅ **Oui** (100 %) | — |
| **02** | **FoundationModels backend** | `FoundationModelsBackend` : `SessionManager` (actor), `respond`, streaming snapshot, `@Generable`, tool calling, `tokenCount`/`contextSize` | ❌ e2e device (`[NON TESTÉ — device requis]` en CI sans runner éligible) | 01 |
| **03** | **ContextManager** | comptage tokens, stratégie `strict`, `ContextOverflowPolicy` → erreur exploitable | ✅ Oui (logique) / e2e device pour le vrai tokenizer | 01 |
| **04** | **OpenAPI + TransportServer** | contrat OpenAPI 3.1, génération serveur Hummingbird, `GET /healthz`, cycle de vie | ✅ Oui (serveur monte, route santé) | 01 |
| **05** | **OpenAIAdapter** | `POST /v1/chat/completions` (+`/v1/models`), SSE, mapping vers `TextGenerating` | ✅ Oui (contre mock) / e2e device | 02, 04 |
| **06** | **AnthropicAdapter + ConversionLayer** | `POST /v1/messages`, SSE, conversion Anthropic↔OpenAI + **golden tests** (priorité) | ✅ **Oui** (golden tests sur traces) | 05 |
| **07** | **ProxyMode** | passthrough `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`, reroute local | ✅ Oui (intégration locale) | 05, 06 |
| **08** | **MCPAdapter** | serveur MCP stdio + Streamable HTTP, tools `generate` / `generate_structured`, JSON Schema ↔ GenerationSchema | ✅ Oui (handshake/tools contre mock) / e2e device | 02 |
| **09** | **CLI** | `FoundationBridgeCLI` : prompt unique, chat, stdin/pipe, sorties plain/JSON/quiet, **codes de sortie sémantiques** | ✅ Oui (codes de sortie contre mock) | 02, 03 |
| **10** | **CI & release** | GitHub Actions runner macOS 26 (build + tests), badge, tag v0.1.0 | ✅ Oui (workflow) | tous |

**Règle de gate inter-plans (§32)** : un sous-plan n'est « terminé » que si `swift build` + ses tests sont **verts**. Les chemins exigeant Apple Intelligence sont marqués `[NON TESTÉ — device requis]` et exécutés sur runner macOS 26 éligible (plan 10).

---

## Détail disponible

- **Plan 01** détaillé (TDD bite-sized, code complet) : `docs/plans/2026-06-04-foundationbridge-01-scaffold-core.md`.
- Plans 02–10 : à détailler à la même granularité au fur et à mesure (chacun rédigé via `superpowers:writing-plans` avant son exécution, pour éviter la dérive de types entre un plan écrit trop tôt et le code réel).

---

## Handoff d'exécution

Exécuter **dans l'ordre** 01 → 10. Pour chaque sous-plan :
1. Le (re)rédiger en détail si pas encore fait.
2. L'exécuter via `superpowers:subagent-driven-development` (subagent frais par tâche, revue entre tâches).
3. Gate vert (build + tests) avant de passer au suivant.

**Contrainte device** : les plans 02, et les chemins e2e de 03/05/08/09, nécessitent un Mac Apple Silicon sous macOS 26 avec Apple Intelligence activé pour la validation réelle.
