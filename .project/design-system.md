# Design system

<!--
Project doc (.project/). Cite as `.project/design-system.md#<section>`. Machine-readable
design tokens live in `tokens.json` alongside this file. Absent or all-[TBD] →
no design-lens grounding (design-reviewer / coherence-reviewer / wireframing
skip it). Skip this file entirely for repos with no UI surface. Keep ## headings
stable — they are citation anchors.
-->

## Design tokens
Canonical color, type, spacing, and radius scales. Source of truth is `tokens.json`; describe intent and usage here.
> None — not applicable. This repo has no UI surface of its own (a Claude Code plugin: markdown skills + script twins). The wireframes it *emits* land in consumer repos and are governed by the wireframer agent's lo-fi contract, not by this file. (interview T7; sibling parity: milestone-bootstrapper)

## Component inventory
The canonical components and where they live. New UI reuses these before introducing a one-off.

| Component | Location | Use for |
|---|---|---|
| _None — not applicable (no UI surface)_ | — | — |

## Layout & responsive rules
Grid, breakpoints, spacing rhythm, density.
> None — not applicable (no UI surface).

## Required states
Every interactive surface must handle these explicitly.
> None — not applicable (no UI surface). The four required states (Empty/Loading/Error/Disabled) are part of the *emitted* spec vocabulary for consumer repos, not of this repo's own UI.

## Accessibility baseline
The standard you hold, plus contrast, focus, target size, and semantics expectations.
> None — not applicable (no UI surface).

## Voice & microcopy
Tone for labels, errors, and empty states.
> None — not applicable (no UI surface). User-facing tone is governed by the suite's shared concise/tabular output style.
