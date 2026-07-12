#!/usr/bin/env python3
"""validate-plugin-structure.py — the plugin-structure validation gate.

What this checks, in plain terms:
  A Claude Code plugin only loads if its manifests are valid JSON and its skills
  and agents each start with a well-formed frontmatter block carrying the keys
  Claude Code reads. This script confirms that, plus a couple of house-policy
  rules this repo's CI holds every governed file to, so a pull request that
  breaks a manifest or a frontmatter block fails before merge.

It checks:
  1. .claude-plugin/plugin.json      — parses as JSON, has required key `name`.
  2. .claude-plugin/marketplace.json — parses as JSON, has required keys
                                       `name` and `plugins` (a non-empty list).
  3. Every skills/**/SKILL.md and agents/**/*.md  — opens with a `---`-fenced
     frontmatter block carrying non-empty `name` and `description`. Every
     commands/**/*.md is required to carry a non-empty `description` — command
     frontmatter is OPTIONAL to Claude Code (a command file loads without any
     frontmatter, and its name comes from its filename), so `description` here
     is a house-policy requirement of this gate per issue #5's AC, not a
     Claude-Code load requirement. Governed frontmatter (skills/**/SKILL.md,
     agents/**/*.md, commands/**/*.md) is additionally strict-scalar checked: no
     unquoted plain scalar may carry a colon+space, or a bare trailing colon,
     that Claude Desktop's strict YAML loader would reject (see the strict-scalar
     note below).
  4. Size budgets — every governed skills/**/SKILL.md stays at or under its own
     per-file word-count ceiling (SKILL_WORD_CEILINGS below), and every
     agents/**/*.md frontmatter `description` stays at or under a flat 150-word
     ceiling. A written size standard with no gate is how a governed file
     silently regrows past its target.

Two readers, two rules (read before "upgrading" this):
  Claude Code's frontmatter reader is tolerant — it takes everything after the
  first colon on a `key:` line as that key's value — so the parser below
  deliberately mirrors it for key extraction: split each top-level `key:` on its
  first colon, keep the rest as the value. It understands the flat `key: value`
  shape and YAML block scalars (`key: |` / `key: >-`, including an explicit
  indentation digit and/or chomping indicator, e.g. `>2`, `|2-`, `>-2`), but it
  is NOT a full YAML engine. Files are read as utf-8-sig so a leading BOM (e.g.
  from a Windows editor) is stripped rather than wrongly failing the line-1
  fence check.

  Claude Desktop's loader, by contrast, is STRICT (js-yaml): an unquoted plain
  scalar whose value contains a colon+space (": "), or ends in a bare colon,
  is read as a mapping, so the skill silently fails to register. That strict
  loader is ground truth for whether a skill loads in Desktop — so the
  strict-scalar check below FAILS any governed frontmatter carrying that
  construct. It is not a false-fail risk: a governed file's long description is
  a folded block scalar (`description: >-`), which the strict loader accepts;
  block-scalar bodies, quoted values, comment lines, and nested-mapping content
  under an empty-valued key are all exempt by construction. The check stays
  stdlib-only by design — it detects the rejected constructs without parsing
  YAML, so CI needs no PyYAML and no dependency-install step.

Dependencies: Python standard library only.

Run it locally from the repo root:  python3 scripts/validate-plugin-structure.py
Exit 0 = valid. Exit 1 = at least one structural problem (each printed).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Size-budget ceilings (the ratchet discipline is documented in the size-budget
# section below). Defined up here so the agent-description ceiling is enforced
# in the SAME section-3 agent walk (one rglob, one parse per agent file) rather
# than a second walk that double-reported fence errors and over-counted.
SKILL_WORD_CEILINGS: dict[str, int] = {}
AGENT_DESCRIPTION_WORD_CEILING = 150

errors: list[str] = []
warnings: list[str] = []
checked = 0


def err(path: Path, msg: str) -> None:
    errors.append(f"{path.relative_to(REPO_ROOT)}: {msg}")


def warn(path: Path, msg: str) -> None:
    warnings.append(f"{path.relative_to(REPO_ROOT)}: {msg}")


def load_json(path: Path) -> dict | None:
    """Parse a JSON file; record an error and return None on any failure."""
    if not path.is_file():
        err(path, "required manifest is missing")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        err(path, f"is not valid JSON ({exc})")
        return None
    if not isinstance(data, dict):
        err(path, "must be a JSON object at the top level")
        return None
    return data


def _is_block_scalar_header(value: str) -> bool:
    """True if `value` is a YAML block-scalar header.

    A block-scalar header is '|' or '>' optionally followed by an indentation
    digit (1-9) and/or a chomping indicator (+/-), in EITHER order and at most
    one of each: e.g. |, >, |-, >-, |+, >+, >2, |2-, >-2, |+3. Any trailing
    content beyond that (an inline value or a comment) means the line is a plain
    `key: value`, not a bare block header. Recognised identically by the parser
    and the strict-scalar check so the two can never drift.
    """
    if not value or value[0] not in "|>":
        return False
    rest = value[1:]
    if len(rest) > 2:
        return False
    seen_digit = seen_chomp = False
    for ch in rest:
        if ch in "123456789":
            if seen_digit:
                return False
            seen_digit = True
        elif ch in "+-":
            if seen_chomp:
                return False
            seen_chomp = True
        else:
            return False
    return True


def parse_frontmatter(path: Path) -> dict | None:
    """Extract the leading `---` frontmatter block as a key->value dict.

    Lenient, dependency-free parser that mirrors Claude Code's tolerant reader
    (see the module docstring for why this is NOT strict YAML). Handles flat
    `key: value` lines and `key: |` / `key: >-`-style block scalars (any header
    per _is_block_scalar_header). The file MUST open with `---` on line 1 and the
    block MUST close with a later `---`. Returns the parsed keys, or None if the
    fence is missing/unterminated (an error is recorded in that case).
    """
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()

    if not lines or lines[0].strip() != "---":
        err(path, "missing opening '---' frontmatter fence on line 1")
        return None

    # Find the closing fence.
    close_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            close_idx = i
            break
    if close_idx is None:
        err(path, "frontmatter opened with '---' but is never closed")
        return None

    body = lines[1:close_idx]
    data: dict[str, str] = {}
    current_key: str | None = None
    collecting_block = False  # inside a `key: |`/`key: >-` block scalar

    for raw in body:
        stripped = raw.strip()
        is_indented = raw[:1] in (" ", "\t")

        if collecting_block:
            if is_indented or stripped == "":
                # Continuation of the block scalar's body.
                data[current_key] = (data[current_key] + "\n" + stripped).strip()
                continue
            # An unindented line ends the block; fall through and parse it with
            # the SAME key logic as the main path (no drifted copy) — including
            # the block-scalar-header check, so back-to-back block scalars like
            # `tools: >-` then `description: >-` are both recognised.
            collecting_block = False

        if not is_indented and ":" in raw:
            key, _, value = raw.partition(":")
            key = key.strip()
            value = value.strip()
            if _is_block_scalar_header(value):
                # Block scalar — value continues on indented lines below.
                current_key = key
                data[key] = ""
                collecting_block = True
            else:
                # Inline value (may be quoted; strip matching quotes).
                if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                    value = value[1:-1]
                data[key] = value
                current_key = key

    return data


def require_keys(path: Path, data: dict, keys: list[str]) -> None:
    for key in keys:
        if key not in data:
            err(path, f"frontmatter is missing required key '{key}'")
        elif not str(data[key]).strip():
            err(path, f"frontmatter key '{key}' is empty")


_STRICT_MSG = (
    "Claude Desktop's strict YAML loader (js-yaml) parses this as a mapping and "
    "the skill silently fails to register; make the value a folded block scalar "
    "('key: >-' with the text indented below) or quote it"
)


def _report_strict_scalar(
    path: Path, line_no: int, text: str, display: str, kind: str
) -> None:
    """Record a strict-loader defect if `text` carries the rejected construct.

    `text` keeps its trailing whitespace so a value ending in ": " or in a bare
    ":" is not masked. Two defect classes: a colon+space (": ") anywhere, or a
    bare trailing colon at end-of-line — js-yaml reads both as a mapping. `kind`
    is "value" (a top-level plain value) or "continuation" (a folded plain-scalar
    line), which only shapes the message.
    """
    if ": " in text:
        defect = "contains a colon+space (': ')"
    elif text.rstrip().endswith(":"):
        defect = "ends in a bare colon (':')"
    else:
        return
    if kind == "continuation":
        err(
            path,
            f"frontmatter line {line_no} plain-scalar continuation '{display}' {defect} — {_STRICT_MSG}",
        )
    else:
        err(
            path,
            f"frontmatter line {line_no} value '{display}' is an unquoted plain scalar that {defect} — {_STRICT_MSG}",
        )


def check_strict_scalars(path: Path) -> None:
    """Fail any governed-frontmatter plain scalar a STRICT YAML loader rejects.

    Claude Desktop's frontmatter loader is strict (js-yaml): an unquoted plain
    scalar whose value contains a colon+space (": "), or ends in a bare colon, is
    parsed as a mapping and the skill silently fails to register. This check
    catches exactly those defect classes — stdlib-only, no YAML parse — across the
    governed frontmatter (skills/**/SKILL.md, agents/**/*.md, commands/**/*.md).

    What is exempt, and why (each matches how js-yaml actually reads the file):
      - Block-scalar bodies. A `key: >-` (any header per _is_block_scalar_header)
        opens a block scalar; its indented body and any blank line within it are
        literal text, never re-parsed for ": ".
      - Quoted values. A quoted scalar escapes the colon.
      - Comment lines. js-yaml strips a line whose first non-space char is '#'
        (top-level or indented) before parsing, so a ": " inside one is not a
        defect.
      - Nested-mapping content. An indented `sub: value` line under a top-level
        key that had an EMPTY value (e.g. `metadata:`) is a nested mapping, valid
        YAML — NOT a folded plain scalar. Only an indented line under a top-level
        key that held a NON-empty inline plain value is a folded continuation,
        which js-yaml folds and rejects a ": " (or trailing ":") on just as it
        would on the header line.

    Errors are recorded via err(); nothing is returned. Fence problems are not
    re-reported here (parse_frontmatter/require_keys already flag them).
    """
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    if not lines or lines[0].strip() != "---":
        return
    close_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            close_idx = i
            break
    if close_idx is None:
        return

    collecting_block = False  # inside a block scalar (its body is exempt)
    prev_plain_value = (
        False  # the last top-level key held a non-empty inline plain value
    )
    for i in range(1, close_idx):
        raw = lines[i]
        stripped = raw.strip()
        is_indented = raw[:1] in (" ", "\t")

        # Comments are stripped by js-yaml before parsing — never a defect.
        if stripped.startswith("#"):
            continue

        if collecting_block:
            if is_indented or stripped == "":
                continue  # block-scalar body — exempt.
            collecting_block = False  # dedent ends the block; process this line.

        if is_indented:
            if stripped == "":
                continue
            # A folded plain-scalar CONTINUATION is a defect; nested-mapping
            # content under an empty-valued top-level key is not.
            if prev_plain_value:
                _report_strict_scalar(path, i + 1, raw, stripped, "continuation")
            continue

        # Top-level line.
        if stripped == "" or ":" not in raw:
            prev_plain_value = False
            continue

        # lstrip only: drop the leading space after the key's own colon, but keep
        # TRAILING whitespace so a value ending in ": " / ":" is still caught.
        value = raw.partition(":")[2].lstrip()
        vstripped = value.strip()
        if _is_block_scalar_header(vstripped):
            collecting_block = True
            prev_plain_value = False
            continue
        if not vstripped or vstripped[0] in ("'", '"'):
            # Empty value (a nested mapping/block follows) or a quoted scalar.
            prev_plain_value = False
            continue
        # A non-empty unquoted plain scalar value.
        prev_plain_value = True
        _report_strict_scalar(path, i + 1, value, vstripped, "value")


# --- 1 & 2: manifests -------------------------------------------------------

plugin_json = REPO_ROOT / ".claude-plugin" / "plugin.json"
marketplace_json = REPO_ROOT / ".claude-plugin" / "marketplace.json"

pj = load_json(plugin_json)
if pj is not None:
    checked += 1
    if not str(pj.get("name", "")).strip():
        err(plugin_json, "missing required key 'name'")
    for rec in ("version", "description"):
        if rec not in pj:
            warn(plugin_json, f"recommended key '{rec}' is absent")

mj = load_json(marketplace_json)
if mj is not None:
    checked += 1
    if not str(mj.get("name", "")).strip():
        err(marketplace_json, "missing required key 'name'")
    plugins = mj.get("plugins")
    if not isinstance(plugins, list) or len(plugins) == 0:
        err(marketplace_json, "required key 'plugins' must be a non-empty list")

# --- 3: skill / agent / command frontmatter (single walk each) --------------

# Skills: every skills/**/SKILL.md — require name + description.
for skill_md in sorted((REPO_ROOT / "skills").rglob("SKILL.md")):
    checked += 1
    fm = parse_frontmatter(skill_md)
    if fm is not None:
        require_keys(skill_md, fm, ["name", "description"])
        check_strict_scalars(skill_md)

# Agents: every agents/**/*.md (recursive) — require name + description, and
# enforce the description size budget in this SAME walk (one parse per file).
agents_dir = REPO_ROOT / "agents"
if agents_dir.is_dir():
    for agent_md in sorted(agents_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(agent_md)
        if fm is not None:
            require_keys(agent_md, fm, ["name", "description"])
            check_strict_scalars(agent_md)
            description = str(fm.get("description", "")).strip()
            if description:
                word_count = len(description.split())
                if word_count > AGENT_DESCRIPTION_WORD_CEILING:
                    err(
                        agent_md,
                        f"frontmatter 'description' is {word_count} words, "
                        f"over the flat {AGENT_DESCRIPTION_WORD_CEILING}-word "
                        f"ceiling every agent description is held to — trim it",
                    )

# Commands: every commands/**/*.md (recursive) — require description only
# (a command's name is derived from its filename). None exist today.
commands_dir = REPO_ROOT / "commands"
if commands_dir.is_dir():
    for cmd_md in sorted(commands_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(cmd_md)
        if fm is not None:
            require_keys(cmd_md, fm, ["description"])
            # Desktop's strict loader reads command frontmatter identically to
            # skills'/agents', so the strict-scalar rule governs it too.
            check_strict_scalars(cmd_md)

# --- 4: size budgets ---------------------------------------------------------
#
# Why this exists: a written size STANDARD with no enforcing GATE is exactly
# what lets a governed SKILL.md regrow past its own stated target — this check
# is the gate that protects the standard. (The agents/**/*.md description
# ceiling is enforced in the section-3 agent walk above, reusing that walk's
# single parse per file; only the SKILL.md ceilings are enforced here.)
#
# Ceiling discipline (documented, not machine-enforced):
#   - SKILL_WORD_CEILINGS values ONLY GO DOWN, NEVER UP. When a skill is added,
#     seed its ceiling at the file's actual word count plus ~5% headroom, rounded
#     to a clean number. Raising one requires a recorded decision on the issue
#     that grows the file.
#   - A skills/**/SKILL.md not named in SKILL_WORD_CEILINGS is not yet governed
#     by this check — it is silently unchecked until a ceiling is added for it (a
#     deliberate scope choice: an ungoverned file has no ceiling to violate).
#   - A path NAMED in SKILL_WORD_CEILINGS but absent from disk (renamed or deleted
#     without updating this table) IS a failure, never a silent pass. This is why
#     the loop below iterates SKILL_WORD_CEILINGS itself, not a glob.
#
# This repo ships no skills yet, so SKILL_WORD_CEILINGS (defined at the top of
# this file) is empty; a skill added in a later issue lands its ceiling there in
# the same change.
#
# Measurement: whole-file word count (`len(text.split())`, identical to `wc -w`)
# for every governed SKILL.md.

for rel_path, ceiling in sorted(SKILL_WORD_CEILINGS.items()):
    skill_md = REPO_ROOT / rel_path
    checked += 1
    if not skill_md.is_file():
        err(
            skill_md,
            f"is listed in SKILL_WORD_CEILINGS ({ceiling}-word ceiling) "
            f"but is missing from disk — a renamed or deleted governed "
            f"file must update this table in the same change, not "
            f"silently drop out of the size-budget gate",
        )
        continue
    word_count = len(skill_md.read_text(encoding="utf-8-sig").split())
    if word_count > ceiling:
        err(
            skill_md,
            f"is {word_count} words, over its {ceiling}-word "
            f"size-budget ceiling (SKILL_WORD_CEILINGS in this script) "
            f"— trim it, or if the growth is deliberate, record a "
            f"decision on the issue that grows it and raise the "
            f"ceiling in the same change",
        )

# --- report -----------------------------------------------------------------

for w in warnings:
    print(f"WARN: {w}", file=sys.stderr)

if errors:
    print(
        f"FAIL: plugin structure invalid ({len(errors)} problem(s)):", file=sys.stderr
    )
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

print(
    f"PASS: plugin structure valid ({checked} file(s) checked, "
    f"{len(warnings)} warning(s))."
)
sys.exit(0)
