# Contribuer à FoundationBridge

Merci de l'intérêt porté au projet ! FoundationBridge expose le LLM on-device
d'Apple (FoundationModels) à l'écosystème agentique via plusieurs protocoles.

## Prérequis

- Mac Apple Silicon (M1+), macOS 26, Apple Intelligence activé (pour les tests e2e)
- Swift 6.x / Xcode 26 (ou Command Line Tools)

> Le module `FoundationBridgeCore` et `ProtocolConversion` compilent et se testent
> sur n'importe quelle machine Swift 6 (y compris x86_64), sans Apple Intelligence.
> Seuls les chemins e2e du backend `FoundationModelsBackend` exigent un device éligible.

## Boucle de développement (TDD)

1. Choisir un sous-plan dans `docs/plans/`.
2. Écrire le test qui échoue (Red), puis le code minimal (Green), puis refactor.
3. `swift test` doit être **vert** avant tout commit (règle : ne jamais committer de code cassé).

## Architecture

« Un cœur, plusieurs façades » — voir `docs/specs/2026-06-04-foundationbridge-design.md`.
Le binding FoundationModels est isolé derrière le protocole `TextGenerating` :
tout le code transport dépend de cette abstraction, jamais directement du framework Apple.

## Style de commit

Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `test:`). Messages clairs,
en français ou anglais. Stage explicite des fichiers (pas de `git add -A`).

## Zones prioritaires pour contribuer

- Golden tests de la couche de conversion Anthropic↔OpenAI (SSE inclus).
- Adaptateurs de protocole (MCP, REST, ACP).
- Mapping du streaming par snapshots de FoundationModels.

## Licence

En contribuant, vous acceptez que vos contributions soient sous licence Apache-2.0.
