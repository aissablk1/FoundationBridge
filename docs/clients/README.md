# Clients FoundationBridge — base_url swap

FoundationBridge expose le LLM on-device d'Apple (FoundationModels) derrière des
APIs compatibles **OpenAI** et **Anthropic**. Le principe de ces guides est le
**base_url swap** : on réutilise les **SDKs officiels** `openai` / `anthropic`
sans aucun SDK propriétaire, en pointant simplement leur URL de base sur le
bridge local.

> Aucun client maison à installer : si vous savez déjà parler à OpenAI ou à
> Anthropic, vous savez déjà parler à FoundationBridge.

## Sommaire

- [Démarrer le serveur](#démarrer-le-serveur)
- [Rappel base_url, port et authentification](#rappel-base_url-port-et-authentification)
- [Guides par langage](#guides-par-langage)
- [Endpoints disponibles](#endpoints-disponibles)
- [Le modèle exposé](#le-modèle-exposé)

## Démarrer le serveur

```bash
foundationbridge serve
```

Par défaut, le serveur HTTP écoute sur `http://127.0.0.1:11434` (localhost).

Pour exiger un jeton sur toutes les routes (sauf `/healthz`) :

```bash
foundationbridge serve --token mon-secret
# ou via l'environnement
FB_TOKEN=mon-secret foundationbridge serve
```

## Rappel base_url, port et authentification

| Élément | Valeur |
| --- | --- |
| Hôte par défaut | `127.0.0.1` (localhost) |
| Port par défaut | `11434` |
| base_url (SDK OpenAI) | `http://127.0.0.1:11434/v1` |
| base_url (SDK Anthropic) | `http://127.0.0.1:11434` |
| Modèle | `apple-foundation` |
| Authentification | optionnelle |

**Authentification.** Sans `--token` ni `FB_TOKEN`, et avec un bind sur
localhost, le bridge est **ouvert** : aucune clé n'est vérifiée. Une valeur
factice comme `foundationbridge-local` suffit alors à satisfaire les SDKs qui
exigent une clé non vide.

Avec un jeton configuré, fournir l'une des deux en-têtes :

- `Authorization: Bearer <token>` (en-tête standard OpenAI / Anthropic) ;
- `x-api-key: <token>`.

## Guides par langage

| Langage | SDKs officiels réutilisés | Guide |
| --- | --- | --- |
| Python | `openai`, `anthropic` | [python.md](./python.md) |
| Node.js | `openai`, `@anthropic-ai/sdk` | [nodejs.md](./nodejs.md) |
| Go | `sashabaranov/go-openai` | [go.md](./go.md) |
| Rust | `async-openai` | [rust.md](./rust.md) |
| curl (HTTP brut) | — | [curl.md](./curl.md) |

## Endpoints disponibles

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| `GET` | `/healthz` | Sonde de liveness (exemptée d'authentification) |
| `GET` | `/v1/models` | Liste des modèles (style OpenAI) |
| `POST` | `/v1/chat/completions` | Chat compatible OpenAI, `"stream": true` en SSE |
| `POST` | `/v1/messages` | Messages compatibles Anthropic, SSE |

## Le modèle exposé

Le bridge expose un unique modèle : `apple-foundation`.

- Fenêtre de contexte d'environ **4096 tokens**.
- Spécialisé dans les **tâches courtes** : résumé, extraction, classification,
  dialogue.

Ce n'est pas un modèle généraliste à très long contexte : concevez vos requêtes
en conséquence (prompts compacts, sorties brèves).

---

**Auteur** : Aïssa BELKOUSSA
