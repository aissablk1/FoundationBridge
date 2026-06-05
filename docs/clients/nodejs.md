# Node.js — SDKs officiels pointés sur FoundationBridge

On réutilise les SDKs officiels `openai` et `@anthropic-ai/sdk` sans aucun
client propriétaire : on remplace simplement la `baseURL` par celle du bridge
local.

## Sommaire

- [Prérequis](#prérequis)
- [SDK OpenAI](#sdk-openai)
  - [Non-stream](#openai--non-stream)
  - [Stream (SSE)](#openai--stream-sse)
- [SDK Anthropic](#sdk-anthropic)
  - [Non-stream](#anthropic--non-stream)
  - [Stream (SSE)](#anthropic--stream-sse)
- [Avec un vrai jeton](#avec-un-vrai-jeton)

## Prérequis

Le serveur doit tourner :

```bash
foundationbridge serve
```

Ajoutez les paquets `openai` et `@anthropic-ai/sdk` à votre projet avec votre
gestionnaire habituel (npm, pnpm, yarn). Les exemples utilisent la syntaxe ESM
(`"type": "module"` dans `package.json`).

## SDK OpenAI

La `baseURL` pour le SDK OpenAI inclut le segment `/v1` :
`http://127.0.0.1:11434/v1`.

### OpenAI — non-stream

```javascript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://127.0.0.1:11434/v1",
  apiKey: "foundationbridge-local", // factice : le bridge ouvert n'authentifie pas
});

const response = await client.chat.completions.create({
  model: "apple-foundation",
  messages: [
    { role: "system", content: "Tu es un assistant concis." },
    { role: "user", content: "Résume en une phrase : le chat dort sur le canapé." },
  ],
});

console.log(response.choices[0].message.content);
```

### OpenAI — stream (SSE)

```javascript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://127.0.0.1:11434/v1",
  apiKey: "foundationbridge-local",
});

const stream = await client.chat.completions.create({
  model: "apple-foundation",
  messages: [{ role: "user", content: "Liste trois fruits." }],
  stream: true,
});

for await (const chunk of stream) {
  const delta = chunk.choices[0]?.delta?.content;
  if (delta) process.stdout.write(delta);
}
process.stdout.write("\n");
```

## SDK Anthropic

La `baseURL` pour le SDK Anthropic n'inclut **pas** de segment `/v1` (le SDK
ajoute lui-même `/v1/messages`) : `http://127.0.0.1:11434`.

### Anthropic — non-stream

```javascript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic({
  baseURL: "http://127.0.0.1:11434",
  apiKey: "foundationbridge-local", // factice en mode ouvert
});

const message = await client.messages.create({
  model: "apple-foundation",
  max_tokens: 256,
  messages: [
    { role: "user", content: "Classe ce message comme positif ou négatif : j'adore ce produit." },
  ],
});

console.log(message.content[0].text);
```

### Anthropic — stream (SSE)

```javascript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic({
  baseURL: "http://127.0.0.1:11434",
  apiKey: "foundationbridge-local",
});

const stream = client.messages.stream({
  model: "apple-foundation",
  max_tokens: 256,
  messages: [{ role: "user", content: "Énumère deux couleurs primaires." }],
});

stream.on("text", (text) => process.stdout.write(text));
await stream.finalMessage();
process.stdout.write("\n");
```

## Avec un vrai jeton

Si le serveur a été lancé avec `--token mon-secret` (ou `FB_TOKEN`), passez ce
jeton comme `apiKey`. Les deux SDKs envoient alors l'en-tête attendu
(`Authorization: Bearer ...`, accepté par le bridge ; `x-api-key` l'est aussi) :

```javascript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://127.0.0.1:11434/v1",
  apiKey: "mon-secret", // le vrai jeton passé à --token / FB_TOKEN
});
```

```javascript
import Anthropic from "@anthropic-ai/sdk";

const client = new Anthropic({
  baseURL: "http://127.0.0.1:11434",
  apiKey: "mon-secret",
});
```

---

**Auteur** : Aïssa BELKOUSSA
