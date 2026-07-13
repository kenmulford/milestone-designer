# Environment

<!--
Project doc (.project/). Cite as `.project/environment.md#<section>`. Declares what the
project's runtime and production environment looks like — the facts downstream tools ground
their data, test, and caching decisions in. It does NOT provision anything; it records the
model so issues don't drift. Fill every [TBD]; a section left [TBD] is treated as "not
specified." Humans own this file; tools propose, never rewrite. Keep the ## headings stable
— they are citation anchors.
-->

## Environments
Which environments exist (production, staging, test, local) and how they differ.
> Local dev = a Claude Code session in the repo; CI = GitHub Actions `ubuntu-latest`. No prod/staging tiers — the deployed form is a published plugin version.

## Data stores
Databases and other persistent stores: the engine(s), and the **topology** — separate prod / staging / test databases, or a shared one. **Test-data isolation:** how tests get a clean, isolated database (a dedicated test DB, a per-worker DB suffix, transactional rollback, truncate-on-start). This is the single biggest drift source if left unstated.
> None — no databases. State is repo files: design artifacts land in *consumer* repos under `docs/designs/<slug>/`; this repo's own state is `.milestone-config/designer.json`. No test-data isolation concern.

## Caching
Whether caching exists and, if so, the layer and technology (in-memory, Redis, CDN), what is cached, and the invalidation policy. **"None" is a valid, drift-preventing answer** — record it explicitly.
> None — no cache layer.

## Async & messaging
Background jobs, queues, streams, schedulers — or "none."
> None — wireframer fan-out (concurrent, rolling cap 4) is in-session agent orchestration, not a queue.

## External services & integrations
Third-party services the app depends on: auth / identity, payments, email / SMS, object storage, analytics, other APIs.
> claude.ai DesignSync — optional review push, permission-gated per plan, one-way local→project; a missing login degrades to local browser review, never a blocker. GitHub is explicitly *not* a prerequisite — the designer writes no GitHub state. (brief :28, 64-68, 87)

## Runtime & hosting
Where it runs and the runtime/version targets (hosting platform, language-runtime versions, regions). For mandated frameworks and packages, cross-reference `library-manifest.md`.
> Runs inside Claude Code sessions on user machines — cross-platform: bash (jq) and PowerShell 7+ (see `library-manifest.md#Runtime & frameworks`).

## Deployment targets
Where the app is **deployed** — the hosting vendor / platform / target (Cloudflare, AWS, Azure, Vercel, Netlify, Fly.io, a self-managed host). **Records** the deploy destination; it does **not** provision it. Boundary vs `## Runtime & hosting`: that anchor is the runtime/version targets and regions the app *needs*; this anchor is *where it is deployed to* and who hosts it.
> milestone-suite marketplace (`kenmulford/milestone-suite`), versioned plugin releases; the marketplace entry itself is a suite-side follow-up PR. (brief :58, 77)
