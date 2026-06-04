# Security Policy

🇬🇧 **English** · 🇫🇷 [Français](SECURITY.fr.md)

## Supported versions

FoundationBridge is an early-stage project; security fixes land on `main`.

| Version | Supported |
|---|---|
| `v2.x` (main) | ✅ |
| `< v2.0` | ❌ |

## Reporting a vulnerability

**Please do not open a public issue for security problems.** Report privately through
**GitHub private vulnerability reporting**: repository **Security → Advisories → Report a vulnerability**.
This keeps the report confidential between you and the maintainer.

Please include: affected version or commit, reproduction steps, impact, and a suggested fix if you have one. You can expect an acknowledgement within **5 business days**, and a coordinated disclosure once a fix is available.

## Security model

- **Local by default** — the HTTP server binds `127.0.0.1`. A non-local bind (`--host 0.0.0.0`) **requires** a Bearer token.
- **On-device inference** — generation runs through Apple FoundationModels on the Neural Engine; no prompt or data leaves the machine, and there is no telemetry.
- **Optional authentication** — Bearer token (`--token` / `FB_TOKEN`), compared in **constant time** (`BearerAuth`); `/healthz` is exempt for liveness probes.
- **Input hardening** — request validation, 1 MiB body limit, `X-Content-Type-Options: nosniff`; internal errors are logged to stderr and never leaked verbatim to clients.
- **Dependencies** — audited via OSV: **0 known CVE** at the pinned versions in `Package.resolved`.

## Out of scope

- Vulnerabilities in Apple's FoundationModels, Apple Intelligence, or the operating system — please report those to Apple's security team.
- Issues that require a non-default, deliberately insecure configuration you opted into (e.g. binding to `0.0.0.0` with no token).

## License

This policy is part of FoundationBridge, licensed under Apache-2.0 — © 2026 Aïssa BELKOUSSA.
