# Rust — async-openai pointé sur FoundationBridge

On réutilise le crate de référence `async-openai` sans aucun client
propriétaire : on remplace l'URL de base via `OpenAIConfig::with_api_base`.
L'API Anthropic n'est pas couverte ici (passez par l'endpoint compatible OpenAI
`/v1/chat/completions`, ou par curl — voir [curl.md](./curl.md) — pour
`/v1/messages`).

## Sommaire

- [Prérequis](#prérequis)
- [Configuration du client](#configuration-du-client)
- [Non-stream](#non-stream)
- [Stream (SSE)](#stream-sse)
- [Avec un vrai jeton](#avec-un-vrai-jeton)

## Prérequis

Le serveur doit tourner :

```bash
foundationbridge serve
```

Dépendances `Cargo.toml` :

```toml
[dependencies]
async-openai = "0.28"
tokio = { version = "1", features = ["full"] }
futures = "0.3"
```

## Configuration du client

L'`api_base` pour le crate inclut le segment `/v1` :
`http://127.0.0.1:11434/v1`. On force aussi la clé à une valeur factice en mode
ouvert.

```rust
use async_openai::{config::OpenAIConfig, Client};

fn build_client() -> Client<OpenAIConfig> {
    let config = OpenAIConfig::new()
        .with_api_base("http://127.0.0.1:11434/v1")
        .with_api_key("foundationbridge-local"); // factice en mode ouvert
    Client::with_config(config)
}
```

## Non-stream

```rust
use async_openai::{
    config::OpenAIConfig,
    types::{
        ChatCompletionRequestSystemMessageArgs,
        ChatCompletionRequestUserMessageArgs,
        CreateChatCompletionRequestArgs,
    },
    Client,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = OpenAIConfig::new()
        .with_api_base("http://127.0.0.1:11434/v1")
        .with_api_key("foundationbridge-local");
    let client = Client::with_config(config);

    let request = CreateChatCompletionRequestArgs::default()
        .model("apple-foundation")
        .messages([
            ChatCompletionRequestSystemMessageArgs::default()
                .content("Tu es un assistant concis.")
                .build()?
                .into(),
            ChatCompletionRequestUserMessageArgs::default()
                .content("Résume en une phrase : le chat dort sur le canapé.")
                .build()?
                .into(),
        ])
        .build()?;

    let response = client.chat().create(request).await?;

    if let Some(content) = &response.choices[0].message.content {
        println!("{content}");
    }

    Ok(())
}
```

## Stream (SSE)

```rust
use async_openai::{
    config::OpenAIConfig,
    types::{ChatCompletionRequestUserMessageArgs, CreateChatCompletionRequestArgs},
    Client,
};
use futures::StreamExt;
use std::io::{stdout, Write};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = OpenAIConfig::new()
        .with_api_base("http://127.0.0.1:11434/v1")
        .with_api_key("foundationbridge-local");
    let client = Client::with_config(config);

    let request = CreateChatCompletionRequestArgs::default()
        .model("apple-foundation")
        .messages([ChatCompletionRequestUserMessageArgs::default()
            .content("Liste trois fruits.")
            .build()?
            .into()])
        .build()?;

    let mut stream = client.chat().create_stream(request).await?;
    let mut lock = stdout().lock();

    while let Some(result) = stream.next().await {
        let response = result?;
        if let Some(content) = &response.choices[0].delta.content {
            write!(lock, "{content}")?;
            lock.flush()?;
        }
    }
    writeln!(lock)?;

    Ok(())
}
```

## Avec un vrai jeton

Si le serveur a été lancé avec `--token mon-secret` (ou `FB_TOKEN`), passez ce
jeton à `with_api_key`. Le crate l'envoie en `Authorization: Bearer ...`,
accepté par le bridge :

```rust
let config = OpenAIConfig::new()
    .with_api_base("http://127.0.0.1:11434/v1")
    .with_api_key("mon-secret"); // le vrai jeton passé à --token / FB_TOKEN
```

---

**Auteur** : Aïssa BELKOUSSA
