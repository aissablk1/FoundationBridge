# FoundationBridge — v2 design "the most complete bridge"

🇬🇧 **English** · 🇫🇷 [Français](2026-06-04-foundationbridge-v2-design.fr.md)

> **Status**: ✅ **v2-MVP implemented** (2026-06-04) — SessionManager, MCP stdio, snapshot
> streaming, Bearer auth, port 11434, server hardening and integration tests shipped.
> **2026-06-05 hardening**: proxy-safe SSE headers (`X-Accel-Buffering: no`, `nosniff`),
> MCP `list_models` now reports real availability (`ready`/`status`), OSV dependency scan
> wired into CI.
> **2026-06-05 v2.1**: `generate_structured` (JSON Schema → guided JSON, device-verified),
> MCP Streamable-HTTP (`mcp --http`), WebSocket `/ws` (device-verified), client guides
> (Python/Node/Go/Rust/curl), and **ACP** (Zed Agent Client Protocol, synthetic-smoke-verified).
> 79 tests passing. All advertised v2.1 surfaces shipped.
> **Author**: Aïssa BELKOUSSA · **Date**: 2026-06-04
> **Scope**: extension of v1 (working server) toward a multi-protocol / multi-language bridge.
> **Method**: derived from multi-agent research (teardown of 7 competitors + 7 protocols + adversarial completeness critique), reframed against the real v1 code.

---

## 0. Real starting point (v1, verified in code)

| Item | Verified state |
|---|---|
| `SystemLanguageModel.availability` (enum) → `ModelAvailability` mapping | ✅ already correct (`FoundationModelsGenerator.modelAvailability()`) |
| Non-stream generation | ✅ `respond()` — **but creates a fresh `LanguageModelSession` on every call = stateless** |
| Streaming | ⚠️ `stream()` is a **mono-block fallback** (yields the full text) — real snapshot streaming not wired |
| Token counting | ⚠️ `HeuristicTokenEstimator` ~4 chars/token, not Apple's exact tokenizer |
| HTTP server | ✅ Hummingbird 2, OpenAI + Anthropic REST + SSE, default bind `127.0.0.1` |
| Authentication | ❌ absent |
| SessionManager | ❌ absent (each request is isolated) |
| Security | ✅ input validation, `X-Content-Type-Options: nosniff` header, 1 MiB body limit |

**Consequence**: v2 invents nothing from scratch — it **fixes** (streaming, stateless) and **adds** (MCP, sessions, auth, SDKs).

---

## A. Architecture summary

FoundationBridge applies "**one core, many façades**": the FoundationModels binding stays isolated behind the `TextGenerating` protocol, and each external protocol (OpenAI REST, Anthropic REST, **MCP stdio**, ACP, WebSocket) is a **thin adapter** on top of a **`SessionManager` actor** that owns the live `LanguageModelSession` objects. v2 adds three cross-cutting capabilities — **named in-memory sessions**, **real snapshot streaming**, **optional Bearer authentication** — then a first high-value new adapter (**MCP stdio**, which unlocks Claude Desktop/Code, Cursor, Zed with no client-side change). Everything else (ACP, WebSocket, gRPC, published SDKs) is sequenced into v2.1+ under strict YAGNI discipline.

---

## B. Module decomposition

| Module | Role | Language | Depends on | New? |
|---|---|---|---|---|
| `FoundationBridgeCore` | Errors, `ModelAvailability`, `TextGenerating`, `GenerationOptions`, `ContextManager`, `TokenEstimating`, `ExitCode` | Swift | — | existing |
| **`FoundationBridgeSession`** | `SessionManager` **actor**: `sessionId → LanguageModelSession` map, per-session queue, global concurrency cap, TTL/eviction | Swift | Core | **new** |
| `ProtocolConversion` | OpenAI ↔ Anthropic models, conversion, validation, response build | Swift | Core | existing |
| **`MCPAdapter`** | **stdio** MCP server (JSON-RPC): `generate`, `generate_structured`, `list_models` tools | Swift | Core, Session | **new** |
| `FoundationModelsBackend` | Real binding + **real snapshot streaming** (`streamResponse`) | Swift | Core | extended |
| `FoundationBridgeServer` | Hummingbird: REST + SSE + **Auth middleware** | Swift | Core, Session, Conversion, Backend | extended |
| `FoundationBridgeCLI` | `version/diagnose/generate/serve` + **`mcp`** (launches the stdio adapter) + `--token`, `--host` | Swift | all | extended |

