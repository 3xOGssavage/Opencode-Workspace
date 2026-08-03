#Requires -Version 5.1
<#
.SYNOPSIS
  Creates a git bundle of the entire workspace on D:\Backups\ for offline/air-gapped
  backup. Intended to be invoked as the 2nd action of "Opencode monthly backup"
  scheduled task (after scripts\backup-workspace.ps1 pushes to GitHub).

.DESCRIPTION
  - Runs `git bundle create <bundle> --all` from the workspace root.
  - Runs `git bundle verify <bundle>` as builtin integrity check.
  - Retains only the last 3 bundles (older ones removed).
  - Exits 0 if target drive is missing (soft skip for unplugged USB / external disk).
  - Exits 1 only on git bundle create/verify failure.

.PARAMETER BundleDir
  Target directory for .bundle files. Default: D:\Backups
  Drive letter parsed from this path; missing drive = silent skip (exit 0).

.EXAMPLE
  pwsh -File scripts\backup-bundle.ps1
  pwsh -File scripts\backup-bundle.ps1 -BundleDir E:\Backups
#>
[CmdletBinding()]
param(
    [string]$BundleDir = "D:\Backups"
)

$ErrorActionPreference = "Stop"
$WorkspaceRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
Set-Location $WorkspaceRoot

# Soft skip if target drive is missing (external USB unplugged, etc.)
$drive = ($BundleDir -split ':')[0] + ':'
if (-not (Test-Path $drive)) {
    Write-Host "Target drive $drive not available - bundle skipped (soft skip)." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path $BundleDir)) {
    New-Item -ItemType Directory -Path $BundleDir | Out-Null
}

$date   = Get-Date -Format "yyyy-MMdd"
$bundle = Join-Path $BundleDir "opencode-$date.bundle"

Write-Host "Creating bundle: $bundle" -ForegroundColor Green
git bundle create $bundle --all
if ($LASTEXITCODE -ne 0) { throw "git bundle create failed (exit $LASTEXITCODE)" }

Write-Host "Verifying bundle integrity..." -ForegroundColor Green
git bundle verify $bundle
if ($LASTEXITCODE -ne 0) { throw "git bundle verify failed (exit $LASTEXITCODE)" }

# Retain only the last 3 bundles (by name descending = newest first).
Get-ChildItem $BundleDir -Filter "opencode-*.bundle" |
    Sort-Object Name -Descending |
    Select-Object -Skip 3 |
    Remove-Item -Force

Write-Host "Bundle complete: $bundle (retained last 3)" -ForegroundColor Green
