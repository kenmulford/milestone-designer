---
name: design
description: >-
  This skill should be used when the user invokes "/milestone-designer:design
  <brief>", or asks to design a feature before planning it. Turns a feature
  brief into a committed design artifact set — spec.md plus per-screen lo-fi
  wireframes under the configured design dir — via exactly one ux-architect
  dispatch and a rolling-cap-4 wireframer fan-out, resolving convention-backed
  UX gaps inline with citations and parking product-scope gaps to a needs-input
  report. Runs Step 0's config + design-docs gate through the local review
  checkpoint. The no-UI-surface exit writes nothing; a zero-screen exit writes at
  most the gitignored needs-input scratch report — never a design artifact. Both
  stop early with a quotable notice; every run that writes design artifacts blocks at
  the unskippable local browser review before printing the /milestone-feeder:plan
  handoff. Read-only agents; writes only local repo files; no GitHub state, gh
  never a runtime prerequisite.
---

# design — brief → committed design artifact set

Turn a feature brief into the committed design artifact set (`spec.md` +
per-screen lo-fi wireframes) the feeder, driver, and coherence-reviewer ground
on — the milestone-suite's **pre-plan design phase**
(`brief → /milestone-designer:design → /milestone-feeder:plan → create → drive`).
This skill orchestrates read-only agents and writes only local repo files
(`.project/design-philosophy.md#Layering & boundaries`). It mirrors the feeder
`plan` skill's brief normalization, slug rule, agent fan-out, and needs-input
report (`.project/conventions.md#Canonical exemplars (mirror these)`).

## Announce first

Say this before doing any work:

> Producing a design from the brief — a `spec.md` + per-screen wireframes under
> the design dir, then a local review checkpoint. Read-only on GitHub; I write
> only local repo files.

## Procedure

### Step 0 — Resolve config + design docs (the no-UI-surface gate)

