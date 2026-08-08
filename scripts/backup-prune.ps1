#Requires -Version 5.1
<#
.SYNOPSIS
  Prunes old backup bundles, keeping the most recent N. Protects user-named
  bundles from deletion.

.DESCRIPTION
  Deletes all but the N most-recent bundles in BackupDir (default 8). Bundles
  whose name doesn't match the auto-generated pattern are PROTECTED from
  deletion (recognized as user-saved snapshots).

  Pattern protected: anything NOT matching 'opencode-YYYY-MM-DD*.bundle'
  Pattern deleted:   bundles older than the N-th most recent auto-generated one

  Idempotent and safe: pass -WhatIf to preview, -Force to actually delete.

.PARAMETER BackupDir
  Directory containing backup bundles (default: D:\Backups).

.PARAMETER Keep
  Number of most-recent bundles to keep (default: 8).

.PARAMETER WhatIf
  Show what would be deleted without actually deleting.

.PARAMETER Force
  Required to actually delete. Without -Force, runs in WhatIf mode.

.EXAMPLE
  pwsh -File scripts\backup-prune.ps1
  pwsh -File scripts\backup-prune.ps1 -Keep 4
  pwsh -File scripts\backup-prune.ps1 -Keep 4 -Force
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$BackupDir = "D:\Backups",
    [int]$Keep = 8,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupDir)) {
    throw "Backup directory not found: $BackupDir"
}

# auto-generated bundles follow: opencode-YYYY-MM-DD[-suffix].bundle
$autoPattern = '^opencode-\d{4}-\d{2}-\d{2}(-.+)?\.bundle$'

$bundles = Get-ChildItem -Path $BackupDir -Filter "*.bundle" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending

if ($bundles.Count -eq 0) {
    Write-Host "No bundles found in $BackupDir"
    exit 0
}

# Separate: auto-generated vs user-named (protected)
$autoBundles = $bundles | Where-Object { $_.Name -match $autoPattern }
$protectedBundles = $bundles | Where-Object { $_.Name -notmatch $autoPattern }

Write-Host "=== backup-prune ==="
Write-Host "  Backup dir  : $BackupDir"
Write-Host "  Total       : $($bundles.Count) bundle(s)"
Write-Host "  Auto-gen    : $($autoBundles.Count) (eligible for pruning)"
Write-Host "  Protected   : $($protectedBundles.Count) (user-named, not touched)"
Write-Host "  Keep        : $Keep most-recent auto-gen bundles"
Write-Host ""

if ($protectedBundles.Count -gt 0) {
    Write-Host "Protected (will NOT be deleted):"
    foreach ($b in $protectedBundles) {
        Write-Host "  [protected] $($b.Name) ($([math]::Round(((Get-Date)-$b.LastWriteTime).TotalDays,1))d old)"
    }
    Write-Host ""
}

if ($autoBundles.Count -le $Keep) {
    Write-Host "Nothing to prune: only $($autoBundles.Count) auto-gen bundle(s), keep=$Keep"
    exit 0
}

# Identify which to delete: keep first $Keep, delete the rest
$toKeep = $autoBundles | Select-Object -First $Keep
$toDelete = $autoBundles | Select-Object -Skip $Keep

Write-Host "Will keep (most recent $Keep):"
foreach ($b in $toKeep) {
    Write-Host "  [keep] $($b.Name) ($([math]::Round(((Get-Date)-$b.LastWriteTime).TotalDays,1))d old, $($b.Length) bytes)"
}
Write-Host ""
Write-Host "Will delete (older than top $Keep):"
foreach ($b in $toDelete) {
    Write-Host "  [delete] $($b.Name) ($([math]::Round(((Get-Date)-$b.LastWriteTime).TotalDays,1))d old, $($b.Length) bytes)"
}
Write-Host ""

$actuallyDelete = $Force -and (-not $WhatIf)
if (-not $actuallyDelete) {
    Write-Host "(Dry run - pass -Force to actually delete. Use -WhatIf to preview without -Force.)"
    exit 0
}

# Actually delete
$deleted = 0
$failed = 0
foreach ($b in $toDelete) {
    if ($PSCmdlet.ShouldProcess($b.FullName, "Delete backup bundle")) {
        try {
            Remove-Item -LiteralPath $b.FullName -Force -ErrorAction Stop
            $deleted++
            Write-Host "  deleted: $($b.Name)"
        } catch {
            $failed++
            Write-Warning "  failed to delete $($b.Name): $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "=== prune complete: $deleted deleted, $failed failed ==="
exit 0