> The `FoundationBridgeCore` SwiftPM product (already declared as `.library`) remains the only embeddable surface for native macOS/iOS apps.

---

## C. Data flow (two distinct paths)

**Free text (MVP path)**:
`client (REST/MCP) → adapter → SessionManager.session(for: id) → LanguageModelSession.streamResponse(to:) → cumulative snapshots → delta = snapshot.dropFirst(previous prefix) → wire chunk (SSE/MCP)`.

**Structured `@Generable` output (v2.1 path)**:
snapshots are `PartiallyGenerated<T>` (all-Optional fields) — you **CANNOT** compute a string-suffix delta. Emit **field-level partial JSON** (diff of the partial object), or buffer until `final` depending on the protocol. Dedicated `generate_structured` endpoint (**pre-registered** `@Generable` schema, not arbitrary at runtime — `[TO VERIFY]`: extracting the JSON Schema from the macro).

---

## D. Protocol surface (prioritized, YAGNI)

| Surface | Adapter | Priority | Rationale |
|---|---|---|---|
| OpenAI REST + SSE | `FoundationBridgeServer` | ✅ v1 | already shipped, unlocks any OpenAI SDK via `base_url` swap |
| Anthropic REST + SSE | `FoundationBridgeServer` | ✅ v1 | already shipped, unlocks Claude Code via `ANTHROPIC_BASE_URL` |
| **MCP stdio** | `MCPAdapter` | **v2-MVP** | single highest value: Claude Desktop/Code, Cursor, Zed via `claude mcp add` |
| MCP Streamable-HTTP | `MCPAdapter` | v2.1 | web/remote MCP clients |
| WebSocket | new | v2.1 | full-duplex streaming, Tauri/Electron apps |
| ACP (Zed/JetBrains) | new | v2.1 | agentic editor ecosystem |
| Unix domain socket | `FoundationBridgeServer` | v2.1 | low-latency local IPC, no port |
| gRPC | — | **cut** | YAGNI: no service-mesh audience for a single-user on-device model ; reopen only on real demand |

---

## E. Availability → error mapping (per protocol)

| `ModelAvailability` | OpenAI REST | Anthropic REST | MCP | CLI exit |
|---|---|---|---|---|
| `.available` | 200 | 200 | tool result | 0 |
| `.deviceNotEligible` | 503 + message | error envelope | init/tool error | dedicated code |
| `.appleIntelligenceNotEnabled` | 503 + remedy | error envelope | error + remedy | dedicated code |
| `.modelNotReady` (downloading) | **503 + `Retry-After`** | error + retry | **retryable** transient error | dedicated code |
| `.unknown` | 500 | error envelope | generic error | dedicated code |

> `.modelNotReady` is **transient**: a poll/retry path is exposed (never treat it as a final error). Mapping already seeded by `asErrorIfUnavailable()` + `BridgeError.httpStatus`.

---

## F. Concurrency & sessions

