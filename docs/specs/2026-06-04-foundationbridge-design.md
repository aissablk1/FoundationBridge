---
title: FoundationBridge — Design spec (v1/v2)
date: 2026-06-04
author: Aïssa BELKOUSSA
status: in review
tags: [swift, foundation-models, mcp, acp, openai, anthropic, on-device, apple-silicon, gateway]
license: Apache-2.0
---

# FoundationBridge — Design specification

🇬🇧 **English** · 🇫🇷 [Français](2026-06-04-foundationbridge-design.fr.md)

> **A single native gateway that exposes Apple's on-device LLM (FoundationModels, macOS 26 / Apple Silicon) to the whole agentic ecosystem** — via MCP, OpenAI-compatible REST, Anthropic-compatible REST, proxy, ACP, CLI and WebSocket — from **a single Swift binary**, plus generated multi-language client SDKs.

**Author**: Aïssa BELKOUSSA · **Date**: 2026-06-04 · **License**: Apache-2.0
**Target hardware**: Apple Silicon Mac (M1+), macOS 26, Apple Intelligence enabled.

---

## 1. Problem & rationale

Comparative research (7 existing projects, 4 protocols — see §9 Sources) establishes a **clear gap**: **no** project combines, in a single binary:

- a **native FoundationModels binding** (on-device, free, private inference),
- **+** a dual **OpenAI AND Anthropic REST** surface,
- **+** a **proxy mode** (`ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`),
- **+** an **MCP server** (stdio + Streamable HTTP),
- **+** an **ACP (Zed Agent Client Protocol)** bridge.

| Project | Has | Missing |
|---|---|---|
| `phimage/mcp-foundation-models` | clean native MCP | stdio only, no streaming, no sessions, abandoned |
| `apfel` (upstream, 5.5k ⭐) | native OpenAI REST + MCP | no Anthropic, 4096 context |
| `waybarrios/vllm-mlx` | OpenAI+Anthropic+proxy | on **MLX**, not FoundationModels |
| `claude-local-proxy` | Anthropic↔OpenAI conversion | on **vLLM**, near-dead, no tests |
| `macOS26/Agent` | FoundationModels.Tool + 18 providers | self-contained app, 100% in-house IP |
| `deckameron/Ti.Apple.Intelligence` | high-level helpers | single session, no tool calling, simulated schema |
| ToolPiper | HTTP gateway + MCP façade | **closed source** |

**FoundationBridge fills exactly this missing combination.**

---

## 2. Goals / Non-goals

### Goals
- Expose FoundationModels through **all** targeted protocols (shipped in 2 waves).
- **A single reusable core** with **thin, additive protocol façades**.
- Production quality: **tests (golden + e2e), macOS 26 CI, signed releases**.
- Reuse **proven dependencies** (anti-reinvention) rather than reimplement.

### Non-goals (YAGNI)
- No Linux/x86/Windows port (FoundationModels is Apple-only — accepted).
- No server-side GPU scaling (on-device model, ~4096 tokens).
- No multimodal/embeddings in v1.
- No general-knowledge chatbot (~3B model specialized for short tasks).

---

## 3. Acceptance criteria (v1)

1. **Claude Code** via local `ANTHROPIC_BASE_URL` → full response **and** streaming.
2. **OpenAI client** via `OPENAI_BASE_URL` → `/v1/chat/completions` (stream + non) and `/v1/models`.
3. **Claude Desktop / Cursor** via **MCP** (stdio) → generation + structured `@Generable` output.
4. **CLI**: single prompt, interactive chat, stdin/pipe, **semantic exit codes**.
5. `availability` checked → **actionable** error (HTTP 503/409, dedicated exit code), never an opaque crash.
6. `.exceededContextWindowSize` overflow → usable **HTTP 413/422**.
7. **Anthropic↔OpenAI conversion layer**: green suite of **golden tests** on real SSE traces.
8. **GitHub Actions CI** on a **macOS 26** runner: green build + tests (gate: green before merge).

---

