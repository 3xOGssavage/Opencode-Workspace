# verify-setup.ps1
# Comprehensive 12-check post-setup verification. Cross-platform: runs on
# Windows (PowerShell 5.1+ / pwsh) and Linux/macOS (pwsh 7+). Soft-skips on
# Linux/CI for Windows-only checks (env var User scope, auth.json location).
#
# Usage:
#   pwsh scripts/verify-setup.ps1
#   pwsh scripts/verify-setup.ps1 -Verbose

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$failures = 0
$warnings = 0
$ok = 0

$IsWin = (-not $PSVersionTable.Platform) -or ($PSVersionTable.Platform -eq 'Win32NT')
$root = Split-Path $PSScriptRoot -Parent

function PrintOk  { param($msg) Write-Host "    [OK] $msg" -ForegroundColor Green; $script:ok++ }
function PrintWarn{ param($msg) Write-Host "    [WARN] $msg" -ForegroundColor Yellow; $script:warnings++ }
function PrintFail{ param($msg) Write-Host "    [FAIL] $msg" -ForegroundColor Red; $script:failures++ }

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Opencode Workspace Setup Verification" -ForegroundColor Cyan
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Check 1-4 in batch: env vars (User scope on Win, exported in current shell on Linux)
Write-Host "[1-4] Checking 4 setup env vars..." -ForegroundColor Yellow
$envVars = @('OPENCODE_CONFIG', 'OPENCODE_CONFIG_DIR', 'MEMORY_FILE_PATH', 'OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS')
foreach ($var in $envVars) {
    if ($IsWin) {
        $v = [Environment]::GetEnvironmentVariable($var, 'User')
    } else {
        $v = (Get-ChildItem "env:$var" -ErrorAction SilentlyContinue).Value
    }
    if ($v) {
        PrintOk "$var = $v (length $($v.Length))"
    } else {
        # Check Process scope as fallback (setx may not have propagated)
        $pv = [Environment]::GetEnvironmentVariable($var, 'Process')
        if ($pv) {
            PrintOk "$var (Process scope only): $pv"
        } else {
            PrintWarn "$var not set - run scripts/setup-env-vars.ps1"
        }
    }
}

# Check 5-11 in batch: 7 secret API keys (no values printed)
Write-Host "[5-11] Checking 7 secret env vars (no values printed)..." -ForegroundColor Yellow
$secretVars = @('HCNSEC_API_KEY', 'TOKENROUTER_API_KEY', 'AIHUBMIX_API_KEY', 'GEMINI_API_KEY', 'TAVILY_API_KEY', 'SENTRY_AUTH_TOKEN', 'GITHUB_PERSONAL_ACCESS_TOKEN')
foreach ($var in $secretVars) {
    if ($IsWin) {
        $v = [Environment]::GetEnvironmentVariable($var, 'User')
    } else {
        $v = (Get-ChildItem "env:$var" -ErrorAction SilentlyContinue).Value
    }
    if ($v) {
        $shape = 'unknown'
        if ($v.Length -ge 4) { $shape = $v.Substring(0, 4) }
        PrintOk "$var (length $($v.Length), starts '$shape...')"
    } else {
        # Process scope fallback
        $pv = [Environment]::GetEnvironmentVariable($var, 'Process')
        if ($pv) {
            PrintOk "$var (Process scope only, length $($pv.Length))"
        } else {
            PrintWarn "$var not set - run scripts/set-secrets.ps1"
        }
    }
}

