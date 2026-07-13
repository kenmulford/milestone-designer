# Config catalog

<!--
Project doc (.project/). Cite as `.project/config-catalog.md#<section>`. A norms file for the
project's configuration & secrets — the analog of `.env.example` / an `appsettings.template.*`.
It records the *shape* of every config/secret key so downstream tools build config, secrets, and
CORS correctly the first time. For each entry record: **key name · source bucket · format/shape ·
environment(s) · required?** — and NEVER a secret value. Non-secret config facts a builder needs
verbatim (CORS origin URLs, the sender/from address, the JWT issuer/audience) ARE recorded here as
norms; secret material (signing keys, passwords, API-key strings) is NEVER recorded — name the
bucket it lives in and leave the value out. Fill every [TBD]; a section left [TBD] is treated as
"not specified." Humans own this file; tools propose, never rewrite. Keep the ## headings stable —
they are citation anchors. Add rows to a table; never rename a heading.
-->

## Connection strings
DB and service connection strings the app needs, **including the local-dev DB engine** — SQL Server LocalDB, a Docker SQL container, or a dev cloud DB. The F5/local-dev target is the single most-missed entry. Record the key name and its shape; **never the value** (a connection string's password is secret).
| Key | Source bucket | Format / shape | Environment(s) | Required? |
|---|---|---|---|---|
| _None — no databases or connected services_ | — | — | — | — |

## Auth / JWT
The **full** auth/JWT key set — signing key, issuer, AND audience — not just the signing key. Issuer and audience are non-secret identifiers and ARE recorded; the signing key's value is secret and is NEVER recorded.
| Key | Source bucket | Format / shape | Environment(s) | Required? |
|---|---|---|---|---|
| _None — DesignSync rides the session's claude.ai login; no stored credential, no key set_ | — | — | — | — |

## Third-party API keys
API keys / tokens for third-party services (payments, storage, external APIs). Record the key name and where it is sourced; **never the key value**.
| Key | Source bucket | Format / shape | Environment(s) | Required? |
|---|---|---|---|---|
| _None_ | — | — | — | — |

## Notification targets
Email / SMS / push configuration, **including the sender / from address** — not only the recipient. From/sender and recipient addresses are non-secret and ARE recorded.
| Key | Source bucket | Format / shape | Environment(s) | Required? |
|---|---|---|---|---|
| _None_ | — | — | — | — |

## CORS origins
The **complete** set of allowed CORS origins across every environment — localhost dev origin(s), the apex domain, the `www` origin, and any API origin. Origins are non-secret and ARE recorded in full; an incomplete list is a common first-try bug.
| Key | Source bucket | Format / shape | Environment(s) | Required? |
|---|---|---|---|---|
| _None — no web surface_ | — | — | — | — |

## App config (per-environment)
Non-secret per-environment application settings — API base URLs (`apiUrl`), feature flags, timeouts, log levels — that differ across environments.
| Key | Source bucket | Format / shape | Environment(s) | Required? |
|---|---|---|---|---|
| `designTool` | `.milestone-config/designer.json` | enum: `claude-design` (default) · `pencil` · `figma` · `canva` | all | no (defaults) |
| `designDocsDir` | `.milestone-config/designer.json` | repo-relative path (default `docs/designs`) | all | no (defaults) |
| `uxArchitectAgent` | `.milestone-config/designer.json` | agent ref (default `milestone-designer:ux-architect`) | all | no (defaults) |
| `wireframerAgent` | `.milestone-config/designer.json` | agent ref (default `milestone-designer:wireframer`) | all | no (defaults) |
| `designSyncProjectId` | `.milestone-config/designer.json` | string (claude.ai Design System project id) | all | no — written by `design` at the first granted DesignSync push, never by setup |

Shared keys (`uiSurfaceGlobs`, `projectDocs`) are resolved from the existing driver/feeder config, never duplicated in `designer.json`. (brief :48-57)

## Build outputs
Build / publish output locations and artifact paths a deploy consumes — the publish directory, the bundle output dir, the artifact name.
| Key | Source bucket | Format / shape | Environment(s) | Required? |
|---|---|---|---|---|
| _None — no build step; the plugin ships as repo files_ | — | — | — | — |
