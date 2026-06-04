# Contributing to FoundationBridge

🇬🇧 **English** · 🇫🇷 [Français](CONTRIBUTING.fr.md)

Thanks for your interest! FoundationBridge exposes Apple's on-device LLM
(FoundationModels) to the agentic ecosystem through several protocols.

## Requirements

- Apple Silicon Mac (M1+), macOS 26, Apple Intelligence enabled (for e2e tests)
- Swift 6.x / Xcode 26 (or Command Line Tools)

> The `FoundationBridgeCore` and `ProtocolConversion` modules build and test on any
> Swift 6 machine (including x86_64), without Apple Intelligence. Only the e2e paths
> of the `FoundationModelsBackend` backend require an eligible device.

## Development loop (TDD)

1. Pick a sub-plan in `docs/plans/`.
2. Write the failing test (Red), then the minimal code (Green), then refactor.
3. `swift test` must be **green** before any commit (rule: never commit broken code).

## Architecture

"One core, many façades" — see `docs/specs/2026-06-04-foundationbridge-v2-design.md`.
The FoundationModels binding is isolated behind the `TextGenerating` protocol: all
transport code depends on that abstraction, never directly on Apple's framework.

## Commit style

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`). Clear messages,
in English or French. Stage files explicitly (no `git add -A`).

## Priority areas to contribute

- Golden tests for the Anthropic↔OpenAI conversion layer (SSE included).
- Protocol adapters (MCP, REST, ACP, WebSocket).
- FoundationModels snapshot-streaming mapping.

## License

By contributing, you agree that your contributions are licensed under Apache-2.0.
