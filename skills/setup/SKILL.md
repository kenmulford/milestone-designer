---
name: setup
description: >-
  This skill should be used when "milestone-designer:setup" is invoked directly,
  OR auto-invoked by the design skill when `.milestone-config/designer.json` is
  absent.
---

# setup — designer config bootstrap

Materialize `.milestone-config/designer.json`, the designer-specific config
holding four keys. The skill writes/patches the file **directly with its own
Read/Write tools** — no script, no `gh` call, no GitHub state. Re-runs are
idempotent: an already-complete config is never touched; a partial one is
repaired key-by-key.

## When this runs

| Trigger | How |
|---|---|
| Direct | `/milestone-designer:setup` — onboarding a repo, or repairing/inspecting the config |
| Auto | The `design` skill's Step 0 may invoke setup when `designer.json` is absent, then continue |

## Config schema (canonical)

`.milestone-config/designer.json` holds exactly these four keys, each
`Required? no (defaults)` and defaulting independently. This table is the
in-file source of truth for the keys and their defaults; per-key shape/enum
detail lives in `.project/config-catalog.md#App config (per-environment)`.

| Key | Documented default |
|---|---|
| `designTool` | `claude-design` |
| `designDocsDir` | `docs/designs` |
| `uxArchitectAgent` | `milestone-designer:ux-architect` |
| `wireframerAgent` | `milestone-designer:wireframer` |

Full happy-path file the **Absent** branch writes **verbatim** on a fresh
install (the four keys above, at their defaults):

```json
{
  "designTool": "claude-design",
  "designDocsDir": "docs/designs",
  "uxArchitectAgent": "milestone-designer:ux-architect",
  "wireframerAgent": "milestone-designer:wireframer"
}
```

**Shared keys are never written here.** `uiSurfaceGlobs` and `projectDocs` stay
resolved from the existing driver/feeder config — never duplicated into
`designer.json` (`docs/milestone-designer-brief.md:48-57`;
`.project/config-catalog.md#App config (per-environment)`). Do not write them
even if a consumer asks for them; a `designer.json` carrying either key is a bug.

## Procedure

Resolve the target path `<repo-root>/.milestone-config/designer.json`, then act
on its state.

| Step | Action |
|---|---|
| 1 | **Ensure the parent dir.** If `.milestone-config/` does not exist, create it first (`mkdir -p .milestone-config` or the Write tool's implicit dir creation). Never fail on a missing parent. |
| 2 | **Read the existing file** if present; parse it as JSON. |
| 3 | **Branch on state** per the table below, then report the resulting config values back to the user. |

| State | Behavior |
|---|---|
| **Absent** (no file, `.milestone-config/` may also be absent) | Create the dir if needed, then write all four keys at the table's defaults — the **verbatim** JSON above. |
| **Malformed** — file exists but does not parse as JSON | Make **no writes**. Report 🔴 with the parse problem and ask the human to fix or delete the file. Never rewrite or clobber a hand-edited file (`.project/design-philosophy.md#Error & failure philosophy`). |
| **Complete** — all four keys present | Make **no changes** (non-destructive re-run). Report the current values back to the user. Never silently overwrite a complete config (`.project/design-philosophy.md#Error & failure philosophy`, `#One-way doors` — repo files are canonical). |
| **Partial** — some of the four keys missing (hand-edited, or an older schema) | Fill **only** the missing keys with their documented defaults from the table. Leave every already-present key's value **untouched** — do not rewrite the whole file. Each key defaults independently. |

**Never overwrite a present key's value.** In the partial case, a key the user
set to a non-default value (e.g. `"designTool": "figma"`) stays as they set it;
only genuinely-absent keys are added.

**Stray shared key present.** If a parsed file carries `uiSurfaceGlobs` or
`projectDocs` (they never belong here), leave the **stray key in place** — the
skill never deletes keys. Report it with 🔴 and the instruction to remove it
manually. The normal state-table branch still governs the rest of the file: a
Partial file still gets **only** its missing keys filled, a Complete file gets
no changes — the stray key is neither stripped nor a reason to skip an otherwise
due repair.

Write the file as **UTF-8 (no BOM)**, valid JSON, two-space indent — matching
`driver.json`/`feeder.json`. Print the final contents so the user can verify.

## Config is git-tracked

`designer.json` lands as a **tracked** file, mirroring `driver.json` and
`feeder.json`. Do **not** add it to `.milestone-config/.gitignore` — that file
lists only per-run scratch and intentionally leaves tracked config unlisted
(`.milestone-config/.gitignore`). When invoked directly, suggest the user commit
it (`git add .milestone-config/designer.json`).

## Conventions

- **Markdown-only, no script twin.** Setup writes the config with its own
  Read/Write tools; `scripts/<name>.{sh,ps1}` twins in this repo are reserved for
  CI-gate logic (`scripts/*`), so sibling setup skills stay markdown-only.
- **No first-run notice.** Consumers resolve the same documented defaults whether
  or not `designer.json` exists on disk, so an install that never runs setup
  behaves identically (`docs/milestone-designer-brief.md:48-57`); setup only
  materializes the defaults for visibility/editing.

## Output style

Concise — report status and outcomes flatly, no wall-of-text. Present state and
values as **tables**, not prose. Mark anything needing a human with 🔴. (Mirrors
the suite's agent communication-style contract.)

## Non-negotiables

- **Local file only — no GitHub state.** Setup touches exactly one file,
  `.milestone-config/designer.json`. No `gh` calls, no labels, no issues, no PRs.
- **Non-destructive re-run.** A complete config is never overwritten; a partial
  one is repaired key-by-key, never wholesale-rewritten. Present values survive.
- **Never write the shared keys.** `uiSurfaceGlobs` and `projectDocs` are
  resolved from the driver/feeder config and must never appear in `designer.json`.
- **Never fail on a missing parent.** Create `.milestone-config/` when absent.
- **Tracked, not ignored.** Do not add `designer.json` to any `.gitignore`.
