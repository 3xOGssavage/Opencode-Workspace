#Requires -Version 5.1
<#
.SYNOPSIS
  Semi-automated workspace backup runner.
.DESCRIPTION
  - Refuses to run if `git status` shows uncommitted changes (safer than auto-stashing).
  - Creates a dated chore/auto-backup-YYYY-MM-DD branch from current HEAD.
  - Stages tracked-only changes (respects .gitignore).
  - Commits + pushes via inline credential helper using GITHUB_PERSONAL_ACCESS_TOKEN.
  - Prints a summary with the branch URL.
  - User merges the resulting PR manually via GitHub UI.

  Schedule with Windows Task Scheduler for monthly auto-run (see README.md).

.PARAMETER Message
  Optional custom commit message. Default: "chore(workspace): auto-backup YYYY-MM-DD".

.PARAMETER SkipPush
  Switch: commit locally but don't push to GitHub. Useful for offline workflows.

.EXAMPLE
  pwsh scripts/backup-workspace.ps1
  pwsh scripts/backup-workspace.ps1 -Message "chore: post-v1.18.11-upgrade snapshot"
  pwsh scripts/backup-workspace.ps1 -SkipPush
#>
[CmdletBinding()]
param(
  [string]$Message = "",
  [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = $PSScriptRoot | Split-Path -Parent
Set-Location -LiteralPath $WorkspaceRoot

$date = Get-Date -Format 'yyyy-MM-dd'
$branchName = "chore/auto-backup-$date"
if (-not $Message) { $Message = "chore(workspace): auto-backup $date" }

Write-Host "=== opencode workspace backup ===" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceRoot"
Write-Host "Branch:    $branchName"
Write-Host ""

# --- 1. Preflight: refuse if dirty working tree ---
$status = git status --porcelain 2>&1
$uncommitted = $status | Where-Object { $_ -match '^[MARD]|^\?\?' }
if ($uncommitted) {
  Write-Host "ERROR: working tree has uncommitted changes. Please commit or stash first." -ForegroundColor Red
  Write-Host "Running auto-backup now would mix your in-progress edits with the backup." -ForegroundColor Red
  Write-Host ""
  Write-Host "Uncommitted files:" -ForegroundColor Yellow
  $uncommitted | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" }
  exit 1
}
Write-Host "[1/5] Working tree clean." -ForegroundColor Green

# --- 2. Create dated branch ---
$existingBranch = git branch --list $branchName 2>&1
if ($existingBranch) {
  Write-Host "[2/5] Branch $branchName already exists. Reusing." -ForegroundColor Yellow
  git checkout $branchName 2>&1 | Out-Null
} else {
  git checkout -b $branchName 2>&1 | Out-Null
  Write-Host "[2/5] Created + checked out $branchName"
}

# --- 3. Stage tracked-only changes (respect .gitignore) ---
git add -A 2>&1 | Out-Null
$stagedCount = (git diff --cached --name-only 2>&1 | Measure-Object).Count
if ($stagedCount -eq 0) {
  Write-Host "[3/5] No changes to back up. Nothing to commit." -ForegroundColor Green
  Set-Location -LiteralPath $WorkspaceRoot
  git checkout - 2>&1 | Out-Null
  Write-Host "Backup skipped - workspace already in sync with last commit."
  exit 0
}
Write-Host "[3/5] Staged $stagedCount file(s)."

# --- 4. Commit ---
git commit -m $Message 2>&1 | Out-Null
if (-not $?) {
  Write-Host "[4/5] ERROR: commit failed" -ForegroundColor Red
  exit 1
}
$commitHash = git rev-parse --short HEAD 2>&1
Write-Host "[4/5] Committed: $commitHash"

# --- 5. Push (optional) ---
if ($SkipPush) {
  Write-Host "[5/5] SkipPush set - skipping push to GitHub." -ForegroundColor Yellow
} else {
  $pat = $env:GITHUB_PERSONAL_ACCESS_TOKEN
  if (-not $pat) {
    Write-Host "[5/5] WARN: GITHUB_PERSONAL_ACCESS_TOKEN not set - cannot push." -ForegroundColor Red
    Write-Host "        Commit is local only. Set the env var + re-run, or push manually:" -ForegroundColor Red
    Write-Host "        git push -u origin $branchName"
    exit 0
  }
  $helper = "!f() { echo username=3xOGssavage; echo password=$pat; }; f"
  git -c credential.helper="$helper" push -u origin $branchName 2>&1 | Out-Host
  if ($?) {
    Write-Host "[5/5] Pushed to origin/$branchName" -ForegroundColor Green
    Write-Host ""
    Write-Host "Review + merge:  https://github.com/3xOGssavage/Opencode-Workspace/pulls" -ForegroundColor Cyan
  } else {
    Write-Host "[5/5] ERROR: push failed. Network or auth issue." -ForegroundColor Red
    exit 1
  }
}

Write-Host ""
Write-Host "=== Backup complete. Merge the PR via GitHub UI when ready. ===" -ForegroundColor Green
