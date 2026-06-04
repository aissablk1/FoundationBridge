<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# FoundationBridge

**Une passerelle native qui expose le LLM on-device d'Apple (FoundationModels) à tout l'écosystème agentique — MCP, REST OpenAI, REST Anthropic, proxy, ACP, CLI, WebSocket — depuis un seul binaire Swift.**

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%20·%20Apple%20Silicon-black.svg)]()
[![Status](https://img.shields.io/badge/status-scaffold%20(v1%20en%20cours)-orange.svg)]()

</div>

> [!WARNING]
> **Statut : scaffold / conception.** Le dépôt contient la spécification, l'architecture et la fondation. L'implémentation v1 est en cours. Voir [`docs/specs/`](docs/specs/) et la feuille de route ci-dessous.

---

## Pourquoi

Chaque Mac Apple Silicon récent embarque un LLM ~3 Mds de paramètres via **Apple Intelligence**. Le framework **FoundationModels** (macOS 26) y donne accès — mais uniquement depuis du code Swift, app par app.

Les ponts existants couvrent chacun une partie du besoin, **jamais l'ensemble** : l'un fait MCP mais pas de streaming, un autre OpenAI mais pas Anthropic, un troisième Anthropic+OpenAI mais sur MLX (pas FoundationModels)…

**FoundationBridge réunit, dans un seul binaire, toutes les façons de se connecter** au modèle on-device — pour que n'importe quel agent IA (Claude Code, Claude Desktop, Cursor, Zed, clients OpenAI/Anthropic…) puisse l'utiliser : gratuit, privé, hors-ligne.

## Caractéristiques (cibles)

| Surface de connexion | Statut |
|---|---|
| **MCP** (stdio + Streamable HTTP) | v1 |
| **REST OpenAI-compatible** (`/v1/chat/completions`, `/v1/models`, SSE) | v1 |
| **REST Anthropic-compatible** (`/v1/messages`, SSE) | v1 |
| **Mode proxy** (`ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`) | v1 |
| **CLI** (prompt unique, chat, stdin/pipe, codes de sortie sémantiques) | v1 |
| **ACP** (Zed Agent Client Protocol) | v2 |
| **WebSocket** (streaming bidirectionnel) | v2 |
| **SDK clients** générés (TypeScript, Python, Go) | v2 |

Plus : génération guidée typée (`@Generable`), tool calling natif, sessions multi-tours, gestion de la fenêtre de contexte (~4096 tokens), vérification de disponibilité du modèle, observabilité.

## Prérequis

- **Mac Apple Silicon** (M1 ou plus récent)
- **macOS 26** (Tahoe)
- **Apple Intelligence activé** (Réglages → Apple Intelligence & Siri) + modèle téléchargé
- **Swift 6.x** / Xcode 26 (ou Command Line Tools) pour compiler

> FoundationModels est exclusif aux plateformes Apple récentes : FoundationBridge ne vise pas Linux/Windows/x86.

## Architecture

« Un cœur, plusieurs façades » : le binding FoundationModels (plan exécution) est isolé du transport (MCP, REST, ACP, CLI, WebSocket — plan transport). Le contrat **OpenAPI** sert de source de vérité unique d'où sont générés le serveur Swift (Hummingbird 2) et les SDK clients.

Détails complets : [`docs/specs/2026-06-04-foundationbridge-design.md`](docs/specs/2026-06-04-foundationbridge-design.md).

## Feuille de route

- **v1 (MVP)** — binding natif, streaming, sessions, guided generation, tool calling, REST OpenAI + Anthropic + conversion testée, proxy, MCP, CLI, gestion contexte, CI macOS 26.
- **v2** — ACP, WebSocket, SDK publiés, observabilité Prometheus, compaction tiérée, binaire signé/notarisé + Homebrew.

## Contribuer

Voir [`CONTRIBUTING.md`](CONTRIBUTING.md). Les contributions sont les bienvenues, en particulier sur les golden tests de conversion et les adaptateurs de protocole.

## Licence

[Apache-2.0](LICENSE) — © 2026 Aïssa BELKOUSSA.
