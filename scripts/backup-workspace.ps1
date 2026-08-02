#Requires -Version 5.1
<#
.SYNOPSIS
  Backs up the opencode workspace state to a dated branch on the GitHub remote.

.DESCRIPTION
  Creates a branch named chore/auto-backup-YYYY-MM-DD from current HEAD, stages all
  untracked/modified files, commits, and pushes to origin. On success, writes a
  .last-backup marker (gitignored) and an Information Event Log entry. On failure,
  writes an Error Event Log entry and exits non-zero. GitHub username is parsed
  from `git remote get-url origin` so this script is repo-agnostic.

.PARAMETER DryRun
  Print every step without writing, pushing, creating the marker, or writing to
  the Event Log.

.PARAMETER SkipPush
  Commit locally but do not push to origin. Useful for testing.

.EXAMPLE
  pwsh -File scripts\backup-workspace.ps1
  pwsh -File scripts\backup-workspace.ps1 -DryRun
  pwsh -File scripts\backup-workspace.ps1 -SkipPush
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"
$WorkspaceRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
Set-Location $WorkspaceRoot

function Step([string]$desc, [scriptblock]$action) {
    if ($DryRun) {
        Write-Host "[DryRun] would: $desc" -ForegroundColor Yellow
    } else {
        Write-Host "  $desc" -ForegroundColor Green
        & $action
    }
}

try {
    Write-Host "=== opencode-workspace backup ==="
    if ($DryRun) { Write-Host "(DRY RUN - no changes will be made)" -ForegroundColor Cyan }
    Write-Host ""

    # 1. Pre-flight: working tree must be clean for a clean backup
    $dirty = git status --porcelain
    if ($dirty) {
        Write-Host "Pre-flight: uncommitted changes detected - stash or commit first:" -ForegroundColor Red
        $dirty | ForEach-Object { Write-Host "  $_" }
        throw "Working tree not clean"
    }
    Write-Host "Pre-flight: working tree clean" -ForegroundColor Green

    # 2. Parse GitHub username from origin remote (keeps script repo-agnostic)
    $remoteUrl = git remote get-url origin
    if (-not $remoteUrl) { throw "No 'origin' git remote configured" }
    $ghUser = ($remoteUrl -split '/')[-2]
    Write-Host "Parsed GitHub user from origin: $ghUser"

    # 3. Create dated backup branch
    $date = Get-Date -Format "yyyy-MM-dd"
    $branchName = "chore/auto-backup-$date"
    $existing = git for-each-ref --format='%(refname:short)' "refs/heads/$branchName"
    if ($existing) {
        Write-Host "Backup branch $branchName already exists locally - reusing" -ForegroundColor Yellow
    } else {
        Step "create backup branch $branchName" { git checkout -b $branchName | Out-Null }
    }

    # 4. Stage every untracked/modified file (heuristic: workspace state changes only)
    Step "stage all changes" { git add -A }

    # 5. Commit if there's anything to commit
    $stagedCount = (git diff --cached --numstat | Measure-Object -Line).Lines
    if ($stagedCount -eq 0) {
        Write-Host "Nothing to commit - no backup needed" -ForegroundColor Yellow
        if (-not $DryRun) { git checkout main | Out-Null }
        return
    }
    $commitMsg = "chore(backup): auto-snapshot $date"
    Step "commit ($stagedCount files)" { git commit -m $commitMsg | Out-Null }

    # 6. Push
    if (-not $SkipPush) {
        Step "push $branchName to origin" {
            $pat = $env:GITHUB_PERSONAL_ACCESS_TOKEN
            if ($pat) {
                $helper = "!f() { echo username=$ghUser; echo password=$pat; }; f"
                git -c credential.helper= -c credential.helper="!$helper" push -u origin $branchName 2>&1 | Out-Null
            } else {
                git push -u origin $branchName 2>&1 | Out-Null
            }
        }
    } else {
        Write-Host "  (-SkipPush: skipping push)" -ForegroundColor Yellow
    }

    # 7. Capture commit hash for marker + event log
    $commitHash = (git rev-parse HEAD).Substring(0, 12)

    # 8. Write .last-backup marker (gitignored - local only)
    if (-not $DryRun) {
        $marker = Join-Path $WorkspaceRoot "scripts\.last-backup"
        "lastBackupDate: $(Get-Date -Format o)"  | Set-Content $marker
        "lastBackupBranch: $branchName"           | Add-Content $marker
        "lastBackupCommit: $commitHash"           | Add-Content $marker
        Write-Host "Wrote marker: $marker" -ForegroundColor Green
    }

    # 9. Return to main
    Step "checkout main" { git checkout main | Out-Null }

    # 10. Event Log success entry (uses existing "Windows PowerShell" source - no admin needed)
    if (-not $DryRun) {
        Write-EventLog -LogName Application -Source 'Windows PowerShell' `
            -EventId 100 -EntryType Information `
            -Message "opencode-workspace backup OK (branch $branchName, commit $commitHash)"
        Write-Host "Event Log: success entry written (EventId 100)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== backup complete ===" -ForegroundColor Green
    if (-not $DryRun -and -not $SkipPush) {
        Write-Host "Branch:  $branchName"
        Write-Host "Commit:  $commitHash"
        Write-Host "Remote:  https://github.com/$ghUser/Opencode-Workspace/pulls"
    }
}
catch {
    if (-not $DryRun) {
        try {
            Write-EventLog -LogName Application -Source 'Windows PowerShell' `
                -EventId 101 -EntryType Error `
                -Message "opencode-workspace backup FAILED: $($_.Exception.Message)"
        } catch {}
    }
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
