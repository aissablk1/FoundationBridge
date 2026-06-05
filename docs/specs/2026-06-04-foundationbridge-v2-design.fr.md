# FoundationBridge — Design v2 « le pont le plus complet »

> **Statut** : ✅ **v2-MVP implémenté** (2026-06-04) — SessionManager, MCP stdio, snapshot
> streaming, auth Bearer, port 11434, durcissement serveur et tests d'intégration livrés.
> **Durcissement 2026-06-05** : en-têtes SSE compatibles proxy (`X-Accel-Buffering: no`,
> `nosniff`), l'outil MCP `list_models` expose la disponibilité réelle (`ready`/`status`),
> scan de dépendances OSV branché dans la CI.
> **v2.1 (2026-06-05)** : `generate_structured` (JSON Schema → JSON guidé, vérifié on-device),
> MCP Streamable-HTTP (`mcp --http`), WebSocket `/ws` (vérifié on-device), guides clients
> (Python/Node/Go/Rust/curl), et **ACP** (Zed Agent Client Protocol, vérifié par smoke-test
> synthétique). 79 tests verts. Toutes les surfaces v2.1 annoncées sont livrées.
> **Auteur** : Aïssa BELKOUSSA
> **Date** : 2026-06-04
> **Portée** : extension de la v1 (serveur fonctionnel) vers un pont multi-protocoles / multi-langages.
> **Méthode** : issu d'une recherche multi-agents (teardown de 7 concurrents + recherche de 7 protocoles + critique adversariale de complétude), recadrée sur le code v1 réel.

---

## 0. Point de départ réel (v1, vérifié dans le code)

| Élément | État vérifié |
|---|---|
| Mapping `SystemLanguageModel.availability` (enum) → `ModelAvailability` | ✅ déjà correct (`FoundationModelsGenerator.modelAvailability()`) |
| Génération non-stream | ✅ `respond()` — **mais crée une `LanguageModelSession` neuve à chaque appel = stateless** |
| Streaming | ⚠️ `stream()` est un **repli mono-bloc** (yield du texte complet) — le vrai snapshot streaming n'est pas branché |
| Comptage tokens | ⚠️ `HeuristicTokenEstimator` ~4 char/token, pas le tokenizer exact d'Apple |
| Serveur HTTP | ✅ Hummingbird 2, REST OpenAI + Anthropic + SSE, bind `127.0.0.1` par défaut |
| Authentification | ❌ absente |
| SessionManager | ❌ absent (chaque requête est isolée) |
| Sécurité | ✅ validation entrées, header `X-Content-Type-Options: nosniff`, limite corps 1 Mio |

**Conséquence** : la v2 n'invente rien depuis zéro — elle **corrige** (streaming, stateless) et **ajoute** (MCP, sessions, auth, SDKs).

---

## A. Résumé d'architecture

FoundationBridge applique « **un cœur, plusieurs façades** » : le binding FoundationModels reste isolé derrière le protocole `TextGenerating`, et chaque protocole externe (REST OpenAI, REST Anthropic, **MCP stdio**, ACP, WebSocket) est un **adaptateur mince** au-dessus d'un **`SessionManager` actor** qui possède les `LanguageModelSession` vivantes. La v2 ajoute trois capacités transverses — **sessions nommées en mémoire**, **streaming par snapshots réel**, **authentification Bearer optionnelle** — puis un premier nouvel adaptateur à forte valeur (**MCP stdio**, qui débloque Claude Desktop/Code, Cursor, Zed sans aucun changement côté client). Tout le reste (ACP, WebSocket, gRPC, SDKs publiés) est séquencé en v2.1+ selon une discipline YAGNI stricte.

---

## B. Décomposition en modules

