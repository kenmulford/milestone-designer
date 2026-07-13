#!/usr/bin/env bash
#
# check-skill-size.sh — the CI skill-size gate for SKILL.md word ceilings.
#
# What this checks, in plain terms:
#   Every skills/**/SKILL.md in this repo (recursively, at any nesting depth)
#   has a written word-budget: the whole file must stay at or under 2,500 words
#   (wc -w), and its frontmatter description: field must stay at or under ~200
#   words. A written size standard with no enforcing gate is exactly how a
#   SKILL.md silently regrows past its target — this script is the enforcement
#   that closes that gap. This gate is the single owner of skill-size governance
#   (issue #13): the validator's SKILL_WORD_CEILINGS ratchet was retired in
#   favour of this flat ceiling, so every SKILL.md at any depth is covered here.
#
# Ceilings enforced, verbatim, no rounding:
#   - whole-file word count (wc -w)               <= 2500
#   - frontmatter description: field word count   <= ~200
#
# Cross-platform twin: scripts/check-skill-size.ps1 is the PowerShell 7+ twin
# of this script (identical ceilings, behaviour, exit codes, and messages), per
# the suite's bash-first-with-PowerShell-7+-fallback convention
# (.project/library-manifest.md#Runtime & frameworks). CI (ubuntu-latest) runs
# THIS .sh twin (.github/workflows/ci.yml, unit-tests job); the .ps1 twin exists
# for local Windows dev parity.
#
# bash-3.2 compatible on purpose, even though the required execution is the
# ubuntu-latest runner's bash 5: a contributor may still run this locally on
# macOS system bash (3.2) to reproduce a CI failure. No ${var,,}/${var^^}, no
# mapfile/readarray, no declare -A. Recursive discovery uses `find` (NOT a **/
# globstar, which needs bash 4's `shopt -s globstar`) fed to a `while read` loop
# over a process substitution — so the fail/found_any counters stay in this
# shell (a `find | while` pipe would run the loop in a subshell and lose them).
# `find -H` dereferences the skills command-line argument only, so a symlinked
# skills/ ROOT is still walked (default -P would treat the link as a leaf and
# silently walk nothing, passing where the .ps1 twin — which follows a symlinked
# root — enforces); links found DURING the walk are left un-dereferenced,
# matching the twin's default of not recursing into linked subdirectories. The
# find PRUNES dot-named directories at any depth (`-name '.*' -type d -prune`),
# matching skills/**/SKILL.md globstar semantics (globstar without dotglob does
# not descend into dot-dirs) and the .ps1 twin's dot-dir exclusion, so the two
# twins stay byte-identical. The find is guarded by a skills/ dir test, so its
# zero-match / no-dir cases stay quiet and pass.
#
# Twin-parity contract with scripts/check-skill-size.ps1 (issue #14):
#   - File-set case parity (AC1a): `find -name SKILL.md` is EXACT-CASE by
#     pattern, so skill.md / Skill.md are NOT gated. Exact-case `SKILL.md` is the
#     repo convention (.project/conventions.md#Naming: `skills/<name>/SKILL.md`).
#     The .ps1 twin's Get-ChildItem `-Filter` is case-INSENSITIVE on Windows, so
#     it adds an exact-case post-filter to gate the IDENTICAL set.
#   - Violation-order parity (AC1b): the find output is `LC_ALL=C sort`ed (byte
#     order), so every violation is emitted deterministically in byte order. The
#     .ps1 twin sorts ordinally ([string]::CompareOrdinal) to match this byte
#     order exactly — NOT a culture-aware sort, which would diverge on
#     hyphen/underscore/case-mixed names.
#
# Frontmatter robustness: a leading UTF-8 BOM on line 1 and CRLF line endings
# are both tolerated (a Windows-authored SKILL.md must not slip past the gate on
# a fence mismatch). The description: field may be an inline scalar OR a YAML
# block scalar (`description: >-` / `|`, including an indentation/chomping
# indicator such as `>2`); a block scalar's indented body is accumulated and
# the ceiling is enforced on that body text.
#
# Run it locally from the repo root: ./scripts/check-skill-size.sh
# Exit 0 = every skills/**/SKILL.md is within both ceilings (or none exist).
# Exit 1 = at least one SKILL.md breached a ceiling — the offending file, the
#          ceiling breached, and its actual word count are printed to stderr.
#          ALL violations across all files are reported in one run (no
#          stop-at-first-failure).

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

FILE_CEILING=2500
DESC_CEILING=200

fail=0
found_any=0

# extract_description FILE -> the description: text on stdout (inline value, or
# the accumulated block-scalar body). Tolerates a line-1 BOM and CRLF; matches
# only the first frontmatter block (between the first two bare `---` fences).
extract_description() {
  awk '
    NR == 1 && substr($0, 1, 3) == "\357\273\277" { $0 = substr($0, 4) }
    {
      line = $0
      if (length(line) > 0 && substr(line, length(line)) == "\r") {
        line = substr(line, 1, length(line) - 1)
      }
      if (line == "---") {
        fences++
        indesc = 0
        next
      }
      if (fences != 1) next
      if (indesc) {
        if (line ~ /^[ \t]/ || line == "") {
          sub(/^[ \t]+/, "", line)
          desc = desc " " line
          next
        }
        indesc = 0
      }
      if (!descfound && line ~ /^description:/) {
        val = line
        sub(/^description:[ \t]*/, "", val)
        sub(/[ \t]+$/, "", val)
        if (val ~ /^[|>]([1-9][+-]?|[+-][1-9]?)?$/) {
          indesc = 1
          descfound = 1
          desc = ""
        } else {
          desc = val
          descfound = 1
        }
        next
      }
    }
    END { print desc }
  ' "$1"
}

if [ -d skills ]; then
  while IFS= read -r f; do
    found_any=1

    # --- whole-file ceiling ---
    words="$(wc -w < "$f" | tr -d ' ')"
    if [ "$words" -gt "$FILE_CEILING" ]; then
      echo "FAIL: ${f} — whole-file word count is ${words}, exceeds the ${FILE_CEILING}-word ceiling." >&2
      fail=1
    fi

    # --- frontmatter description: ceiling ---
    desc_text="$(extract_description "$f")"
    if [ -n "$desc_text" ]; then
      desc_words="$(printf '%s' "$desc_text" | wc -w | tr -d ' ')"
      if [ "$desc_words" -gt "$DESC_CEILING" ]; then
        echo "FAIL: ${f} — frontmatter description: word count is ${desc_words}, exceeds the ~${DESC_CEILING}-word ceiling." >&2
        fail=1
      fi
    fi
  done < <(find -H skills -name '.*' -type d -prune -o -name SKILL.md -type f -print | LC_ALL=C sort)
fi

if [ "$found_any" -eq 0 ]; then
  echo "PASS: no skills/**/SKILL.md files found — nothing to check."
  exit 0
fi

if [ "$fail" -eq 1 ]; then
  exit 1
fi

echo "PASS: every skills/**/SKILL.md is within the whole-file (<= ${FILE_CEILING} words) and description: (<= ~${DESC_CEILING} words) ceilings."
exit 0
