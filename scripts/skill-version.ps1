#Requires -Version 5.1
<#
.SYNOPSIS
  Tags the current commit with a skill-version tag if changes were made to
  .opencode/skills/ since the last tag.

.DESCRIPTION
  Called by .githooks/post-commit. Inspects changes since the most-recent
  skill-* tag. If any changed files are under .opencode/skills/, creates a new
  semver tag (auto-incrementing the patch version).

  Uses a lock file at .git/.skill-version.lock to prevent race conditions during
  git commit --amend. Lock is acquired via PID + timestamp; stale locks (>5 min
  old) are force-removed.

  Idempotent: re-running produces no new tag if the changes have already been
  tagged. Tags are created locally only (not pushed) — push happens via the
  GH Action alternative or manual git push --tags.

.PARAMETER DryRun
  Print what would happen without creating any tags.

.EXAMPLE
  pwsh -File scripts\skill-version.ps1
  pwsh -File scripts\skill-version.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) { throw "Not in a git repository" }
Set-Location $repoRoot

$lockFile = Join-Path $repoRoot ".git\.skill-version.lock"
$tagPrefix = "skill-v"

# --- Lock acquisition (prevents amend race) ---
$lockMaxAgeSec = 300  # 5 minutes
$lockAcquired = $false
$myPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
$lockAttempts = 0
while (-not $lockAcquired -and $lockAttempts -lt 30) {
    if (Test-Path $lockFile) {
        $lockContent = Get-Content $lockFile -Raw -ErrorAction SilentlyContinue
        $lockTime = $null
        $lockPid = $null
        if ($lockContent -match "pid=(\d+)") { $lockPid = [int]$Matches[1] }
        if ($lockContent -match "time=(.+)") { $lockTime = [datetime]$Matches[1] }
        $isStale = ($lockTime -and (((Get-Date) - $lockTime).TotalSeconds -gt $lockMaxAgeSec))
        $isDead = ($lockPid -and -not (Get-Process -Id $lockPid -ErrorAction SilentlyContinue))
        if ($isStale -or $isDead) {
            Write-Host "[skill-version] removing stale lock (pid=$lockPid, age=$(([math]::Round(((Get-Date) - $lockTime).TotalSeconds)))s)"
            Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
        } else {
            Start-Sleep -Milliseconds 100
            $lockAttempts++
            continue
        }
    }
    # Acquire lock
    "pid=$myPid`ntime=$(Get-Date -Format 'o')" | Set-Content $lockFile -ErrorAction SilentlyContinue
    if ($?) { $lockAcquired = $true }
    $lockAttempts++
}
if (-not $lockAcquired) {
    Write-Warning "[skill-version] could not acquire lock after 30 attempts - skipping"
    exit 0
}

try {
    # 1. Find most-recent skill-* tag
    $latestTag = git tag --list "$tagPrefix*" --sort=-v:refname | Select-Object -First 1
    if (-not $latestTag) {
        $latestTag = "skill-v0.0.0"
    }

    # 2. Determine diff range
    $commitCount = 0
    if ($latestTag -eq "skill-v0.0.0") {
        # First-ever tag: tag the current commit
        $commitCount = 1
        $diffRange = "HEAD"
    } else {
        # Count commits between latest tag and HEAD touching skills
        $changedFiles = git diff --name-only $latestTag..HEAD -- .opencode/skills/ 2>$null
        if (-not $changedFiles) {
            Write-Host "[skill-version] no skill changes since $latestTag - skipping"
            exit 0
        }
        $commitCount = 1
        $diffRange = "HEAD"
    }

    # 3. Bump patch version
    $version = $latestTag.Substring($tagPrefix.Length)  # e.g., "0.1.3"
    $parts = $version -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2] + 1
    $newVersion = "$major.$minor.$patch"
    $newTag = "$tagPrefix$newVersion"

    # 4. Check if tag already exists (idempotent)
    $existing = git tag --list $newTag
    if ($existing) {
        Write-Host "[skill-version] tag $newTag already exists - skipping (idempotent)"
        exit 0
    }

    if ($DryRun) {
        Write-Host "[skill-version] (dry-run) would create tag $newTag at $(git rev-parse --short HEAD)"
        exit 0
    }

    # 5. Create tag
    git tag -a $newTag -m "Skills version $newVersion - changes in .opencode/skills/" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git tag failed (exit $LASTEXITCODE)"
    }
    Write-Host "[skill-version] created tag $newTag"
    Write-Host "  push with: git push origin $newTag"
}
finally {
    # Always release lock
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}
