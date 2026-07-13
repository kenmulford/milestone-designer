# Library manifest

<!--
Project doc (.project/). Cite as `.project/library-manifest.md#<section>`. The
implementer's "new dependency = PAUSE" gate reads this; the coherence-reviewer
flags a new library that duplicates one listed here. Keep it current. Keep ##
headings stable — they are citation anchors.
-->

## Runtime & frameworks
The platform/runtime and primary frameworks, with versions. (Mirror these into milestone-driver `nonNegotiables` where they're hard constraints.)
> Claude Code plugin (driver `stack: plugin`). Markdown skills + read-only agents; scripts as cross-platform twins — bash-first (jq) with PowerShell 7+ fallback; JSON config in `.milestone-config/designer.json`. No app runtime, no SQL, no ORM. (interview T3; sibling exemplar: milestone-bootstrapper repo)

## Approved libraries (by purpose)
One approved choice per purpose, so a redundant alternative is easy to spot.

| Purpose | Library | Notes |
|---|---|---|
| Process skills (TDD, debugging, skill authoring) | superpowers | suite plugin dependency — required by suite convention (brief :84) |
| Wireframe authoring guidance | frontend-design skill | guides lo-fi HTML wireframe authoring |
| Plugin structure & validation (dev-time) | plugin-dev | scaffolding, validation, skill review |
| JSON in bash scripts | jq | bash-side of the script-twin convention |

## Adding a dependency (the gate)
A new dependency is a PAUSE, not an autonomous call. Record what it buys, its license / OSS status, and why nothing approved suffices; a human approves before it's added.
> Suite convention — a new dependency is a PAUSE: propose via an issue labeled `needs decision` with what it buys and why nothing approved suffices; a human approves before it is added. No new external SDK without a recorded decision.

## Avoid / banned
Libraries explicitly not to use, and why.
> External design-tool SDKs (Figma / Canva / Pencil APIs) in v1 — the adapter seam ships as contract docs only; no adapter code beyond `claude-design`. `gh` is not a runtime dependency (the designer touches no GitHub state). (brief :47, 80, 87)
