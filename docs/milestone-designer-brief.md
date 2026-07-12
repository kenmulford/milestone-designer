# milestone-designer — feeder brief

> **How to use this doc.** Feature brief for `milestone-feeder`, staged in the suite repo until `kenmulford/milestone-designer` exists — move it there as `BRIEF.md`, then run `/milestone-feeder:plan BRIEF.md`.
>
> Suggested milestone line: `Milestone: milestone-designer v0.1.0`.

## What it is

`milestone-designer` is the suite's fifth plugin: a **pre-plan design phase**. It sits between the brief and `/milestone-feeder:plan` — it reads a feature brief, maps the screens/flows/states the brief implies, surfaces UX gaps *before* decomposition, and produces lo-fi wireframes plus a design spec that the feeder, driver, and coherence-reviewer ground on.

It is the "wireframing tool" the bootstrapper docs already name as a consumer of `design-system.md` + `tokens.json` (bootstrapper `project-docs/SPEC.md:33`, `templates/tokens.json:2`) but which nothing implements.

Pipeline position: `brief → /milestone-designer:design → /milestone-feeder:plan → create → drive`.

## Why

Today the pipeline is design-downstream-only: the feeder's issue-author writes a prose `## Design` section, the driver's design-reviewer judges that prose, and the human sees rendered UI only after the build. Nothing ever *produces* a design, so decomposition-level UX gaps — missing empty states, missing screens, flows nobody wrote an issue for — surface late as `needs design` parks or post-build rework. Designing before the architect decomposes turns those gaps into issues instead of parks.

## What to build (capability scope)

