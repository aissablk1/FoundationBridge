---
title: Rapport détaillé de session — FoundationBridge v2-MVP
session_id: 336bf774-99d6-4023-9f26-517122f9cbb9
date: 2026-06-04
workspace: FoundationBridge
auteur: Aïssa BELKOUSSA
statut: livré + publié
tags: [rapport, swift, foundation-models, mcp, sessions, streaming, auth, securite, tests, ci]
---

# Rapport détaillé de session — FoundationBridge v2-MVP

> Compte rendu exhaustif et hiérarchisé de la session du 2026-06-04 :
> recherche → design → implémentation → perfectionnement → documentation → publication.
> Résultat : v2-MVP livré, **57 tests verts**, **0 warning**, **0 CVE**, poussé sur GitHub.

---

## 0. Contexte & genèse

1. **Point de départ** : question sur l'intégration de **FoundationModels + Playgrounds**
   (WWDC25 #286). Production d'une note de ressource (vault Obsidian).
2. **Recherche d'écosystème** (GitHub + Reddit/Exa) : ponts existants exposant l'IA
   on-device d'Apple aux LLMs — `phimage/mcp-foundation-models`, apfel, vllm-mlx,
   macOS26/Agent, Ti.Apple.Intelligence, claude-local-proxy, ToolPiper.
3. **Découverte** : un projet **FoundationBridge** existait déjà (v1 : serveur REST
   OpenAI/Anthropic + SSE), lié à `github.com/aissablk1/FoundationBridge`. La demande
   « créer le repo le plus complet » s'est donc recadrée en **extension v2**.

---

## 1. Phase Recherche (orchestration multi-agents)

### 1.1 Essaim de découverte (workflow, 18 agents, ~1,2 M tokens)
- **7 teardowns concurrents** (forces/faiblesses, leçons « steal/avoid ») :
  - *steal* : abstraction backend (`TextGenerationService`), `swift-service-lifecycle`,
    config par variables d'environnement, licence permissive.
  - *avoid* : stdio-only, sessions stateless, `Task.sleep` comme run-loop, zéro test,
    hard-code de `SystemLanguageModel.default`.
- **7 protocoles étudiés** : MCP (stdio/HTTP), ACP, OpenAI-compat, Anthropic-compat,
  gRPC/HTTP natif, WebSocket, CLI/stdio.
- **Synthèse** : stratégie SDK (« le protocole EST le SDK »), positionnement startup,
  **critique adversariale de complétude** (10 must-fix).

### 1.2 Findings critiques de la critique adversariale
- `availability` est un **enum** (`.deviceNotEligible`/`.appleIntelligenceNotEnabled`/
  `.modelNotReady`/…), pas un booléen.
- `LanguageModelSession` traite **une requête à la fois** (`isResponding`).
- Le **delta-suffixe** de streaming est **faux** pour la sortie structurée `@Generable`
  (snapshots = structs `PartiallyGenerated`, pas des chaînes préfixes).
- Persistance disque de session **non garantie** → ne pas la promettre.
- Token-counting sans tokenizer public → heuristique + marge.

---

## 2. Phase Design (v2)

- Document : `docs/specs/2026-06-04-foundationbridge-v2-design.md`.
- Architecture « **un cœur, plusieurs façades** » : binding FoundationModels isolé
  derrière `TextGenerating`, adaptateurs de protocole minces au-dessus d'un
  `SessionManager`.
- **Arbitrages YAGNI** : gRPC coupé, serveur iOS de-scopé, `generate_structured`
  reporté en v2.1 (`@Generable`→JSON Schema `[À VÉRIFIER]`).
- **Décisions ouvertes tranchées** : licence Apache-2.0 conservée, port par défaut
  `8080 → 11434` (convention Ollama), périmètre v2-MVP = tout-en-un.

---

## 3. Phase Implémentation (TDD, 3 tranches vérifiées)

### Tranche 1 — `9b8de7f`
- **`FoundationBridgeSession`** : `SessionManager` actor.
  - Sessions nommées multi-tours **en mémoire** (rejeu de transcript).
  - **Une requête en vol par session** (garde `busy` posée avant tout `await`).
  - Garde-fou contexte 4096 ; isolation, delete/reset.
- Port par défaut → 11434 (`ServerConfig`, CLI).
- **+8 tests** (24 → … ; total 34 verts).

### Tranche 2 — `b728f54`
- **`FoundationBridgeMCP`** : séparation logique/transport.
  - `MCPToolRouter` (logique pure, testable sans transport).
  - `MCPServerRunner` (câblage stdio via **SDK officiel** `modelcontextprotocol/swift-sdk`).
  - Outils `generate` (avec session multi-tours) + `list_models`.
- CLI : commande `mcp` (stdout réservé au JSON-RPC).
- **+7 tests** (total 41 verts). Débloque Claude Desktop/Code, Cursor, Zed.

### Tranche 3 — `02fd550`
- **Snapshot streaming réel** : `FoundationModelsGenerator.stream()` utilise
  `session.streamResponse(to:)` → deltas (suffixe de snapshot cumulatif).
  Remplace le repli mono-bloc. *Validé par compilation sur le vrai backend macOS 26.*
- **Auth Bearer optionnelle** : `BearerAuth` (helper pur) + `BearerAuthMiddleware`
  Hummingbird ; `--token` / `FB_TOKEN` / `--host` (refus host non-local sans token).
- **+5 tests** (total 46 verts).

---

## 4. Phase Perfectionnement (analyse → sécurité → debug → tests → perf)

### 4.1 Analyse (4 agents parallèles)
- **CVE** (`cve-analyzer`) : audit OSV des **26 dépendances** SwiftPM → **0 CVE**.
  Vigilance hors-CVE : `swift-sdk` 0.12.1 (pré-1.0), `mattt/eventsource` (bus-factor 1).
- **Erreurs silencieuses** (`silent-failure-hunter`) : findings F1–F4.
  - F1 : `try?` avale l'erreur d'écriture SSE.
  - F2 : fallback `?? "{}"` masque un échec de sérialisation SSE.
  - F3 : fallback `?? Data(...)` masque un échec d'encodage d'erreur.
  - F4 : `catch { jsonError(.invalidInput) }` écrase la cause réelle.
- **Sécurité** : comparaison de token non constante, `/healthz` derrière l'auth, fuite
  de `\(error)` brut.

### 4.2 Corrections — `6e96659`
| Domaine | Correction |
|---|---|
| Sécurité | Comparaison de token à **temps constant** (`BearerAuth.constantTimeEquals`) |
| Sécurité | `/healthz` **exempté** de l'auth (sondes de liveness) |
| Sécurité | SSE : plus de fuite de `\(error)`, journalisation **stderr** |
| Debug | `catch` decode (400) distinct de cause inattendue (500), **journalisés** |
| Debug | `jsonString` : log si sérialisation échoue au lieu d'avaler |
| Perf | Backend `TextGenerating` **injectable** (débloque les tests d'intégration) |
| Perf | **`Retry-After`** sur 503 (modèle indisponible/en téléchargement) |
| Perf | `UnavailableGenerator` : repli explicite hors macOS 26 |

### 4.3 Tests — `6e96659`
- **11 tests d'intégration HTTP réels** (Hummingbird `.router` + `MockTextGenerator`) :
  healthz, models, chat/completions, messages, corps invalide (400), 503+Retry-After.
- **Golden SSE** : OpenAI (`content` deltas + `finish_reason` + `[DONE]`) et Anthropic
  (`message_start`/`content_block_delta`/`message_stop`).
- **Auth** : 401 sans token, 200 avec bon token, `/healthz` exempté.
- **46 → 57 tests verts.**

---

## 5. Phase Documentation

- **`59b277a`** — README aligné sur la réalité v2-MVP (matrice des surfaces, sections
  MCP + auth, port 11434, roadmap v2-MVP/v2.1, modules + 57 tests).
- **`3d56088`** — `PROJECT.nfo` **corrigé** (version 2.0.0 ; STACK/STRUCTURE alignés
  sur le code réel ; suppression des dépendances fictives `swift-openapi-generator`,
  `swift-argument-parser`), statut design « implémenté », journal QQOQCCP.

---

## 6. Phase Publication

- Push `5c2a929..3d56088 main -> main` → **8 commits** publiés (6 de cette session
  + 2 antérieurs non poussés). Dépôt public à jour.

---

## 7. Checks de code (résultats factuels)

| Check | Résultat |
|---|---|
| `swift build -c release` | ✅ complet ; **1 warning** (déprécation MCP) → **corrigé** |
| `swift build` (après fix) | ✅ **0 warning** |
| `swift test` | ✅ **57 tests verts** |
| Force-unwraps suspects | ✅ aucun (hors `HTTPField.Name(...)!` idiomatique) |
| `print(` hors CLI | ✅ aucun (stdout propre pour MCP) |
| TODO/FIXME/XXX | ✅ aucun |
| `try?` résiduels | 2 fallbacks d'encodage **intentionnels** (un journalisé) |
| swiftlint / swift-format | ⚠️ absents de la machine — non exécutés |

---

## 8. Métriques

- **Commits** (session) : 7 (6 v2-MVP + 1 fix déprécation).
- **Tests** : 16 → **57** verts.
- **Modules Swift** : 7 (`Core`, `Session`, `ProtocolConversion`, `FoundationModelsBackend`,
  `Server`, `MCP`, `CLI`).
- **Dépendances** : 26 pins, **0 CVE**.
- **Warnings** : 0.

---

## 9. Décisions & arbitrages

- **Licence** Apache-2.0 maintenue (déjà publiée) — pas de bascule MIT sans accord.
- **Sessions** = in-process uniquement (pas de fausse promesse de persistance).
- **Streaming** : deux chemins (texte = suffixe ; structuré = JSON partiel, v2.1).
- **YAGNI** : gRPC coupé, iOS serveur de-scopé.
- **Process** : pipeline Brainstorm→Ship, gate fact-force désactivé pendant les bursts
  puis **réactivé**, snapshot DELEGATE-52 avant perfectionnement.

---

## 10. Risques & reste à faire (v2.1)

- **`[À VÉRIFIER]`** : extraction du JSON Schema d'une macro `@Generable` au runtime
  (conditionne `generate_structured`) ; tokenizer exact d'Apple ; persistance de session.
- **Non testé en CI** : flux token-par-token du streaming réel → **smoke test sur device**
  (Apple Intelligence) requis.
- **À venir** : MCP Streamable-HTTP, ACP (Zed/JetBrains), WebSocket, Unix socket, SDK
  Swift first-class + guides Python/TS/Go/Rust, observabilité, Homebrew tap + notarisation.

---

## Annexe — Commits de la session

```
<fix>    fix(mcp): API .text(text:annotations:_meta:) non depreciee
3d56088  docs: PROJECT.nfo corrige (modules reels, v2.0.0), statut design, journal
6e96659  harden(server,sec): injection backend, durcissement, tests d'integration
59b277a  docs(readme): reflete le v2-MVP livre
02fd550  feat(stream,auth): snapshot streaming reel + auth Bearer optionnelle
b728f54  feat(mcp): serveur MCP stdio (outils generate + list_models)
9b8de7f  feat(session): SessionManager actor multi-tours + port 11434 + design v2
```
