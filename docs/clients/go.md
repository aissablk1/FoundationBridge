# Go — go-openai pointé sur FoundationBridge

On réutilise le SDK communautaire de référence `sashabaranov/go-openai` sans
aucun client propriétaire : on remplace `ClientConfig.BaseURL` par l'URL du
bridge local. L'API Anthropic n'est pas couverte ici (passez par l'endpoint
compatible OpenAI `/v1/chat/completions`, ou par curl — voir
[curl.md](./curl.md) — pour `/v1/messages`).

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

Ajoutez la dépendance à votre module :

```bash
go get github.com/sashabaranov/go-openai
```

## Configuration du client

La `BaseURL` pour le SDK OpenAI inclut le segment `/v1` :
`http://127.0.0.1:11434/v1`.

```go
package main

import (
	openai "github.com/sashabaranov/go-openai"
)

func newClient() *openai.Client {
	config := openai.DefaultConfig("foundationbridge-local") // clé factice en mode ouvert
	config.BaseURL = "http://127.0.0.1:11434/v1"
	return openai.NewClientWithConfig(config)
}
```

## Non-stream

```go
package main

import (
	"context"
	"fmt"
	"log"

	openai "github.com/sashabaranov/go-openai"
)

func main() {
	config := openai.DefaultConfig("foundationbridge-local")
	config.BaseURL = "http://127.0.0.1:11434/v1"
	client := openai.NewClientWithConfig(config)

	resp, err := client.CreateChatCompletion(
		context.Background(),
		openai.ChatCompletionRequest{
			Model: "apple-foundation",
			Messages: []openai.ChatCompletionMessage{
				{Role: openai.ChatMessageRoleSystem, Content: "Tu es un assistant concis."},
				{Role: openai.ChatMessageRoleUser, Content: "Résume en une phrase : le chat dort sur le canapé."},
			},
		},
	)
	if err != nil {
		log.Fatalf("erreur : %v", err)
	}

	fmt.Println(resp.Choices[0].Message.Content)
}
```

## Stream (SSE)

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"

	openai "github.com/sashabaranov/go-openai"
)

func main() {
	config := openai.DefaultConfig("foundationbridge-local")
	config.BaseURL = "http://127.0.0.1:11434/v1"
	client := openai.NewClientWithConfig(config)

	stream, err := client.CreateChatCompletionStream(
		context.Background(),
		openai.ChatCompletionRequest{
			Model: "apple-foundation",
			Messages: []openai.ChatCompletionMessage{
				{Role: openai.ChatMessageRoleUser, Content: "Liste trois fruits."},
			},
			Stream: true,
		},
	)
	if err != nil {
		log.Fatalf("erreur : %v", err)
	}
	defer stream.Close()

	for {
		response, err := stream.Recv()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			log.Fatalf("erreur de flux : %v", err)
		}
		fmt.Print(response.Choices[0].Delta.Content)
	}
	fmt.Println()
}
```

## Avec un vrai jeton

Si le serveur a été lancé avec `--token mon-secret` (ou `FB_TOKEN`), passez ce
jeton à `DefaultConfig`. Le SDK l'envoie en `Authorization: Bearer ...`, accepté
par le bridge :

```go
config := openai.DefaultConfig("mon-secret") // le vrai jeton passé à --token / FB_TOKEN
config.BaseURL = "http://127.0.0.1:11434/v1"
client := openai.NewClientWithConfig(config)
```

---

**Auteur** : Aïssa BELKOUSSA