| # | Action |
|---|---|
| 1 | Resolve the **shared keys** `uiSurfaceGlobs` / `projectDocs` from the existing driver/feeder config (`.milestone-config/driver.json`, then `feeder.json`), absent-means-default (`projectDocs` → `.project/`). **Never duplicated into `designer.json`** (`skills/setup/SKILL.md` Non-negotiables). `uiSurfaceGlobs` unset → no surface can match; every screen is net-new (degrade, not error). |
| 2 | Read the **consumer repo's** `design-system.md` **and** `tokens.json` (under `projectDocs`). |
| 3 | **Gate — before any config write or dispatch.** `design-system.md` **or** `tokens.json` — **either absent, or present with every field `[TBD]`** → **exit immediately**, printing the verbatim no-UI-surface notice (fenced below). **No dispatch, no config write**; no partial `<designDocsDir>/<slug>/` tree and no `designer.json` bootstrap is left behind — the same skip rule the design-reviewer uses (`docs/milestone-designer-brief.md:22`; `agents/ux-architect.md:28`; `docs/artifact-contract.md#No-UI-surface case`; `.project/design-system.md:5-6`). |
| 4 | **Resolve `designer.json`** (only now, past the gate) — keys `designTool` / `designDocsDir` / `uxArchitectAgent` / `wireframerAgent`, absent-means-default (`.project/config-catalog.md#App config (per-environment)`). **Absent file → invoke `/milestone-designer:setup`** to bootstrap it, then continue — the user does not re-run the command (`skills/setup/SKILL.md` "When this runs" → Auto). Setup writes `designer.json` **only here, past the gate** — a gated exit at row 3 above leaves the tree untouched (row 3's own "No dispatch, no config write" rule). |
| 5 | **`designTool` guard.** If `designTool` resolves to `pencil` / `figma` / `canva` (legal enum values, documented-contract-only in v1) → **halt** with a clear notice: that adapter has **no runtime dispatch in v1** — set `designTool` to `claude-design` or leave it unset (`docs/adapter-seam.md#v1 boundary`). This is a **deliberate-config halt**, distinct from the Step 6 adapter-failure degrade, which never halts. |
| 6 | **Resolve the digests once.** Match `uiSurfaceGlobs` against the repo and read the matched surface files, plus `design-system.md` / `tokens.json` and the relevant sibling `.project/` docs, **once** into digests. Steps 2 and 4 pass **these** digests to the agents; agents never re-read directories (`agents/ux-architect.md` → "What you receive"; `agents/wireframer.md` → "What you receive"). |

**No-UI-surface notice** — the canonical text Step 0's gate prints **verbatim**
(the notice `docs/milestone-designer-brief.md:22` and
`docs/artifact-contract.md#No-UI-surface case` reference):

```
No UI surface for this brief: design-system.md / tokens.json are absent or
all-[TBD], so no design phase applies. Nothing was written. Proceed to
/milestone-feeder:plan <brief> when ready.
```

### Step 1 — Ingest the brief + derive the slug

Ingest the brief with the feeder `plan` skill's **Step 1 normalization**, verbatim:
detect the form (GitHub epic `#n` / file path / inline text), read it, and
normalize to `{ goal, in-scope, out-of-scope, surfaces }` before anything
downstream consumes it (`.project/conventions.md#Canonical exemplars (mirror these)`).
For the **GitHub epic `#n`** form, read it via `gh` — **when `gh` is unavailable,
do not fail**: ask the user to paste the brief text or point at a file. `gh` is
**never a runtime prerequisite** (`.milestone-config/driver.json:24` nonNegotiable).

Derive `<slug>` from the normalized brief's **one-line goal** — the **same
deterministic rule the feeder uses** to name `plan-<slug>.md`, so `<slug>` matches
across repos with no configuration (**slug parity is a cross-repo contract** —
`.project/conventions.md#Naming`; `docs/artifact-contract.md#Slug derivation`). The
designer applies that transformation to the **brief's one-line goal** — stated
honestly, that is the input difference: the feeder's rule names the *milestone*
goal, the designer runs the same transformation over the *brief's* one-line goal.

The rule, as a **quoted mirror** of the feeder's — tracked mirror; the feeder
(milestone-feeder `skills/plan/SKILL.md` Step 7) is the single owning implementation
per `docs/artifact-contract.md#Slug derivation`; if the feeder's rule changes, this
mirror must be updated:

> take the one-line milestone goal, lowercase it, replace every run of
> non-alphanumeric characters with a single hyphen, then strip any
> leading/trailing hyphens (cap the length at a reasonable bound, trimming a
> trailing hyphen if the cut lands on one).

**Do not pin a specific length cap here** — inventing one breaks slug parity with
the feeder's owning implementation.

### Step 2 — Dispatch the ux-architect (exactly once)

Dispatch the agent named in `uxArchitectAgent` (default
`milestone-designer:ux-architect`) **exactly once**, never re-invoked mid-run
(`.project/design-philosophy.md#Layering & boundaries`). Brief it with (matches
`agents/ux-architect.md` → "What you receive"):

- the **normalized brief** from Step 1;
- the **resolved project-docs digest** — the digests resolved once at Step 0
  (design-system.md, tokens.json, sibling `.project/` docs), passed as *content*,
  not directories to re-read;
- **pointers to existing UI surfaces** matched by `uiSurfaceGlobs` — omit when
  unset / matching nothing (every screen is then net-new).

It returns one `SCREENS / FLOWS / STATES / UX_GAPS` block — shape owned by
`agents/ux-architect.md` → "Structured return block". Steps 3–5 consume it:
`UX_GAPS` drives Step 3's split; each `SCREENS` entry (with its four-key `STATES`
coverage — empty / loading / error / disabled) drives one Step 4 wireframer
dispatch; the whole block feeds Step 5 assembly. **The destructive signal is the
literal `(DESTRUCTIVE)` marker on an affordance; marker absence means the action
is non-destructive — never conflated with the literal `none`, which the agent
writes only for a screen with no interactive affordances at all**
(`agents/ux-architect.md` clause 1).

### Step 3 — Split UX_GAPS (resolve design inline, park product) — before Step 5

Split every `UX_GAPS` entry by its `tag`, **before** Step 5 assembly:

