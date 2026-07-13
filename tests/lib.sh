#!/usr/bin/env bash
#
# lib.sh — shared machinery for this repo's bash test harnesses
# (tests/check-skill-size.test.sh and tests/validate-plugin-structure.test.sh).
# SOURCED, never executed: `. "$SCRIPT_DIR/lib.sh"`.
#
# Carries the assert helpers, the temp-root + cleanup-trap scaffold, a loud
# dependency guard, and the summary/exit footer — the footer enforces a
# ZERO-ASSERTION FLOOR (issue #14 review): a harness that ran no assertions is
# never green, it fails loudly. Extracting this here means that floor (and the
# assert-on-failure output dump) lives in ONE place instead of drifting between
# the two hand-copied harnesses.
#
# Contract for a sourcing harness:
#   - runs under `set -uo pipefail`;
#   - calls lib_make_tmproot once at top level (installs the EXIT cleanup trap);
#   - sets OUT before each assert_exit (dumped on failure);
#   - ends with `lib_finish "<harness-name>"`.

# Assertion counters — reset at source time.
pass=0
fail=0

# lib_make_tmproot -> create one temp root in TMP_ROOT and install an EXIT trap
# to remove it. Call once from the harness's top-level shell so the trap sees it.
lib_make_tmproot() {
  TMP_ROOT="$(mktemp -d)"
  trap 'lib_cleanup' EXIT
}

lib_cleanup() {
  [ -n "${TMP_ROOT:-}" ] && [ -d "${TMP_ROOT:-}" ] && rm -rf "$TMP_ROOT"
}

# lib_require_cmd CMD HINT -> loud FAIL + exit 1 if CMD is not on PATH. Mirrors
# the python3 interpreter guard so a missing dependency fails loudly up front
# rather than yielding a vacuous zero-case pass.
lib_require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "FAIL: required command '$1' not found on PATH — $2"
    exit 1
  fi
}

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $desc (exit $actual)"; pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected exit $expected, got $actual)"
    echo "--- output ---"; echo "${OUT:-}"; fail=$((fail + 1))
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) echo "PASS: $desc"; pass=$((pass + 1)) ;;
    *) echo "FAIL: $desc (missing '$needle')"; echo "--- output ---"; echo "$haystack"; fail=$((fail + 1)) ;;
  esac
}

# lib_finish NAME -> print the summary, enforce the zero-assertion floor, exit.
# pass+fail == 0 means the harness asserted nothing (a broken table/dependency
# slipped past the up-front guards) — that is a LOUD failure, never a green run.
lib_finish() {
  local name="$1"
  echo ""
  if [ "$((pass + fail))" -eq 0 ]; then
    echo "$name: FAIL — zero assertions ran (harness asserted nothing; check its inputs)."
    exit 1
  fi
  echo "$name: $pass passed, $fail failed."
  [ "$fail" -eq 0 ] || exit 1
  exit 0
}
