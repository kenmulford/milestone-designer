# Design philosophy

<!--
Part of your project docs (.project/). Tools read and cite this file as
`.project/design-philosophy.md#<section>`. Fill every [TBD]. A section left as
[TBD] is treated as "not specified" — tools fall back to inferred repo
convention rather than ground on a placeholder. Humans own this file; tools may
*propose* changes but never rewrite it. Keep the ## headings stable — they are
citation anchors. Add new sections by appending, not renaming.
-->

## Architectural stance
What kind of system is this, and what does it fundamentally optimize for?
> milestone-designer is the milestone-suite's fifth plugin: the **pre-plan design phase**. It reads a feature brief, maps the screens/flows/states the brief implies, surfaces UX gaps *before* decomposition, and produces lo-fi wireframes plus a design spec that the feeder, driver, and coherence-reviewer ground on. Pipeline position: `brief → /milestone-designer:design → /milestone-feeder:plan → create → drive`. Structurally mirrors the sibling suite plugins (feeder, driver, bootstrapper). (docs/milestone-designer-brief.md:7-13)

## Layering & boundaries
The layers and the allowed dependency directions — what may depend on what, and what must never.
> Skills orchestrate (`design`, `setup`) → read-only agents (ux-architect, dispatched exactly once; wireframer, one per screen, concurrent rolling cap 4) → the committed artifact contract `docs/designs/<slug>/` (`spec.md`, `screens/*.html`, `exports/*.png`). Adapter seam behind the `designTool` config key (default `claude-design`); an adapter satisfies the pipeline iff it lands `spec.md` + screens in the design dir. Downstream consumes only committed files, never a design tool. Agents never write; skills write only local repo files — bar the `design` skill's approval-gated DesignSync push (brief :68). (brief :21-47)

## What we optimize for
Ranked priorities, and the explicit non-goals that follow from them.
> 1) Surfacing decomposition-level UX gaps before the architect decomposes — gaps become issues, not parks. 2) Spec-sufficiency over visual design — the lo-fi boundary: structure, states, affordances; final rendering is judged at the driver's post-build visual gate. 3) Park-don't-guess — product-scope gaps go to the needs-input report; only convention-backed design gaps auto-resolve, each with a citation. Non-goals: not a design-review tool; not a component-library manager; no Figma/Canva/Pencil implementation in v1; never modifies the sibling plugins. (brief :15-17, 62-80)

## One-way doors
Decisions that require human sign-off *before* they're made — irreversible or expensive-to-reverse choices.
> The artifact contract is the interface — the design *tool* is swappable, the contract is not. HTML is the default wireframe format (greppable/diffable/renderable with zero tooling). Slug parity with the feeder is a cross-repo contract. Pre-plan pipeline position (design informs decomposition), not plan→create. Repo files are canonical; claude.ai is a view (DesignSync push is one-way and optional). (brief :60-69)

## Error & failure philosophy
How the system handles and surfaces failure: fail-open vs fail-closed, the user-facing error policy, logging expectations.
> Adapter failures (DesignSync unavailable, no claude.ai login) degrade gracefully to the local browser path — they never fail the run. The human review checkpoint in `design` cannot be skipped by any flag. Re-runs are idempotent: per-screen diff shown before any overwrite. (brief :28-29, 82-87)

## Testing philosophy
What we test, at what level, and what "verified" means before a change is done.
> Tests mirror the sibling plugins' harness; the CI floor gates PRs. "Done" is behavioral: `design` produces the artifact set, parks product gaps, and stops at the human review checkpoint; re-running on an unchanged brief is a diff-shown no-op. (brief :58, 97-99)
