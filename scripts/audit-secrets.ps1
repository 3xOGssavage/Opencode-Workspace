#Requires -Version 5.1
<#
.SYNOPSIS
  Pre-commit secret guard. Scans staged files for known API-key patterns.
.DESCRIPTION
  Reads the list of staged files from `git diff --cached --name-only`,
  inspects each text file for common secret patterns, and exits non-zero
  if any are found. Designed to be called by .githooks/pre-commit.
  Can also be run standalone: `pwsh scripts/audit-secrets.ps1`.
.PARAMETER StagedOnly
  Default: true (only scan files staged for commit).
  Switch -StagedOnly:$false to scan all tracked files instead.
.EXITCODES
  0 = clean, no secrets detected
  1 = secrets detected, commit blocked
#>
[CmdletBinding()]
param(
  [bool]$StagedOnly = $true
)

$ErrorActionPreference = 'Stop'

# 6 secret patterns covering the workspace's known provider keys + generic high-risk formats
$patterns = @(
  'sk-[A-Za-z0-9]{20,}',          # OpenAI/Anthropic/hcnsec/TokenRouter-style
  'ghp_[A-Za-z0-9]{36}',          # GitHub PAT (classic)
  'github_pat_[A-Za-z0-9_]{82}',  # GitHub PAT (fine-grained)
  'nvapi-[A-Za-z0-9]{20,}',       # NVIDIA
  'AQ\.[A-Za-z0-9_\-]{20,}',      # Google AI Studio (Gemini)
  'xox[baprs]-[A-Za-z0-9\-]+',    # Slack
  'AKIA[0-9A-Z]{16}',             # AWS access key
  'sntrys_[A-Za-z0-9_\-]{20,}'    # Sentry auth token
)
$regex = ($patterns -join '|')

# File extensions worth scanning (text-based, may contain secrets)
$includeExts = @('.json','.jsonc','.md','.yml','.yaml','.txt','.ps1','.bat','.cmd','.py','.js','.ts','.tsx','.env','.toml','.ini','.cfg','.xml','.html','.css','.sh')

if ($StagedOnly) {
  $files = git diff --cached --name-only --diff-filter=ACM 2>$null
  if (-not $files) { Write-Host 'audit-secrets: no staged files to scan.'; exit 0 }
} else {
  $files = git ls-files 2>$null
  if (-not $files) { Write-Host 'audit-secrets: no tracked files to scan.'; exit 0 }
}

$hits = @()
$scanned = 0
foreach ($f in $files) {
  $ext = [System.IO.Path]::GetExtension($f)
  if ($ext -notin $includeExts) { continue }
  if (-not (Test-Path -LiteralPath $f)) { continue }
  try {
    $content = Get-Content -LiteralPath $f -Raw -Encoding UTF8 -ErrorAction Stop
    if (-not $content) { continue }
    $matches = [regex]::Matches($content, $regex)
    if ($matches.Count -gt 0) {
      foreach ($m in $matches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Count
        $hits += [PSCustomObject]@{ File = $f; Line = $lineNum; Match = $m.Value }
      }
    }
    $scanned++
  } catch {
    # Skip binary / unreadable files silently
  }
}

if ($hits.Count -eq 0) {
  Write-Host "audit-secrets: PASS - $scanned files scanned, no secrets detected." -ForegroundColor Green
  exit 0
} else {
  Write-Host "audit-secrets: FAIL - $($hits.Count) secret(s) detected in $($hits.Count) file(s):" -ForegroundColor Red
  foreach ($h in $hits) {
    Write-Host "  $($h.File):$($h.Line)  =>  $($h.Match)" -ForegroundColor Red
  }
  Write-Host ""
  Write-Host "To bypass in emergencies:  git commit --no-verify" -ForegroundColor Yellow
  exit 1
}
