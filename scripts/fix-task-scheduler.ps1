#Requires -Version 5.1
<#
.SYNOPSIS
  Fixes the existing "Opencode monthly backup" scheduled task: battery/sleep settings
  and collapses it to the single scripts\backup-task-runner.ps1 action
  (the runner chains push -> bundle and reports the worse exit code, so a
  failed push can never again be masked by a passing bundle).

.DESCRIPTION
  Idempotent.
  - Sets DisallowStartIfOnBatteries=false (laptop on battery still runs)
  - Sets StopIfGoingOnBatteries=false  (don't kill mid-backup if power changes)
  - Sets WakeToRun=true               (wake from sleep to fire on schedule)
  - Sets single Action: powershell.exe -File scripts\backup-task-runner.ps1
  Result: one task, one action (runner chains push -> bundle), worst-code exit.

.PARAMETER TaskName
  Name of the scheduled task to fix. Default: "Opencode monthly backup".

.PARAMETER WorkingDirectory
  Workspace root. Default: F:\CD\Opencode (resolved from script location).

.EXAMPLE
  pwsh -File scripts\fix-task-scheduler.ps1
#>
[CmdletBinding()]
param(
    [string]$TaskName = "Opencode monthly backup",
    [string]$WorkingDirectory = $(if ($PSScriptRoot) { (Get-Item -Path $PSScriptRoot).Parent.FullName } else { 'F:\CD\Opencode' })
)

$ErrorActionPreference = "Stop"

if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
    Write-Host "Task '$TaskName' not found. See README 'Weekly backup procedure' for the manual registration snippet." -ForegroundColor Red
    exit 1
}

$task = Get-ScheduledTask -TaskName $TaskName
Write-Host "Before:" -ForegroundColor Cyan
$task.Settings | Select-Object DisallowStartIfOnBatteries, StopIfGoingOnBatteries, WakeToRun | Format-List
Write-Host "Actions: $(($task.Actions | ForEach-Object { $_.Arguments }) -join ' | ')" -ForegroundColor Cyan

$newSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -WakeToRun `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -DontStopOnIdleEnd

$runnerArg   = "-File `"$WorkingDirectory\scripts\backup-task-runner.ps1`""
$runnerAction = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass $runnerArg" `
    -WorkingDirectory $WorkingDirectory

Set-ScheduledTask -TaskName $TaskName -Settings $newSettings -Action @($runnerAction) | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
Write-Host "After:" -ForegroundColor Green
$task.Settings | Select-Object DisallowStartIfOnBatteries, StopIfGoingOnBatteries, WakeToRun | Format-List
Write-Host "Actions: $(($task.Actions | ForEach-Object { $_.Arguments }) -join ' | ')" -ForegroundColor Green
Write-Host "Done. Next weekly run will push AND bundle via the wrapper (worst-code exit)." -ForegroundColor Green
