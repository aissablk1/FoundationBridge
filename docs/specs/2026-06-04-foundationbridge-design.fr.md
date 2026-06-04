---
title: FoundationBridge — Spec de conception (v1/v2)
date: 2026-06-04
author: Aïssa BELKOUSSA
statut: en revue
tags: [swift, foundation-models, mcp, acp, openai, anthropic, on-device, apple-silicon, gateway]
licence: Apache-2.0
---

# FoundationBridge — Spécification de conception

> **Une seule passerelle native qui expose le LLM on-device d'Apple (FoundationModels, macOS 26 / Apple Silicon) à tout l'écosystème agentique** — via MCP, REST OpenAI-compatible, REST Anthropic-compatible, proxy, ACP, CLI et WebSocket — depuis **un seul binaire Swift**, plus des SDK clients multi-langages générés.

**Auteur** : Aïssa BELKOUSSA · **Date** : 2026-06-04 · **Licence** : Apache-2.0
**Cible matérielle** : Mac Apple Silicon (M1+), macOS 26, Apple Intelligence activé.

---

## 1. Problème & raison d'être

La recherche comparative (7 projets existants, 4 protocoles — voir §9 Sources) établit un **manque net** : **aucun** projet ne réunit dans un seul binaire :

- un **binding FoundationModels natif** (inférence on-device, gratuite, privée),
- **+** une double surface **REST OpenAI ET Anthropic**,
- **+** un **mode proxy** (`ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`),
- **+** un **serveur MCP** (stdio + Streamable HTTP),
- **+** un pont **ACP (Zed Agent Client Protocol)**.

| Projet | A | Manque |
|---|---|---|
| `phimage/mcp-foundation-models` | MCP natif propre | stdio seul, pas de streaming, pas de sessions, abandonné |
| `apfel` (upstream, 5,5k ⭐) | REST OpenAI natif + MCP | pas d'Anthropic, contexte 4096 |
| `waybarrios/vllm-mlx` | OpenAI+Anthropic+proxy | sur **MLX**, pas FoundationModels |
| `claude-local-proxy` | conversion Anthropic↔OpenAI | sur **vLLM**, quasi mort, pas de tests |
| `macOS26/Agent` | FoundationModels.Tool + 18 providers | app fermée sur soi, IP 100 % maison |
| `deckameron/Ti.Apple.Intelligence` | helpers haut niveau | session unique, pas de tool calling, schéma simulé |
| ToolPiper | gateway HTTP + MCP façade | **closed source** |

**FoundationBridge comble exactement cette combinaison manquante.**

---

## 2. Objectifs / Non-objectifs

### Objectifs
- Exposer FoundationModels via **tous** les protocoles ciblés (livrés en 2 vagues).
- **Un cœur unique** réutilisable, des **façades protocolaires fines** additives.
- Qualité production : **tests (golden + e2e), CI macOS 26, releases signées**.
- Réutiliser des **dépendances éprouvées** (anti-réinvention) plutôt que réimplémenter.

### Non-objectifs (YAGNI)
- Pas de portage Linux/x86/Windows (FoundationModels est Apple-only — assumé).
- Pas de scaling GPU serveur (modèle on-device, ~4096 tokens).
- Pas de multimodal/embeddings en v1.
- Pas de chatbot de culture générale (modèle ~3 Mds spécialisé tâches courtes).

---

## 3. Critères d'acceptation (v1)

1. **Claude Code** via `ANTHROPIC_BASE_URL` local → réponse complète **et** streaming.
2. **Client OpenAI** via `OPENAI_BASE_URL` → `/v1/chat/completions` (stream + non) et `/v1/models`.
3. **Claude Desktop / Cursor** via **MCP** (stdio) → génération + sortie structurée `@Generable`.
4. **CLI** : prompt unique, chat interactif, stdin/pipe, **codes de sortie sémantiques**.
5. `availability` vérifiée → erreur **actionnable** (HTTP 503/409, code de sortie dédié), jamais de crash opaque.
6. Dépassement `.exceededContextWindowSize` → **HTTP 413/422** exploitable.
7. **Couche de conversion Anthropic↔OpenAI** : suite de **golden tests** sur traces SSE réelles, verte.
8. **CI GitHub Actions** runner **macOS 26** : build + tests verts (gate : vert avant merge).

