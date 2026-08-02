#Requires -Version 5.1
<#
.SYNOPSIS
  Applies classic branch protection + enables auto-merge on a GitHub repo's
  default branch. Requires gitleaks status check to pass before any merge.
  Run setup-secret-scanning.ps1 FIRST (otherwise the required check never reports
  and no PR can ever merge).

  Idempotent: safe to run multiple times.
  Use -Remove to undo (deletes branch protection + disables auto-merge).

.PARAMETER Owner
  GitHub repo owner (default: 3xOGssavage).

.PARAMETER Repo
  GitHub repo name (required).

.PARAMETER RequiredCheck
  Status check name that must pass before merge (default: gitleaks).
  Must EXACTLY match the check name produced by the workflow.

.PARAMETER Remove
  Undo: delete branch protection rule + disable auto-merge.

.EXAMPLE
  .\setup-branch-protection.ps1 -Repo Opencode-Workspace
.EXAMPLE
  .\setup-branch-protection.ps1 -Repo neodev-portal -LocalPath F:\CD\Opencode\Projects\neodev-portal
.EXAMPLE
  .\setup-branch-protection.ps1 -Repo Opencode-Workspace -Remove
#>
[CmdletBinding()]
param(
    [string]$Owner = "3xOGssavage",
    [Parameter(Mandatory=$true)][string]$Repo,
    [string]$RequiredCheck = "gitleaks",
    [switch]$Remove
)

$ErrorActionPreference = "Stop"

$pat = $env:GITHUB_PERSONAL_ACCESS_TOKEN
if (-not $pat) { throw "GITHUB_PERSONAL_ACCESS_TOKEN env var not set" }

$headers = @{
    Authorization = "token $pat"
    Accept        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}
$base = "https://api.github.com/repos/$Owner/$Repo"

function Invoke-GhApi { param([string]$Method, [string]$Uri, $Body)
    $params = @{ Method = $Method; Uri = $Uri; Headers = $headers }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10) }
    try { return Invoke-RestMethod @params }
    catch { throw "API $Method $Uri failed: $($_.Exception.Message)" }
}

Write-Output "=== setup-branch-protection on $Owner/$Repo ==="

# 1. Detect default branch
$repoInfo = Invoke-GhApi -Method GET -Uri $base
$defaultBranch = $repoInfo.default_branch
Write-Output "  default branch: $defaultBranch"

if ($Remove) {
    Write-Output "  [REMOVE mode]"
    try {
        Invoke-GhApi -Method DELETE -Uri "$base/branches/$defaultBranch/protection"
        Write-Output "  deleted branch protection on $defaultBranch"
    } catch { Write-Output "  no protection to delete (or already removed)" }
    $patchBody = @{ allow_auto_merge = $false } | ConvertTo-Json
    Invoke-RestMethod -Method PATCH -Uri $base -Headers $headers -Body $patchBody -ContentType "application/json" | Out-Null
    Write-Output "  disabled auto-merge"
    Write-Output "=== REMOVE complete ==="
    return
}

# 2. Enable auto-merge at repo level
$patchBody = @{ allow_auto_merge = $true } | ConvertTo-Json
Invoke-RestMethod -Method PATCH -Uri $base -Headers $headers -Body $patchBody -ContentType "application/json" | Out-Null
Write-Output "  enabled allow_auto_merge"

# 3. Set classic branch protection rule on default branch
#    Classic (not ruleset) - auto-merge has a known bug with rulesets (#162623).
#    Solo-dev friendly: no required reviews (you can't self-approve anyway).
#    Structure-enforced gates: gitleaks status check must pass before any merge.
$protectionBody = @{
    required_status_checks = @{
        strict   = $true   # require branches up to date
        contexts = @($RequiredCheck)
    }
    enforce_admins                = $true   # no bypass, even for the repo owner
    required_pull_request_reviews = $null   # solo dev: can't self-approve
    restrictions                  = $null   # no push restrictions
    required_linear_history       = $true
    allow_force_pushes            = $false
    allow_deletions               = $false
}

try {
    Invoke-GhApi -Method PUT -Uri "$base/branches/$defaultBranch/protection" -Body $protectionBody | Out-Null
    Write-Output "  set branch protection on $defaultBranch (strict, enforce_admins, gitleaks required)"
} catch {
    Write-Output "  ERROR setting protection: $($_.Exception.Message)"
    throw
}

# 4. Verify
Start-Sleep -Seconds 1
$verify = Invoke-RestMethod -Uri "$base/branches/$defaultBranch/protection" -Headers $headers
$checkName = $verify.required_status_checks.contexts
$enforceAdmins = $verify.enforce_admins.enabled
$strict = $verify.required_status_checks.strict
Write-Output ""
Write-Output "=== VERIFICATION ==="
Write-Output "  required_status_checks.contexts : $($checkName -join ', ')"
Write-Output "  strict (up-to-date)            : $strict"
Write-Output "  enforce_admins                 : $enforceAdmins"
Write-Output "  allow_force_pushes             : $($verify.allow_force_pushes.enabled)"
Write-Output "  allow_deletions                 : $($verify.allow_deletions.enabled)"
Write-Output ""
$verifyRepo = Invoke-RestMethod -Uri $base -Headers $headers
Write-Output "  allow_auto_merge                : $($verifyRepo.allow_auto_merge)"
Write-Output ""
if ($checkName -contains $RequiredCheck -and $strict -and $enforceAdmins) {
    Write-Output "=== setup-branch-protection complete - VERIFIED ==="
} else {
    Write-Output "=== WARNING: verification mismatch - check settings manually ==="
}
