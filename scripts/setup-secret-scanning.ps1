#Requires -Version 5.1
<#
.SYNOPSIS
  Copies gitleaks secret-scanning workflow + config into a target GitHub repo.
  Run setup-branch-protection.ps1 AFTER this one.

.PARAMETER Owner
  GitHub repo owner (default: 3xOGssavage).

.PARAMETER Repo
  GitHub repo name (required).

.PARAMETER LocalPath
  Local path to the repo root (required). Used to write the files.

.PARAMETER DryRun
  Show what would happen without making changes.

.EXAMPLE
  .\setup-secret-scanning.ps1 -Repo neodev-portal -LocalPath F:\CD\Opencode\Projects\neodev-portal
#>
[CmdletBinding()]
param(
    [string]$Owner = "3xOGssavage",
    [Parameter(Mandatory=$true)][string]$Repo,
    [Parameter(Mandatory=$true)][string]$LocalPath,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$workspaceRoot = "F:\CD\Opencode"
$sourceWorkflow = Join-Path $workspaceRoot ".github\workflows\secret-scan.yml"
$sourceConfig    = Join-Path $workspaceRoot ".github\gitleaks.toml"

if (-not (Test-Path $sourceWorkflow)) { throw "Source workflow not found: $sourceWorkflow" }
if (-not (Test-Path $sourceConfig))    { throw "Source config not found: $sourceConfig" }
if (-not (Test-Path $LocalPath))       { throw "Target path does not exist: $LocalPath" }

$destWorkflowDir = Join-Path $LocalPath ".github\workflows"
$destConfigDir   = Join-Path $LocalPath ".github"
$destWorkflow    = Join-Path $destWorkflowDir "secret-scan.yml"
$destConfig      = Join-Path $destConfigDir "gitleaks.toml"

function Invoke-Step { param([string]$desc, [scriptblock]$action)
    if ($DryRun) { Write-Output "  [DRY] $desc" } else { Write-Output "  $desc"; & $action }
}

Write-Output "=== setup-secret-scanning on $Owner/$Repo ==="
Write-Output "  target: $LocalPath"
if ($DryRun) { Write-Output "  (DRY RUN - no changes)" }
Write-Output ""

# 1. Ensure .github/workflows dir exists
Invoke-Step "ensure $destWorkflowDir exists" {
    if (-not (Test-Path $destWorkflowDir)) { New-Item -ItemType Directory -Path $destWorkflowDir -Force | Out-Null }
}

# 2. Copy workflow if missing or different
$needsWorkflow = (-not (Test-Path $destWorkflow)) -or ((Get-Content $sourceWorkflow -Raw) -ne (Get-Content $destWorkflow -Raw))
if ($needsWorkflow) {
    Invoke-Step "copy secret-scan.yml -> $destWorkflow" { Copy-Item $sourceWorkflow $destWorkflow -Force }
} else {
    Write-Output "  secret-scan.yml already up to date - skip"
}

# 3. Copy gitleaks.toml if missing or different
$needsConfig = (-not (Test-Path $destConfig)) -or ((Get-Content $sourceConfig -Raw) -ne (Get-Content $destConfig -Raw))
if ($needsConfig) {
    Invoke-Step "copy gitleaks.toml -> $destConfig" { Copy-Item $sourceConfig $destConfig -Force }
} else {
    Write-Output "  gitleaks.toml already up to date - skip"
}

Write-Output ""
if ($DryRun) {
    Write-Output "=== DRY RUN complete ==="
} else {
    Write-Output "=== setup-secret-scanning complete ==="
    Write-Output "Next: commit these files, push to the repo, then run setup-branch-protection.ps1"
}