| Module | Rôle | Langage | Dépend de | Nouveau ? |
|---|---|---|---|---|
| `FoundationBridgeCore` | Erreurs, `ModelAvailability`, `TextGenerating`, `GenerationOptions`, `ContextManager`, `TokenEstimating`, `ExitCode` | Swift | — | existant |
| **`FoundationBridgeSession`** | `SessionManager` **actor** : map `sessionId → LanguageModelSession`, file d'attente par session, cap global de concurrence, TTL/éviction | Swift | Core | **nouveau** |
| `ProtocolConversion` | Modèles OpenAI ↔ Anthropic, conversion, validation, build réponse | Swift | Core | existant |
| **`MCPAdapter`** | Serveur MCP **stdio** (JSON-RPC) : outils `generate`, `generate_structured`, `list_models` | Swift | Core, Session | **nouveau** |
| `FoundationModelsBackend` | Binding réel + **vrai snapshot streaming** (`streamResponse`) | Swift | Core | étendu |
| `FoundationBridgeServer` | Hummingbird : REST + SSE + **middleware Auth** | Swift | Core, Session, Conversion, Backend | étendu |
| `FoundationBridgeCLI` | `version/diagnose/generate/serve` + **`mcp`** (lance l'adaptateur stdio) + `--token`, `--host` | Swift | tous | étendu |

> Le produit SwiftPM `FoundationBridgeCore` (déjà déclaré `.library`) reste l'unique surface embarquable pour apps natives macOS/iOS.

---

## C. Flux de données (deux chemins distincts)

**Texte libre (chemin MVP)** :
`client (REST/MCP) → adaptateur → SessionManager.session(for: id) → LanguageModelSession.streamResponse(to:) → snapshots cumulatifs → delta = snapshot.dropFirst(préfixe précédent) → chunk wire (SSE/MCP)`.

**Sortie structurée `@Generable` (chemin v2.1)** :
les snapshots sont des `PartiallyGenerated<T>` (champs tous optionnels) — **on ne peut PAS faire un delta suffixe de chaîne**. On émet une **émission JSON partielle au niveau champ** (diff de l'objet partiel), ou on bufferise jusqu'au `final` selon le protocole. Endpoint dédié `generate_structured` (schéma `@Generable` **pré-enregistré**, pas arbitraire au runtime — `[À VÉRIFIER]` : extraction du JSON Schema depuis la macro).

---

## D. Surface protocolaire (priorisée, YAGNI)

| Surface | Adaptateur | Priorité | Justification |
|---|---|---|---|
| REST OpenAI + SSE | `FoundationBridgeServer` | ✅ v1 | déjà livré, débloque tout SDK OpenAI par swap `base_url` |
| REST Anthropic + SSE | `FoundationBridgeServer` | ✅ v1 | déjà livré, débloque Claude Code via `ANTHROPIC_BASE_URL` |
| **MCP stdio** | `MCPAdapter` | **v2-MVP** | unique plus forte valeur : Claude Desktop/Code, Cursor, Zed en `claude mcp add` |
| MCP Streamable-HTTP | `MCPAdapter` | v2.1 | clients MCP web/distants |
| WebSocket | nouveau | v2.1 | streaming full-duplex, apps Tauri/Electron |
| ACP (Zed/JetBrains) | nouveau | v2.1 | écosystème éditeurs agentiques |
| Unix domain socket | `FoundationBridgeServer` | v2.1 | IPC local faible latence, sans port |
| gRPC | — | **coupé** | YAGNI : audience service-mesh inexistante pour un modèle mono-utilisateur on-device ; à rouvrir seulement sur demande réelle |

---

## E. Mapping disponibilité → erreur (par protocole)

| `ModelAvailability` | REST OpenAI | REST Anthropic | MCP | CLI exit |
|---|---|---|---|---|
| `.available` | 200 | 200 | résultat outil | 0 |
| `.deviceNotEligible` | 503 + message | error envelope | erreur init/outil | code dédié |
| `.appleIntelligenceNotEnabled` | 503 + remède | error envelope | erreur + remède | code dédié |
| `.modelNotReady` (téléchargement) | **503 + `Retry-After`** | error + retry | erreur transitoire **retryable** | code dédié |
| `.unknown` | 500 | error envelope | erreur générique | code dédié |

> Le `.modelNotReady` est **transitoire** : chemin de poll/retry exposé (ne jamais traiter comme erreur définitive). Mapping déjà amorcé par `asErrorIfUnavailable()` + `BridgeError.httpStatus`.

---

## F. Concurrence & sessions

- **`SessionManager` actor** : `sessionId → LanguageModelSession`. Sessions **en mémoire, durée de vie du process** (multi-tours réel).
- **Une requête en vol par session** (miroir de `isResponding` de FoundationModels) : requêtes concurrentes sur la **même** session → **mises en file** (ou rejet `409` configurable), jamais exécutées en parallèle.
- **Cap global de concurrence** configurable (sémaphore) pour borner la pression sur le Neural Engine.
- **Persistance disque inter-redémarrage** : `[À VÉRIFIER]` — `LanguageModelSession` n'est pas documentée comme sérialisable. **On ne promet PAS** la persistance ; repli éventuel = **rejeu de transcript** (réinjecter l'historique de messages dans une session neuve). Le différenciateur « sessions nommées » est défini comme **in-process**, pas cross-restart.

---

## G. Comptage tokens & dépassement (fenêtre 4096)

- Garder `HeuristicTokenEstimator` (~4 char/token) comme **repli portable** (tests, hors-device).
- Backend réel : tenter le **tokenizer exact d'Apple** si exposé `[À VÉRIFIER]` ; sinon heuristique + **marge de sécurité** (ex. 90 % de 4096).
- **Pré-flight** avant appel modèle : si `instructions + prompt` estimés > seuil → erreur **claire** par protocole (OpenAI 400 `context_length_exceeded`, Anthropic error envelope, MCP erreur outil), **avant** l'échec opaque du modèle.

---

## H. Auth / binding / sandbox / distribution

- **Bind `127.0.0.1` par défaut** (déjà le cas). `--host 0.0.0.0` (LAN/tunnel) **exige** un token.
- **Bearer optionnel** : `--token <valeur>` ou env `FB_TOKEN` ; middleware Hummingbird vérifie `Authorization: Bearer …` (et `x-api-key` côté Anthropic). Absence de token + bind localhost = ouvert (ergonomie locale) ; documenté explicitement.
- **Non-sandboxé** : distribution **Homebrew / build-from-source / Swift Package Index**. **App Store de-scopé** (sandbox vs bind de port arbitraire = conflit irréductible).

---

## I. Périmètre iOS / visionOS

- **Serveur de-scopé sur iOS** : un démon HTTP de fond ne transfère pas depuis le modèle « daemon macOS ».
- **iOS reste servi** uniquement par le **produit SwiftPM `FoundationBridgeCore`** embarqué in-process. On cesse de présenter iOS comme un différenciateur serveur.

---

## J. Stratégie de tests

- **Frontière CI sans Apple Intelligence** : tout le transport teste contre `MockTextGenerator` (déjà présent) → CI GitHub Actions verte sans matériel.
- **Golden files** : SSE OpenAI/Anthropic (déjà amorcé) + **golden framing MCP** (JSON-RPC) + golden conversion.
- **Smoke sur vrai device** (macOS 26 + Apple Intelligence) : job manuel/optionnel, jamais bloquant en CI.
- **Tests de concurrence** : file d'attente par session, cap global.

---

## K. Plan SDK (« le protocole EST le SDK »)

- **MVP first-class** : **Swift** (`FoundationBridgeCore` SwiftPM — typage `@Generable`, in-process/stdio, le seul sans round-trip réseau).
- **Guides `base_url`** au MVP (zéro code) : Python (`openai`/`anthropic`), Node, Go (`go-openai`), Rust (`async-openai`), Bash/curl — lab exécutable façon apfel.
- **TypeScript/Node** : **rétrogradé en guide au MVP**, **SDK fin en v2.1** (un SDK npm first-class réintroduit une dépendance Node qui casse le récit « pure native » ; on attend le gel des contrats).
- **Contrats gelés + `/v1/openapi.json` vivant** avant tout SDK → wrappers fins auto-générables. Ruby/Kotlin = guides « plus tard ».

---

## L. Feuille de route séquencée

**v2-MVP** (cœur du « pont le plus complet », mappe les tâches pending) :
1. `SessionManager` actor (sessions nommées in-process) — *tâche #3*
2. **Vrai snapshot streaming** via `streamResponse` (delta suffixe texte) — *tâche #2*
3. **Adaptateur MCP stdio** (`generate`, `list_models`) + commande CLI `mcp` — *tâche #5*
4. **Auth Bearer optionnelle** (`--token`/`FB_TOKEN`, `--host`) — *tâche #6*
5. Revue de code serveur (concurrence, erreurs silencieuses) — *tâche #9*
6. Tests d'intégration + golden MCP/SSE — *tâche #10*
7. README : matrice protocoles à jour + snippets par client (Claude Code/Desktop, Cursor, Zed)

**v2.1** : endpoint `generate_structured` (`@Generable`→JSON Schema), MCP Streamable-HTTP, WebSocket, Unix socket, SDK TS fin, guides multi-langages publiés.

**Plus tard** : ACP (Zed/JetBrains), Homebrew tap + binaire notarisé, observabilité Prometheus, (gRPC seulement si demande réelle).

---

## Décisions ouvertes (à trancher avec l'auteur)

1. **Licence** : la v1 est déjà publiée en **Apache-2.0** (badge + LICENSE commités). La recherche recommandait MIT (parité avec les concurrents). → **Garder Apache-2.0** (déjà engagé, clause brevets rassurante) sauf décision explicite de bascule. *Aucun changement de licence sans ton accord.*
2. **Port par défaut** : v1 = `8080`. Faut-il aligner sur `11434` (convention Ollama, ergonomie « ça marche tout de suite » pour les outils) ?
3. **Périmètre du premier increment** : tout le v2-MVP d'un coup, ou MCP stdio seul d'abord (livraison la plus rapide du chaînon « Claude ↔ IA Apple ») ?

---

## Risques / points `[À VÉRIFIER]` (§29)

- Sérialisation/reprise de `LanguageModelSession` sur disque — **non promis**.
- Extraction du JSON Schema d'une macro `@Generable` au runtime — conditionne `generate_structured`.
- Tokenizer exact d'Apple exposé ou non.
- Appels d'outils parallèles vs séquentiels côté FoundationModels.
- Support vision/multimodal (content-blocks image OpenAI/Anthropic).
