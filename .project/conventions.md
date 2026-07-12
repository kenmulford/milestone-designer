# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. This is the file the
implementer and coherence-reviewer lean on hardest — "reuse conventions" and
"does this fit the app?" both resolve here. Prefer pointing at a canonical
exemplar in the codebase (path:line) over prose. Keep ## headings stable — they
are citation anchors.
-->

## Naming
Files, types, functions, tests, branches.
> Suite conventions — skills as `skills/<name>/SKILL.md`, agents as `agents/<name>.md`, script twins `scripts/<name>.sh` + `scripts/<name>.ps1`; kebab-case throughout; the deterministic brief→slug derivation is shared with the feeder (cross-repo contract).

## File & folder layout
Where things go, and the shape of a feature.
> Mirror the sibling suite plugins — `.claude-plugin/plugin.json`, `skills/`, `agents/`, `scripts/`, `docs/`, `.github/workflows/ci.yml`; runtime config in `.milestone-config/`.

## Test patterns
Where tests live, how they're named, fixtures/factories, and what a good test looks like.
> Mirror the sibling plugins' harness; CI floor = skill-size gate (`scripts/check-skill-size.sh`, word ceilings on SKILL.md files). Note: the harness lands with this milestone's repo-hygiene issue — land it early; the `unit-tests` CI check is red until it exists.

## Canonical exemplars (mirror these)
The reference implementations to copy when building something similar. Point at real code.

| For… | Mirror | Notes |
|---|---|---|
| Brief normalization, slug rule, agent fan-out, needs-input report | milestone-feeder `skills/plan/SKILL.md` | slug parity is a cross-repo contract |
| Design-spec vocabulary (four required states, affordances, confirm-on-destructive) | milestone-driver design-reviewer agent | `spec.md` is written in this vocabulary so triage passes clean |
| Script twins, CI shape, `.project/` doc style | milestone-bootstrapper repo | bash-first + PowerShell 7+ twin convention |

## Commits & PRs
Message format and PR expectations.
> Suite convention — feature work PRs into `develop`; `main` is protected (PR + required checks); concise commit style; per-PR version bump.

## Versioning
Does the project follow semantic versioning? If so, **where the version lives** (e.g. `pyproject.toml`, `package.json`, `*.csproj`, a `VERSION` file) and the **bump cadence** (per feature / milestone). When semver is on, `milestone-driver` applies the bump per PR and `milestone-feeder` names milestones as versions so the driver can derive the target.
> SemVer. Version lives in `.claude-plugin/plugin.json`; `milestone-driver` applies the bump per PR; `milestone-feeder` names milestones as versions. (interview T6)
