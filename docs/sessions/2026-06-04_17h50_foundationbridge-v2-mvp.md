---
session_id: 336bf774-99d6-4023-9f26-517122f9cbb9
date_debut: 2026-06-04
date_fin: 2026-06-04
workspace: FoundationBridge
auteur: Aïssa BELKOUSSA
statut: livré
tags: [swift, foundation-models, mcp, sessions, streaming, auth, securite, tests]
---

# Session — FoundationBridge v2-MVP

## QQOQCCP

- **Qui** : Aïssa BELKOUSSA.
- **Quoi** : étendre FoundationBridge (v1 : serveur REST OpenAI/Anthropic + SSE) vers
  un pont multi-protocoles « le plus complet » — MCP, sessions, streaming réel, auth —
  puis perfectionnement (analyse, sécurité, debug, tests, documentation).
- **Où** : `/Volumes/Professionnel/Projets/Développement/Outils/FoundationBridge`,
  dépôt `github.com/aissablk1/FoundationBridge`.
- **Quand** : 2026-06-04.
- **Comment** : pipeline Brainstorm → Spec → Plan → TDD → Review → Ship. Recherche
  multi-agents (teardown de 7 concurrents + protocoles + critique adversariale),
  design v2 validé, implémentation TDD par tranches vérifiées (`swift test`).
- **Combien** : 5 commits, 7 modules Swift, 16 → 57 tests verts, 0 CVE sur 26 deps.
- **Pourquoi** : faire de FoundationBridge la référence open-source exposant l'IA
  on-device d'Apple à tout agent (Claude Code/Desktop, Cursor, Zed, clients OpenAI/Anthropic).

## Actions analysées

- Cartographie concurrentielle (phimage/mcp-foundation-models, apfel, vllm-mlx,
  macOS26/Agent, Ti.Apple.Intelligence, claude-local-proxy, ToolPiper) : leçons
  « steal/avoid » (abstraction backend, sessions stateful, streaming réel, éviter
  stdio-only, éviter zéro-test).
- Critique adversariale du design : enum `availability` (pas booléen), `isResponding`
  (1 requête/session), delta-suffixe faux pour la sortie structurée `@Generable`,
  persistance de session non garantie, MVP sur-dimensionné, token-counting sans
  tokenizer public.
- Revues de code/sécurité : erreurs silencieuses (F1–F4), comparaison de token non
  constante, `/healthz` derrière l'auth, fuite de `\(error)`.

## Actions réalisées

- `SessionManager` actor (sessions multi-tours nommées, 1 requête en vol/session,
  garde-fou contexte 4096) — commit `9b8de7f`.
- Serveur MCP stdio (`generate`, `list_models`) via SDK officiel — commit `b728f54`.
- Snapshot streaming réel (`streamResponse` → deltas) + auth Bearer optionnelle
  — commit `02fd550`.
- README aligné sur la réalité v2-MVP — commit `59b277a`.
- Durcissement : injection de backend (tests d'intégration), comparaison de token à
  temps constant, `/healthz` hors auth, journalisation stderr des erreurs avalées,
  `Retry-After` sur 503, 11 tests d'intégration HTTP + golden SSE — commit `6e96659`.
- Documentation : design v2, PROJECT.nfo corrigé, ce journal.
- Port HTTP par défaut 8080 → 11434 (convention Ollama).

## Actions à mener à l'avenir (v2.1)

- Outil MCP `generate_structured` (`@Generable` → JSON Schema, `[À VÉRIFIER]`).
- MCP Streamable-HTTP, ACP (Zed/JetBrains), WebSocket, Unix socket.
- SDK Swift first-class + guides `base_url` Python/TS/Go/Rust.
- Smoke test sur vrai device (Apple Intelligence) pour valider le flux token-par-token.
- Push GitHub + tags de release + Homebrew tap.

## Notes / Décisions / Blocages

- Licence Apache-2.0 conservée (déjà publiée) — pas de bascule MIT sans accord.
- gRPC coupé (YAGNI), serveur iOS de-scopé (daemon non transférable).
- Sessions « nommées » = in-process uniquement (pas de persistance disque promise).
- Audit CVE : 0 vulnérabilité ; surveiller `swift-sdk` 0.12.x (pré-1.0) et
  `mattt/eventsource` (bus-factor 1).
- Coût de session élevé assumé explicitement par l'auteur.
