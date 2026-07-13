#!/usr/bin/env bash
#
# validate-plugin-structure.test.sh — standalone fixture-driven characterization
# tests for the plugin-structure gate (scripts/validate-plugin-structure.py).
#
# Run it locally from the repo root:  bash tests/validate-plugin-structure.test.sh
# Exit 0 = every case behaved as expected. Exit 1 = at least one case failed.
#
# WHY (issue #14, AC3): the validator is a single cross-platform Python script
# with a hand-rolled (deliberately non-strict-YAML) frontmatter parser and a
# strict-scalar check. A parser regression there would only surface at CI
# preflight — too late. This black-box harness pins the parser's edge behaviour
# (block scalars incl. `>2`-style headers, nested mappings, comment lines,
# trailing bare colon, colon+space, fence errors, missing keys, invalid JSON, the
# zero-skills case) so a regression fails locally first. It is a CHARACTERIZATION
# harness: every case asserts what today's validator DOES — it is not a spec to
# change validator behaviour against.
#
# BASH-ONLY, by recorded pick: unlike the skill-size gate (a bash + PowerShell
# twin pair), this harness ships as a SINGLE bash black-box harness with no .ps1
# twin. That was the operator's recorded decision on issue #14 — the subject under
# test is one cross-platform Python script (scripts/validate-plugin-structure.py),
# so a second PowerShell harness would only re-run the identical Python process
# with zero added coverage. The deviation from the suite's twin convention is
# therefore sanctioned, not drift.
#
# Style mirrors tests/check-skill-size.test.sh and shares tests/lib.sh: no test
# framework (none is approved — .project/library-manifest.md#Approved libraries);
# the assert helpers, temp-root/cleanup scaffold, and zero-assertion-floor footer
# come from the lib. Each case is a throwaway fixture plugin under one temp root
# that the EXIT trap removes.
#
# Black-box mechanism: the validator resolves its REPO_ROOT from its OWN file
# location (Path(__file__).resolve().parent.parent), NOT the cwd — so it is
# copied INTO each fixture's scripts/ dir and run there, making it validate the
# fixture rather than this repo.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-plugin-structure.py"

# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/lib.sh"

# CI and preflight invoke the validator as `python3`; prefer it, fall back to
# `python` for dev boxes where only that name exists. Loud up-front guard mirrors
# the size harness's jq guard — a missing interpreter fails LOUDLY, never as a
# vacuous zero-case pass (the lib footer's zero-assertion floor is the backstop).
PYTHON="$(command -v python3 || command -v python || true)"
if [ -z "$PYTHON" ]; then
  echo "FAIL: no python3/python interpreter found on PATH."
  exit 1
fi

lib_make_tmproot

# mk_fixture -> a fresh fixture plugin root with the validator copied in and VALID
# baseline manifests (plugin.json carries version+description so no WARN noise).
# Cases add skills/agents or overwrite a manifest as needed.
mk_fixture() {
  local d
  d="$(mktemp -d "$TMP_ROOT/fix.XXXXXX")"
  mkdir -p "$d/scripts" "$d/.claude-plugin"
  cp "$VALIDATOR" "$d/scripts/validate-plugin-structure.py"
  cat > "$d/.claude-plugin/plugin.json" <<'JSON'
{ "name": "fixture-plugin", "version": "0.0.1", "description": "fixture plugin" }
JSON
  cat > "$d/.claude-plugin/marketplace.json" <<'JSON'
{ "name": "fixture-market", "plugins": [ { "name": "fixture-plugin", "source": "./" } ] }
JSON
  printf '%s' "$d"
}

# write_file PATH  (content on stdin) -> writes stdin verbatim to PATH, mkdir -p'ing.
write_file() {
  local p="$1"
  mkdir -p "$(dirname "$p")"
  cat > "$p"
}

# run_validator FIXTURE -> sets OUT (merged stdout+stderr) and CODE (exit status).
run_validator() {
  OUT="$("$PYTHON" "$1/scripts/validate-plugin-structure.py" 2>&1)"
  CODE=$?
}

# --- Case 1: valid baseline (exit 0) ----------------------------------------
fix="$(mk_fixture)"
write_file "$fix/skills/valid/SKILL.md" <<'EOF'
---
name: valid
description: >-
  A perfectly valid skill description folded across a block scalar so the
  strict loader accepts it.
---
Body text.
EOF
run_validator "$fix"
assert_exit "valid baseline -> exit 0" 0 "$CODE"
assert_contains "valid baseline reports PASS" "$OUT" "PASS: plugin structure valid"

# --- Case 2: block scalar with a >2-style header, colon in body is exempt ----
fix="$(mk_fixture)"
write_file "$fix/skills/block-indent/SKILL.md" <<'EOF'
---
name: block-indent
description: >2
    A folded description whose body contains a colon: value pair that a strict
    loader would reject at the top level but which is exempt inside a block
    scalar body.
---
Body text.
EOF
run_validator "$fix"
assert_exit "block-scalar >2 header + colon body -> exit 0" 0 "$CODE"
assert_contains "block-scalar >2 case reports PASS" "$OUT" "PASS: plugin structure valid"