---

## 4. Architecture — « un cœur, plusieurs façades »

Séparer le **plan exécution** (binding FoundationModels) du **plan transport** (protocoles).

```
FoundationBridge/  (SwiftPM, Swift 6.x strict concurrency, Apache-2.0)
├── FoundationBridgeCore/            # logique métier réutilisable
│   ├── ModelService/
│   │   ├── AvailabilityChecker      #   availability + waitForModel (polling)
│   │   ├── SessionManager           #   LanguageModelSession nommées, multi-tours (actor isolé)
│   │   ├── TextGenerationService    #   protocole ABSTRAIT → testable/substituable (mock)
│   │   ├── StreamingService         #   streamResponse snapshots → flux unifié
│   │   ├── GuidedGeneration         #   @Generable / GenerationSchema (vrai typage)
│   │   └── ToolCalling              #   protocole Tool FoundationModels
│   ├── ContextManager/              #   tokenCount/contextSize + stratégies
│   │   └── ContextOverflowPolicy    #   .exceededContextWindowSize → erreur exploitable
│   ├── Diagnostics/                 #   diagnostics() exhaustif
│   ├── Observability/               #   latence, tokens, taux guardrail
│   ├── Safety/                      #   niveau guardrail (--permissive) + logs
│   └── Errors/                      #   erreurs typées + codes de sortie sémantiques (0–6)
│
├── ProtocolAdapters/
│   ├── MCPAdapter/                  #   SDK MCP Swift officiel — stdio + Streamable HTTP
│   ├── OpenAIAdapter/               #   /v1/chat/completions, /v1/models, SSE
│   ├── AnthropicAdapter/            #   /v1/messages, SSE
│   ├── ConversionLayer/             #   Anthropic↔OpenAI ← golden tests
│   ├── ACPAdapter/                  #   [v2] Zed Agent Client Protocol, JSON-RPC 2.0 / stdio
│   └── WebSocketAdapter/            #   [v2] streaming bidirectionnel
│
├── TransportServer/                 # Hummingbird 2 (ServerTransport swift-openapi-generator)
├── ProxyMode/                       # ANTHROPIC_BASE_URL / OPENAI_BASE_URL passthrough
├── FoundationBridgeCLI/             # exécutable (ArgumentParser + swift-service-lifecycle)
└── Tests/                           # swift-testing / XCTest
```

### Dépendances éprouvées (ne pas réinventer)
- `modelcontextprotocol/swift-sdk` (MCP — **pré-1.0, isolé derrière un adaptateur**)
- **Hummingbird 2** (serveur HTTP léger, Swift Concurrency natif) — **choix validé**
- `swift-openapi-generator` 1.0 (contrat OpenAPI → serveur **et** clients)
- `swift-service-lifecycle` · `swift-argument-parser`

### SDK multi-langages — **OpenAPI-first**
OpenAPI 3.1 = source de vérité unique → génère le **serveur Swift** + clients **TS** (`openapi-typescript`), **Python** (`openapi-python-client`), **Go** (`oapi-codegen`).
**Synergie** : un `@Generable` (modèle) et un schéma OpenAPI (API) décrivent la **même** structure → constrained decoding fiable, cohérence end-to-end.

---

## 5. Mapping protocoles → cœur

| Protocole | Transport | Mapping `ModelService` | Vague |
|---|---|---|---|
| MCP | stdio + Streamable HTTP | respond exposé comme tool ; JSON Schema ↔ GenerationSchema ; snapshot → progress | **v1** |
| REST OpenAI | HTTP + SSE | requête → prompt+instructions ; réponse → `choices`/`delta` | **v1** |
| REST Anthropic | HTTP + SSE | requête → prompt ; réponse → content blocks ; `content_block_delta` | **v1** |
| Conversion | interne | Anthropic↔OpenAI (messages, tool defs, events) — **golden tests** | **v1** |
| Proxy | env var | `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL` reroute local | **v1** |
| CLI | stdin/pipe/args | prompt unique, chat, `-f`, sorties plain/JSON/quiet | **v1** |
| ACP (Zed) | JSON-RPC 2.0 / stdio | `initialize`→availability ; `session/new`→session ; `session/prompt`→respond | **v2** |
| WebSocket | WS | streaming bidirectionnel | **v2** |

