#Requires -Version 5.1
<#
.SYNOPSIS
  Single-action runner for the Sunday backup: push (backup-workspace.ps1)
  then bundle (backup-bundle.ps1), reporting the WORSE exit code.

.DESCRIPTION
  Replaces the 2-action scheduled-task layout whose LastTaskResult only
  reflected the LAST action (Sep-06 silent push failure). Each half runs in
  a CHILD powershell.exe so its `exit <n>` cannot kill this wrapper; the
  wrapper exits with the worst code, so Task Scheduler can never report
  success when either half failed.

  Push output is captured to a TEMP diary (password= redacted, keep last 4)
  because backup-workspace.ps1 swallows git push output (Out-Null).

  Event Log: writes EventId 104 on wrapper-level failure only (100/101 push
  and 102/103 bundle entries remain owned by the two scripts).

.PARAMETER DryRun
  Echo-only rehearsal: prints what would run and exits 0 WITHOUT invoking
  anything (neither half supports a trustworthy dry mode).

.PARAMETER SkipPush
  Passes -SkipPush through to backup-workspace.ps1 (bundle still runs).

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\backup-task-runner.ps1
  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\backup-task-runner.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$diaryDir = Join-Path ([IO.Path]::GetTempPath()) "opencode-backup-diary"
if (-not (Test-Path $diaryDir)) { New-Item -ItemType Directory -Path $diaryDir | Out-Null }
$stamp = Get-Date -Format "yyyy-MMdd-HHmm"
$diary = Join-Path $diaryDir "backup-$stamp.log"
# Keep only the last 4 diaries (rotation).
Get-ChildItem $diaryDir -Filter "backup-*.log" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -Skip 4 |
    Remove-Item -Force -ErrorAction SilentlyContinue

function Invoke-Half([string]$Script, [string]$Args, [string]$Label) {
    $p = Start-Process powershell.exe `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$Script`" $Args" `
        -Wait -PassThru `
        -RedirectStandardOutput (Join-Path $diaryDir "tmp-$Label-out.txt") `
        -RedirectStandardError (Join-Path $diaryDir "tmp-$Label-err.txt")
    $out = ""
    foreach ($f in @((Join-Path $diaryDir "tmp-$Label-out.txt"), (Join-Path $diaryDir "tmp-$Label-err.txt"))) {
        if (Test-Path $f) { $out += (Get-Content $f -Raw); Remove-Item $f -Force }
    }
    # Redact any credential material before the diary hits disk.
    $out = $out -replace '(?i)(password=)\S+', '$1[REDACTED]'
    "===== $Label (exit $($p.ExitCode)) $stamp =====" | Add-Content $diary
    $out | Add-Content $diary
    return $p.ExitCode
}

# TRUE dry run: echo only, invoke NOTHING. (Proven 2026-09-07: passing
# -DryRun through is unsafe because backup-workspace.ps1 ignores it and
# runs live. Never forward execution to children in DryRun mode.)
if ($DryRun) {
    Write-Host "DRYRUN: would invoke backup-workspace.ps1 (child process)"
    Write-Host "DRYRUN: would invoke backup-bundle.ps1 (child process, always live)"
    Write-Host "DRYRUN: would exit with worst of the two codes; diary=$diary"
    exit 0
}

$wsArgs = ""
if ($SkipPush) { $wsArgs += " -SkipPush" }

$c1 = Invoke-Half (Join-Path $scriptDir "backup-workspace.ps1") $wsArgs "push"
$c2 = Invoke-Half (Join-Path $scriptDir "backup-bundle.ps1") "" "bundle"

$worst = [Math]::Max($c1, $c2)
Write-Host "backup-task-runner: push=$c1 bundle=$c2 worst=$worst diary=$diary"
if ($worst -ne 0) {
    try {
        Write-EventLog -LogName Application -Source 'Windows PowerShell' `
            -EventId 104 -EntryType Error `
            -Message "opencode-workspace backup FAILED (push=$c1 bundle=$c2). Diary: $diary"
    } catch {
        Write-Host "Event Log: could not write 104 (non-fatal)" -ForegroundColor Yellow
    }
}
exit $worst