## 4. Architecture — "one core, many façades"

Separate the **execution plane** (FoundationModels binding) from the **transport plane** (protocols).

```
FoundationBridge/  (SwiftPM, Swift 6.x strict concurrency, Apache-2.0)
├── FoundationBridgeCore/            # reusable business logic
│   ├── ModelService/
│   │   ├── AvailabilityChecker      #   availability + waitForModel (polling)
│   │   ├── SessionManager           #   named LanguageModelSession, multi-turn (isolated actor)
│   │   ├── TextGenerationService    #   ABSTRACT protocol → testable/substitutable (mock)
│   │   ├── StreamingService         #   streamResponse snapshots → unified stream
│   │   ├── GuidedGeneration         #   @Generable / GenerationSchema (real typing)
│   │   └── ToolCalling              #   FoundationModels Tool protocol
│   ├── ContextManager/              #   tokenCount/contextSize + strategies
│   │   └── ContextOverflowPolicy    #   .exceededContextWindowSize → usable error
│   ├── Diagnostics/                 #   exhaustive diagnostics()
│   ├── Observability/               #   latency, tokens, guardrail rate
│   ├── Safety/                      #   guardrail level (--permissive) + logs
│   └── Errors/                      #   typed errors + semantic exit codes (0–6)
│
├── ProtocolAdapters/
│   ├── MCPAdapter/                  #   official Swift MCP SDK — stdio + Streamable HTTP
│   ├── OpenAIAdapter/               #   /v1/chat/completions, /v1/models, SSE
│   ├── AnthropicAdapter/            #   /v1/messages, SSE
│   ├── ConversionLayer/             #   Anthropic↔OpenAI ← golden tests
│   ├── ACPAdapter/                  #   [v2] Zed Agent Client Protocol, JSON-RPC 2.0 / stdio
│   └── WebSocketAdapter/            #   [v2] bidirectional streaming
│
├── TransportServer/                 # Hummingbird 2 (ServerTransport swift-openapi-generator)
├── ProxyMode/                       # ANTHROPIC_BASE_URL / OPENAI_BASE_URL passthrough
├── FoundationBridgeCLI/             # executable (ArgumentParser + swift-service-lifecycle)
└── Tests/                           # swift-testing / XCTest
```

### Proven dependencies (do not reinvent)
- `modelcontextprotocol/swift-sdk` (MCP — **pre-1.0, isolated behind an adapter**)
- **Hummingbird 2** (lightweight HTTP server, native Swift Concurrency) — **validated choice**
- `swift-openapi-generator` 1.0 (OpenAPI contract → server **and** clients)
- `swift-service-lifecycle` · `swift-argument-parser`

### Multi-language SDKs — **OpenAPI-first**
OpenAPI 3.1 = single source of truth → generates the **Swift server** + **TS** (`openapi-typescript`), **Python** (`openapi-python-client`), **Go** (`oapi-codegen`) clients.
**Synergy**: a `@Generable` (model) and an OpenAPI schema (API) describe the **same** structure → reliable constrained decoding, end-to-end consistency.

---

## 5. Protocol → core mapping

| Protocol | Transport | `ModelService` mapping | Wave |
|---|---|---|---|
| MCP | stdio + Streamable HTTP | respond exposed as a tool ; JSON Schema ↔ GenerationSchema ; snapshot → progress | **v1** |
| OpenAI REST | HTTP + SSE | request → prompt+instructions ; response → `choices`/`delta` | **v1** |
| Anthropic REST | HTTP + SSE | request → prompt ; response → content blocks ; `content_block_delta` | **v1** |
| Conversion | internal | Anthropic↔OpenAI (messages, tool defs, events) — **golden tests** | **v1** |
| Proxy | env var | `ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL` local reroute | **v1** |
| CLI | stdin/pipe/args | single prompt, chat, `-f`, plain/JSON/quiet outputs | **v1** |
| ACP (Zed) | JSON-RPC 2.0 / stdio | `initialize`→availability ; `session/new`→session ; `session/prompt`→respond | **v2** |
| WebSocket | WS | bidirectional streaming | **v2** |

