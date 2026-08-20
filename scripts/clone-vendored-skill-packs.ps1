# clone-vendored-skill-packs.ps1
# Git-clones the 5 vendored skill packs that live inside .opencode/ and are
# gitignored (auto-reinstallable). Uses --depth 1 for speed.
# Cross-platform (Windows + Linux/macOS via pwsh).
#
# The 6th vendored pack (.opencode/github-mcp-server) is a released tarball
# extract, not a git repo - see TODO below.
#
# Usage:
#   pwsh scripts/clone-vendored-skill-packs.ps1
#   pwsh scripts/clone-vendored-skill-packs.ps1 -Force

[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$targetDir = Join-Path $root '.opencode'

# Source => target subdir (verified in research: cycles 6-7 of Plan V8)
$packs = @(
    @{ Name='agent-skills';        Url='https://github.com/addyosmani/agent-skills.git' },
    @{ Name='anthropic-skills';    Url='https://github.com/anthropics/skills.git' },
    @{ Name='vercel-agent-skills'; Url='https://github.com/vercel-labs/agent-skills.git' },
    @{ Name='last30days-skill';    Url='https://github.com/mvanhorn/last30days-skill.git' },
    @{ Name='playwright-bp-skill'; Url='https://github.com/currents-dev/playwright-best-practices-skill.git' }
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Vendored Skill Pack Cloner" -ForegroundColor Cyan
Write-Host " Target: $targetDir" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# TODO (deferred): .opencode/github-mcp-server is a release tarball extract
# (no .git dir). Future improvement: download the latest release .zip from
# https://github.com/github/github-mcp-server/releases and unzip here.
# For now, team members download manually if they need the local binary MCP.

$ok = 0
$skipped = 0
$failed = 0

foreach ($pack in $packs) {
    $dest = Join-Path $targetDir $pack.Name
    $marker = Join-Path $dest 'SKILL.md'
    $hasGit = Test-Path (Join-Path $dest '.git')

    if ((Test-Path $marker) -and $hasGit -and -not $Force) {
        Write-Host "[skip] $($pack.Name) (already cloned)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    if (Test-Path $dest) {
        Write-Host "[clean] removing existing $($pack.Name)" -ForegroundColor DarkGray
        Remove-Item $dest -Recurse -Force
    }

    Write-Host "[clone] $($pack.Name) from $($pack.Url)" -ForegroundColor Yellow
    try {
        git clone --depth 1 $pack.Url $dest 2>&1 | Out-Host
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] $($pack.Name) cloned" -ForegroundColor Green
            $ok++
        } else {
            Write-Host "    [FAIL] git exit $LASTEXITCODE" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "    [FAIL] $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " RESULT: $ok cloned, $skipped skipped, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
Write-Host "===========================================" -ForegroundColor Cyan

if ($failed -gt 0) { exit 1 }
exit 0
