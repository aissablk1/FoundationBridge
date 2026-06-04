<!-- markdownlint-disable MD033 MD041 -->
<div align="center">

# FoundationBridge

**Une passerelle native qui expose le LLM on-device d'Apple (FoundationModels) à tout l'écosystème agentique — REST OpenAI, REST Anthropic, SSE, CLI, proxy — depuis un seul binaire Swift.**

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%20·%20Apple%20Silicon-black.svg)]()
[![Status](https://img.shields.io/badge/status-v1%20—%20serveur%20fonctionnel-brightgreen.svg)]()

[Dépôt GitHub](https://github.com/aissablk1/FoundationBridge)

</div>

---

## Pourquoi

Chaque Mac Apple Silicon récent embarque un LLM ~3 Mds de paramètres via **Apple Intelligence**. Le framework **FoundationModels** (macOS 26) y donne accès — mais uniquement depuis du code Swift, app par app.

Les ponts existants couvrent chacun une partie du besoin, **jamais l'ensemble** : l'un fait du streaming mais pas Anthropic, un autre OpenAI mais pas FoundationModels, un troisième MLX mais pas on-device natif…

**FoundationBridge réunit, dans un seul binaire, toutes les façons de se connecter** au modèle on-device — pour que n'importe quel agent IA (Claude Code, Claude Desktop, Cursor, Zed, clients OpenAI/Anthropic…) puisse l'utiliser : gratuit, privé, hors-ligne.

---

## Surfaces de connexion

| Surface | Statut |
|---|---|
| **REST OpenAI-compatible** (`/v1/chat/completions`, `/v1/models`) | ✅ disponible |
| **REST Anthropic-compatible** (`/v1/messages`) | ✅ disponible |
| **Streaming SSE** (les deux formats, `stream: true`) | ✅ disponible |
| **Snapshot streaming réel** (deltas via `streamResponse`) | ✅ disponible |
| **MCP stdio** (`generate`, `list_models`) — Claude Desktop/Code, Cursor, Zed | ✅ disponible |
| **Sessions multi-tours nommées** (in-process) | ✅ disponible |
| **Authentification Bearer** optionnelle (`--token` / `FB_TOKEN`) | ✅ disponible |
| **Mode proxy** (`ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`) | ✅ disponible |
| **CLI** (`version`, `diagnose`, `generate`, `serve`, `mcp`) | ✅ disponible |
| **Binaire universel** (arm64 + x86_64 / Rosetta) | ✅ disponible |
| **MCP Streamable-HTTP** + outil `generate_structured` | ⬜ à venir (v2.1) |
| **ACP** (Zed Agent Client Protocol) | ⬜ à venir (v2.1) |
| **WebSocket** (streaming bidirectionnel) | ⬜ à venir (v2.1) |
| **SDK clients** (Swift first-class, guides Python/TS/Go/Rust) | ⬜ à venir (v2.1) |

---

## Prérequis

- **Mac Apple Silicon** (M1 ou plus récent)
- **macOS 26** (Tahoe, 26.5.x ou plus récent)
- **Apple Intelligence activé** — Réglages → Apple Intelligence & Siri → modèle téléchargé
- **Swift 6.x** / Xcode 26 (ou Command Line Tools)

> FoundationModels est exclusif aux plateformes Apple récentes : FoundationBridge ne vise pas Linux/Windows/x86.

---

## Démarrage rapide

### 1 — Compiler

```bash
swift build -c release
```

Le binaire est produit dans `.build/release/foundationbridge`.

### 2 — Lancer le serveur

```bash
.build/release/foundationbridge serve --port 11434
```

Ou, si le binaire est dans votre `PATH` :

```bash
foundationbridge serve --port 11434
```

Vérification :

```bash
curl http://127.0.0.1:11434/healthz
curl http://127.0.0.1:11434/v1/models
```

---

### 3 — Exemples curl

#### Format OpenAI — requête simple

```bash
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple/on-device",
    "messages": [{"role": "user", "content": "Résume en une phrase : Swift est un langage compilé."}]
  }'
```

#### Format OpenAI — streaming SSE

```bash
curl --no-buffer http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple/on-device",
    "stream": true,
    "messages": [{"role": "user", "content": "Résume en une phrase : Swift est un langage compilé."}]
  }'
```

#### Format Anthropic — requête simple

```bash
curl http://127.0.0.1:11434/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: local" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-3-haiku-20240307",
    "max_tokens": 256,
    "messages": [{"role": "user", "content": "Explique ce qu'\''est Apple Intelligence."}]
  }'
```

#### Format Anthropic — streaming SSE

```bash
curl --no-buffer http://127.0.0.1:11434/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: local" \
  -H "anthropic-version: 2023-06-01" \
  -d '{
    "model": "claude-3-haiku-20240307",
    "max_tokens": 256,
    "stream": true,
    "messages": [{"role": "user", "content": "Explique ce qu'\''est Apple Intelligence."}]
  }'
```

---

### 4 — Branchement Claude Code (mode proxy)

Pour router Claude Code vers le modèle on-device local, définir la variable d'environnement avant de lancer Claude Code :

```bash
export ANTHROPIC_BASE_URL=http://127.0.0.1:11434
claude
```

Ou ponctuellement :

```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:11434 claude "Résume ce fichier"
```

---

### 5 — Branchement MCP (Claude Desktop/Code, Cursor, Zed)

FoundationBridge expose le modèle on-device comme **serveur MCP stdio** (outils `generate` et `list_models`). Enregistrement dans Claude Code :

```bash
claude mcp add foundationbridge -- /chemin/vers/foundationbridge mcp
```

Ou directement en stdio (JSON-RPC sur stdin/stdout) :

```bash
foundationbridge mcp
```

L'outil `generate` accepte `prompt` (requis) et `session` (optionnel, pour une conversation multi-tours conservée en mémoire).

---

### 6 — Authentification (optionnelle)

Par défaut le serveur écoute sur `127.0.0.1` sans authentification. Pour exiger un token Bearer :

```bash
foundationbridge serve --token mon-secret
# ou via l'environnement
FB_TOKEN=mon-secret foundationbridge serve
```

Les requêtes doivent alors porter `Authorization: Bearer mon-secret` (ou `x-api-key: mon-secret`). Un bind non-local (`--host 0.0.0.0`) **exige** un token.

---

## Binaire universel (arm64 + x86_64)

Le script `scripts/build-universal.sh` produit un binaire universel qui tourne nativement sur Apple Silicon et via Rosetta sur Intel :

```bash
./scripts/build-universal.sh
```

Vérification des architectures embarquées :

```bash
lipo -archs .build/universal/foundationbridge
# → x86_64 arm64
```

---

## CLI — commandes disponibles

```
foundationbridge version          Affiche la version du binaire
foundationbridge diagnose         Vérifie la disponibilité d'Apple Intelligence
foundationbridge generate <texte> Génère une réponse on-device (non-stream)
foundationbridge serve [options]  Lance le serveur HTTP (--port N --host H --token T)
foundationbridge mcp              Lance le serveur MCP stdio (JSON-RPC)
```

---

## Architecture

« Un cœur, plusieurs façades » : le binding FoundationModels est isolé du transport. Les modules Swift compilés et testés :

| Module | Rôle |
|---|---|
| `FoundationBridgeCore` | ExitCode, BridgeError, ModelAvailability, TextGenerating, ContextManager, BearerAuth |
| `FoundationBridgeSession` | `SessionManager` actor : sessions multi-tours nommées, une requête en vol/session |
| `ProtocolConversion` | Modèles OpenAI ↔ Anthropic, golden tests de conversion |
| `FoundationModelsBackend` | Binding réel au framework FoundationModels d'Apple (+ snapshot streaming) |
| `FoundationBridgeServer` | Serveur HTTP Hummingbird 2, routes REST + SSE + middleware auth |
| `FoundationBridgeMCP` | `MCPToolRouter` (logique) + `MCPServerRunner` (stdio via SDK MCP officiel) |
| `FoundationBridgeCLI` | Exécutable, commandes `version/diagnose/generate/serve/mcp` |

46 tests passent. Détails : [`docs/specs/2026-06-04-foundationbridge-v2-design.md`](docs/specs/2026-06-04-foundationbridge-v2-design.md).

---

## Feuille de route

- **v1** — binding natif, streaming SSE, REST OpenAI + Anthropic + conversion testée, proxy, CLI, gestion contexte, binaire universel.
- **v2-MVP (disponible)** — **serveur MCP stdio** (`generate`, `list_models`), **sessions multi-tours nommées** (`SessionManager` actor), **snapshot streaming réel** (`streamResponse`), **auth Bearer optionnelle**, port par défaut 11434.
- **v2.1** — MCP Streamable-HTTP, outil `generate_structured` (`@Generable` → JSON Schema), ACP (Zed/JetBrains), WebSocket, Unix socket, SDK Swift first-class + guides Python/TS/Go/Rust.
- **plus tard** — observabilité Prometheus, binaire signé/notarisé + Homebrew tap.

Détails : [`docs/specs/2026-06-04-foundationbridge-v2-design.md`](docs/specs/2026-06-04-foundationbridge-v2-design.md).

---

## Contribuer

Voir [`CONTRIBUTING.md`](CONTRIBUTING.md). Les contributions sont les bienvenues, en particulier sur les golden tests de conversion et les adaptateurs de protocole.

---

## Licence

[Apache-2.0](LICENSE) — © 2026 Aïssa BELKOUSSA.
