# Python — SDKs officiels pointés sur FoundationBridge

On réutilise les SDKs officiels `openai` et `anthropic` sans aucun client
propriétaire : il suffit de remplacer la `base_url` par celle du bridge local.

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

Installez les paquets `openai` et `anthropic` depuis PyPI avec votre
gestionnaire habituel (pip, uv, poetry…), de préférence dans un environnement
virtuel.

## SDK OpenAI

La `base_url` pour le SDK OpenAI inclut le segment `/v1` :
`http://127.0.0.1:11434/v1`.

### OpenAI — non-stream

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:11434/v1",
    api_key="foundationbridge-local",  # factice : le bridge ouvert n'authentifie pas
)

response = client.chat.completions.create(
    model="apple-foundation",
    messages=[
        {"role": "system", "content": "Tu es un assistant concis."},
        {"role": "user", "content": "Résume en une phrase : le chat dort sur le canapé."},
    ],
)

print(response.choices[0].message.content)
```

### OpenAI — stream (SSE)

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:11434/v1",
    api_key="foundationbridge-local",
)

stream = client.chat.completions.create(
    model="apple-foundation",
    messages=[{"role": "user", "content": "Liste trois fruits."}],
    stream=True,
)

for chunk in stream:
    delta = chunk.choices[0].delta.content
    if delta:
        print(delta, end="", flush=True)
print()
```

## SDK Anthropic

La `base_url` pour le SDK Anthropic n'inclut **pas** de segment `/v1` (le SDK
ajoute lui-même `/v1/messages`) : `http://127.0.0.1:11434`.

### Anthropic — non-stream

```python
from anthropic import Anthropic

client = Anthropic(
    base_url="http://127.0.0.1:11434",
    api_key="foundationbridge-local",  # factice en mode ouvert
)

message = client.messages.create(
    model="apple-foundation",
    max_tokens=256,
    messages=[
        {"role": "user", "content": "Classe ce message comme positif ou négatif : j'adore ce produit."},
    ],
)

print(message.content[0].text)
```

### Anthropic — stream (SSE)

```python
from anthropic import Anthropic

client = Anthropic(
    base_url="http://127.0.0.1:11434",
    api_key="foundationbridge-local",
)

with client.messages.stream(
    model="apple-foundation",
    max_tokens=256,
    messages=[{"role": "user", "content": "Énumère deux couleurs primaires."}],
) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
print()
```

## Avec un vrai jeton

Si le serveur a été lancé avec `--token mon-secret` (ou `FB_TOKEN`), passez ce
jeton comme `api_key`. Les deux SDKs envoient alors l'en-tête attendu
(`Authorization: Bearer ...`, accepté par le bridge ; `x-api-key` l'est aussi) :

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://127.0.0.1:11434/v1",
    api_key="mon-secret",  # le vrai jeton passé à --token / FB_TOKEN
)
```

```python
from anthropic import Anthropic

client = Anthropic(
    base_url="http://127.0.0.1:11434",
    api_key="mon-secret",
)
```

---

**Auteur** : Aïssa BELKOUSSA