1. **`/milestone-designer:design <brief>`** — the main skill. Flow:
   - Step 0: resolve config + shared keys (`uiSurfaceGlobs`, `projectDocs`); read `design-system.md` + `tokens.json`. Absent or all-`[TBD]` design docs → exit with the standard no-UI-surface notice (same skip rule the design-reviewer uses).
   - Step 1: ingest the brief (same normalization as the feeder's plan Step 1).
   - Step 2: dispatch the **ux-architect agent exactly once** → structured `SCREENS / FLOWS / STATES / UX_GAPS` block. Gaps split two ways: *design-resolvable* (has a conventional default — resolve it, cite the convention) vs *product* (no conventional default — park, never guess).
   - Step 3: park product gaps to a needs-input report (mirror the feeder's report format and routing).
   - Step 4: dispatch one **wireframer agent per screen** (concurrent, rolling cap 4 — mirror the feeder's issue-author fan-out), grounded in `tokens.json`, `design-system.md`, and existing `uiSurfaceGlobs` surfaces.
   - Step 5: assemble `spec.md`; write the artifact set (contract below).
   - Step 6: human review checkpoint — never skipped. Open the wireframes locally; if the `claude-design` adapter is active, offer a DesignSync push (permission-gated, per-plan) so review happens in the claude.ai Design System pane, cards grouped by feature slug. On approval, print the handoff line: `/milestone-feeder:plan <brief>`.
   - Re-runs are idempotent: per-screen diff shown before any overwrite (mirror the feeder `update` skill's diff-before-PATCH ethos).
2. **The artifact contract** (tool-agnostic — this is the interface; everything downstream consumes only these committed files, never a design tool):
   ```
   docs/designs/<slug>/
     spec.md          # flows, per-screen layout/states/affordances, gap resolutions with citations
     screens/*.html   # lo-fi wireframes (default format)
     exports/*.png    # only for adapters that can't emit HTML
   ```
   `<slug>` uses the feeder's deterministic brief→slug derivation (same rule as `plan-<slug>.md`) so the feeder can find designs without configuration.
   `spec.md` is written in the driver design-reviewer's vocabulary — layout/grouping, the four required states (empty/loading/error/disabled), affordances incl. confirm-on-destructive, pattern-to-mirror — so triage passes clean by construction.
3. **The `ux-architect` agent** — read-only, dispatched once. Brief + design docs + existing UI surfaces in → screen/flow inventory, state matrix, UX_GAPS out. This is the gap-catching step; it never invents product scope.
4. **The `wireframer` agent** — one per screen. Produces a single self-contained HTML wireframe. Lo-fi by contract: grayscale boxes, real information hierarchy, real states — spec-sufficiency, not visual design (the design-reviewer's "never produces the final visual design" boundary applies here too).
5. **Adapter seam** — `designTool` config key, default `claude-design`:
   | Adapter | v1 status | Produces |
   |---|---|---|
   | `claude-design` | implemented | HTML (the artifact *is* the source); optional DesignSync push for review |
   | `pencil` | documented contract only | PNG exports + spec.md (`.pen` committed as editable source, never referenced by the contract — it's encrypted) |
   | `figma`, `canva` | documented contract only | PNG/SVG exports + spec.md; one-way import bridges |
   An adapter satisfies the pipeline iff it lands `spec.md` + screens in the design dir. No adapter code beyond `claude-design` in v1.
6. **`/milestone-designer:setup`** — writes `.milestone-config/designer.json`, following the suite's config conventions:
   ```json
   {
     "designTool": "claude-design",
     "designDocsDir": "docs/designs",
     "uxArchitectAgent": "milestone-designer:ux-architect",
     "wireframerAgent": "milestone-designer:wireframer"
   }
   ```
   Shared keys (`uiSurfaceGlobs`, `projectDocs`) are resolved from the existing shared config, not duplicated.
7. **Repo hygiene** — README (suite-consistent, with the pipeline diagram updated to show the design slot), LICENSE (MIT), CHANGELOG, CI floor, tests mirroring the sibling plugins' harness.

## Recorded decisions (grounding — so the feeder doesn't invent these)

- **Pre-plan, not plan→create.** Design informs decomposition; wireframing after the architect runs can only decorate existing issues, not surface missing ones.
- **HTML is the default wireframe format** because it is greppable/diffable/renderable by every downstream agent with zero tooling. The design *tool* is swappable; the artifact contract is not.
- **`claude-design` is the only hard-implemented adapter in v1.** Authoring needs no external dependency (Claude writes HTML; `frontend-design` skill guides it); DesignSync is a built-in Claude Code tool used only at the review checkpoint, permission-gated, and only when a claude.ai login with design scopes exists. A missing login degrades to local browser review — never a blocker.
- **Repo files are canonical; claude.ai is a view.** The DesignSync push is one-way (local → project) and optional.
- **Park-don't-guess carries over:** product-scope UX gaps go to the needs-input report; only convention-backed design gaps are auto-resolved, each with a citation.
- **Lo-fi boundary:** wireframes specify structure, states, and affordances — not final visual design. Final rendering is still judged at the driver's post-build visual gate.
- **No GitHub writes.** The designer writes only local repo files (and, on explicit approval, the DesignSync project).
- **Slug parity with the feeder** is a contract, recorded in both repos' docs when the integration lands.

## Non-goals (what it refuses)

- **Does not modify the sibling plugins.** The integration PRs are manual follow-ups, each small and independently shippable:
  - *feeder:* plan Step 0 checks `docs/designs/<slug>/spec.md`; if present, add to the grounding digest and thread to architect + issue-authors; issue-author cites screen files via the existing `Config pointers:` line.
  - *driver:* design-reviewer brief gains one line — if the issue's Design section links wireframe files, read them.
  - *bootstrapper:* `SPEC.md` consumers column and templates rename "wireframing" → `milestone-designer`.
  - *suite:* marketplace entry + README diagram.
- **Not a design-review tool** — the driver's design-reviewer keeps that job. No duplicate review lens.
- **Not a component-library manager** — it consumes `design-system.md`/`tokens.json`, it doesn't author them (that's the bootstrapper interview).
- **No Figma/Canva/Pencil implementation in v1** — contract docs only.

## Constraints / non-negotiables

- Suite conventions throughout: superpowers dependency, concise doc style, structured agent return blocks, read-only agents, config in `.milestone-config/`, versioned releases.
- The human review checkpoint in `design` cannot be skipped by any flag.
- Adapter failures (DesignSync unavailable, no login) degrade gracefully to the local path; they never fail the run.
- `gh` is *not* a prerequisite (nothing touches GitHub).

## Sequencing hints (for the architect's wave order)

- Artifact contract + `designer.json` schema land first (everything cites them).
- `ux-architect` before `wireframer` (the wireframer consumes its screen inventory).
- The `design` skill orchestration after both agents.
- DesignSync review path after the local review path works.
- README/CI/hygiene alongside.

## Definition of done

Running `/milestone-designer:design <brief>` in a repo with a filled `design-system.md` produces `docs/designs/<slug>/` with a spec and per-screen HTML wireframes, parks any product-scope UX gap to a needs-input report, and stops at a human review checkpoint (local browser, plus DesignSync push when authorized). A subsequent `/milestone-feeder:plan` on the same brief — once the feeder follow-up lands — grounds on the spec, and the resulting UI issues pass the driver's design-reviewer with `GAPS: none` when the spec covers them. Re-running `design` on an unchanged brief is a diff-shown no-op.
