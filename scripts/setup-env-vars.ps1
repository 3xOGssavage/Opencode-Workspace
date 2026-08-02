#Requires -Version 5.1
<#
.SYNOPSIS
  Idempotent setup script for the opencode workspace on a new (or same) machine.
.DESCRIPTION
  1. Auto-detects its parent dir as $WorkspaceRoot (no hardcoding).
  2. Sets 4 User env vars pointing into the workspace (or prints them in DryRun).
  3. Copies global-config\* to %USERPROFILE%\.config\opencode\ (overwrites).
  4. Runs `npm install` in that target dir (reproducible via package-lock.json).
  5. Regex-replaces the original clone path in opencode.json with $WorkspaceRoot
     so the 12 absolute paths (skills.paths, permission.edit.deny, mcp.command)
     resolve correctly on this machine.
  6. Configures `git config core.hooksPath .githooks` so the pre-commit secret
     guard is portable across clones.
  7. Prints the manual steps the user still must complete (API keys, MCP auth,
     skill installs, provider logins).
.PARAMETER DryRun
  Switch: simulate every action, modify nothing. Use to test the setup script
  on a new machine before committing to real changes.
.NOTES
  Re-runnable. Overwrites env vars + global-config files each time (unless -DryRun).
  Does NOT touch auth.json, mcp-auth.json, or any API-key env var.
#>
[CmdletBinding()]
param(
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$WorkspaceRoot = $PSScriptRoot | Split-Path -Parent
if ($DryRun) {
  Write-Host "=== opencode workspace setup (DRY RUN) ===" -ForegroundColor Magenta
  Write-Host "No changes will be made. Add -DryRun:$false to execute for real." -ForegroundColor Magenta
} else {
  Write-Host "=== opencode workspace setup ===" -ForegroundColor Cyan
}
Write-Host "Detected workspace: $WorkspaceRoot"
Write-Host ""

function Invoke-Step {
  param([string]$Desc, [scriptblock]$Action, [scriptblock]$DryPreview)
  if ($DryRun) {
    Write-Host "[DRY] $Desc" -ForegroundColor Magenta
    & $DryPreview
  } else {
    Write-Host $Desc -ForegroundColor Yellow
    & $Action
  }
  Write-Host ""
}

# --- 1. Set 4 User env vars (idempotent) ---
Invoke-Step "[1/6] Setting User env vars..." {
  [Environment]::SetEnvironmentVariable('OPENCODE_CONFIG', "$WorkspaceRoot\opencode.json", 'User')
  [Environment]::SetEnvironmentVariable('OPENCODE_CONFIG_DIR', "$WorkspaceRoot\.opencode", 'User')
  [Environment]::SetEnvironmentVariable('MEMORY_FILE_PATH', "$WorkspaceRoot\.opencode\memory.jsonl", 'User')
  [Environment]::SetEnvironmentVariable('OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS', 'true', 'User')
  Write-Host "  OPENCODE_CONFIG                        = $WorkspaceRoot\opencode.json"
  Write-Host "  OPENCODE_CONFIG_DIR                    = $WorkspaceRoot\.opencode"
  Write-Host "  MEMORY_FILE_PATH                       = $WorkspaceRoot\.opencode\memory.jsonl"
  Write-Host "  OPENCODE_EXPERIMENTAL_BACKGROUND_...   = true"
} {
  Write-Host "  Would set: OPENCODE_CONFIG                        = $WorkspaceRoot\opencode.json"
  Write-Host "  Would set: OPENCODE_CONFIG_DIR                    = $WorkspaceRoot\.opencode"
  Write-Host "  Would set: MEMORY_FILE_PATH                       = $WorkspaceRoot\.opencode\memory.jsonl"
  Write-Host "  Would set: OPENCODE_EXPERIMENTAL_BACKGROUND_...   = true"
}

# --- 2. Copy global-config files to ~/.config/opencode/ (idempotent) ---
$TargetConfigDir = Join-Path $env:USERPROFILE '.config\opencode'
$globalConfigSrc = Join-Path $WorkspaceRoot 'global-config'
Invoke-Step "[2/6] Copying global-config to $TargetConfigDir ..." {
  if (-not (Test-Path $TargetConfigDir)) { New-Item -ItemType Directory -Path $TargetConfigDir -Force | Out-Null }
  if (-not (Test-Path $globalConfigSrc)) {
    Write-Host "  ERROR: global-config\ not found at $globalConfigSrc" -ForegroundColor Red
  } else {
    Get-ChildItem -Path $globalConfigSrc -File | Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
      Copy-Item -Path $_.FullName -Destination (Join-Path $TargetConfigDir $_.Name) -Force
      Write-Host "  Copied: $($_.Name)"
    }
  }
} {
  if (-not (Test-Path $globalConfigSrc)) {
    Write-Host "  ERROR: global-config\ not found at $globalConfigSrc"
  } else {
    Write-Host "  Would create: $TargetConfigDir (if missing)"
    Get-ChildItem -Path $globalConfigSrc -File | Where-Object { $_.Name -ne 'README.md' } | ForEach-Object {
      Write-Host "  Would copy: $($_.Name) -> $(Join-Path $TargetConfigDir $_.Name)"
    }
  }
}

