#!/usr/bin/env bash
#
# check-skill-size.test.sh — standalone fixture-driven tests for the skill-size
# gate (scripts/check-skill-size.sh).
#
# Run it locally from the repo root:  bash tests/check-skill-size.test.sh
# Exit 0 = every case behaved as expected. Exit 1 = at least one case failed.
#
# No test-framework dependency (none is approved — .project/library-manifest.md
# #Approved libraries): plain shell conditionals and exit-code/substring
# assertions only. Every case builds throwaway SKILL.md fixtures in a fresh temp
# git repo (so the gate's `git rev-parse --show-toplevel` scopes to the fixtures,
# never this repo). All repos live under ONE parent temp root created in this
# (parent) shell, which the EXIT trap removes — no fixture files are committed
# and none leak.
#
# Its .ps1 twin (tests/check-skill-size.test.ps1) exercises the SAME logical
# cases against the .ps1 gate and must report identically.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE="$REPO_ROOT/scripts/check-skill-size.sh"

pass=0
fail=0

# One parent temp root, created in THIS shell so the trap can see it (mk_repo
# runs inside command substitution — a subshell — so any variable it set would
# be lost; creating repos as subdirs under this root sidesteps that entirely).
TMP_ROOT="$(mktemp -d)"
cleanup() {
  [ -n "${TMP_ROOT:-}" ] && [ -d "$TMP_ROOT" ] && rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

mk_repo() {
  local d
  d="$(mktemp -d "$TMP_ROOT/repo.XXXXXX")"
  git -C "$d" init -q
  printf '%s' "$d"
}

# gen_words N -> a single space-separated run of N "word" tokens (wc -w == N).
gen_words() {
  awk -v n="$1" 'BEGIN{for(i=0;i<n;i++) printf "word "}'
}

# write_skill REPO NAME DESC BODY -> REPO/skills/NAME/SKILL.md (inline desc).
write_skill() {
  local repo="$1" name="$2" desc="$3" body="$4"
  mkdir -p "$repo/skills/$name"
  {
    echo "---"
    echo "name: $name"
    echo "description: $desc"
    echo "---"
    echo ""
    echo "$body"
  } > "$repo/skills/$name/SKILL.md"
}

# write_skill_block_desc REPO NAME DESCBODY BODY -> a SKILL.md whose description
# is a folded block scalar (`description: >-`) with DESCBODY as its indented body.
write_skill_block_desc() {
  local repo="$1" name="$2" descbody="$3" body="$4"
  mkdir -p "$repo/skills/$name"
  {
    echo "---"
    echo "name: $name"
    echo "description: >-"
    echo "  $descbody"
    echo "---"
    echo ""
    echo "$body"
  } > "$repo/skills/$name/SKILL.md"
}

# run_gate REPO -> sets OUT (merged stdout+stderr) and CODE (exit status).
run_gate() {
  OUT="$(cd "$1" && bash "$GATE" 2>&1)"
  CODE=$?
}

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $desc (exit $actual)"; pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected exit $expected, got $actual)"; fail=$((fail + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) echo "PASS: $desc"; pass=$((pass + 1)) ;;
    *) echo "FAIL: $desc (missing '$needle')"; echo "--- output ---"; echo "$haystack"; fail=$((fail + 1)) ;;
  esac
}

# --- Case 1: under-ceiling pass ---------------------------------------------
repo="$(mk_repo)"
write_skill "$repo" "under" "a short description under the ceiling" "$(gen_words 20)"
run_gate "$repo"
assert_exit "under-ceiling -> exit 0" 0 "$CODE"

# --- Case 2: empty-glob pass (no skills/ dir) -------------------------------
repo="$(mk_repo)"
run_gate "$repo"
assert_exit "empty-glob (no SKILL.md) -> exit 0" 0 "$CODE"
assert_contains "empty-glob prints the no-files notice" "$OUT" "no skills/**/SKILL.md files found"

# --- Case 3: whole-file over ceiling fail -----------------------------------
repo="$(mk_repo)"
write_skill "$repo" "big-file" "small description" "$(gen_words 2600)"
run_gate "$repo"
assert_exit "whole-file over ceiling -> exit 1" 1 "$CODE"
assert_contains "names the offending file" "$OUT" "skills/big-file/SKILL.md"
assert_contains "names the whole-file ceiling" "$OUT" "whole-file word count"

# --- Case 4: description over ceiling fail (inline) --------------------------
repo="$(mk_repo)"
write_skill "$repo" "big-desc" "$(gen_words 210)" "$(gen_words 20)"
run_gate "$repo"
assert_exit "inline description over ceiling -> exit 1" 1 "$CODE"
assert_contains "names the offending file" "$OUT" "skills/big-desc/SKILL.md"
assert_contains "names the description ceiling" "$OUT" "description: word count"

# --- Case 5: multi-violation, all reported in one run -----------------------
repo="$(mk_repo)"
write_skill "$repo" "a-big-file" "small description" "$(gen_words 2600)"
write_skill "$repo" "b-big-desc" "$(gen_words 210)" "$(gen_words 20)"
run_gate "$repo"
assert_exit "multi-violation -> exit 1" 1 "$CODE"
assert_contains "reports the file-ceiling violation" "$OUT" "skills/a-big-file/SKILL.md"
assert_contains "reports the description-ceiling violation" "$OUT" "skills/b-big-desc/SKILL.md"

# --- Case 6: block-scalar description over ceiling (guards C2/D1) ------------
repo="$(mk_repo)"
write_skill_block_desc "$repo" "block-desc" "$(gen_words 250)" "small body"
run_gate "$repo"
assert_exit "block-scalar description over ceiling -> exit 1" 1 "$CODE"
assert_contains "names the offending file" "$OUT" "skills/block-desc/SKILL.md"
assert_contains "names the description ceiling" "$OUT" "description: word count"

# --- Case 7: nested skill over ceiling (proves recursive skills/**/ scope) ---
# A SKILL.md two levels deep (skills/group/name/SKILL.md) must be found and
# failed — the one-level skills/*/SKILL.md glob would miss it entirely.
repo="$(mk_repo)"
write_skill "$repo" "group/nested-big" "small description" "$(gen_words 2600)"
run_gate "$repo"
assert_exit "nested skill over ceiling -> exit 1" 1 "$CODE"
assert_contains "names the nested offending file" "$OUT" "skills/group/nested-big/SKILL.md"
assert_contains "names the whole-file ceiling" "$OUT" "whole-file word count"

# --- summary -----------------------------------------------------------------
echo ""
echo "check-skill-size.test.sh: $pass passed, $fail failed."
[ "$fail" -eq 0 ] || exit 1
exit 0
