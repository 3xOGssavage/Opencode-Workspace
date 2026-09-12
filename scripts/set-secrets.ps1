# set-secrets.ps1
# Interactive prompts for 7 User-scope env var API keys. Cross-platform:
# Windows uses setx (User scope) + Process scope for the current shell;
# Linux/macOS prints export lines for ~/.bashrc or ~/.zshrc (same keys).
# Soft validation (warn-not-fail) per Plan V8 C3.9. Never prints key fragments.
#
# Non-interactive mode: read values from a local gitignored file via
# $env:OC_SECRETS_FILE (file path; contents are KEY=VALUE lines).
#
# Usage:
#   pwsh scripts/set-secrets.ps1
#   pwsh scripts/set-secrets.ps1 -Member   # teammates: owner-only keys skipped
#   $env:OC_SECRETS_FILE = "$HOME\secrets.local.ps1"; pwsh scripts/set-secrets.ps1
#   pwsh scripts/set-secrets.ps1 -DryRun

[CmdletBinding()]
param([switch]$DryRun, [switch]$Member)

$ErrorActionPreference = "Stop"

# (key, label, expected-prefix-or-shape, expected-min-length, expected-max-length)
$secretSpec = @(
    @{ Key='HCNSEC_API_KEY';                Label='hcnsec.cn AI provider';     Shape='sk-';   MinLen=40; MaxLen=80 },
    @{ Key='AIHUBMIX_API_KEY';              Label='aihubmix.com (44 models)';  Shape='sk-';   MinLen=40; MaxLen=80 },
    @{ Key='GEMINI_API_KEY';                Label='Google AI Studio';          Shape='AQ.';    MinLen=40; MaxLen=80 },
    @{ Key='NVIDIA_API_KEY';                Label='Nvidia build.nvidia.com';     Shape='nvapi-'; MinLen=40; MaxLen=100 },
    @{ Key='TAVILY_API_KEY';                Label='tavily.com (web search)';   Shape='tvly-';  MinLen=20; MaxLen=80 },
    @{ Key='SENTRY_AUTH_TOKEN';             Label='sentry.io (production)';    Shape='sntrys_'; MinLen=20; MaxLen=120 },
    @{ Key='GITHUB_PERSONAL_ACCESS_TOKEN';  Label='GitHub (gh CLI + MCP)';     Shape='ghp_';   MinLen=30; MaxLen=80 }
)

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " Opencode Workspace Secrets Setter" -ForegroundColor Cyan
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

if ($PSVersionTable.Platform -eq 'Unix') {
    Write-Host "[WARN] This script is Windows-focused (uses setx)." -ForegroundColor Yellow
    Write-Host "       Linux/macOS: copy the printed export lines to ~/.bashrc or ~/.zshrc" -ForegroundColor Yellow
    Write-Host ""
}

# Non-interactive mode: read KEY=VALUE lines from $env:OC_SECRETS_FILE
$fileSecrets = @{}
if ($env:OC_SECRETS_FILE) {
    if (-not (Test-Path $env:OC_SECRETS_FILE)) {
        Write-Host "[FAIL] OC_SECRETS_FILE set but file not found: $($env:OC_SECRETS_FILE)" -ForegroundColor Red
        exit 1
    }
    Write-Host "[info] Reading secrets from $($env:OC_SECRETS_FILE)" -ForegroundColor Cyan
    Get-Content $env:OC_SECRETS_FILE | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $idx = $line.IndexOf('=')
            if ($idx -gt 0) {
                $k = $line.Substring(0, $idx).Trim()
                $v = $line.Substring($idx + 1).Trim()
                $fileSecrets[$k] = $v
            }
        }
    }
    Write-Host "[info] Loaded $($fileSecrets.Count) secrets from file" -ForegroundColor Cyan
}

$ok = 0
$warn = 0
$fail = 0

if ($Member) {
    Write-Host "[info] Member mode: AIHUBMIX skipped-by-design; HCNSEC is extended-only (press Enter to skip)." -ForegroundColor Cyan
    Write-Host ""
}

foreach ($spec in $secretSpec) {
    $key = $spec.Key
    if ($Member -and $key -eq 'AIHUBMIX_API_KEY') {
        Write-Host "[skip] $key - owner only (member mode)" -ForegroundColor DarkGray
        continue
    }
    $label = $spec.Label
    $shape = $spec.Shape
    Write-Host "[set] $key - $label" -ForegroundColor Yellow

    $value = $null
    if ($fileSecrets.ContainsKey($key)) {
        $value = $fileSecrets[$key]
        Write-Host "    [from-file] loaded from $($env:OC_SECRETS_FILE)" -ForegroundColor DarkGray
    } elseif ($DryRun) {
        Write-Host "    [DRY-RUN] skipping (would prompt interactively)" -ForegroundColor Magenta
        continue
    } else {
        $sec = Read-Host "    Enter $key (input hidden)" -AsSecureString
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        try {
            $value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        } finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }

    if (-not $value) {
        Write-Host "    [WARN] $key empty - skipping" -ForegroundColor Yellow
        $warn++
        continue
    }

    # Soft validation: warn-not-fail
    if ($value.Length -lt $spec.MinLen -or $value.Length -gt $spec.MaxLen) {
        Write-Host "    [WARN] $key length is $($value.Length) (expected $($spec.MinLen))-$($spec.MaxLen)) - setting anyway" -ForegroundColor Yellow
        $warn++
    }
    if ($shape -and -not $value.StartsWith($shape)) {
        # ponytail: never print key fragments (member machines share logs/screens)
        Write-Host "    [WARN] $key has an unexpected shape - setting anyway" -ForegroundColor Yellow
        $warn++
    }

    if (-not $DryRun) {
        if ($PSVersionTable.Platform -eq 'Unix') {
            # ponytail: Linux/macOS - print export line; user sources it
            Write-Host "    export $key='<redacted>'  # add to ~/.bashrc or ~/.zshrc" -ForegroundColor Cyan
        } else {
            # Windows: setx to User scope + Process scope for current shell
            setx $key $value | Out-Null
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
            Write-Host "    [OK] $key set (User + Process scope, length $($value.Length))" -ForegroundColor Green
        }
    } else {
        Write-Host "    [DRY-RUN] would set $key (length $($value.Length))" -ForegroundColor Magenta
    }
    $ok++
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host " RESULT: $ok set, $warn warnings, $fail failures" -ForegroundColor $(if ($fail -eq 0) { 'Green' } else { 'Red' })
if (-not $env:OC_SECRETS_FILE -and -not $DryRun) {
    Write-Host " Restart any open opencode shells for env var changes to take effect" -ForegroundColor Cyan
}
Write-Host "===========================================" -ForegroundColor Cyan

if ($fail -gt 0) { exit 1 }
exit 0
