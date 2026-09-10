#Requires -Version 5.1
<#
.SYNOPSIS
  Idempotent setup script for the opencode workspace on a new (or same) machine.
.DESCRIPTION
  1. Auto-detects its parent dir as $WorkspaceRoot (no hardcoding).
  2. Sets 4 User env vars pointing into the workspace.
  3. Copies global-config\* to %USERPROFILE%\.config\opencode\ (overwrites).
  4. Runs `npm install` in that target dir (reproducible via package-lock.json).
  5. Regex-replaces the original clone path in opencode.json with $WorkspaceRoot
     so the 12 absolute paths (skills.paths, permission.edit.deny, mcp.command)
     resolve correctly on this machine.
  6. Prints the manual steps the user still must complete (API keys, MCP auth,
     skill installs, provider logins).
.NOTES
  Re-runnable. Overwrites env vars + global-config files each time.
  -Member: teammate flow (safe-default identity, portable paths, blank notebook).
  Does NOT touch auth.json, mcp-auth.json, or any API-key env var.
#>

[CmdletBinding()]
param([switch]$Member)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = $PSScriptRoot | Split-Path -Parent
$IsWinOS = (-not $PSVersionTable.Platform) -or ($PSVersionTable.Platform -eq 'Win32NT')
$homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }

# Identity: one question, safe default = teammate (member). Owner answers yes.
# Non-interactive shells can't answer: default to member (safe) instead of hanging.
if (-not $Member) {
    try {
        $ans = Read-Host "Is this the owner's machine? (yes/no, default: no)"
        if ($ans -ne 'yes') { $Member = $true }
    } catch { $Member = $true }
}
if ($Member) { Write-Host "Member mode: fresh paths, own keys, blank notebook." -ForegroundColor Cyan }
Write-Host "=== opencode workspace setup ===" -ForegroundColor Cyan
Write-Host "Detected workspace: $WorkspaceRoot"
Write-Host ""

# --- 1. Set 4 setup env vars (idempotent, portable) ---
Write-Host "[1/5] Setting setup env vars..." -ForegroundColor Yellow
$cfgPath = Join-Path $WorkspaceRoot 'opencode.json'
$cfgDir = Join-Path $WorkspaceRoot '.opencode'
$memPath = Join-Path $cfgDir 'memory.jsonl'
if ($IsWinOS) {
    [Environment]::SetEnvironmentVariable('OPENCODE_CONFIG', $cfgPath, 'User')
    [Environment]::SetEnvironmentVariable('OPENCODE_CONFIG_DIR', $cfgDir, 'User')
    [Environment]::SetEnvironmentVariable('MEMORY_FILE_PATH', $memPath, 'User')
    [Environment]::SetEnvironmentVariable('OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS', 'true', 'User')
    Write-Host "  OPENCODE_CONFIG                        = $cfgPath"
    Write-Host "  OPENCODE_CONFIG_DIR                    = $cfgDir"
    Write-Host "  MEMORY_FILE_PATH                       = $memPath"
} else {
    Write-Host "  Linux/macOS: User-scope registry does not exist here."
    Write-Host "  Add these 4 lines to ~/.bashrc (or ~/.zshrc), then restart the shell:"
    Write-Host "    export OPENCODE_CONFIG='$cfgPath'"
    Write-Host "    export OPENCODE_CONFIG_DIR='$cfgDir'"
    Write-Host "    export MEMORY_FILE_PATH='$memPath'"
    Write-Host "    export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS='true'"
}
Write-Host "  OPENCODE_EXPERIMENTAL_BACKGROUND_...   = true"
Write-Host ""

# --- 2. Copy global-config files to ~/.config/opencode/ (idempotent) ---
Write-Host "[2/5] Copying global-config to ~/.config/opencode/..." -ForegroundColor Yellow
$TargetConfigDir = Join-Path (Join-Path $homeDir '.config') 'opencode'
if (-not (Test-Path $TargetConfigDir)) { New-Item -ItemType Directory -Path $TargetConfigDir -Force | Out-Null }
$globalConfigSrc = Join-Path $WorkspaceRoot 'global-config'
if (-not (Test-Path $globalConfigSrc)) {
    Write-Host "  ERROR: global-config\ directory not found at $globalConfigSrc" -ForegroundColor Red
    Write-Host "  Skipping copy. Repo may be incomplete." -ForegroundColor Red
} else {
    Get-ChildItem -Path $globalConfigSrc -File | Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination (Join-Path $TargetConfigDir $_.Name) -Force
        Write-Host "  Copied: $($_.Name)"
    }
}
Write-Host ""

