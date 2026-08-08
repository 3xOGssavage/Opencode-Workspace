#Requires -Version 5.1
<#
.SYNOPSIS
  Applies minimal branch protection on a GitHub repo's default branch using
  Invoke-RestMethod (curl-equivalent). No gh CLI required. Idempotent.

.DESCRIPTION
  This is the SIMPLE alternative to scripts/setup-branch-protection.ps1.
  Use this if you just need the minimum protection (gitleaks check required,
  no force push, no deletion) without auto-merge.

  For full features (auto-merge, enforce_admins, required_linear_history),
  use scripts/setup-branch-protection.ps1 instead.

.PARAMETER Owner
  GitHub repo owner (default: 3xOGssavage).

.PARAMETER Repo
  GitHub repo name (required).

.PARAMETER RequiredCheck
  Status check name that must pass before merge (default: gitleaks).

.PARAMETER Remove
  Undo: delete branch protection rule.

.EXAMPLE
  pwsh -File scripts\setup-branch-protection-curl.ps1 -Repo Opencode-Workspace
  pwsh -File scripts\setup-branch-protection-curl.ps1 -Repo Opencode-Workspace -Remove
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
if (-not $pat) {
    throw "GITHUB_PERSONAL_ACCESS_TOKEN env var not set. Run scripts/setup-env-vars.ps1 to configure."
}
if ($pat.Length -lt 40) {
    Write-Warning "PAT length is $($pat.Length) chars - GitHub PATs are usually 40+ chars. May be malformed."
}

$headers = @{
    Authorization = "token $pat"
    Accept        = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}
$base = "https://api.github.com/repos/$Owner/$Repo"

function Invoke-GhApi {
    param([string]$Method, [string]$Uri, $Body)
    $params = @{ Method = $Method; Uri = $Uri; Headers = $headers }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10) }
    try { return Invoke-RestMethod @params }
    catch { throw "API $Method $Uri failed: $($_.Exception.Message)" }
}

Write-Output "=== setup-branch-protection-curl on $Owner/$Repo ==="

# 1. Detect default branch
$repoInfo = Invoke-GhApi -Method GET -Uri $base
$defaultBranch = $repoInfo.default_branch
Write-Output "  default branch: $defaultBranch"

# 2. If Remove, delete protection and exit
if ($Remove) {
    Write-Output "  [REMOVE mode]"
    try {
        Invoke-GhApi -Method DELETE -Uri "$base/branches/$defaultBranch/protection" | Out-Null
        Write-Output "  deleted branch protection on $defaultBranch"
    } catch { Write-Output "  no protection to delete (or already removed)" }
    Write-Output "=== REMOVE complete ==="
    return
}

# 3. GET current protection (GET-merge-PUT idempotent pattern)
$existing = $null
try {
    $existing = Invoke-GhApi -Method GET -Uri "$base/branches/$defaultBranch/protection"
    Write-Output "  existing protection found (will be updated in place)"
} catch {
    Write-Output "  no existing protection (will be created)"
}

# 4. Build desired protection body
$protectionBody = @{
    required_status_checks = @{
        strict   = $true   # require branches up to date before merge
        contexts = @($RequiredCheck)
    }
    enforce_admins                = @{
        enabled = $false  # solo dev: don't enforce on admins (you can't self-approve anyway)
    }
    required_pull_request_reviews = $null   # no PR reviews required (solo dev)
    restrictions                  = $null   # no push restrictions
    required_linear_history       = $false  # allow merge commits (simpler)
    allow_force_pushes            = $false
    allow_deletions               = $false
}

# 5. PUT protection
try {
    Invoke-GhApi -Method PUT -Uri "$base/branches/$defaultBranch/protection" -Body $protectionBody | Out-Null
    Write-Output "  set branch protection on $defaultBranch (gitleaks required, no force push, no deletion)"
} catch {
    Write-Output "  ERROR setting protection: $($_.Exception.Message)"
    throw
}

# 6. Verify
Start-Sleep -Seconds 1
try {
    $verify = Invoke-GhApi -Method GET -Uri "$base/branches/$defaultBranch/protection"
    Write-Output ""
    Write-Output "=== VERIFICATION ==="
    Write-Output "  required_status_checks.contexts : $($verify.required_status_checks.contexts -join ', ')"
    Write-Output "  strict (up-to-date)            : $($verify.required_status_checks.strict)"
    Write-Output "  enforce_admins                 : $($verify.enforce_admins.enabled)"
    Write-Output "  allow_force_pushes             : $($verify.allow_force_pushes.enabled)"
    Write-Output "  allow_deletions                : $($verify.allow_deletions.enabled)"
    Write-Output ""
    $checkOk = $verify.required_status_checks.contexts -contains $RequiredCheck
    $strictOk = $verify.required_status_checks.strict
    $noForceOk = -not $verify.allow_force_pushes.enabled
    $noDeleteOk = -not $verify.allow_deletions.enabled
    if ($checkOk -and $strictOk -and $noForceOk -and $noDeleteOk) {
        Write-Output "=== setup-branch-protection-curl complete - VERIFIED ==="
    } else {
        Write-Output "=== WARNING: verification mismatch - check settings manually ==="
    }
} catch {
    Write-Output "=== WARNING: could not verify protection (may still have been applied) ==="
}
