# curl — HTTP brut vers FoundationBridge

Aucun SDK requis : ces exemples parlent directement aux endpoints du bridge en
HTTP. Utiles pour déboguer, scripter ou comprendre exactement ce que les SDKs
envoient sous le capot.

## Sommaire

- [Prérequis](#prérequis)
- [Healthcheck](#healthcheck)
- [Lister les modèles](#lister-les-modèles)
- [Chat (OpenAI) non-stream](#chat-openai--non-stream)
- [Chat (OpenAI) stream SSE](#chat-openai--stream-sse)
- [Messages (Anthropic) non-stream](#messages-anthropic--non-stream)
- [Messages (Anthropic) stream SSE](#messages-anthropic--stream-sse)
- [Avec un vrai jeton](#avec-un-vrai-jeton)

## Prérequis

Le serveur doit tourner :

```bash
foundationbridge serve
```

En mode ouvert (sans `--token` ni `FB_TOKEN`, bind localhost), aucune en-tête
d'authentification n'est nécessaire. Les exemples sans Bearer ci-dessous
fonctionnent tels quels.

## Healthcheck

`/healthz` est toujours exempté d'authentification.

```bash
curl http://127.0.0.1:11434/healthz
# -> ok
```

## Lister les modèles

```bash
curl http://127.0.0.1:11434/v1/models
```

Réponse (forme) :

```json
{"object":"list","data":[{"id":"apple-foundation","object":"model","owned_by":"apple"}]}
```

## Chat (OpenAI) — non-stream

```bash
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-foundation",
    "messages": [
      {"role": "system", "content": "Tu es un assistant concis."},
      {"role": "user", "content": "Résume en une phrase : le chat dort sur le canapé."}
    ]
  }'
```

## Chat (OpenAI) — stream SSE

Ajoutez `"stream": true` ; la réponse arrive en Server-Sent Events. L'option
`-N` désactive le tampon de sortie de curl.

```bash
curl -N http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-foundation",
    "messages": [
      {"role": "user", "content": "Liste trois fruits."}
    ],
    "stream": true
  }'
```

Chaque événement est une ligne `data: {...}` ; le flux se termine par
`data: [DONE]`.

## Messages (Anthropic) — non-stream

```bash
curl http://127.0.0.1:11434/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-foundation",
    "max_tokens": 256,
    "messages": [
      {"role": "user", "content": "Classe ce message comme positif ou négatif : j'\''adore ce produit."}
    ]
  }'
```

## Messages (Anthropic) — stream SSE

```bash
curl -N http://127.0.0.1:11434/v1/messages \
  -H "Content-Type: application/json" \
  -d '{
    "model": "apple-foundation",
    "max_tokens": 256,
    "messages": [
      {"role": "user", "content": "Énumère deux couleurs primaires."}
    ],
    "stream": true
  }'
```

## Avec un vrai jeton

Si le serveur a été lancé avec `--token mon-secret` (ou `FB_TOKEN`), toutes les
routes sauf `/healthz` exigent le jeton. Deux en-têtes sont acceptées, au choix.

Avec `Authorization: Bearer` :

```bash
curl http://127.0.0.1:11434/v1/models \
  -H "Authorization: Bearer mon-secret"
```

Avec `x-api-key` :

```bash
curl http://127.0.0.1:11434/v1/models \
  -H "x-api-key: mon-secret"
```

Exemple complet (chat, Bearer) :

```bash
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer mon-secret" \
  -d '{
    "model": "apple-foundation",
    "messages": [
      {"role": "user", "content": "Bonjour."}
    ]
  }'
```

---

**Auteur** : Aïssa BELKOUSSA
