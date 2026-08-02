#Requires -Version 5.1
<#
.SYNOPSIS
  Lightweight pre-commit secret scanner. Crowdpatterns: AWS/GCP/Azure/GitPAT/JWT.

.DESCRIPTION
  Scans staged file contents for common secret patterns and blocks the commit
  if any match. Intended to be called from .githooks/pre-commit. Exits 0 on
  clean, 1 on hit. Allow-list of known-safe fragment patterns (like truncated
  key prefixes in documentation) can be extended below.

.EXAMPLE
  pwsh -File scripts\audit-secrets.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$patterns = @(
    [regex]::new('AKIA[0-9A-Z]{16}'),                              # AWS access key
    [regex]::new('ghp_[0-9A-Za-z]{36}'),                             # GitHub PAT (classic)
    [regex]::new('github_pat_[0-9A-Za-z_]{82}'),                    # GitHub PAT (fine-grained)
    [regex]::new('glpat-[0-9A-Za-z_-]{20}'),                        # GitLab PAT
    [regex]::new('xox[baprs]-[0-9A-Za-z-]{10,}'),                    # Slack token
    [regex]::new('AIza[0-9A-Za-z_-]{35}'),                          # Google API key
    [regex]::new('sk-[0-9A-Za-z]{20,}'),                            # OpenAI / Anthropic-style
    [regex]::new('eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'), # JWT
    [regex]::new('-----BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY-----') # SSH/PEM
)

# Documentation-safe prefixes that are explicitly truncate-patterns, not real keys.
# Matches must be < 20 chars after the prefix to count as truncated (allow), else real (block).
$allowListedPrefixes = @('sk-W8GXu', 'nvapi-W1yyV', 'AQ.Ab8R')

$staged = git diff --cached --name-only --diff-filter=ACM
if (-not $staged) { return }

$hits = @()
foreach ($file in $staged) {
    if (-not (Test-Path $file)) { continue }
    $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    foreach ($p in $patterns) {
        foreach ($m in $p.Matches($content)) {
            $value = $m.Value
            $isAllowListed = $false
            foreach ($prefix in $allowListedPrefixes) {
                if ($value.StartsWith($prefix) -and $value.Length -lt ($prefix.Length + 20)) {
                    $isAllowListed = $true
                    break
                }
            }
            if (-not $isAllowListed) {
                $hits += [pscustomobject]@{ File = $file; Match = $value }
            }
        }
    }
}

if ($hits.Count -gt 0) {
    Write-Host "ERROR: $(($hits.Count)) potential secret(s) found in staged files:" -ForegroundColor Red
    $hits | ForEach-Object {
        $preview = if ($_.Match.Length -gt 40) { $_.Match.Substring(0, 40) + '...' } else { $_.Match }
        Write-Host "  $($_.File): $preview" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "If false positive, extend `$allowListedPrefixes in scripts/audit-secrets.ps1" -ForegroundColor Yellow
    exit 1
}

exit 0
