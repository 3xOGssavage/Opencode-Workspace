# check-prerequisites.ps1
# Verifies the minimum toolchain required to onboard onto this workspace.
# Cross-platform (Windows PowerShell 5.1+, PowerShell 7+, Linux/macOS pwsh).
# Exits 0 if all required prereqs present (with warnings for soft checks).
# Exits 1 if any required prereq is missing.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/check-prerequisites.ps1
#   pwsh scripts/check-prerequisites.ps1

$ErrorActionPreference = "Stop"
$failures = 0
$warnings = 0

# ponytail: minimum versions chosen to match what this workspace was tested on
$REQUIRED = @{
    Node    = [version]'18.17.0'
    Python  = [version]'3.10.0'
    Opencode = [version]'1.18.11'
}
$TESTED_OPENCODE = [version]'1.18.19'

function Test-Command {
    param([string]$Name)
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

function Get-VersionString {
    param([string]$Cmd)
    try {
        & $Cmd --version 2>&1 | Select-Object -First 1 | Out-String -OutVariable v
        return ($v.Trim())
    } catch { return $null }
}

function Parse-Version {
    param([string]$VersionString)
    if (-not $VersionString) { return $null }
    $match = [regex]::Match($VersionString, '(\d+\.\d+(?:\.\d+)?)')
    if ($match.Success) { return [version]$match.Groups[1].Value }
    return $null
}

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Opencode Workspace Prerequisites Check" -ForegroundColor Cyan
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Required: git
Write-Host "[1] Checking git..." -ForegroundColor Yellow
$gitPath = Test-Command 'git'
if ($gitPath) {
    $gitVer = Get-VersionString 'git'
    Write-Host "    [OK] git found: $gitVer" -ForegroundColor Green
} else {
    Write-Host "    [FAIL] git not found. Install from https://git-scm.com/" -ForegroundColor Red
    $failures++
}

# Required: node
Write-Host "[2] Checking Node.js (>= $($REQUIRED.Node))..." -ForegroundColor Yellow
$nodePath = Test-Command 'node'
if ($nodePath) {
    $nodeVer = Parse-Version (Get-VersionString 'node')
    if ($nodeVer -and $nodeVer -ge $REQUIRED.Node) {
        Write-Host "    [OK] Node $nodeVer found" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] Node $nodeVer found, need >= $($REQUIRED.Node). Upgrade via https://nodejs.org/" -ForegroundColor Red
        $failures++
    }
} else {
    Write-Host "    [FAIL] Node not found. Install from https://nodejs.org/" -ForegroundColor Red
    $failures++
}

# Required: npm (ships with Node, separate check)
Write-Host "[3] Checking npm..." -ForegroundColor Yellow
$npmPath = Test-Command 'npm'
if ($npmPath) { Write-Host "    [OK] npm found" -ForegroundColor Green }
else {
    Write-Host "    [FAIL] npm not found (should ship with Node)" -ForegroundColor Red
    $failures++
}

# Required: npx (ships with Node)
Write-Host "[4] Checking npx..." -ForegroundColor Yellow
$npxPath = Test-Command 'npx'
if ($npxPath) { Write-Host "    [OK] npx found" -ForegroundColor Green }
else {
    Write-Host "    [FAIL] npx not found (should ship with Node)" -ForegroundColor Red
    $failures++
}

# Required: Python
Write-Host "[5] Checking Python (>= $($REQUIRED.Python))..." -ForegroundColor Yellow
$pyPath = Test-Command 'python'
if (-not $pyPath) { $pyPath = Test-Command 'python3' }
if ($pyPath) {
    $pyVer = Parse-Version (Get-VersionString ($pyPath | Split-Path -Leaf))
    if (-not $pyVer) {
        $pyVer = Parse-Version (& python --version 2>&1 | Out-String)
    }
    if ($pyVer -and $pyVer -ge $REQUIRED.Python) {
        Write-Host "    [OK] Python $pyVer found" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] Python $pyVer found, need >= $($REQUIRED.Python). Upgrade via https://www.python.org/" -ForegroundColor Red
        $failures++
    }
} else {
    Write-Host "    [WARN] Python not found. Some MCP servers (fetch, vision-tool) need it." -ForegroundColor Yellow
    $warnings++
}

