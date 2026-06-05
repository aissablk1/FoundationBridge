---
session_id: 2026-06-05_v2.1
date_debut: 2026-06-05 01h45
date_fin: 2026-06-05 02h30
workspace: /Volumes/Professionnel/Projets/Développement/Outils/FoundationBridge
auteur: Aïssa BELKOUSSA
statut: terminé
tags: [v2.1, websocket, mcp-http, generate_structured, sdk-guides, foundationmodels]
---

# Session 2026-06-05 (v2.1) — 4 surfaces de connexion livrées

## QQOQCCP

- **Qui** : Aïssa BELKOUSSA.
- **Quoi** : implémenter les 4 surfaces marquées « coming (v2.1) » du README
  (WebSocket, MCP Streamable-HTTP, `generate_structured`, guides clients) — réellement,
  testées, vérifiées on-device, sans aucun faux « available ».
- **Où** : FoundationBridge (`main`), MacBook Pro M3 Pro / macOS 26.5 (build natif arm64
  pour atteindre FoundationModels ; shell de session sous Rosetta).
- **Quand** : nuit du 2026-06-05.
- **Comment** : faisabilité d'abord (probe de l'API FoundationModels + SDK MCP) ; TDD pour
  la logique pure ; vérification réelle on-device/smoke avant chaque commit (§32).
- **Combien** : 62 → 71 tests ; 4 surfaces ; 1 sous-agent (guides) ; 1 nouvelle dépendance
  (hummingbird-websocket, org de confiance).
- **Pourquoi** : l'utilisateur a relevé que le README annonçait « available » des surfaces
  non codées (mensonge §2/§29) — on corrige en les rendant réelles.

## Actions réalisées

- **F3 `generate_structured`** : JSON Schema (sous-ensemble) → `SchemaNode` neutre (pur,
  testé CI) → `DynamicGenerationSchema` Apple → `respond(to:schema:)` → JSON. Outil MCP +
  CLI `structured`. **Vérifié on-device** : `{name,age,active}` → `{"name":"Marie","age":30,"active":true}`.
- **F2 MCP Streamable-HTTP** : hébergement du `StatefulHTTPServerTransport` du SDK derrière
  une route Hummingbird `/mcp` (`mcp --http`). **Smoke-vérifié** : `initialize` (session id +
  capabilities), `tools/list` (generate, generate_structured, list_models) en HTTP.
- **F1 WebSocket `/ws`** : endpoint full-duplex (hummingbird-websocket) ; message texte =
  prompt, réponse streamée token par token + `[DONE]`. **Vérifié on-device** : upgrade 101 +
  échange réel (« Bonjour, je suis ici pour vous aider. »), REST coexistant.
- **F4 Guides clients** (sous-agent) : `docs/clients/` Python/Node/Go/Rust/curl (base_url swap).
- **Doc** : README EN/FR tableau des surfaces (3 lignes → available, ACP reste coming),
  statut design v2, PROJECT.nfo (71 tests).

## Actions à mener à l'avenir

- **ACP (Zed Agent Client Protocol)** : seule surface restante en « coming ».
- Tests d'intégration automatisés pour WS et MCP-HTTP (actuellement smoke/manuels).
- Réactiver le billing GitHub Actions (CI bloquée au niveau du compte).

## Notes / Décisions / Blocages

- **Sécurité** : auth Bearer honorée sur `/ws` et `/mcp` ; garde `--host` non-local → token.
  Nouvelle dépendance `hummingbird-websocket` couverte par le scan OSV en CI.
- **Coût** : session longue et coûteuse, budget explicitement validé par l'utilisateur.
- **Vérité terrain** : chaque surface device a été exécutée réellement sur le M3 Pro avant
  d'être annoncée « available » (zéro faux claim, §2/§29).
