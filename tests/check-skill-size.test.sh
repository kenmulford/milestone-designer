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
# assertions from tests/lib.sh only. Every case builds throwaway SKILL.md
# fixtures in a fresh temp git repo (so the gate's `git rev-parse
# --show-toplevel` scopes to the fixtures, never this repo). All repos live under
# ONE parent temp root (lib_make_tmproot) that the EXIT trap removes — no fixture
# files are committed and none leak.
#
# The fixture CASES are DATA, not code: they live in the shared table
# tests/check-skill-size.cases.json and are consumed here via jq (a sanctioned
# dependency — .milestone-config/driver.json#nonNegotiables "bash (jq)"). Its
# .ps1 twin (tests/check-skill-size.test.ps1) drives the SAME table against the
# .ps1 gate, so the two twins can never hand-sync-drift (issue #14 AC4b): they
# share the case DATA and each keeps its own runner. Every skill's filler is a
# word COUNT — the gate only counts words, so a count is a behaviourally exact
# fixture and the assertions never inspect filler text.
#
# The whole table is read in ONE jq pass (issue #14 review) — a tab-delimited
# record stream (CASE / SKILL / CONTAIN / END) consumed by a bash-3.2-safe
# `while read` loop — rather than dozens of per-field jq spawns. jq's presence
# and a positive case count are guarded up front; the lib's summary footer
# enforces a zero-assertion floor, so a missing/renamed table fails LOUDLY
# instead of yielding a vacuous zero-case "pass".

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GATE="$REPO_ROOT/scripts/check-skill-size.sh"
TABLE="$SCRIPT_DIR/check-skill-size.cases.json"

# shellcheck source=tests/lib.sh
. "$SCRIPT_DIR/lib.sh"

# --- up-front dependency + table guards (fail LOUDLY, never vacuously) --------
lib_require_cmd jq "install jq (a repo nonNegotiable dependency) to run this harness"
if [ ! -f "$TABLE" ]; then
  echo "FAIL: shared case table not found: $TABLE"
  exit 1
fi
ncases="$(jq '.cases | length' "$TABLE" 2>/dev/null | tr -d '\r')"
case "$ncases" in
  '' | *[!0-9]*)
    echo "FAIL: case table $TABLE did not yield a numeric .cases length (got '${ncases}')"
    exit 1
    ;;
esac
if [ "$ncases" -eq 0 ]; then
  echo "FAIL: case table $TABLE has zero cases"
  exit 1
fi

lib_make_tmproot

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

# --- data-driven case runner (shared table: check-skill-size.cases.json) ------
# ONE jq pass emits a tab-delimited record stream; the loop below writes each
# case's skill fixtures, runs the gate once at END, then asserts the exit code
# and every buffered output substring. `tr -d '\r'` neutralises msys jq's
# text-mode CRLF so the last field is clean on Windows (no-op on Linux CI).
# bash-3.2-safe: `while read`, indexed arrays, arithmetic — no mapfile/readarray.
cur_desc=""
cur_exit=""
repo=""
n_contain=0
contain_desc=()
contain_needle=()

while IFS=$'\t' read -r tag a b c d; do
  case "$tag" in
    CASE)
      cur_desc="$a"; cur_exit="$b"
      repo="$(mk_repo)"
      n_contain=0
      contain_desc=()
      contain_needle=()
      ;;
    SKILL)
      # a=kind b=name c=descWords d=bodyWords
      if [ "$a" = "block" ]; then
        write_skill_block_desc "$repo" "$b" "$(gen_words "$c")" "$(gen_words "$d")"
      else
        write_skill "$repo" "$b" "$(gen_words "$c")" "$(gen_words "$d")"
      fi
      ;;
    CONTAIN)
      # a=assertion-desc b=needle
      contain_desc[$n_contain]="$a"
      contain_needle[$n_contain]="$b"
      n_contain=$((n_contain + 1))
      ;;
    END)
      run_gate "$repo"
      assert_exit "$cur_desc" "$cur_exit" "$CODE"
      k=0
      while [ "$k" -lt "$n_contain" ]; do
        assert_contains "${contain_desc[$k]}" "$OUT" "${contain_needle[$k]}"
        k=$((k + 1))
      done
      ;;
  esac
done < <(
  jq -r '
    .cases[] |
      ("CASE\t" + .desc + "\t" + (.expectExit | tostring)),
      (.skills[] | "SKILL\t" + .kind + "\t" + .name + "\t" + (.descWords | tostring) + "\t" + (.bodyWords | tostring)),
      (.expectContains[] | "CONTAIN\t" + .desc + "\t" + .needle),
      "END"
  ' "$TABLE" | tr -d '\r'
)

lib_finish "check-skill-size.test.sh"