- **`SessionManager` actor**: `sessionId → LanguageModelSession`. Sessions are **in-memory, process-lifetime** (real multi-turn).
- **One in-flight request per session** (mirrors FoundationModels' `isResponding`): concurrent requests on the **same** session are **queued** (or `409` rejected, configurable), never run in parallel.
- **Global concurrency cap** (semaphore) to bound pressure on the Neural Engine.
- **Cross-restart disk persistence**: `[TO VERIFY]` — `LanguageModelSession` is not documented as serializable. We **do NOT promise** persistence; possible fallback = **transcript replay** (re-inject message history into a fresh session). The "named sessions" differentiator is defined as **in-process**, not cross-restart.

---

## G. Token counting & overflow (4096 window)

- Keep `HeuristicTokenEstimator` (~4 chars/token) as a **portable fallback** (tests, off-device).
- Real backend: try Apple's **exact tokenizer** if exposed `[TO VERIFY]`; otherwise heuristic + **safety margin** (e.g. 90% of 4096).
- **Pre-flight** before the model call: if estimated `instructions + prompt` > threshold → **clear** per-protocol error (OpenAI 400 `context_length_exceeded`, Anthropic error envelope, MCP tool error), **before** the model's opaque failure.

---

## H. Auth / binding / sandbox / distribution

- **Bind `127.0.0.1` by default** (already the case). `--host 0.0.0.0` (LAN/tunnel) **requires** a token.
- **Optional Bearer**: `--token <value>` or env `FB_TOKEN`; Hummingbird middleware checks `Authorization: Bearer …` (and `x-api-key` for Anthropic). No token + localhost bind = open (local ergonomics); explicitly documented.
- **Non-sandboxed**: distribution via **Homebrew / build-from-source / Swift Package Index**. **App Store de-scoped** (sandbox vs arbitrary port binding = irreducible conflict).

---

## I. iOS / visionOS scope

- **Server de-scoped on iOS**: a background HTTP daemon does not transfer from the "macOS daemon" model.
- **iOS is served** only by the embeddable **`FoundationBridgeCore` SwiftPM product**, in-process. We stop presenting iOS as a server differentiator.

---

## J. Test strategy

- **CI boundary without Apple Intelligence**: all transport tests against `MockTextGenerator` (already present) → green GitHub Actions CI with no hardware.
- **Golden files**: OpenAI/Anthropic SSE (already seeded) + **MCP framing** (JSON-RPC) + conversion golden.
- **Real-device smoke** (macOS 26 + Apple Intelligence): manual/optional job, never CI-blocking.
- **Concurrency tests**: per-session queue, global cap.

---

## K. SDK plan ("the protocol IS the SDK")

- **MVP first-class**: **Swift** (`FoundationBridgeCore` SwiftPM — `@Generable` typing, in-process/stdio, the only one without a network round-trip).
- **`base_url` GUIDES** at MVP (zero code): Python (`openai`/`anthropic`), Node, Go (`go-openai`), Rust (`async-openai`), Bash/curl — runnable lab, apfel-style.
- **TypeScript/Node**: **demoted to a guide at MVP**, **thin SDK in v2.1** (a first-class npm SDK reintroduces a Node dependency that breaks the "pure native" story; wait for the contracts to freeze).
- **Frozen contracts + live `/v1/openapi.json`** before any SDK → thin auto-generatable wrappers. Ruby/Kotlin = "later" guides.

---

## L. Sequenced roadmap

**v2-MVP** (heart of "the most complete bridge", maps the pending tasks):
1. `SessionManager` actor (in-process named sessions)
2. **Real snapshot streaming** via `streamResponse` (text suffix delta)
3. **MCP stdio adapter** (`generate`, `list_models`) + CLI `mcp` command
4. **Optional Bearer auth** (`--token`/`FB_TOKEN`, `--host`)
5. Server code review (concurrency, silent failures)
6. Integration tests + MCP/SSE golden
7. README: up-to-date protocol matrix + per-client snippets (Claude Code/Desktop, Cursor, Zed)

**v2.1**: `generate_structured` endpoint (`@Generable`→JSON Schema), MCP Streamable-HTTP, WebSocket, Unix socket, thin TS SDK, published multi-language guides.

**Later**: ACP (Zed/JetBrains), Homebrew tap + notarized binary, Prometheus observability, (gRPC only on real demand).

---

## Open decisions (to settle with the author)

1. **License**: v1 is already published under **Apache-2.0** (badge + committed LICENSE). Research recommended MIT (parity with competitors). → **Keep Apache-2.0** (already committed, reassuring patent clause) unless explicitly switched. *No license change without your approval.*
2. **Default port**: v1 = `8080`. Should it align on `11434` (Ollama convention, "it just works" ergonomics for tools)? — **Done: 11434.**
3. **First increment scope**: the whole v2-MVP at once, or MCP stdio alone first (fastest delivery of the "Claude ↔ Apple AI" link)? — **Done: full v2-MVP.**

---

## Risks / `[TO VERIFY]` items (§29)

- Serializing/resuming `LanguageModelSession` to disk — **not promised**.
- Extracting the JSON Schema from a `@Generable` macro at runtime — gates `generate_structured`.
- Apple's exact tokenizer exposed or not.
- Parallel vs sequential tool calls in FoundationModels.
- Vision/multimodal support (OpenAI/Anthropic image content blocks).