# --- Case 3: nested mapping under an empty-valued key, colon exempt ----------
fix="$(mk_fixture)"
write_file "$fix/skills/nested/SKILL.md" <<'EOF'
---
name: nested
description: A short valid inline description.
metadata:
  type: user
  scope: universal
---
Body text.
EOF
run_validator "$fix"
assert_exit "nested mapping (colon exempt) -> exit 0" 0 "$CODE"
assert_contains "nested mapping case reports PASS" "$OUT" "PASS: plugin structure valid"

# --- Case 4: comment lines in frontmatter (incl. a colon) are ignored --------
fix="$(mk_fixture)"
write_file "$fix/skills/commented/SKILL.md" <<'EOF'
---
name: commented
# this is a comment: with a colon-space that a strict loader must ignore
description: A valid description.
---
Body text.
EOF
run_validator "$fix"
assert_exit "comment line with colon -> exit 0" 0 "$CODE"
assert_contains "comment-line case reports PASS" "$OUT" "PASS: plugin structure valid"

# --- Case 5: a trailing bare colon on a plain scalar value (exit 1) ----------
fix="$(mk_fixture)"
write_file "$fix/skills/trailing-colon/SKILL.md" <<'EOF'
---
name: trailing-colon
description: A valid description.
tagline: draft ready to ship:
---
Body text.
EOF
run_validator "$fix"
assert_exit "trailing bare colon -> exit 1" 1 "$CODE"
assert_contains "trailing-colon names the defect" "$OUT" "ends in a bare colon"

# --- Case 6: a colon+space in an unquoted inline scalar (exit 1) -------------
fix="$(mk_fixture)"
write_file "$fix/skills/colon-space/SKILL.md" <<'EOF'
---
name: colon-space
description: Loads workflow: the second half looks like a mapping to js-yaml.
---
Body text.
EOF
run_validator "$fix"
assert_exit "colon+space in inline scalar -> exit 1" 1 "$CODE"
assert_contains "colon+space names the defect" "$OUT" "contains a colon+space"

# --- Case 7: a folded plain-scalar continuation carrying a colon+space --------
fix="$(mk_fixture)"
write_file "$fix/skills/folded-cont/SKILL.md" <<'EOF'
---
name: folded-cont
description: A valid description.
summary: starts here
  and continues: with a colon-space on the folded continuation line
---
Body text.
EOF
run_validator "$fix"
assert_exit "folded plain-scalar continuation -> exit 1" 1 "$CODE"
assert_contains "continuation names the defect" "$OUT" "plain-scalar continuation"

# --- Case 8: unclosed frontmatter fence (exit 1) -----------------------------
fix="$(mk_fixture)"
write_file "$fix/skills/unclosed/SKILL.md" <<'EOF'
---
name: unclosed
description: A description whose frontmatter block never closes.
Body text with no closing fence.
EOF
run_validator "$fix"
assert_exit "unclosed fence -> exit 1" 1 "$CODE"
assert_contains "unclosed fence names the defect" "$OUT" "is never closed"

# --- Case 9: missing opening fence on line 1 (exit 1) ------------------------
fix="$(mk_fixture)"
write_file "$fix/skills/no-open/SKILL.md" <<'EOF'
name: no-open
description: The first line is not a fence.
---
Body text.
EOF
run_validator "$fix"
assert_exit "missing opening fence -> exit 1" 1 "$CODE"
assert_contains "missing opening fence names the defect" "$OUT" "missing opening '---' frontmatter fence on line 1"

# --- Case 10: missing required key (exit 1) ---------------------------------
fix="$(mk_fixture)"
write_file "$fix/skills/no-desc/SKILL.md" <<'EOF'
---
name: no-desc
foo: bar
---
Body text.
EOF
run_validator "$fix"
assert_exit "missing required 'description' -> exit 1" 1 "$CODE"
assert_contains "missing-key names the defect" "$OUT" "missing required key 'description'"

# --- Case 11: invalid JSON manifest (exit 1) --------------------------------
fix="$(mk_fixture)"
write_file "$fix/.claude-plugin/plugin.json" <<'EOF'
{ "name": "fixture-plugin", }
EOF
run_validator "$fix"
assert_exit "invalid JSON manifest -> exit 1" 1 "$CODE"
assert_contains "invalid JSON names the defect" "$OUT" "is not valid JSON"

# --- Case 12: zero-skills repo (exit 0, only manifests checked) --------------
# AC2: a fixture with valid manifests and NO skills/ dir stays green and counts
# only the two manifests — the validator's rglob over a non-existent skills/ dir
# yields nothing (no error).
fix="$(mk_fixture)"
run_validator "$fix"
assert_exit "zero-skills repo -> exit 0" 0 "$CODE"
assert_contains "zero-skills checks only the 2 manifests" "$OUT" "2 file(s) checked"

# --- summary -----------------------------------------------------------------
lib_finish "validate-plugin-structure.test.sh"
