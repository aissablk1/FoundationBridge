# Politique de sécurité

🇬🇧 [English](SECURITY.md) · 🇫🇷 **Français**

## Versions supportées

FoundationBridge est un projet en phase initiale ; les correctifs de sécurité atterrissent sur `main`.

| Version | Supportée |
|---|---|
| `v2.x` (main) | ✅ |
| `< v2.0` | ❌ |

## Signaler une vulnérabilité

**Merci de ne pas ouvrir d'issue publique pour un problème de sécurité.** Signalez en privé
via le **signalement privé GitHub** : dépôt **Security → Advisories → Report a vulnerability**.
Le rapport reste confidentiel entre vous et le mainteneur.

Merci d'inclure : version ou commit affecté, étapes de reproduction, impact, et un correctif proposé si vous en avez un. Vous pouvez attendre un accusé de réception sous **5 jours ouvrés**, et une divulgation coordonnée une fois le correctif disponible.

## Modèle de sécurité

- **Local par défaut** — le serveur HTTP écoute sur `127.0.0.1`. Un bind non-local (`--host 0.0.0.0`) **exige** un token Bearer.
- **Inférence on-device** — la génération passe par Apple FoundationModels sur le Neural Engine ; aucun prompt ni donnée ne quitte la machine, et il n'y a aucune télémétrie.
- **Authentification optionnelle** — token Bearer (`--token` / `FB_TOKEN`), comparé à **temps constant** (`BearerAuth`) ; `/healthz` est exempté pour les sondes de liveness.
- **Durcissement des entrées** — validation des requêtes, limite de corps 1 Mio, `X-Content-Type-Options: nosniff` ; les erreurs internes sont journalisées sur stderr et jamais renvoyées telles quelles au client.
- **Dépendances** — auditées via OSV : **0 CVE connue** aux versions épinglées dans `Package.resolved`.

## Hors périmètre

- Les vulnérabilités d'Apple FoundationModels, d'Apple Intelligence ou du système d'exploitation — à signaler à l'équipe de sécurité d'Apple.
- Les problèmes nécessitant une configuration non-par-défaut volontairement non sécurisée (ex. bind sur `0.0.0.0` sans token).

## Licence

Cette politique fait partie de FoundationBridge, sous licence Apache-2.0 — © 2026 Aïssa BELKOUSSA.
