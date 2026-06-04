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
| **Mode proxy** (`ANTHROPIC_BASE_URL` / `OPENAI_BASE_URL`) | ✅ disponible |
| **CLI** (`version`, `diagnose`, `generate`, `serve --port`) | ✅ disponible |
| **Binaire universel** (arm64 + x86_64 / Rosetta) | ✅ disponible |
| **MCP** (stdio + Streamable HTTP) | ⬜ à venir (v2) |
| **ACP** (Zed Agent Client Protocol) | ⬜ à venir (v2) |
| **WebSocket** (streaming bidirectionnel) | ⬜ à venir (v2) |
| **SDK clients** générés (TypeScript, Python, Go) | ⬜ à venir (v2) |

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
.build/release/foundationbridge serve --port 8080
```

Ou, si le binaire est dans votre `PATH` :

```bash
foundationbridge serve --port 8080
```

Vérification :

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/v1/models
```

---

### 3 — Exemples curl

#### Format OpenAI — requête simple

```bash
curl http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple/on-device",
    "messages": [{"role": "user", "content": "Résume en une phrase : Swift est un langage compilé."}]
  }'
```

#### Format OpenAI — streaming SSE

```bash
curl --no-buffer http://127.0.0.1:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple/on-device",
    "stream": true,
    "messages": [{"role": "user", "content": "Résume en une phrase : Swift est un langage compilé."}]
  }'
```

#### Format Anthropic — requête simple

```bash
curl http://127.0.0.1:8080/v1/messages \
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
curl --no-buffer http://127.0.0.1:8080/v1/messages \
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
export ANTHROPIC_BASE_URL=http://127.0.0.1:8080
claude
```

Ou ponctuellement :

```bash
ANTHROPIC_BASE_URL=http://127.0.0.1:8080 claude "Résume ce fichier"
```

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
foundationbridge serve --port N   Lance le serveur HTTP sur le port N
```

---

## Architecture

« Un cœur, plusieurs façades » : le binding FoundationModels est isolé du transport. Les modules Swift compilés et testés :

| Module | Rôle |
|---|---|
| `FoundationBridgeCore` | ExitCode, BridgeError, ModelAvailability, TextGenerating, ContextManager |
| `ProtocolConversion` | Modèles OpenAI ↔ Anthropic, golden tests de conversion |
| `FoundationModelsBackend` | Binding réel au framework FoundationModels d'Apple |
| `FoundationBridgeServer` | Serveur HTTP Hummingbird 2, routes REST + SSE |
| `FoundationBridgeCLI` | Exécutable, commandes argument-parser |

16 tests passent. Détails complets : [`docs/specs/2026-06-04-foundationbridge-design.md`](docs/specs/2026-06-04-foundationbridge-design.md).

---

## Feuille de route

- **v1 (disponible)** — binding natif, streaming SSE, sessions, REST OpenAI + Anthropic + conversion testée, proxy, CLI, gestion contexte, binaire universel.
- **v2** — MCP (stdio + Streamable HTTP), ACP, WebSocket, SDK clients publiés (TypeScript, Python, Go), observabilité Prometheus, compaction tiérée, binaire signé/notarisé + Homebrew.

---

## Contribuer

Voir [`CONTRIBUTING.md`](CONTRIBUTING.md). Les contributions sont les bienvenues, en particulier sur les golden tests de conversion et les adaptateurs de protocole.

---

## Licence

[Apache-2.0](LICENSE) — © 2026 Aïssa BELKOUSSA.
