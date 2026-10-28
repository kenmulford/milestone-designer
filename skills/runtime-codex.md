# Codex runtime mapping

Read this when a `design` or `setup` step uses a Claude-only tool and the
session runs on Codex (a `spawn_agent` tool is available and no `Agent` / `Task`
tool is). Claude Code ignores this file. Every rule in the SKILL.md files still
holds; this file only says which Codex tool carries it out.

## Plugin root

`${CLAUDE_PLUGIN_ROOT}` is not expanded on Codex. It is the directory that holds
`skills/`, one level above this file. Resolve it to an absolute path once and
use that path in every brief and file reference.

## Tool mapping

| Claude | Codex |
|---|---|
| `Agent` dispatch | `spawn_agent` with no `agent_type`, then `wait_agent` (see Agent dispatch) |
| A question a step tells you to ask (Step 1's paste request, Step 6's approval) | `request_user_input` (or `request_user_input_async`), one question per call (see Review checkpoint) |
| Invoking `/milestone-designer:setup` | Read `<plugin root>/skills/setup/SKILL.md` and follow it in the same turn |
| `/<plugin>:<skill>` in any printed notice or handoff line | `$<plugin>:<skill>`, e.g. `$milestone-feeder:plan <brief>` |
| Read / Write tools | Shell reads, `apply_patch` writes. Encoding and JSON-format rules are unchanged |
| DesignSync | None. Skip the push (see DesignSync) |

Ask only where a step says to. A `product` UX gap is parked per Step 3, never
asked through `request_user_input`.

## Agent dispatch

Resolve the configured agent name to its role file:

| Agent name | Role file |
|---|---|
| `milestone-designer:<name>` (the defaults) | `<plugin root>/agents/<name>.md` |
| `<other-plugin>:<name>` | `<plugin root>/../../<other-plugin>/<version>/agents/<name>.md` (Codex plugin cache layout), `<version>` being the highest semver directory compared numerically (`0.10.0` > `0.9.0`) |

A role file that does not exist is a dispatch failure: halt per the `design`
skill's Failure handling.

Call `spawn_agent` with no `agent_type`. The message's first line is, verbatim
with the absolute path filled in:

```
Your role instructions are in <abs role file>. Read that file first and follow it. Ignore its YAML frontmatter.
```

The rest of the message is the brief the `design` step lists, unchanged.

| Step | Codex shape |
|---|---|
| Step 2 ux-architect | One `spawn_agent`, then `wait_agent` on it. Never re-spawned in the run. |
| Step 4 wireframer | `spawn_agent` per screen, at most 4 in flight. `wait_agent` on the in-flight set; each return frees a slot for the next screen. A spawn whose error names a thread or concurrency limit waits for the next return and retries once. A second refusal, or any other spawn or wait error, is a dispatch failure. |

Agents stay read-only on Codex. Their role files say so in the body, and the
brief adds nothing that grants writes.

## Review checkpoint

Step 6 requires a human verdict. On Codex:

1. Open each wireframe under review from the shell: `Start-Process "<abs path>"`
   (Windows PowerShell), `open "<abs path>"` (macOS), `xdg-open "<abs path>"`
   (Linux). Print every absolute path as well, so a sandbox that blocks the
   launch still leaves the human a path to open.
2. If `request_user_input` or `request_user_input_async` is listed this turn, ask one question:
   `Approve the design for <slug>?` with options `Approve` and `Reject`.
   The answer selects Step 6's Approved or Rejected row, carried out in full
   (on Approved: write held changes, the 🔴 needs-input line when gaps were
   parked, then the handoff line).
3. If neither is listed, or the call returns no answer, the verdict is
   not approved. Print
   `🔴 Review pending: open the wireframes above, then reply "approve" or "reject".`,
   print no handoff line, and end the turn. Held re-run changes stay in
   `.milestone-designer/` until the human's reply selects a row.
4. When the human's next message approves or rejects, resume Step 6 at that
   row and carry it out in full, as in item 2.

Never continue past this checkpoint on best judgment, in `codex exec` or any
other non-interactive run.

## DesignSync

Codex has no DesignSync tool. Skip the offer and print one line:

```
DesignSync push skipped: not available on Codex. The local files are the artifact.
```

This is not an adapter failure. `designSyncProjectId` is not read or written,
and the review continues on the local path.
