# Artifact contract — `docs/designs/<slug>/`

> **What this is.** The committed interface everything downstream grounds on. The design skill assembles this artifact set; the feeder's adapter-satisfaction check reads it; the driver's design-reviewer judges `spec.md` against its own vocabulary. The design *tool* is swappable — this contract is not (`.project/design-philosophy.md#One-way doors`). Downstream consumes only the committed files listed here, never a design tool (`.project/design-philosophy.md#Layering & boundaries`).

**Artifact root.** The root is `designer.json#designDocsDir` (default `docs/designs`). Consumers resolve it from config — never hardcode the path (`.project/config-catalog.md#App config (per-environment)`). `<slug>` is derived per [Slug derivation](#slug-derivation) below.

## Artifact layout

A satisfied design run commits, under the artifact root:

| Path | Required? | Format | Notes |
|---|---|---|---|
| `spec.md` | Yes | Markdown | The design spec. Structure below. |
| `screens/*.html` | Yes, for HTML-emitting adapters | Self-contained HTML | Lo-fi wireframes, one file per screen. HTML is the default wireframe format — greppable, diffable, renderable with zero tooling (brief:63, `.project/design-philosophy.md#One-way doors`). |
| `exports/*` | For adapters that cannot emit HTML | PNG / SVG | The exported screen representation; stands in for `screens/*.html` when the adapter cannot emit HTML (brief:46). |

Adapter-editable source (e.g. a committed `.pen`) may sit alongside these files; it does not affect satisfaction and is never referenced by this contract, which points only at `spec.md`, `screens/`, and `exports/` (brief:45).

Which adapters emit HTML versus exports is owned by the adapter-seam doc (`docs/adapter-seam.md`, issue #7). This contract fixes only the committed-file interface.

## spec.md structure

`spec.md` is written in the driver design-reviewer's vocabulary so issues grounded on it pass triage clean by construction (brief:38, `.project/conventions.md#Canonical exemplars (mirror these)` — mirror the milestone-driver design-reviewer agent). Required content:

| Section | Contents |
|---|---|
| Flows | The screen-to-screen flows the brief implies — entry points, transitions, exits. |
| Per-screen layout / grouping | For each screen: the layout and visual grouping of its regions and controls. |
| Required states | Every screen documents the **four required states**: **empty**, **loading**, **error**, **disabled**. |
| Affordances | The interactive affordances per screen, including a **confirm affordance for any destructive operation** (delete / archive / bulk-update / irreversible state change). |
| Pattern-to-mirror | The existing pattern each screen mirrors (an in-repo surface from `uiSurfaceGlobs`, or a named design-system pattern). |
| Gap resolutions | Each design-resolvable UX gap and how it was resolved, **with a citation** to the convention that backs the resolution, in one of the three forms the ux-architect writes (`agents/ux-architect.md (exactly one of three legal forms)`): a project-docs anchor, an existing-surface `path (anchor)` citation, or a named convention. That form is owned by milestone-driver `skills/citation-format.md` (shipped v1.19.0) — cite it, never restate it — and carries an anchor and **no line number and no line range**, never both. Anchor-only here because `spec.md` is committed and outlives the surfaces it cites; the ux-architect's clause 4 carries the full rationale. Product-scope gaps are not resolved here — they are parked to the needs-input report (brief:24, brief:66). |

## Slug derivation

`<slug>` is **identical** to the feeder's deterministic brief→slug derivation — the same rule that produces `plan-<slug>.md` — so the feeder finds designs without configuration (brief:37, `.project/conventions.md#Naming`).

This is a **cross-repo pointer, not a re-derivation.** The algorithm is owned by milestone-feeder `skills/plan/SKILL.md` and is out of scope here. Slug parity is a contract recorded in both repos (brief:69, `.project/conventions.md#Naming` — "the deterministic brief→slug derivation is shared with the feeder (cross-repo contract)"). Do not re-implement or restate the algorithm against this document; cite the feeder as the single owning implementation.

## No-UI-surface case

When the consumer repo's `design-system.md` / `tokens.json` are absent or all-`[TBD]` (zero screens implied), the design run **exits before any artifact is written** (brief:22).

No partial `docs/designs/<slug>/` tree is left behind by that exit — a run that stops at the no-UI-surface check writes nothing under the artifact root.

## Adapter satisfaction

An adapter **satisfies the pipeline iff it lands `spec.md` + screens in the design dir** (brief:47), where **screens** = `screens/*.html` for HTML-emitting adapters, or `exports/*` for adapters that cannot emit HTML — a non-HTML adapter's exports *are* its screens (brief:45-47). This is the exact condition the feeder's adapter-seam check depends on (`.project/design-philosophy.md#Layering & boundaries`).

A set does **not** satisfy when:
- `spec.md` is present but there is **no screen representation** — neither `screens/*.html` nor `exports/*`; or
- a screen representation is present but **`spec.md` is absent**.

Satisfaction is defined by the committed files alone — never by which design tool produced them (brief:30).

## Idempotent re-runs

Re-running `design` against an **unchanged brief is a diff-shown no-op** (brief:29): a **per-screen diff is shown before any overwrite**, and no artifact is overwritten silently (`.project/design-philosophy.md#Error & failure philosophy` — "Re-runs are idempotent: per-screen diff shown before any overwrite"). **On a re-run** the diff is surfaced at the human-review checkpoint and the artifact dir is written **only** on Approved; a **first run** has nothing to diff and writes directly (below). This mirrors the feeder `update` skill's diff-before-PATCH ethos (brief:29). Mechanics: `skills/design/SKILL.md` Steps 5–6.

**First run — plain write, no diff.** When no `<designDocsDir>/<slug>/` tree exists there is nothing to diff against: the run writes `spec.md` + `screens/*.html` directly. This is the ordinary first-design path — the diff step is skipped entirely, and it is **not** an error.

**Re-run — diff before any overwrite.** When the tree exists, the rule applies once to **each existing artifact file** — `spec.md` and every `screens/<screen-slug>.html`. For each, before writing it the skill reads the existing file and compares it to the freshly regenerated content (it MAY probe readability as early as the slug is known; the halt below fires no later than this pre-write diff):

| Case | Behavior |
|---|---|
| Regenerated content **identical** to the existing file | Report **"no changes"** for that artifact; perform **no write**. |
| Regenerated content **differs** | **Hold** the write; carry the diff (old vs newly generated) to the Step 6 checkpoint. The file is overwritten **only** if carried forward through Approved — a changed `spec.md` writes on the **same** approval as the changed screens. |
| Existing file **cannot be read** (permissions error / non-UTF-8 content) | **Halt before writing that artifact** and report a clear error **naming the file** — never a silent overwrite, never a silent skip. This is the fail-closed side of the "diff shown before any overwrite" invariant, owned by `.project/design-philosophy.md#Error & failure philosophy`. |

**Zero-writes no-op.** When an unchanged brief regenerates every artifact byte-identical to its committed file, every one reports "no changes" and the run performs **zero writes** (brief:99, `.project/design-philosophy.md#Testing philosophy`).

**Held content lives outside the artifact dir.** Pre-approval, the held regenerated artifacts (changed `screens/*.html` and a changed `spec.md`) live in transient per-run scratch **outside** the artifact set, under the design skill's own self-ignoring per-run scratch `.milestone-designer/` (established at `skills/design/SKILL.md` Step 3), never as a partial overwrite of `<designDocsDir>/<slug>/`. The artifact dir is touched only at approval, so a run abandoned at the checkpoint leaves the committed artifacts exactly as they were.
