# Changelog

All notable changes to `milestone-designer` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-05

**Theme:** citations that survive the code moving — the design spec's grounding is now keyed to file content, not to a line number.

### ✨ Added

| Issue | PR | What |
|---|---|---|
| #40 Anchor-form citations | #41 | The ux-architect's UX-gap `citation` slot takes the `path (anchor)` form in place of the old line-pinned one. A design resolution recorded in a committed `spec.md` now points at content, so it still resolves after the cited surface's line numbers move. |

### Consumer notes (upgrading from 0.1.0)

- **The `citation` field's source-file option changed shape.** A `design-resolvable` gap now cites an existing surface as `` `path (anchor)` `` — a path plus a literal string from the region — instead of a path plus a line number. The other two options are unchanged: the project-docs anchor (`.project/<doc>#<section>`) and `convention: <named convention>`. The enum is still exactly three options.
- **Why it changed.** The `design` skill copies that citation verbatim into a committed `spec.md` that outlives the surface it points at, so any edit above a pinned line silently invalidated it — no warning, and the citation still looked well-formed.
- **The form is defined once, in milestone-driver.** `skills/citation-format.md` (shipped in milestone-driver v1.19.0) owns how to pick an anchor, how it resolves, and what a stale one does. This repo points at it rather than restating it, mirroring how `docs/artifact-contract.md` already points slug derivation at milestone-feeder.
- **Line-pinned citations are not deprecated.** `path:line` and `path:start-end` stay valid to write elsewhere in the suite. The narrowing to anchors is specific to this one slot, because its output is a long-lived committed artifact.
- **No migration needed and nothing to reconfigure.** Citations already written are untouched, and this release changes no `designer.json` key. **No schema changes** to `.milestone-config/driver.json`.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none.

## [0.1.0] - 2026-07-13

**Theme:** the milestone-suite's pre-plan design phase — turn a feature brief into a committed design spec plus lo-fi wireframes *before* the work is decomposed into issues.

Initial release — no prior releases.

### ✨ Added

| Issue | PR | What |
|---|---|---|
| #4 Plugin scaffold + #5 CI floor | #15 | Plugin/marketplace manifests, MIT license, the skill-size gate twins (`scripts/check-skill-size.{sh,ps1}`), the plugin-structure preflight, and the fixture harness. |
| #1 Artifact contract | #17 | `docs/artifact-contract.md` — the committed-file interface (`docs/designs/<slug>/{spec.md, screens/*.html, exports/*}`) everything downstream grounds on. |
| #2 Setup skill | #18 | `/milestone-designer:setup` — non-destructive `designer.json` bootstrap/repair (four defaulted keys; absent-means-default). |
| #3 ux-architect agent | #19 | Read-only screens/flows/states inventory + UX-gap audit, dispatched exactly once per run. |
| #13 Skill-size gate reconciliation | #20 | Flat-ceiling-only, recursive `skills/**/SKILL.md` scope; the shell twins are the sole gate owners. |
| #7 Adapter seam | #21 | `docs/adapter-seam.md` — the `designTool` seam: four-adapter table, satisfaction rule, degrade behavior, v1 boundary. |
| #6 Wireframer agent | #22 | Read-only per-screen lo-fi HTML wireframer (returned, never written) + the extended ux-architect `SCREENS` contract. |
| #9 Design skill core | #23 | `/milestone-designer:design <brief>` — Steps 0–6: no-UI-surface gate, brief normalization + slug parity, gap resolution/parking, rolling-cap-4 wireframer fan-out, artifact write, and the unskippable local review checkpoint. |
| #10 DesignSync push | #24 | Optional, permission-gated per-plan push of the wireframes under review to the claude.ai Design System pane; pick-once-remember `designSyncProjectId`; every miss or failure degrades silently to local review. |
| #11 Idempotent re-runs | #26 | Per-screen diff before any overwrite; identical regeneration → zero writes; held content flushed only on checkpoint approval. |
| #12 CI harness wiring | #27 | The `unit-tests` gate runs the gate **and** its fixture harness (no more vacuous green on a zero-skills repo), emitted from `driver.json#unitTestCmd`. |
| #14 Gate hardening | #28 | Exact-case/ordering twin parity, single-pass validator, one shared case table, a validator characterization harness (24 assertions), and loud-failure guards in every harness. |
| #8 README | #29 | Suite-consistent README: logo, mermaid pipeline diagram with the pre-plan design slot, quick start, degrade paths, config, and non-goals. |

### Consumer notes

- Zero required config: every `designer.json` key defaults; the first `design` run bootstraps the file. `designSyncProjectId` is written only at the first granted DesignSync push, never by setup.
- No runtime dependency on `gh`, external design-tool SDKs, or other plugins; `bash` + `jq` or PowerShell 7+ cover the CI gate twins.
- `pencil` / `figma` / `canva` adapter values are documented-contract-only in v1 — selecting one halts with a clear notice.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: #26 (wireframer-doc scope extension + content-keyed config citations).
