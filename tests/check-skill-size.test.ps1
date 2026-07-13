#!/usr/bin/env pwsh
#
# check-skill-size.test.ps1 — standalone fixture-driven tests for the skill-size
# gate's PowerShell twin (scripts/check-skill-size.ps1).
#
# Run it locally from the repo root:  pwsh tests/check-skill-size.test.ps1
# Exit 0 = every case behaved as expected. Exit 1 = at least one case failed.
#
# No test-framework dependency (none is approved — .project/library-manifest.md
# #Approved libraries): plain conditionals and exit-code/substring assertions
# only. Every case builds throwaway SKILL.md fixtures in a fresh temp git repo
# (so the gate's `git rev-parse --show-toplevel` scopes to the fixtures, never
# this repo). All repos live under ONE parent temp root removed in the finally
# block — no fixture files are committed and none leak.
#
# The fixture CASES are DATA, not code: they live in the shared table
# tests/check-skill-size.cases.json and are consumed here via ConvertFrom-Json.
# Its .sh twin (tests/check-skill-size.test.sh) drives the SAME table against the
# .sh gate, so the two twins can never hand-sync-drift (issue #14, AC4b): they
# share the case DATA and each keeps its own runner. Every skill's filler is a
# word COUNT — the gate only counts words, so a count is a behaviourally exact
# fixture and the assertions never inspect filler text.

Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Gate = Join-Path $RepoRoot 'scripts/check-skill-size.ps1'
$Table = Join-Path $ScriptDir 'check-skill-size.cases.json'

$script:pass = 0
$script:fail = 0

# Load the shared case table up front with a LOUD guard (issue #14 review): a
# missing/renamed table, unparseable JSON, or a renamed `.cases` key must fail
# loudly (exit 1), never yield a vacuous zero-case pass. Set-StrictMode makes a
# missing `.cases` property a terminating error, so the catch covers a renamed
# key too. The zero-assertion floor at the footer is the backstop.
if (-not (Test-Path -LiteralPath $Table)) {
    Write-Host "FAIL: shared case table not found: $Table"
    exit 1
}
try {
    $script:cases = @((Get-Content -LiteralPath $Table -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop).cases)
} catch {
    Write-Host "FAIL: could not load case table $Table — $($_.Exception.Message)"
    exit 1
}
if ($script:cases.Count -eq 0) {
    Write-Host "FAIL: case table $Table has zero cases"
    exit 1
}

# One parent temp root; every repo is a subdir under it, all removed at the end.
$script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("cssz-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:TmpRoot | Out-Null

function New-TempRepo {
    $d = Join-Path $script:TmpRoot ([System.Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $d | Out-Null
    git -C $d init -q | Out-Null
    return $d
}

# Get-Words N -> a single space-separated run of N "word" tokens (wc -w == N).
function Get-Words {
    param([int]$N)
    if ($N -le 0) { return '' }
    return (('word ' * $N).TrimEnd())
}

# Write-Skill REPO NAME DESC BODY -> REPO/skills/NAME/SKILL.md (inline desc).
function Write-Skill {
    param([string]$Repo, [string]$Name, [string]$Desc, [string]$Body)
    $dir = Join-Path $Repo "skills/$Name"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $content = "---`nname: $Name`ndescription: $Desc`n---`n`n$Body`n"
    Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value $content -Encoding utf8NoBOM -NoNewline
}

# Write-SkillBlockDesc REPO NAME DESCBODY BODY -> a SKILL.md whose description is
# a folded block scalar (`description: >-`) with DESCBODY as its indented body.
function Write-SkillBlockDesc {
    param([string]$Repo, [string]$Name, [string]$DescBody, [string]$Body)
    $dir = Join-Path $Repo "skills/$Name"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $content = "---`nname: $Name`ndescription: >-`n  $DescBody`n---`n`n$Body`n"
    Set-Content -LiteralPath (Join-Path $dir 'SKILL.md') -Value $content -Encoding utf8NoBOM -NoNewline
}

# Invoke-Gate REPO -> [PSCustomObject]@{ Output; Code }. Runs the gate in a
# child pwsh (native process) so its stderr merges cleanly via 2>&1 and its
# `exit N` becomes $LASTEXITCODE.
function Invoke-Gate {
    param([string]$Repo)
    Push-Location $Repo
    try {
        $out = & pwsh -NoProfile -NoLogo -File $Gate 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    return [PSCustomObject]@{ Output = $out; Code = $code }
}

function Assert-Exit {
    param([string]$Desc, [int]$Expected, [int]$Actual)
    if ($Actual -eq $Expected) {
        Write-Host "PASS: $Desc (exit $Actual)"; $script:pass++
    } else {
        Write-Host "FAIL: $Desc (expected exit $Expected, got $Actual)"; $script:fail++
    }
}

function Assert-Contains {
    param([string]$Desc, [string]$Haystack, [string]$Needle)
    if (([string]$Haystack).Contains($Needle)) {
        Write-Host "PASS: $Desc"; $script:pass++
    } else {
        Write-Host "FAIL: $Desc (missing '$Needle')"
        Write-Host "--- output ---"; Write-Host $Haystack
        $script:fail++
    }
}

try {
    # --- data-driven case runner (shared table: check-skill-size.cases.json) --
    # Each case builds its skill fixtures, runs the gate once, then asserts the
    # exit code and every required output substring — the SAME table the .sh twin
    # drives, so the two report identically. $script:cases was loaded and guarded
    # up front (above).
    foreach ($case in $script:cases) {
        $repo = New-TempRepo
        foreach ($skill in $case.skills) {
            if ($skill.kind -eq 'block') {
                Write-SkillBlockDesc $repo $skill.name (Get-Words $skill.descWords) (Get-Words $skill.bodyWords)
            } else {
                Write-Skill $repo $skill.name (Get-Words $skill.descWords) (Get-Words $skill.bodyWords)
            }
        }

        $r = Invoke-Gate $repo
        Assert-Exit $case.desc $case.expectExit $r.Code

        foreach ($ec in $case.expectContains) {
            Assert-Contains $ec.desc $r.Output $ec.needle
        }
    }
} finally {
    if (Test-Path -LiteralPath $script:TmpRoot) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
# Zero-assertion floor (issue #14 review): a run that asserted nothing is never
# green — it fails loudly.
if (($script:pass + $script:fail) -eq 0) {
    Write-Host "check-skill-size.test.ps1: FAIL — zero assertions ran (harness asserted nothing; check its inputs)."
    exit 1
}
Write-Host "check-skill-size.test.ps1: $script:pass passed, $script:fail failed."
if ($script:fail -ne 0) { exit 1 }
exit 0
