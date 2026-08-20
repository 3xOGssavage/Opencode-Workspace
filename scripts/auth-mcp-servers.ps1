# auth-mcp-servers.ps1
# Sequentially invoke `opencode mcp auth <name>` for the 4 OAuth MCPs.
# Interactive (opens browser). Cross-platform (opencode CLI cross-plat).
# Accepts -Skip <list> (comma-separated MCP names to skip).
#
# Usage:
#   pwsh scripts/auth-mcp-servers.ps1
#   pwsh scripts/auth-mcp-servers.ps1 -Skip 'vercel,sentry'

[CmdletBinding()]
param(
    [string]$Skip = ''
)

$ErrorActionPreference = "Stop"

$mcpServers = @('composio', 'sentry', 'supabase', 'vercel')
$skipList = if ($Skip) { $Skip -split ',' | ForEach-Object { $_.Trim().ToLower() } } else { @() }

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Opencode MCP Authentication Orchestrator" -ForegroundColor Cyan
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " IMPORTANT: Close any running opencode sessions before continuing." -ForegroundColor Yellow
Write-Host "            The auth flow writes to ~/.local/share/opencode/mcp-auth.json" -ForegroundColor Yellow
Write-Host "            and concurrent sessions may corrupt that file." -ForegroundColor Yellow
Write-Host ""
Write-Host " Press Enter to continue, or Ctrl+C to abort..." -ForegroundColor Cyan
[void](Read-Host)

$ok = 0
$skipped = 0
$failed = 0

foreach ($mcp in $mcpServers) {
    if ($mcp.ToLower() -in $skipList) {
        Write-Host "[skip] $mcp (in -Skip list)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    Write-Host ""
    Write-Host "[auth] $mcp - Run 'opencode mcp auth $mcp' in another terminal" -ForegroundColor Yellow
    Write-Host "        A browser will open; complete the OAuth flow there." -ForegroundColor Yellow
    Write-Host "        Press Enter when authentication is complete, or 's' to skip." -ForegroundColor Yellow
    $resp = Read-Host "    Continue"

    if ($resp -and $resp.ToLower() -eq 's') {
        Write-Host "    [skip] $mcp (user skipped)" -ForegroundColor DarkGray
        $skipped++
        continue
    }

    try {
        Write-Host "    Starting 'opencode mcp auth $mcp'..." -ForegroundColor DarkGray
        $p = Start-Process -FilePath 'opencode' -ArgumentList @('mcp', 'auth', $mcp) -NoNewWindow -Wait -PassThru
        if ($p.ExitCode -eq 0) {
            Write-Host "    [OK] $mcp authenticated" -ForegroundColor Green
            $ok++
        } else {
            Write-Host "    [FAIL] $mcp exit=$($p.ExitCode)" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "    [FAIL] $mcp -> $_" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " RESULT: $ok authenticated, $skipped skipped, $failed failed" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Red' })
Write-Host " Verify with: pwsh scripts/verify-setup.ps1" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

if ($failed -gt 0) { exit 1 }
exit 0