# Check 12: parent opencode.json exists + parses + has hcnsec + aihubmix
Write-Host "[12] Checking parent opencode.json..." -ForegroundColor Yellow
$ocPath = Join-Path $root 'opencode.json'
if (Test-Path $ocPath) {
    try {
        $oc = Get-Content $ocPath -Raw | ConvertFrom-Json
        if ($oc.provider.hcnsec) {
            $hcnModels = ($oc.provider.hcnsec.models.PSObject.Properties | Measure-Object).Count
            PrintOk "parent opencode.json parses; hcnsec has $hcnModels models"
        } else { PrintFail "hcnsec provider MISSING in opencode.json" }
        if ($oc.provider.aihubmix) {
            $amModels = ($oc.provider.aihubmix.models.PSObject.Properties | Measure-Object).Count
            PrintOk "parent opencode.json parses; aihubmix has $amModels models (expect 44)"
            if ($amModels -ne 44) {
                PrintWarn "aihubmix has $amModels models (expected 44 after glm-5.2-free exclusion)"
            }
        } else { PrintFail "aihubmix provider MISSING in opencode.json" }
    } catch {
        PrintFail "parent opencode.json parse error: $_"
    }
} else {
    PrintFail "parent opencode.json MISSING at $ocPath"
}

# Check 13: parent .opencode dir has agents/ commands/ skills/
Write-Host "[13] Checking parent .opencode subdirs..." -ForegroundColor Yellow
$criticalSubdirs = @('agents', 'commands', 'skills')
foreach ($sub in $criticalSubdirs) {
    $p = Join-Path $root ".opencode\$sub"
    if (Test-Path $p) {
        $c = (Get-ChildItem $p | Measure-Object).Count
        if ($c -gt 0) { PrintOk ".opencode/$sub/ ($c items)" }
        else { PrintWarn ".opencode/$sub/ is EMPTY" }
    } else {
        PrintWarn ".opencode/$sub/ MISSING"
    }
}

# Check 14: memory-mcp-wrapper.bat resolves to existing memory.jsonl
Write-Host "[14] Checking memory-mcp-wrapper + memory.jsonl..." -ForegroundColor Yellow
$wrapperPath = Join-Path $root '.opencode\memory-mcp-wrapper.bat'
$memFile = $env:MEMORY_FILE_PATH
if (-not $memFile) { $memFile = Join-Path $root '.opencode\memory.jsonl' }
if ((Test-Path $wrapperPath) -and (Test-Path $memFile)) {
    PrintOk "memory-mcp-wrapper.bat + memory.jsonl both resolve"
} elseif (Test-Path $wrapperPath) {
    PrintWarn "wrapper exists but memory.jsonl not found at $memFile (will be auto-created on first write)"
} else {
    PrintWarn "memory-mcp-wrapper.bat missing at $wrapperPath"
}

# Check 15: ~/.local/share/opencode/auth.json exists + parses + has 4 providers
Write-Host "[15] Checking auth.json..." -ForegroundColor Yellow
$authPath = if ($IsWin) { Join-Path $env:USERPROFILE '.local\share\opencode\auth.json' } else { Join-Path $env:HOME '.local\share\opencode\auth.json' }
if (Test-Path $authPath) {
    try {
        $auth = Get-Content $authPath -Raw | ConvertFrom-Json
        $providers = $auth.PSObject.Properties.Name -join ', '
        if ($providers) {
            PrintOk "auth.json present; providers: $providers"
        } else {
            PrintWarn "auth.json is empty - log in via /models menu in opencode TUI"
        }
    } catch {
        PrintFail "auth.json parse error: $_"
    }
} else {
    PrintWarn "auth.json not found at $authPath - see ONBOARDING.md Step 8"
}

# Check 16: mcp-auth.json has 4 MCP entries each with `tokens`
Write-Host "[16] Checking mcp-auth.json..." -ForegroundColor Yellow
$mcpAuthPath = if ($IsWin) { Join-Path $env:USERPROFILE '.local\share\opencode\mcp-auth.json' } else { Join-Path $env:HOME '.local\share\opencode\mcp-auth.json' }
if (Test-Path $mcpAuthPath) {
    try {
        $mcpAuth = Get-Content $mcpAuthPath -Raw | ConvertFrom-Json
        $mcps = $mcpAuth.PSObject.Properties.Name
        if ($mcps) {
            $okCount = 0
            foreach ($m in $mcps) {
                if ($mcpAuth.$m.tokens) { $okCount++ }
            }
            if ($okCount -eq $mcps.Count) {
                PrintOk "mcp-auth.json: $($mcps.Count) MCPs all have tokens ($($mcps -join ', '))"
            } else {
                PrintWarn "mcp-auth.json: $okCount/$($mcps.Count) MCPs have tokens - run scripts/auth-mcp-servers.ps1"
            }
        } else {
            PrintWarn "mcp-auth.json is empty - run scripts/auth-mcp-servers.ps1"
        }
    } catch {
        PrintFail "mcp-auth.json parse error: $_"
    }
} else {
    PrintWarn "mcp-auth.json not found - run scripts/auth-mcp-servers.ps1"
}