# --- 3. npm install in target config dir (idempotent) ---
Write-Host "[3/5] Running npm install in $TargetConfigDir..." -ForegroundColor Yellow
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "  WARN: npm not found on PATH. Install Node 18+ first, then re-run this script." -ForegroundColor Red
    Write-Host "  Skipping npm install. OMO-Slim + auto-vision + eyesight plugins will not load." -ForegroundColor Red
} else {
    Push-Location $TargetConfigDir
    try {
        & npm install --no-audit --no-fund 2>&1 | Out-Host
        Write-Host "  npm install complete." -ForegroundColor Green
    } catch {
        Write-Host "  WARN: npm install failed: $_" -ForegroundColor Red
        Write-Host "  Plugins may not load. Check network + package-lock.json." -ForegroundColor Red
    } finally {
        Pop-Location
    }
}
Write-Host ""

# --- 4. Regex-replace absolute paths in opencode.json (PORTABILITY FIX) ---
Write-Host "[4/5] Normalizing absolute paths in opencode.json..." -ForegroundColor Yellow
$opencodeJsonPath = Join-Path $WorkspaceRoot 'opencode.json'
if (-not (Test-Path $opencodeJsonPath)) {
    Write-Host "  ERROR: opencode.json not found at $opencodeJsonPath" -ForegroundColor Red
} else {
    $originalPath = 'F:\CD\Opencode'
    $escapedOriginal = [regex]::Escape($originalPath)
    # Build JSON-escaped replacement (double backslashes)
    $newPathJson = $WorkspaceRoot -replace '\\', '\\\\'
    $content = Get-Content -Path $opencodeJsonPath -Raw
    $newContent = [regex]::Replace($content, $escapedOriginal, { param($m) $newPathJson })
    if ($content -eq $newContent) {
        Write-Host "  No path replacements needed (paths already correct or clone unchanged)."
    } else {
        Set-Content -Path $opencodeJsonPath -Value $newContent -NoNewline
        $count = ([regex]::Matches($content, $escapedOriginal)).Count
        Write-Host "  Replaced $count occurrences of '$originalPath' with '$WorkspaceRoot'"
    }
    # Machine-specific spots the workspace replace does not cover:
    # owner's personal folders, memory launcher per OS, temp dir, drive rule.
    # (Order matters: temp-dir first, then the general user-folder replace.)
    $content2 = Get-Content -Path $opencodeJsonPath -Raw
    if ($IsWinOS) {
        $memberTemp = Join-Path ([System.IO.Path]::GetTempPath()) 'opencode'
        $memberTempJson = $memberTemp -replace '\\', '\\'
        $content2 = [regex]::Replace($content2, 'C:\\\\Users\\\\user\\\\AppData\\\\Local\\\\Temp\\\\opencode', { param($m) $memberTempJson })
        $newUserJson = $homeDir -replace '\\', '\\'
        $content2 = [regex]::Replace($content2, 'C:\\\\Users\\\\user', { param($m) $newUserJson })
        # Windows launcher (also reverses a Linux edit on re-install)
        $content2 = $content2 -replace '/\.opencode/memory-mcp-wrapper\.sh', '\.opencode\memory-mcp-wrapper.bat'
        $content2 = $content2 -replace '"command":\s*\["sh",\s*"([^"]+)"\]', '"command": ["$1"]'
        $rootJson = $WorkspaceRoot -replace '\\', '\\'
        # Owner keeps the broad F:\CD\** rule; members get a root-scoped rule.
        if ($Member) {
            $content2 = [regex]::Replace($content2, 'F:\\\\CD\\\\\*\*', { param($m) ($rootJson + '\\**') })
        }
    } else {
        $content2 = $content2 -replace 'C:\\\\Users\\\\user\\\\AppData\\\\Local\\\\Temp\\\\opencode', '/tmp/opencode'
        $content2 = [regex]::Replace($content2, 'C:\\\\Users\\\\user', { param($m) $homeDir })
        # Linux launcher twin (invoked via sh, so no exec bit needed)
        $content2 = $content2 -replace '\.opencode\\\\memory-mcp-wrapper\.bat', '/.opencode/memory-mcp-wrapper.sh'
        $content2 = $content2 -replace '"command":\s*\["([^"]*memory-mcp-wrapper\.sh)"\]', '"command": ["sh", "$1"]'
        $content2 = [regex]::Replace($content2, 'F:\\\\CD\\\\\*\*', { param($m) ($WorkspaceRoot + '/**') })
        if ($Member) {
            Write-Host "  External-directory rule scoped to workspace root."
        }
    }
    if ($content2 -cne (Get-Content -Path $opencodeJsonPath -Raw)) {
        Set-Content -Path $opencodeJsonPath -Value $content2 -NoNewline
        Write-Host "  Machine-specific paths normalized for this machine."
    } else {
        Write-Host "  Machine-specific paths already correct."
    }
    # Member notebook: blank fresh memory (owner notes never ship).
    if ($Member) {
        $memTarget = Join-Path (Join-Path $WorkspaceRoot '.opencode') 'memory.jsonl'
        Set-Content -LiteralPath $memTarget -Value '{"name":"welcome","entityType":"note","observations":["Fresh member notebook. Owner notes were replaced on install."]}' -Encoding UTF8
        Write-Host "  Member notebook: blank fresh memory.jsonl written."
    }
}
Write-Host ""
# --- 5. Print manual steps (owner vs member) ---
Write-Host "[5/5] Manual steps remaining (cannot be automated):" -ForegroundColor Yellow
Write-Host ""
if ($Member) {
    Write-Host "  A. Keys (yours + 1 studio handover, never in chat):" -ForegroundColor White
    Write-Host "     GITHUB_PERSONAL_ACCESS_TOKEN     => your free key, FIRST (private repo needs it)"
    Write-Host "     HCNSEC_API_KEY                   => studio-labeled key, handed over by the owner"
    Write-Host "     GEMINI_API_KEY                   => your free Google AI Studio key"
    Write-Host "     TAVILY_API_KEY                   => your free key"
    Write-Host "     SENTRY_AUTH_TOKEN                => optional day one, skip freely"
    Write-Host "     (skip AIHUBMIX_API_KEY - owner only)"
    Write-Host "     Windows: setx NAME 'value' | Linux: export NAME='value' in ~/.bashrc"
    Write-Host ""
    Write-Host "  B. Logins (your own accounts):" -ForegroundColor White
    Write-Host "     opencode mcp auth sentry   (optional day one)"
    Write-Host "     SKIP supabase + vercel logins (owner only)"
    Write-Host "     /models menu: ollama-cloud, opencode-go, nvidia, google (your own)"
    Write-Host ""
    Write-Host "  C. Verify (must be green):" -ForegroundColor White
    Write-Host "     pwsh scripts/verify-setup.ps1 -Member"
    Write-Host ""
} else {
Write-Host ""
Write-Host "  A. Set 6 API-key env vars (User scope):" -ForegroundColor White
Write-Host "     HCNSEC_API_KEY                  => hcnsec.cn (51-char sk-... key)"
Write-Host "     AIHUBMIX_API_KEY                 => aihubmix.com (51-char sk-... key)"
Write-Host "     GEMINI_API_KEY                   => Google AI Studio (53-char AQ.... key)"
Write-Host "     TAVILY_API_KEY                   => tavily.com"
Write-Host "     SENTRY_AUTH_TOKEN                => sentry.io"
Write-Host "     GITHUB_PERSONAL_ACCESS_TOKEN     => github.com/settings/tokens (repo scope)"
Write-Host "     Use: setx VARNAME 'value' (User scope, persists across restarts)"
Write-Host ""
Write-Host "  B. Re-auth 3 OAuth MCP servers:" -ForegroundColor White
Write-Host "     opencode mcp auth sentry"
Write-Host "     opencode mcp auth supabase"
Write-Host "     opencode mcp auth vercel"
Write-Host ""
Write-Host "  C. Log in 4 auth.json providers via /models menu:" -ForegroundColor White
Write-Host "     opencode-go      (opencode-go   / sk-W8GXu...)"
Write-Host "     ollama-cloud     (ollama-cloud  / API key)"
Write-Host "     nvidia           (nvidia        / nvapi-W1yyV...)"
Write-Host "     google           (google        / AQ.Ab8R...)"
Write-Host "     (Or restore auth.json from a secure backup to:"
Write-Host "      $env:USERPROFILE\.local\share\opencode\auth.json)"
Write-Host ""
Write-Host "  D. Reinstall user skill packs (run from workspace root):" -ForegroundColor White
Write-Host "     npx skills add vercel-deploy-claude-code-plugin    # creates .agents/skills/{deploy,logs,setup,vercel-cli}"
Write-Host "     # See README.md for the full list of 79 user-installed skills"
Write-Host "     # (most live outside the workspace, in ~/.agents/skills/ and ~/.config/opencode/skills/)"
Write-Host "     # If any skill is unavailable, skip it - opencode continues without it."
Write-Host ""
} # end owner manual steps
Write-Host "=== Setup complete. Restart opencode for env vars to take effect. ===" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Restart any open opencode sessions so the new env vars are picked up." -ForegroundColor Cyan