> ⚠️ **ACP = Zed Agent Client Protocol only** (alive). The IBM/BeeAI "Agent Communication Protocol" is **archived** (merged into A2A) → **excluded**.

---

## 6. v1 (MVP) scope vs v2

**v1 — differentiating core**: native FM binding (availability + waitForModel + diagnostics) · text **+ snapshot streaming** · named multi-turn sessions · **real @Generable guided generation** · tool calling · **OpenAI REST** · **Anthropic REST + tested conversion** · **proxy** · **MCP** stdio+HTTP · **CLI** + semantic exit codes · 4096 context management (`tokenCount`/`contextSize` + `strict` strategy + overflow→HTTP) · robust lifecycle + typed errors · **macOS 26 CI + golden tests**.

**v2 — extension & robustness**: **ACP (Zed)** · WebSocket · advanced context strategies · tiered compaction · Prometheus + debug observability · `--permissive` + guardrail logs · **published TS/Python/Go SDKs** · Bearer auth · file safety/guardrails · per-category tool filtering · built-in benchmarker · **signed/notarized binary + Homebrew + tagged releases** · persisted sessions.

---

## 7. Risks & mitigations

| # | Risk | Mitigation |
|---|---|---|
| R1 | **4096-token** window (Apple hard limit) | `tokenCount`/`contextSize`, trimming, strategies, overflow→HTTP ; document does/doesn't |
| R2 | Platform lock-in (macOS 26 + Apple Silicon + AI) | Accepted ; clear availability check ; eligibility doc |
| R3 | **Pre-1.0** Swift MCP SDK + recent FM | Isolate behind adapter + abstract `TextGenerationService` ; pin versions |
| R4 | Fragile Anthropic↔OpenAI SSE conversion | **Golden tests** ; **exact** Apple tokenizer (not cl100k_base) |
| R5 | `LanguageModelSession` not parallel | **Isolated actor** per session ; no busy-wait |
| R6 | Guardrails block benign prompts | `--permissive` + logs ; refusal → actionable error |
| R7 | Zed ACP vs IBM (archived) confusion | Target **Zed ACP only** |
| R8 | Multi-protocol glue | OpenAPI-first, strict separation, CI from the start |
| R10 | Over-engineering / bus factor | Reuse official libraries |

---

## 8. Test strategy (TDD)

1. **Core unit tests** via `TextGenerationService` (mock), **without** loading FoundationModels.
2. **Conversion golden tests (top priority)** — real Anthropic/OpenAI SSE traces.
3. **OpenAPI contract** — schema-conformant responses.
4. **Per-protocol integration** — one harness per adapter ; CLI: exit-code assertions.
5. **E2E on real device** (macOS 26 CI) — real FoundationModels.
6. **Concurrency** — actor serialization.
7. **Lifecycle** — SIGTERM/SIGINT → graceful shutdown.

**Loop**: Red → Green → Refactor. CI mandatory from the 1st commit.

> Honesty (§29/§32): e2e paths requiring Apple Intelligence are only declared "green" on a real eligible device. Any unverified status → `[NOT TESTED — device required]`.

---

## 9. Sources (research 2026-06-04, 12 agents)

Projects: phimage/mcp-foundation-models · Arthur-Ficial/apfel · waybarrios/vllm-mlx · macOS26/Agent · deckameron/Ti.Apple.Intelligence · ModelPiper/ToolPiper · CaistsAI/claude-local-proxy.
Protocols: MCP (spec 2025-11-25, swift-sdk v0.11.x Tier 3) · Zed ACP (alive) vs IBM/BeeAI ACP (archived→A2A) · OpenAI/Anthropic REST + proxy · Hummingbird 2 / swift-openapi-generator 1.0 / FoundationModels.

`[TO VERIFY]`: Hummingbird perf ~2× Vapor ; exact 4096-token value (TN3193 not extracted) — to confirm before stating as fact in the public README.
