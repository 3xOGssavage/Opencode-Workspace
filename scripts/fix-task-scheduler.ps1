#Requires -Version 5.1
<#
.SYNOPSIS
  Fixes the existing "Opencode monthly backup" scheduled task: battery/sleep settings
  and adds a 2nd action that runs scripts\backup-bundle.ps1 after the push.

.DESCRIPTION
  Idempotent. Targets the task registered by scripts\setup-scheduled-backup.ps1.
  - Sets DisallowStartIfOnBatteries=false (laptop on battery still runs)
  - Sets StopIfGoingOnBatteries=false  (don't kill mid-backup if power changes)
  - Sets WakeToRun=true               (wake from sleep to fire at 14:00 Sun)
  - Adds 2nd Action: powershell.exe -File scripts\backup-bundle.ps1
  Result: one task, two sequential actions (push -> bundle), single Event Log signal.

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
    [string]$WorkingDirectory = (Get-Item -Path $PSScriptRoot).Parent.FullName
)

$ErrorActionPreference = "Stop"

if (-not (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue)) {
    Write-Host "Task '$TaskName' not found. Run scripts\setup-scheduled-backup.ps1 first." -ForegroundColor Red
    exit 1
}

$task = Get-ScheduledTask -TaskName $TaskName
Write-Host "Before:" -ForegroundColor Cyan
$task.Settings | Select-Object DisallowStartIfOnBatteries, StopIfGoingOnBatteries, WakeToRun | Format-List
Write-Host "Actions: $(($task.Actions | ForEach-Object { $_.Arguments }) -join ' | ')" -ForegroundColor Cyan

$newSettings = New-ScheduledTaskSettingsSet `
    -DisallowStartIfOnBatteries:$false `
    -StopIfGoingOnBatteries:$false `
    -WakeToRun `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -DontStopOnIdleEnd

$pushAction  = $task.Actions[0]
$bundleArg   = "-File `"$WorkingDirectory\scripts\backup-bundle.ps1`""
$bundleAction = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass $bundleArg" `
    -WorkingDirectory $WorkingDirectory

Set-ScheduledTask -TaskName $TaskName -Settings $newSettings -Action @($pushAction, $bundleAction) | Out-Null

$task = Get-ScheduledTask -TaskName $TaskName
Write-Host "After:" -ForegroundColor Green
$task.Settings | Select-Object DisallowStartIfOnBatteries, StopIfGoingOnBatteries, WakeToRun | Format-List
Write-Host "Actions: $(($task.Actions | ForEach-Object { $_.Arguments }) -join ' | ')" -ForegroundColor Green
Write-Host "Done. Next weekly run (Sun 14:00) will push AND bundle." -ForegroundColor Green
