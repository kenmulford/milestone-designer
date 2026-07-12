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
# block — no fixture files are committed and none leak. Exercises the SAME
# logical cases as its .sh twin (tests/check-skill-size.test.sh) and must report
# identically.

Set-StrictMode -Version Latest

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$Gate = Join-Path $RepoRoot 'scripts/check-skill-size.ps1'

$script:pass = 0
$script:fail = 0

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
    # --- Case 1: under-ceiling pass -----------------------------------------
    $repo = New-TempRepo
    Write-Skill $repo 'under' 'a short description under the ceiling' (Get-Words 20)
    $r = Invoke-Gate $repo
    Assert-Exit 'under-ceiling -> exit 0' 0 $r.Code

    # --- Case 2: empty-glob pass (no skills/ dir) ---------------------------
    $repo = New-TempRepo
    $r = Invoke-Gate $repo
    Assert-Exit 'empty-glob (no SKILL.md) -> exit 0' 0 $r.Code
    Assert-Contains 'empty-glob prints the no-files notice' $r.Output 'no skills/*/SKILL.md files found'

    # --- Case 3: whole-file over ceiling fail -------------------------------
    $repo = New-TempRepo
    Write-Skill $repo 'big-file' 'small description' (Get-Words 2600)
    $r = Invoke-Gate $repo
    Assert-Exit 'whole-file over ceiling -> exit 1' 1 $r.Code
    Assert-Contains 'names the offending file' $r.Output 'skills/big-file/SKILL.md'
    Assert-Contains 'names the whole-file ceiling' $r.Output 'whole-file word count'

    # --- Case 4: description over ceiling fail (inline) ---------------------
    $repo = New-TempRepo
    Write-Skill $repo 'big-desc' (Get-Words 210) (Get-Words 20)
    $r = Invoke-Gate $repo
    Assert-Exit 'inline description over ceiling -> exit 1' 1 $r.Code
    Assert-Contains 'names the offending file' $r.Output 'skills/big-desc/SKILL.md'
    Assert-Contains 'names the description ceiling' $r.Output 'description: word count'

    # --- Case 5: multi-violation, all reported in one run -------------------
    $repo = New-TempRepo
    Write-Skill $repo 'a-big-file' 'small description' (Get-Words 2600)
    Write-Skill $repo 'b-big-desc' (Get-Words 210) (Get-Words 20)
    $r = Invoke-Gate $repo
    Assert-Exit 'multi-violation -> exit 1' 1 $r.Code
    Assert-Contains 'reports the file-ceiling violation' $r.Output 'skills/a-big-file/SKILL.md'
    Assert-Contains 'reports the description-ceiling violation' $r.Output 'skills/b-big-desc/SKILL.md'

    # --- Case 6: block-scalar description over ceiling (guards C2/D1) -------
    $repo = New-TempRepo
    Write-SkillBlockDesc $repo 'block-desc' (Get-Words 250) 'small body'
    $r = Invoke-Gate $repo
    Assert-Exit 'block-scalar description over ceiling -> exit 1' 1 $r.Code
    Assert-Contains 'names the offending file' $r.Output 'skills/block-desc/SKILL.md'
    Assert-Contains 'names the description ceiling' $r.Output 'description: word count'
} finally {
    if (Test-Path -LiteralPath $script:TmpRoot) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "check-skill-size.test.ps1: $script:pass passed, $script:fail failed."
if ($script:fail -ne 0) { exit 1 }
exit 0
