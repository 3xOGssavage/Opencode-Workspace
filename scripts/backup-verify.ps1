#Requires -Version 5.1
<#
.SYNOPSIS
  Verifies the backup workflow is healthy: checks for recent backup, alerts on
  staleness, validates .last-backup marker. Also validates live global-config
  sync (global-config/ master vs live config dir).

.DESCRIPTION
  Exit codes (per AGENTS.md failure-mode convention):
    0 = healthy (backup exists, recent, marker valid)
    1 = degraded (backup missing or stale > 7 days, marker missing/invalid)
    2 = critical (backup missing entirely OR 2 consecutive failures)

  Designed for Task Scheduler: "Run only when user logged on", weekly Sun 09:00.
  On non-zero exit, sends desktop notification via BurntToast OR .NET fallback
  (installed by setup-burnttoast.ps1). Toast rate-limited to 1 per day per
  severity to avoid notification fatigue.

.PARAMETER BackupDir
  Directory containing backup bundles (default: D:\Backups).

.PARAMETER MaxAgeDays
  Maximum acceptable age of most-recent backup in days (default: 7).

.PARAMETER WarmupDays
  Days since first-ever backup before enforcing MaxAgeDays (default: 7).
  During warmup, only checks that AT LEAST ONE backup exists.

.PARAMETER MasterDir
  Master config dir (default: <repo>/global-config). Test seam for temp dirs.

.PARAMETER LiveDir
  Live config dir (default: ~/.config/opencode). Test seam for temp dirs.

.EXAMPLE
  pwsh -File scripts\backup-verify.ps1
  pwsh -File scripts\backup-verify.ps1 -MaxAgeDays 3
#>
[CmdletBinding()]
param(
    [string]$BackupDir = "D:\Backups",
    [int]$MaxAgeDays = 7,
    [int]$WarmupDays = 7,
    [string]$MasterDir = "",
    [string]$LiveDir = ""
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$repoRoot = (Get-Item -Path $scriptDir).Parent.FullName
$marker = Join-Path $repoRoot "scripts\.last-backup"
$toastRateFile = Join-Path $env:LOCALAPPDATA "opencode-backup-toast-rate.txt"

# --- Notification setup: try BurntToast, fall back to .NET ---
$notify = $null
if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
    $notify = {
        param($Title, $Message, $Severity)
        Import-Module BurntToast -ErrorAction SilentlyContinue
        $tag = switch ($Severity) { "Info" { "Information" } "Warning" { "Warning" } "Error" { "Error" } }
        try {
            New-BurntToastNotification -Text $Title, $Message -Sound $tag -ErrorAction Stop
        } catch {
            # BurntToast failed - fall through to .NET
            . (Join-Path $scriptDir "_notify-fallback.ps1")
            Send-Notify -Title $Title -Message $Message -Severity $Severity
        }
    }
} elseif (Test-Path (Join-Path $scriptDir "_notify-fallback.ps1")) {
    $notify = {
        param($Title, $Message, $Severity)
        . (Join-Path $scriptDir "_notify-fallback.ps1")
        Send-Notify -Title $Title -Message $Message -Severity $Severity
    }
} else {
    $notify = { param($Title, $Message, $Severity) Write-Host "[$Severity] $Title : $Message" }
}

# --- Toast rate limiter: max 1 per severity per calendar day ---
$canToast = {
    param([string]$Severity)
    if (-not (Test-Path $toastRateFile)) { return $true }
    $entries = Get-Content $toastRateFile -ErrorAction SilentlyContinue
    $today = Get-Date -Format "yyyy-MM-dd"
    $recent = $entries | Where-Object { $_ -like "$today $Severity" }
    return ($recent.Count -eq 0)
}
$recordToast = {
    param([string]$Severity)
    $today = Get-Date -Format "yyyy-MM-dd"
    "$today $Severity $(Get-Date -Format 'HH:mm:ss')" | Add-Content $toastRateFile
}

# --- Backup discovery ---
$bundles = @()
if (Test-Path $BackupDir) {
    $bundles = Get-ChildItem -Path $BackupDir -Filter "opencode-*.bundle" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
}
$bundleCount = $bundles.Count
$mostRecent = $null
if ($bundleCount -gt 0) {
    $mostRecent = $bundles[0]
    $ageDays = [math]::Round(((Get-Date) - $mostRecent.LastWriteTime).TotalDays, 1)
} else {
    $ageDays = $null
}

# --- Marker validation ---
$markerValid = $false
$markerData = @{}
if (Test-Path $marker) {
    $markerContent = Get-Content $marker -ErrorAction SilentlyContinue
    foreach ($line in $markerContent) {
        if ($line -match "^(\w+):\s*(.+)$") {
            $markerData[$Matches[1]] = $Matches[2].Trim()
        }
    }
    $markerValid = ($markerData.Count -ge 2)  # at least date + branch
}

# --- Determine overall status ---
$status = "healthy"
$reasons = @()

