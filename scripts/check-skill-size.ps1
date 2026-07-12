#!/usr/bin/env pwsh
#
# check-skill-size.ps1 — PowerShell 7+ twin of scripts/check-skill-size.sh.
#
# Identical to the .sh twin in every observable way: same ceilings, same
# skills/*/SKILL.md scope, same whole-file (wc -w) and frontmatter description:
# word counts, same FAIL/PASS messages, same exit codes, and the same
# "report every violation in one run" behaviour. CI (ubuntu-latest) runs the
# .sh twin; this .ps1 twin exists for local Windows dev parity, per the suite's
# bash-first-with-PowerShell-7+-fallback convention
# (.project/library-manifest.md#Runtime & frameworks).
#
# Ceilings enforced, verbatim, no rounding:
#   - whole-file word count (wc -w equivalent)    <= 2500
#   - frontmatter description: field word count   <= ~200
#
# Parity notes with the .sh twin:
#   - Word counting splits on ASCII whitespace only (space, tab, CR, LF, FF, VT)
#     to match glibc `wc -w`; a non-breaking space (U+00A0) or ideographic space
#     (U+3000) does NOT split a word, exactly as wc -w treats them.
#   - The skills/*/SKILL.md scope matches the bash glob: one directory level
#     deep, dot-named directories excluded, OS-hidden directories included.
#   - A leading UTF-8 BOM and CRLF line endings are tolerated; the description:
#     field may be an inline scalar or a YAML block scalar (`description: >-`/`|`,
#     including an indentation/chomping indicator such as `>2`) whose indented
#     body is accumulated and held to the ~200-word ceiling.
#
# Run it locally from the repo root: pwsh scripts/check-skill-size.ps1
# Exit 0 = every skills/*/SKILL.md is within both ceilings (or none exist).
# Exit 1 = at least one SKILL.md breached a ceiling — the offending file, the
#          ceiling breached, and its actual word count are printed to stderr.

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Set-Location (git rev-parse --show-toplevel)

$FileCeiling = 2500
$DescCeiling = 200

$fail = $false
$foundAny = $false

# wc -w equivalent: count maximal runs of ASCII whitespace only, so NBSP / U+3000
# do NOT split a word (parity with glibc wc -w).
function Get-WordCount {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return 0 }
    return @($Text -split '[ \t\r\n\f\x0B]+' | Where-Object { $_ -ne '' }).Count
}

# Extract the description: text from a SKILL.md's raw content (inline value, or
# an accumulated block-scalar body). Tolerates a line-1 BOM and CRLF; matches
# only the first frontmatter block. Mirrors the .sh twin's awk exactly.
function Get-DescriptionText {
    param([string]$Raw)
    if ([string]::IsNullOrEmpty($Raw)) { return '' }
    if ($Raw[0] -eq [char]0xFEFF) { $Raw = $Raw.Substring(1) }
    $fences = 0
    $inDesc = $false
    $descFound = $false
    $desc = ''
    foreach ($line in ($Raw -split '\r?\n')) {
        if ($line -ceq '---') {
            $fences++
            $inDesc = $false
            continue
        }
        if ($fences -ne 1) { continue }
        if ($inDesc) {
            if ($line -match '^[ \t]' -or $line -eq '') {
                $desc = $desc + ' ' + ($line -replace '^[ \t]+', '')
                continue
            }
            $inDesc = $false
        }
        if (-not $descFound -and $line -cmatch '^description:') {
            $val = ($line -creplace '^description:[ \t]*', '') -replace '[ \t]+$', ''
            if ($val -cmatch '^[|>]([1-9][+-]?|[+-][1-9]?)?$') {
                $inDesc = $true
                $descFound = $true
                $desc = ''
            } else {
                $desc = $val
                $descFound = $true
            }
        }
    }
    return $desc
}

# Mirror the .sh glob `skills/*/SKILL.md`: one level deep, alphabetical,
# dot-named dirs excluded, OS-hidden dirs included (-Force).
$dirs = @()
if (Test-Path -LiteralPath 'skills' -PathType Container) {
    $dirs = Get-ChildItem -LiteralPath 'skills' -Directory -Force |
        Where-Object { $_.Name -notlike '.*' } |
        Sort-Object Name
}

foreach ($dir in $dirs) {
    $f = "skills/$($dir.Name)/SKILL.md"
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $foundAny = $true

    # Read the file once; reuse the raw content for both counts.
    $raw = Get-Content -LiteralPath $f -Raw

    # --- whole-file ceiling ---
    $words = Get-WordCount $raw
    if ($words -gt $FileCeiling) {
        [Console]::Error.WriteLine("FAIL: $f — whole-file word count is $words, exceeds the $FileCeiling-word ceiling.")
        $fail = $true
    }

    # --- frontmatter description: ceiling ---
    $descText = Get-DescriptionText $raw
    if (-not [string]::IsNullOrEmpty($descText)) {
        $descWords = Get-WordCount $descText
        if ($descWords -gt $DescCeiling) {
            [Console]::Error.WriteLine("FAIL: $f — frontmatter description: word count is $descWords, exceeds the ~$DescCeiling-word ceiling.")
            $fail = $true
        }
    }
}

if (-not $foundAny) {
    [Console]::Out.WriteLine("PASS: no skills/*/SKILL.md files found — nothing to check.")
    exit 0
}

if ($fail) {
    exit 1
}

[Console]::Out.WriteLine("PASS: every skills/*/SKILL.md is within the whole-file (<= $FileCeiling words) and description: (<= ~$DescCeiling words) ceilings.")
exit 0