> ⚠️ **ACP = Zed Agent Client Protocol uniquement** (vivant). L'IBM/BeeAI « Agent Communication Protocol » est **archivé** (fusionné dans A2A) → **exclu**.

---

## 6. Périmètre v1 (MVP) vs v2

**v1 — cœur différenciant** : binding FM natif (availability + waitForModel + diagnostics) · texte **+ streaming snapshot** · sessions nommées multi-tours · **guided generation @Generable réelle** · tool calling · **REST OpenAI** · **REST Anthropic + conversion testée** · **proxy** · **MCP** stdio+HTTP · **CLI** + codes de sortie sémantiques · gestion contexte 4096 (`tokenCount`/`contextSize` + stratégie `strict` + overflow→HTTP) · cycle de vie robuste + erreurs typées · **CI macOS 26 + golden tests**.

**v2 — extension & robustesse** : **ACP (Zed)** · WebSocket · stratégies contexte avancées · compaction tiérée · observabilité Prometheus + debug · `--permissive` + logs guardrail · **SDK TS/Python/Go publiés** · auth Bearer · sûreté fichiers/garde-fous · filtrage outils par catégorie · benchmarker intégré · **binaire signé/notarisé + Homebrew + releases taguées** · sessions persistées.

---

## 7. Risques & mitigations

| # | Risque | Mitigation |
|---|---|---|
| R1 | Fenêtre **4096 tokens** (limite dure Apple) | `tokenCount`/`contextSize`, trimming, stratégies, overflow→HTTP ; documenter does/doesn't |
| R2 | Verrouillage plateforme (macOS 26 + Apple Silicon + AI) | Assumé ; availability check clair ; doc d'éligibilité |
| R3 | SDK MCP Swift **pré-1.0** + FM récent | Isoler derrière adaptateur + `TextGenerationService` abstrait ; épingler versions |
| R4 | Conversion SSE Anthropic↔OpenAI fragile | **Golden tests** ; tokenizer **exact** Apple (pas cl100k_base) |
| R5 | `LanguageModelSession` non parallèle | **Actor isolé** par session ; pas de busy-wait |
| R6 | Guardrails bloquent prompts bénins | `--permissive` + logs ; refus → erreur actionnable |
| R7 | Confusion ACP Zed vs IBM (archivé) | Cibler **uniquement Zed ACP** |
| R8 | Glue multi-protocole | OpenAPI-first, séparation stricte, CI dès le départ |
| R10 | Over-engineering / bus factor | Réutiliser libs officielles |

---

## 8. Stratégie de tests (TDD)

1. **Unitaires du cœur** via `TextGenerationService` (mock), **sans** charger FoundationModels.
2. **Golden tests de conversion (priorité absolue)** — traces SSE réelles Anthropic/OpenAI.
3. **Contrat OpenAPI** — réponses conformes au schéma.
4. **Intégration par protocole** — un harnais par adaptateur ; CLI : assertions sur codes de sortie.
5. **E2E sur device réel** (CI macOS 26) — vrai FoundationModels.
6. **Concurrence** — sérialisation par actor.
7. **Cycle de vie** — SIGTERM/SIGINT → arrêt gracieux.

**Boucle** : Red → Green → Refactor. CI obligatoire dès le 1er commit.

> Honnêteté (§29/§32) : les chemins e2e nécessitant Apple Intelligence ne sont déclarés « verts » que sur device réel éligible. Tout statut non vérifié → `[NON TESTÉ — device requis]`.

---

## 9. Sources (recherche 2026-06-04, 12 agents)

Projets : phimage/mcp-foundation-models · Arthur-Ficial/apfel · waybarrios/vllm-mlx · macOS26/Agent · deckameron/Ti.Apple.Intelligence · ModelPiper/ToolPiper · CaistsAI/claude-local-proxy.
Protocoles : MCP (spec 2025-11-25, swift-sdk v0.11.x Tier 3) · Zed ACP (vivant) vs IBM/BeeAI ACP (archivé→A2A) · REST OpenAI/Anthropic + proxy · Hummingbird 2 / swift-openapi-generator 1.0 / FoundationModels.

`[À VÉRIFIER]` : perf Hummingbird ~2× Vapor ; valeur exacte 4096 tokens (TN3193 non extrait) — à confirmer avant inscription comme faits dans le README public.
