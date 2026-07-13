# Adapter seam — the `designTool` config key

> **What this is.** The one canonical, citable record of what a design *adapter* must produce. The artifact contract (`docs/artifact-contract.md`) fixes the committed-file interface; this doc owns which adapters emit HTML versus exports, and the rule an adapter must meet to satisfy the pipeline. The design *tool* is swappable behind this seam — the contract is not (`.project/design-philosophy.md#One-way doors`). Only `claude-design` is implemented in v1; `pencil` / `figma` / `canva` are documented-contract-only.

## The `designTool` key

The adapter seam sits behind a single config key.

| Property | Value |
|---|---|
| Key | `designTool` |
| Source | `.milestone-config/designer.json` (`.project/config-catalog.md#App config (per-environment)`) |
| Shape | enum: `claude-design` (default) · `pencil` · `figma` · `canva` |
| Default | `claude-design` |
| Required? | No — defaults (`.project/config-catalog.md#App config (per-environment)` — "no (defaults)") |

`/milestone-designer:setup` writes this key into `designer.json` (brief:48-56). Consumers resolve it from config; the value selects an adapter, nothing more — downstream consumes only the committed artifact files, never a design tool (`.project/design-philosophy.md#Layering & boundaries`).

## The four-adapter table

Transcribed verbatim from the brief (brief:41-47):

| Adapter | v1 status | Produces |
|---|---|---|
| `claude-design` | implemented | HTML (the artifact *is* the source); optional DesignSync push for review |
| `pencil` | documented contract only | PNG exports + spec.md (`.pen` committed as editable source, never referenced by the contract — it's encrypted) |
| `figma`, `canva` | documented contract only | PNG/SVG exports + spec.md; one-way import bridges |

The `.pen` / native source of a non-HTML adapter is editable source only: it may sit in the design dir but is never referenced by the artifact contract, which points only at `spec.md`, `screens/`, and `exports/` (brief:45, `docs/artifact-contract.md#Artifact layout`).

## Adapter satisfaction

> An adapter **satisfies the pipeline iff it lands `spec.md` + screens in the design dir** (brief:47).

**Screens** = `screens/*.html` for HTML-emitting adapters (`claude-design`), or `exports/*` for adapters that cannot emit HTML (`pencil` / `figma` / `canva`) — a non-HTML adapter's exports *are* its screens (brief:45-47). The full non-satisfaction cases and the "committed files alone, never the tool" framing are owned by `docs/artifact-contract.md#Adapter satisfaction`; this seam only records which adapters land HTML versus exports. This is the exact condition the feeder's adapter-seam check depends on (`.project/design-philosophy.md#Layering & boundaries`).

## Default / unset behavior

An **absent `designTool` key defaults to `claude-design`** (`.project/config-catalog.md#App config (per-environment)` — required "no (defaults)"). No config is needed to get the implemented adapter.

Under `claude-design`, the optional **DesignSync push is off unless a claude.ai login with design scopes exists** — it is never assumed present. It is a built-in Claude Code tool used only at the review checkpoint, permission-gated and per-plan (brief:64). Repo files are canonical; claude.ai is a view, and the push is one-way (local → project) and optional (`.project/design-philosophy.md#One-way doors`).

## Failure / degrade behavior

**Adapter failures — DesignSync unavailable, or no claude.ai login — degrade gracefully to the local browser review path. They never fail the design run** (`.project/design-philosophy.md#Error & failure philosophy`, brief:64). A missing login is not a blocker: review still happens by opening the wireframes locally. The human review checkpoint itself cannot be skipped by any flag (`.project/design-philosophy.md#Error & failure philosophy`).

## v1 boundary

**No adapter code beyond `claude-design` ships in v1.** External design-tool SDKs (Figma / Canva / Pencil APIs) are banned for v1 — the adapter seam ships as contract docs only (`.project/library-manifest.md#Avoid / banned`). Selecting `pencil`, `figma`, or `canva` records the contract this doc describes; there is **no runtime dispatch to invoke** for those values. This is a stated non-goal: "No Figma/Canva/Pencil implementation in v1 — contract docs only" (brief:80).