| Tag | Action |
|---|---|
| `design-resolvable` | Has a conventional default. Carry its `resolution` + `citation` into `spec.md`'s Gap resolutions at Step 5 (`docs/artifact-contract.md#spec.md structure`). Resolved inline **with** its citation — never parked. |
| `product` | No conventional default. **Park** it — **never guessed** (`.project/design-philosophy.md#What we optimize for` — park-don't-guess). |

**Fold a resolved gap back into the working inventory.** When a `design-resolvable`
gap is resolved with its citation, **also update the affected screen's `STATES`
coverage** in the working inventory — replace that state's `gap -> UX_GAPS` value
with the cited resolution — **before** Step 4 dispatch and Step 5 assembly. So the
wireframer renders the resolved state and `spec.md` carries no stale `gap -> UX_GAPS`
marker for a gap that was resolved.

Park by mirroring the feeder `plan` skill's report **format and routing**: write
`.milestone-designer/needs-input-<slug>.md` (same deterministic `<slug>`), one
entry per product gap (its `gap`, `why_unresolved`, `brief_ref` — decide it,
then re-run `design`). **Before the first write**, ensure the scratch dir
self-ignores — create `.milestone-designer/` and a `.milestone-designer/.gitignore`
containing a single `*` line (mirrors milestone-feeder `skills/plan/SKILL.md`
Step 7's self-ignore). The needs-input report is the **routing/scratch mirror**
(gitignored); the **committed** `spec.md` must stay self-contained — so each parked
gap is **also** listed inline in `spec.md`'s Gap resolutions as
`parked — needs input: <the question>` (Step 5), never a dangling reference only
the local clone can see.

**Zero screens (`SCREENS: []`).** No screens to wireframe — nothing satisfies the
artifact contract, so no artifact set is written. Report the empty inventory and
stop with the quotable notice matching the cause:

| Cause | Notice + next step (quotable) |
|---|---|
| Logic-only brief, no product gaps parked | `No screens implied — no design phase applies. Proceed to /milestone-feeder:plan <brief>.` |
| Zero screens because product gaps are parked | `No screens could be inventoried — <N> product gap(s) parked to needs-input-<slug>.md. Decide them, then re-run /milestone-designer:design <brief>.` |

### Step 4 — Dispatch the wireframer per screen (rolling cap 4)

For **each** `SCREENS` entry, dispatch the agent named in `wireframerAgent`
(default `milestone-designer:wireframer`) — **concurrently as background agents,
no more than 4 in flight at once**. N ≤ 4 → dispatch all; N > 4 → a rolling
window refills a slot as each returns, so the in-flight count **never exceeds 4**
(mirrors the feeder issue-author / driver worker fan-out —
`.project/conventions.md#Canonical exemplars (mirror these)`). Await all returns
before Step 5.

Brief each with (matches `agents/wireframer.md` → "What you receive"):

- its **one `SCREENS` entry** — all fields: `name`, `purpose`, `layout/grouping`,
  `affordances` (incl. `(DESTRUCTIVE)` markers), `pattern-to-mirror`, optional
  `references`, **and its four-key `STATES` coverage**;
- the **resolved content** of `tokens.json`, `design-system.md`, and the matched
  `uiSurfaceGlobs` surfaces — **the skill resolves these once (Step 0) and passes
  the digests; agents never re-read directories** (`agents/wireframer.md` →
  "What you receive").

Collect each structured return (`SCREEN` + the `WIREFRAME` HTML document).
**Before Step 5 writes, validate completeness:** **every** `SCREENS` entry must
have **exactly one** returned block whose `SCREEN` echoes the entry name
**verbatim** and carries a **non-empty** `WIREFRAME`. Any missing, name-mismatched,
duplicate, or malformed (empty-`WIREFRAME`) return → **halt-and-report**, naming
the offending screen(s) (see Failure handling).

### Step 5 — Assemble spec.md + write the artifact set

Assemble `spec.md` in the **driver design-reviewer's vocabulary** — every row of
`docs/artifact-contract.md#spec.md structure`:

| Section | Contents |
|---|---|
| Flows | The screen-to-screen flows (from `FLOWS`). |
| Per-screen layout / grouping | Each screen's `layout/grouping`. |
| Required states | Each screen's **four** states — empty / loading / error / disabled. |
| Affordances | Per-screen affordances, incl. a **confirm affordance for any destructive** action. |
| Pattern-to-mirror | Each screen's `pattern-to-mirror`. |
| Gap resolutions | Each `design-resolvable` gap + its citation (Step 3), **and** each parked product gap inline as `parked — needs input: <the question>` — so the committed spec is self-contained (the gitignored needs-input report is the scratch mirror). |

Write the artifact set to `<designDocsDir>/<slug>/` per
`docs/artifact-contract.md#Artifact layout` — **the root is resolved from
`designer.json#designDocsDir`; never hardcode it**:

- `<root>/spec.md`;
- `<root>/screens/<screen-slug>.html` — one per `SCREENS` entry, the returned
  `WIREFRAME` HTML. `<screen-slug>` is the `SCREEN` name run through the **same
  transformation as `<slug>`** (lowercase; every run of non-alphanumeric
  characters → a single hyphen; strip leading/trailing hyphens —
  `.project/conventions.md#Naming`), and `SCREEN` echoes the entry name verbatim
  so the mapping is unambiguous (`agents/wireframer.md` → "Structured return block").
  **Screen-slug collision** — two `SCREENS` entries whose names transform to the
  **same** `<screen-slug>` → **halt-and-report**, naming **both** entries; never
  silently overwrite one wireframe with another (deterministic, no silent overwrite).

Under `claude-design` (the only v1 adapter) the wireframe format is HTML →
`screens/`; other adapters (`exports/*`) are documented-contract-only with no
runtime dispatch (`docs/adapter-seam.md#v1 boundary`; the Step 0 `designTool`
guard has already halted any non-`claude-design` value).

**Scope boundary — plain write only.** This step lays the **plain write path**.
The idempotent re-run behavior — a **per-screen diff shown before any
overwrite** — is **#11's** hardening, out of this issue's scope
(`docs/artifact-contract.md#Idempotent re-runs`).

### Step 6 — Local review checkpoint (never skipped)

Open the wireframes in the **local browser** and **BLOCK on human approval**.
This checkpoint is **never skipped by any flag, config key, env var, or
non-interactive / CI invocation** (`.milestone-config/driver.json:22`
nonNegotiable; `.project/design-philosophy.md#Error & failure philosophy`).

| Outcome | Behavior |
|---|---|
| **Approved** | If any product gaps were parked, **first** print a 🔴 outstanding-needs-input line — the **count** + the `needs-input-<slug>.md` path — so the parks stay visible; **then** print the handoff line, verbatim: `/milestone-feeder:plan <brief>`. (The handoff still prints; the parked gaps are surfaced above it.) |
| **Rejected** | Artifacts **stay in place**; print **no** handoff line; the human fixes the brief/docs and **re-runs** `design`. |

**DesignSync seam (not this issue).** Under `claude-design`, an optional
DesignSync push to claude.ai is offered at this **same** checkpoint — that push
is **#10's** scope, layered on this local path. Leave the seam here; **do not
implement it**. A missing login / unavailable DesignSync degrades to this local
path and never fails the run (`docs/adapter-seam.md#Failure / degrade behavior`).

## Failure handling

A **ux-architect (Step 2) or wireframer (Step 4) dispatch failure**, or a
**Step 4→5 completeness failure** (a `SCREENS` entry with a missing,
name-mismatched, duplicate, or empty-`WIREFRAME` return), or a **screen-slug
collision** (Step 5) → **halt** with a clear report naming **which** dispatch or
**which** screen(s) failed. Write **no partial artifact set** from a failed stage
(fail-closed on the artifact write). **This halt-and-report + fail-closed-write
rule is this skill's own recorded normative rule** (grounded in issue #9's triage
advisory) — it is *not* delegated to `.project/design-philosophy.md#Error &
failure philosophy`, whose scope is adapter-degrade, the never-skipped checkpoint,
and idempotency, not this fail-closed-write.

This is distinct from an **adapter** failure (Step 6 DesignSync), which degrades
to the local path and never fails the run
(`.project/design-philosophy.md#Error & failure philosophy`).

## Output style

Concise — status and outcomes flatly, no wall-of-text. Steps, gates, and options
as **tables**. Mark anything needing a human with 🔴. (Mirrors the suite's agent
communication-style contract.)

## Non-negotiables

- **Agents are read-only.** `ux-architect` and `wireframer` read the repo/docs to
  ground their returns; they never write files or dispatch other agents
  (`.project/design-philosophy.md#Layering & boundaries`).
- **Writes only local repo files** — the artifact set under
  `<designDocsDir>/<slug>/` and the scratch needs-input report. **No GitHub
  state; `gh` is never a runtime prerequisite.**
- **The Step 6 review checkpoint is never skipped** by any flag, config key, env
  var, or non-interactive / CI invocation.
- **Adapter failures degrade to the local path; they never fail the run.** A
  dispatch (agent) failure halts; an adapter (DesignSync) failure degrades.
- **`ux-architect` dispatched exactly once; `wireframer` once per screen**
  (rolling cap 4).
- **Park-don't-guess.** Product-scope UX gaps are parked to the needs-input
  report, never guessed; convention-backed gaps resolve inline with a citation.
- **Plain write path only** — the per-screen diff-before-overwrite idempotency is
  #11's scope.