# Check 17: ~/.agents/skills + ~/.config/opencode/skills have >= 50 skills total
Write-Host "[17] Checking user skill count..." -ForegroundColor Yellow
$sk1 = if ($IsWin) { Join-Path $env:USERPROFILE '.agents\skills' } else { Join-Path $env:HOME '.agents\skills' }
$sk2 = if ($IsWin) { Join-Path $env:USERPROFILE '.config\opencode\skills' } else { Join-Path $env:HOME '.config\opencode\skills' }
$count1 = if (Test-Path $sk1) { (Get-ChildItem $sk1 -Directory | Measure-Object).Count } else { 0 }
$count2 = if (Test-Path $sk2) { (Get-ChildItem $sk2 -Directory | Measure-Object).Count } else { 0 }
$total = $count1 + $count2
if ($total -ge 50) {
    PrintOk "$total skills installed (sk1=$count1, sk2=$count2)"
} elseif ($total -gt 0) {
    PrintWarn "only $total skills installed - run scripts/install-user-skills.ps1 + scripts/clone-vendored-skill-packs.ps1"
} else {
    PrintWarn "no user skills installed - run scripts/install-user-skills.ps1 + scripts/clone-vendored-skill-packs.ps1"
}

# Check 18: AIHUBMIX_API_KEY set (verify-setup check verified separately in 5-11 batch,
#          adding explicit one since it was the most recently added secret)
Write-Host "[18] Checking AIHUBMIX_API_KEY specifically..." -ForegroundColor Yellow
$amKey = if ($IsWin) { [Environment]::GetEnvironmentVariable('AIHUBMIX_API_KEY', 'User') } else { $env:AIHUBMIX_API_KEY }
if ($amKey) {
    PrintOk "AIHUBMIX_API_KEY set (length $($amKey.Length))"
} else {
    PrintWarn "AIHUBMIX_API_KEY not set - aihubmix/* models won't authenticate"
}

# Check 19: run verify-inheritance.ps1
Write-Host "[19] Running verify-inheritance.ps1..." -ForegroundColor Yellow
$viPath = Join-Path $root '.opencode\verify-inheritance.ps1'
if (Test-Path $viPath) {
    try {
        # Try pwsh (PowerShell 7+ cross-platform); fall back to powershell.exe on Windows
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        $psCmd  = Get-Command powershell -ErrorAction SilentlyContinue
        if ($pwshCmd) {
            & pwsh -NoProfile -File $viPath 2>&1 | Out-Host
        } elseif ($psCmd) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $viPath 2>&1 | Out-Host
        } else {
            PrintWarn "no pwsh or powershell found in PATH; verify-inheritance skipped"
        }
        # verify-inheritance's own summary is authoritative; this checks no parse-failure
    } catch {
        PrintFail "verify-inheritance.ps1 invocation error: $_"
    }
} else {
    PrintWarn "verify-inheritance.ps1 not found at $viPath"
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " RESULT: $ok OK, $warnings warnings, $failures failures" -ForegroundColor $(if ($failures -eq 0) { 'Green' } else { 'Red' })
if ($failures -eq 0 -and $warnings -gt 0) {
    Write-Host " All REQUIRED checks passed. Warnings indicate optional setups." -ForegroundColor Yellow
}
Write-Host "===========================================" -ForegroundColor Cyan

if ($failures -gt 0) { exit 1 }
exit 0
