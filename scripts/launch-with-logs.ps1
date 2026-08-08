#Requires -Version 5.1
<#
.SYNOPSIS
  Wrapper around `opencode run` that captures stdout/stderr to dated log files
  with 30-day automatic rotation.

.DESCRIPTION
  Invokes opencode with the --print-logs and --log-level flags (per AGENTS.md
  core operating principles), capturing all output to a dated log file. Old
  logs older than 30 days are auto-rotated.

  Designed for use from Task Scheduler ("run only when user logged on") or
  manual invocation when you want a persistent record of what opencode did.

.PARAMETER Prompt
  The prompt to pass to `opencode run`. If omitted, opens interactive mode.

.PARAMETER LogDir
  Directory for log files (default: $env:LOCALAPPDATA\opencode\logs).

.PARAMETER RetentionDays
  Days to keep old logs (default: 30).

.PARAMETER LogLevel
  Log level for --log-level flag (default: INFO). One of: DEBUG, INFO, WARN, ERROR.

.EXAMPLE
  pwsh -File scripts\launch-with-logs.ps1 -Prompt "refactor scripts/audit-secrets.ps1"
  pwsh -File scripts\launch-with-logs.ps1 -LogLevel DEBUG
#>
[CmdletBinding()]
param(
    [string]$Prompt,
    [string]$LogDir = "$env:LOCALAPPDATA\opencode\logs",
    [int]$RetentionDays = 30,
    [ValidateSet("DEBUG","INFO","WARN","ERROR")][string]$LogLevel = "INFO"
)

$ErrorActionPreference = "Stop"

# 1. Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 2. Rotate old logs
$cutoff = (Get-Date).AddDays(-$RetentionDays)
Get-ChildItem -Path $LogDir -Filter "opencode-*.log" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object {
        Write-Host "Rotating old log: $($_.Name)"
        Remove-Item $_.FullName -Force
    }

# 3. Build log file path
$date = Get-Date -Format "yyyy-MM-dd-HHmmss"
$logFile = Join-Path $LogDir "opencode-$date.log"

# 4. Check opencode is available
$opencodeCmd = Get-Command opencode -ErrorAction SilentlyContinue
if (-not $opencodeCmd) {
    throw "opencode command not found in PATH. Install from https://opencode.ai"
}

# 5. Build arguments
$args = @("run", "--print-logs", "--log-level", $LogLevel)
if ($Prompt) { $args += $Prompt }

# 6. Launch with output capture
Write-Host "=== launch-with-logs ==="
Write-Host "  Log file : $logFile"
Write-Host "  Log level: $LogLevel"
Write-Host "  Retention: $RetentionDays days"
Write-Host "  Prompt   : $(if ($Prompt) { '<provided>' } else { '<interactive>' })"
Write-Host ""

try {
    $proc = Start-Process -FilePath $opencodeCmd.Source -ArgumentList $args `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $logFile `
        -RedirectStandardError "$logFile.err"
    Write-Host "opencode exited with code $($proc.ExitCode)"
    Write-Host "Log: $logFile"
    if (Test-Path "$logFile.err") {
        $errSize = (Get-Item "$logFile.err").Length
        if ($errSize -gt 0) {
            Write-Host "stderr: $logFile.err ($errSize bytes)"
        } else {
            Remove-Item "$logFile.err" -Force
        }
    }
    exit $proc.ExitCode
} catch {
    Write-Error "Failed to launch opencode: $($_.Exception.Message)"
    exit 1
}
