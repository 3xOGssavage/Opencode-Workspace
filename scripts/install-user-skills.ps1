# install-user-skills.ps1
# Bulk-install user-level agent skills from scripts/skills-snapshot.json
# Iterates the snapshot's `source` field (groups duplicates) - 9 packages cover
# all 58 skills, not 58 individual installs.
# Cross-platform (Windows + Linux/macOS via pwsh).
# Accepts -DryRun for CI smoke tests (parse snapshot, print plan, no install).
#
# Usage:
#   pwsh scripts/install-user-skills.ps1
#   pwsh scripts/install-user-skills.ps1 -DryRun
#   pwsh scripts/install-user-skills.ps1 -TimeoutSec 120

[CmdletBinding()]
param(
    [switch]$DryRun,
    [int]$TimeoutSec = 90
)

$ErrorActionPreference = "Stop"
$snapshotPath = Join-Path $PSScriptRoot 'skills-snapshot.json'
$logDir = Join-Path $PSScriptRoot '..\.opencode\skill-reinstall-artifacts'
$logFile = Join-Path $logDir 'skill-install.log'

if (-not (Test-Path $snapshotPath)) {
    Write-Host "[FAIL] snapshot not found: $snapshotPath" -ForegroundColor Red
    exit 1
}

if (-not $DryRun) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Start-Transcript -Path $logFile -Force | Out-Null
}

$snapshot = Get-Content $snapshotPath -Raw | ConvertFrom-Json
$skills = $snapshot.skills
$skillCount = ($skills.PSObject.Properties.Name | Measure-Object).Count
$uniqueSources = $skills.PSObject.Properties.Value | Select-Object -ExpandProperty source -Unique

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " User Skills Installer" -ForegroundColor Cyan
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host " Snapshot v$($snapshot.version): $skillCount skills from $($uniqueSources.Count) sources" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "[DRY RUN] Would invoke these $($uniqueSources.Count) commands:" -ForegroundColor Magenta
    foreach ($src in $uniqueSources) {
        $count = ($skills.PSObject.Properties.Value | Where-Object { $_.source -eq $src } | Measure-Object).Count
        Write-Host "  npx -y skills@latest add $src -y -a * -s *    (covers $count skill(s))" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "[DRY RUN] PASS - snapshot parses, no install attempted" -ForegroundColor Green
    exit 0
}

$ok = 0
$failed = 0
foreach ($src in $uniqueSources) {
    Write-Host "[install] $src ..." -ForegroundColor Yellow
    $args = @('-y', 'skills@latest', 'add', $src, '-y', '-a', '*', '-s', '*')
    try {
        $p = Start-Process -FilePath 'npx' -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$logDir\$($src.Replace('/','_')).out" -RedirectStandardError "$logDir\$($src.Replace('/','_')).err"
        if ($p.ExitCode -eq 0) {
            Write-Host "    [OK] $src" -ForegroundColor Green
            $ok++
        } else {
            Write-Host "    [FAIL] $src exit=$($p.ExitCode)" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "    [FAIL] $src -> $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " RESULT: $ok sources installed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
Write-Host " Log: $logFile" -ForegroundColor DarkGray
Write-Host "===========================================" -ForegroundColor Cyan

Stop-Transcript | Out-Null
if ($failed -gt 0) { exit 1 }
exit 0