# --- 3. npm install in target config dir (idempotent) ---
Invoke-Step "[3/6] Running npm install in $TargetConfigDir ..." {
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "  WARN: npm not found. Install Node 18+ then re-run." -ForegroundColor Red
  } else {
    Push-Location $TargetConfigDir
    try {
      & npm install --no-audit --no-fund 2>&1 | Out-Host
      Write-Host "  npm install complete." -ForegroundColor Green
    } catch {
      Write-Host "  WARN: npm install failed: $_" -ForegroundColor Red
    } finally { Pop-Location }
  }
} {
  if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "  Would run npm install, but npm not found."
  } else {
    Write-Host "  Would run: npm install --no-audit --no-fund (in $TargetConfigDir)"
    Write-Host "  Uses package-lock.json for reproducible versions."
  }
}

# --- 4. Regex-replace absolute paths in opencode.json (PORTABILITY FIX) ---
$opencodeJsonPath = Join-Path $WorkspaceRoot 'opencode.json'
$originalPath = 'F:\CD\Opencode'
$escapedOriginal = [regex]::Escape($originalPath)
$newPathJson = $WorkspaceRoot -replace '\\', '\\\\'
Invoke-Step "[4/6] Normalizing absolute paths in opencode.json..." {
  if (-not (Test-Path $opencodeJsonPath)) {
    Write-Host "  ERROR: opencode.json not found at $opencodeJsonPath" -ForegroundColor Red
  } else {
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
} {
  if (-not (Test-Path $opencodeJsonPath)) {
    Write-Host "  opencode.json not found at $opencodeJsonPath"
  } else {
    $content = Get-Content -Path $opencodeJsonPath -Raw
    $count = ([regex]::Matches($content, $escapedOriginal)).Count
    if ($count -gt 0) {
      Write-Host "  Would replace $count occurrences of '$originalPath' with '$WorkspaceRoot'"
    } else {
      Write-Host "  No path replacements needed (clone path already matches or opencode.json unchanged)"
    }
  }
}

# --- 5. Configure git hooksPath for portable pre-commit guard ---
Invoke-Step "[5/6] Configuring git core.hooksPath = .githooks ..." {
  if (Test-Path (Join-Path $WorkspaceRoot '.githooks/pre-commit')) {
    git config core.hooksPath .githooks
    Write-Host "  core.hooksPath = .githooks (pre-commit secret guard active)"
  } else {
    Write-Host "  .githooks/pre-commit not found - skipping. (Hooks not in this clone?)"
  }
} {
  if (Test-Path (Join-Path $WorkspaceRoot '.githooks/pre-commit')) {
    Write-Host "  Would run: git config core.hooksPath .githooks"
    Write-Host "  Pre-commit hook would activate after this step."
  } else {
    Write-Host "  .githooks/pre-commit not found in this clone - would skip."
  }
}

# --- 6. Print manual steps ---
Write-Host "[6/6] Manual steps remaining (cannot be automated):" -ForegroundColor Yellow
Write-Host ""
Write-Host "  A. Set 6 API-key env vars (User scope):" -ForegroundColor White
Write-Host "     HCNSEC_API_KEY                  => hcnsec.cn (51-char sk-... key)"
Write-Host "     TOKENROUTER_API_KEY              => tokenrouter.com (51 chars)"
Write-Host "     GEMINI_API_KEY                   => Google AI Studio (AQ.... key)"
Write-Host "     TAVILY_API_KEY                   => tavily.com"
Write-Host "     SENTRY_AUTH_TOKEN                => sentry.io"
Write-Host "     GITHUB_PERSONAL_ACCESS_TOKEN     => github.com/settings/tokens (repo scope)"
Write-Host "     Use: setx VARNAME 'value'"
Write-Host ""
Write-Host "  B. Re-auth 4 OAuth MCP servers:" -ForegroundColor White
Write-Host "     opencode mcp auth composio"
Write-Host "     opencode mcp auth sentry"
Write-Host "     opencode mcp auth supabase"
Write-Host "     opencode mcp auth vercel"
Write-Host ""
Write-Host "  C. Log in 4 auth.json providers via /models menu:" -ForegroundColor White
Write-Host "     opencode-go, ollama-cloud, nvidia, google"
Write-Host "     (Or restore auth.json from secure backup to:"
Write-Host "      $env:USERPROFILE\.local\share\opencode\auth.json)"
Write-Host ""
Write-Host "  D. Reinstall user skill packs (see README for full list):" -ForegroundColor White
Write-Host "     npx skills add vercel-deploy-claude-code-plugin"
Write-Host "     # See README.md for the full list of 75+ user-installed skills"
Write-Host ""

if ($DryRun) {
  Write-Host "=== DRY RUN complete. Re-run without -DryRun to apply. ===" -ForegroundColor Magenta
} else {
  Write-Host "=== Setup complete. Restart opencode for env vars to take effect. ===" -ForegroundColor Green
  Write-Host ""
  Write-Host "IMPORTANT: Restart any open opencode sessions so new env vars + hooks are picked up." -ForegroundColor Cyan
}