# Required: opencode CLI
Write-Host "[6] Checking opencode CLI (>= $($REQUIRED.Opencode))..." -ForegroundColor Yellow
$ocPath = Test-Command 'opencode'
if ($ocPath) {
    $ocVer = Parse-Version (Get-VersionString 'opencode')
    if ($ocVer -and $ocVer -ge $REQUIRED.Opencode) {
        Write-Host "    [OK] opencode $ocVer found" -ForegroundColor Green
        if ($ocVer -gt $TESTED_OPENCODE) {
            Write-Host "    [WARN] Workspace tested on $TESTED_OPENCODE; you have $ocVer" -ForegroundColor Yellow
            Write-Host "           If prompts look off, pin via: npm install -g opencode-ai@$TESTED_OPENCODE" -ForegroundColor Yellow
            $warnings++
        }
    } else {
        Write-Host "    [FAIL] opencode $ocVer found, need >= $($REQUIRED.Opencode)" -ForegroundColor Red
        Write-Host "           Install via: npm install -g opencode-ai@$TESTED_OPENCODE" -ForegroundColor Red
        $failures++
    }
} else {
    Write-Host "    [FAIL] opencode CLI not found." -ForegroundColor Red
    Write-Host "           Install via: npm install -g opencode-ai@$TESTED_OPENCODE" -ForegroundColor Red
    $failures++
}

# Required: PowerShell 5.1+ (Windows) or pwsh 7+ (Linux/macOS)
Write-Host "[7] Checking PowerShell..." -ForegroundColor Yellow
$psVer = $PSVersionTable.PSVersion
if ($PSVersionTable.Platform -eq 'Unix') {
    if ($psVer.Major -ge 7) {
        Write-Host "    [OK] pwsh $psVer (Linux/macOS)" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] pwsh >=7 required on Linux/macOS; found $psVer" -ForegroundColor Red
        Write-Host "           Install: https://github.com/PowerShell/PowerShell#get-powershell" -ForegroundColor Red
        $failures++
    }
} else {
    if ($psVer.Major -ge 5) {
        Write-Host "    [OK] Windows PowerShell $psVer" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] PowerShell 5.1+ required; found $psVer" -ForegroundColor Red
        $failures++
    }
}

# Optional but recommended: GitHub SSH key (for sub-repos in Projects/)
Write-Host "[8] Checking SSH key for GitHub (optional)..." -ForegroundColor Yellow
# Cross-platform home dir: $env:HOME is null on Windows runners (which use
# $env:USERPROFILE); $env:USERPROFILE is null on Linux. Resolve before Join-Path
# so Join-Path never receives a null first argument (would throw on PS 5.1/7).
$homeDir = if ($env:HOME) { $env:HOME }
           elseif ($env:USERPROFILE) { $env:USERPROFILE }
           else { [Environment]::GetFolderPath('UserProfile') }
$sshDir = if ($homeDir) { Join-Path $homeDir '.ssh' } else { $null }
$sshKey = $null
if ($sshDir -and (Test-Path $sshDir)) {
    $sshKey = Get-ChildItem $sshDir -Filter 'id_*' -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -notmatch '\.pub$' -and $_.Name -notmatch 'known_hosts' } |
              Select-Object -First 1
}
if ($sshKey) {
    Write-Host "    [OK] SSH key found at $($sshKey.FullName)" -ForegroundColor Green
    Write-Host "         Required for cloning sub-repos in Projects/ (git@github.com:...)" -ForegroundColor DarkGray
} else {
    $sshDirDisplay = if ($sshDir) { $sshDir } else { '<HOME>/.ssh (HOME not set on this runner)' }
    Write-Host "    [WARN] No SSH key found in $sshDirDisplay" -ForegroundColor Yellow
    Write-Host "           Sub-repos in Projects/ use SSH; generate: ssh-keygen -t ed25519 -C 'you@'" -ForegroundColor Yellow
    $warnings++
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
if ($failures -eq 0) {
    Write-Host " RESULT: ALL REQUIRED PREREQS PRESENT ($warnings warnings)" -ForegroundColor Green
    if ($warnings -gt 0) {
        Write-Host " Warnings are non-blocking but may limit some MCP servers/sub-repos" -ForegroundColor Yellow
    }
    Write-Host " Next: run scripts/setup-env-vars.ps1" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host " RESULT: $failures PREREQ(S) MISSING - fix above before proceeding" -ForegroundColor Red
    Write-Host "===========================================" -ForegroundColor Cyan
    exit 1
}
