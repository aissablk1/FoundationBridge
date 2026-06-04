<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# 🌉 FoundationBridge

🇬🇧 **English** · 🇫🇷 [Français](README.fr.md)

**A native gateway that exposes Apple's on-device LLM (FoundationModels) to the whole agentic ecosystem — MCP, OpenAI REST, Anthropic REST, SSE, CLI, proxy — from a single Swift binary.**

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%20·%20Apple%20Silicon-black.svg)](#-requirements)
[![Status](https://img.shields.io/badge/status-v2--MVP-brightgreen.svg)](#-roadmap)
[![Tests](https://img.shields.io/badge/tests-57%20✓-brightgreen.svg)](#-architecture)

[![Quick start](https://img.shields.io/badge/▶_Quick_start-2ea44f?style=for-the-badge)](#-quick-start)

</div>

---

## 💡 Why

Every recent Apple Silicon Mac ships a ~3B-parameter LLM through **Apple Intelligence**. The **FoundationModels** framework (macOS 26) unlocks it — but only from Swift code, app by app.

Existing bridges each cover part of the need, **never the whole**: one does streaming but not Anthropic, another OpenAI but not FoundationModels, a third MLX but not the native on-device model…

**FoundationBridge brings every way to connect together in a single binary** — so any AI agent (Claude Code, Claude Desktop, Cursor, Zed, OpenAI/Anthropic clients…) can use the on-device model: free, private, offline.

---

## 🔌 Connection surfaces

| Surface | Status |
|---|---|
| **OpenAI-compatible REST** (`/v1/chat/completions`, `/v1/models`) | ✅ available |
| **Anthropic-compatible REST** (`/v1/messages`) | ✅ available |
| **SSE streaming** (both formats, `stream: true`) | ✅ available |
| **Real snapshot streaming** (deltas via `streamResponse`) | ✅ available |
| **MCP stdio** (`generate`, `list_models`) — Claude Desktop/Code, Cursor, Zed | ✅ available |
| **Named multi-turn sessions** (in-process) | ✅ available |
| **Optional Bearer auth** (`--token` / `FB_TOKEN`) | ✅ available |
| **Proxy mode** (`ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`) | ✅ available |
| **CLI** (`version`, `diagnose`, `generate`, `serve`, `mcp`) | ✅ available |
| **Universal binary** (arm64 + x86_64 / Rosetta) | ✅ available |
| **MCP Streamable-HTTP** + `generate_structured` tool | 🚧 coming (v2.1) |
| **ACP** (Zed Agent Client Protocol) | 🚧 coming (v2.1) |
| **WebSocket** (bidirectional streaming) | 🚧 coming (v2.1) |
| **Client SDKs** (first-class Swift, Python/TS/Go/Rust guides) | 🚧 coming (v2.1) |

---

## 📋 Requirements

- **Apple Silicon Mac** (M1 or newer)
- **macOS 26** (Tahoe, 26.5.x or newer)
- **Apple Intelligence enabled** — Settings → Apple Intelligence & Siri → model downloaded
- **Swift 6.x** / Xcode 26 (or Command Line Tools)

> ⚠️ FoundationModels is exclusive to recent Apple platforms: FoundationBridge does not target Linux/Windows/x86.

---

## 🚀 Quick start

### 1 — Build

```bash
swift build -c release
```

The binary lands in `.build/release/foundationbridge`.

### 2 — Run the server

```bash
.build/release/foundationbridge serve --port 11434
```

Check it:

```bash
curl http://127.0.0.1:11434/healthz
curl http://127.0.0.1:11434/v1/models
```

### 3 — curl example (OpenAI format)

```bash
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple/on-device",
    "messages": [{"role": "user", "content": "Summarize in one sentence: Swift is a compiled language."}]
  }'
```

Add `"stream": true` for SSE streaming. The Anthropic format is served at `/v1/messages`.

### 4 — Wire up Claude Code (proxy mode)

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:11434
claude
```

### 5 — Wire up MCP (Claude Desktop/Code, Cursor, Zed)

```bash
claude mcp add foundationbridge -- /path/to/foundationbridge mcp
```

The `generate` tool takes `prompt` (required) and `session` (optional, for multi-turn).

### 6 — Authentication (optional)

```bash
foundationbridge serve --token my-secret
# or: FB_TOKEN=my-secret foundationbridge serve
```

Requests then carry `Authorization: Bearer my-secret` (or `x-api-key`). A non-local bind (`--host 0.0.0.0`) **requires** a token.

---

## 🧰 CLI — available commands

```
foundationbridge version          Print the binary version
foundationbridge diagnose         Check Apple Intelligence availability
foundationbridge generate <text>  Generate an on-device response (non-stream)
foundationbridge serve [options]  Start the HTTP server (--port N --host H --token T)
foundationbridge mcp              Start the MCP stdio server (JSON-RPC)
```

Universal binary (arm64 + x86_64): `./scripts/build-universal.sh`.

---

## 🏗️ Architecture

"One core, many façades": the FoundationModels binding is isolated from transport.

| Module | Role |
|---|---|
| `FoundationBridgeCore` | ExitCode, BridgeError, ModelAvailability, TextGenerating, ContextManager, BearerAuth |
| `FoundationBridgeSession` | `SessionManager` actor: named multi-turn sessions, one in-flight request per session |
| `ProtocolConversion` | OpenAI ↔ Anthropic models, conversion golden tests |
| `FoundationModelsBackend` | Real binding to Apple's FoundationModels framework (+ snapshot streaming) |
| `FoundationBridgeServer` | Hummingbird 2 HTTP server, REST + SSE routes + auth middleware |
| `FoundationBridgeMCP` | `MCPToolRouter` (logic) + `MCPServerRunner` (stdio via the official MCP SDK) |
| `FoundationBridgeCLI` | Executable, `version/diagnose/generate/serve/mcp` commands |

✅ **58 tests passing.** Details: [`docs/specs/2026-06-04-foundationbridge-v2-design.md`](docs/specs/2026-06-04-foundationbridge-v2-design.md).

---

## 🗺️ Roadmap

- **v1** — native binding, SSE streaming, OpenAI + Anthropic REST + tested conversion, proxy, CLI, context management, universal binary.
- **v2-MVP (available)** — 🆕 **MCP stdio server** (`generate`, `list_models`), **named multi-turn sessions**, **real snapshot streaming**, **optional Bearer auth**, default port 11434.
- **v2.1** — MCP Streamable-HTTP, `generate_structured` tool (`@Generable` → JSON Schema), ACP (Zed/JetBrains), WebSocket, Unix socket, first-class Swift SDK + Python/TS/Go/Rust guides.
- **later** — Prometheus observability, signed/notarized binary + Homebrew tap.

---

## 📚 References — official Apple documentation

- [Foundation Models framework](https://developer.apple.com/documentation/FoundationModels) — the on-device model for language understanding, structured output and tool calling
- [Generating content and performing tasks](https://developer.apple.com/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models)
- [Adding intelligent app features with generative models](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models) — guided generation & tool calling
- [`SystemLanguageModel`](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel) — model availability & the on-device model
- [TN3193 — Managing the on-device model's context window](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window) — the ~4096-token budget
- [Loading and using a custom adapter](https://developer.apple.com/documentation/foundationmodels/loading-and-using-a-custom-adapter-with-foundation-models)
- WWDC25 videos: [Meet the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/286/) · [Deep dive into the Foundation Models framework](https://developer.apple.com/videos/play/wwdc2025/301/) · [Code-along: bring on-device AI to your app](https://developer.apple.com/videos/play/wwdc2025/259/)

Related (non-Apple): [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) · [Hummingbird](https://github.com/hummingbird-project/hummingbird).

---

## 🤝 Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Contributions are welcome, especially on conversion golden tests and protocol adapters.

---

## 📄 License

[Apache-2.0](LICENSE) — © 2026 Aïssa BELKOUSSA.
