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
  Does NOT touch auth.json, mcp-auth.json, or any API-key env var.
#>

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = $PSScriptRoot | Split-Path -Parent
Write-Host "=== opencode workspace setup ===" -ForegroundColor Cyan
Write-Host "Detected workspace: $WorkspaceRoot"
Write-Host ""

# --- 1. Set 4 User env vars (idempotent) ---
Write-Host "[1/5] Setting User env vars..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable('OPENCODE_CONFIG', "$WorkspaceRoot\opencode.json", 'User')
[Environment]::SetEnvironmentVariable('OPENCODE_CONFIG_DIR', "$WorkspaceRoot\.opencode", 'User')
[Environment]::SetEnvironmentVariable('MEMORY_FILE_PATH', "$WorkspaceRoot\.opencode\memory.jsonl", 'User')
[Environment]::SetEnvironmentVariable('OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS', 'true', 'User')
Write-Host "  OPENCODE_CONFIG                        = $WorkspaceRoot\opencode.json"
Write-Host "  OPENCODE_CONFIG_DIR                    = $WorkspaceRoot\.opencode"
Write-Host "  MEMORY_FILE_PATH                       = $WorkspaceRoot\.opencode\memory.jsonl"
Write-Host "  OPENCODE_EXPERIMENTAL_BACKGROUND_...   = true"
Write-Host ""

# --- 2. Copy global-config files to ~/.config/opencode/ (idempotent) ---
Write-Host "[2/5] Copying global-config to ~/.config/opencode/..." -ForegroundColor Yellow
$TargetConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
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
}
Write-Host ""

# --- 5. Print manual steps ---
Write-Host "[5/5] Manual steps remaining (cannot be automated):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  A. Set 6 API-key env vars (User scope):" -ForegroundColor White
Write-Host "     HCNSEC_API_KEY                  => hcnsec.cn (51-char sk-... key)"
Write-Host "     TOKENROUTER_API_KEY              => tokenrouter.com (51-char sk-... key)"
Write-Host "     GEMINI_API_KEY                   => Google AI Studio (53-char AQ.... key)"
Write-Host "     TAVILY_API_KEY                   => tavily.com"
Write-Host "     SENTRY_AUTH_TOKEN                => sentry.io"
Write-Host "     GITHUB_PERSONAL_ACCESS_TOKEN     => github.com/settings/tokens (repo scope)"
Write-Host "     Use: setx VARNAME 'value' (User scope, persists across restarts)"
Write-Host ""
Write-Host "  B. Re-auth 4 OAuth MCP servers:" -ForegroundColor White
Write-Host "     opencode mcp auth composio"
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
Write-Host "=== Setup complete. Restart opencode for env vars to take effect. ===" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Restart any open opencode sessions so the new env vars are picked up." -ForegroundColor Cyan