if ($bundleCount -eq 0) {
    # No bundles at all = critical
    $status = "critical"
    $reasons += "No backup bundles found in $BackupDir"
} elseif (-not $markerValid) {
    # Bundles exist but marker missing/invalid = degraded
    $status = "degraded"
    $reasons += "Marker file missing or invalid: $marker"
} elseif ($ageDays -gt $MaxAgeDays) {
    # Warmup check: if most recent is within WarmupDays AND it's the first backup, OK
    if ($bundleCount -eq 1 -and $ageDays -le $WarmupDays) {
        $status = "healthy"
        $reasons += "Warmup: only $($bundleCount) bundle, age $([math]::Round($ageDays,1))d within warmup window ($WarmupDays days)"
    } else {
        $status = "degraded"
        $reasons += "Most recent backup is $([math]::Round($ageDays,1)) days old (max $MaxAgeDays)"
    }
} else {
    $reasons += "OK - $($bundleCount) bundles, most recent $([math]::Round($ageDays,1))d old"
}

# --- Live-config sync check (global-config/ master vs live config dir) ---
# Sunday watchdog for settings sync. Depends on this script's schedule/notify
# plumbing - do not split into a separate script without re-homing (see R1).
# Compared files carry no secrets (audited); reasons print filenames only.
# Alert-only by design: drift direction is ambiguous (master may be stale),
# so this section never auto-corrects. Excluded: package-lock.json
# (npm-managed), README.md (doc), auth/mcp-auth files (machine secrets).
$syncMaster = $MasterDir
if ([string]::IsNullOrEmpty($syncMaster)) { $syncMaster = Join-Path $repoRoot "global-config" }
$syncLive = $LiveDir
if ([string]::IsNullOrEmpty($syncLive)) { $syncLive = Join-Path $env:USERPROFILE ".config\opencode" }
$syncFiles = @("opencode.jsonc", "oh-my-opencode-slim.json", "tui.json", "package.json")
$syncOkCount = 0
if ([string]::IsNullOrEmpty($env:USERPROFILE)) {
    if ($status -eq "healthy") { $status = "degraded" }
    $reasons += "Config sync UNCHECKED: USERPROFILE unavailable (unexpected scheduler context)"
} elseif (-not (Test-Path -LiteralPath $syncLive)) {
    if ($status -eq "healthy") { $status = "degraded" }
    $reasons += "Live config dir missing: re-run setup-env-vars.ps1 step 2 (copies global-config/ over)"
} else {
    foreach ($sf in $syncFiles) {
        try {
            $mf = Join-Path $syncMaster $sf
            $lf = Join-Path $syncLive $sf
            if (-not (Test-Path -LiteralPath $mf)) {
                if ($status -eq "healthy") { $status = "degraded" }
                $reasons += "Config sync UNCHECKED for ${sf}: master copy missing (incomplete checkout?)"
            } elseif (-not (Test-Path -LiteralPath $lf)) {
                if ($status -eq "healthy") { $status = "degraded" }
                $reasons += "Config drift: live $sf missing (re-run setup-env-vars.ps1 step 2)"
            } elseif ((Get-FileHash -LiteralPath $mf).Hash -ne (Get-FileHash -LiteralPath $lf).Hash) {
                if ($status -eq "healthy") { $status = "degraded" }
                $reasons += "Config drift: $sf differs from global-config/ master (master wins: re-run setup step 2; live wins: copy live to master, commit, PR)"
            } else {
                $syncOkCount++
            }
        } catch {
            if ($status -eq "healthy") { $status = "degraded" }
            $reasons += "Config sync UNCHECKED for ${sf}: $($_.Exception.Message)"
        }
    }
    if ($syncOkCount -eq $syncFiles.Count) {
        $reasons += "Config sync OK - 4/4 files match master"
    }
}

# --- Output + exit code ---
Write-Host "=== backup-verify ==="
Write-Host "  Backup dir      : $BackupDir"
Write-Host "  Bundle count    : $bundleCount"
if ($mostRecent) {
    Write-Host "  Most recent     : $($mostRecent.Name) ($([math]::Round($ageDays,1))d old, $($mostRecent.Length) bytes)"
}
Write-Host "  Marker valid    : $markerValid"
Write-Host "  Max age (days)  : $MaxAgeDays"
Write-Host "  Status          : $status"
Write-Host "  Reasons         :"
foreach ($r in $reasons) { Write-Host "    - $r" }

# --- Notification (rate-limited) ---
$shouldNotify = ($status -ne "healthy")
if ($shouldNotify) {
    $severity = if ($status -eq "critical") { "Error" } else { "Warning" }
    if (& $canToast $severity) {
        & $notify "opencode backup $status" ($reasons -join "; ") $severity
        & $recordToast $severity
        Write-Host "  Notification sent: $severity"
    } else {
        Write-Host "  Notification skipped: rate-limited (already sent today)"
    }
}

# --- Exit code ---
switch ($status) {
    "healthy"   { exit 0 }
    "degraded"  { exit 1 }
    "critical"  { exit 2 }
}
