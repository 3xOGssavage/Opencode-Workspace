#Requires -Version 5.1
# Auto-generated .NET fallback for BurntToast - do not edit manually
# Used by scripts/backup-verify.ps1 and scripts/backup-workspace.ps1 when
# BurntToast module is not available (install failed, network down, etc.)

function Send-Notify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Title,
        [Parameter(Mandatory=$true)][string]$Message,
        [ValidateSet("Info","Warning","Error")][string]$Severity = "Info"
    )
    try {
        $entryType = switch ($Severity) {
            "Info"    { "Information" }
            "Warning" { "Warning" }
            "Error"   { "Error" }
        }
        $eventId = switch ($Severity) {
            "Info"    { 1000 }
            "Warning" { 1001 }
            "Error"   { 1002 }
        }
        Write-EventLog -LogName Application -Source 'Windows PowerShell' `
            -EventId $eventId -EntryType $entryType -Message "$Title : $Message" `
            -ErrorAction Stop
        Write-Verbose "Notify: Event Log entry written (EventId $eventId)"
    } catch {
        Write-Warning "Notify: Event Log write failed - $($_.Exception.Message)"
        $color = switch ($Severity) {
            "Info"    { "Cyan" }
            "Warning" { "Yellow" }
            "Error"   { "Red" }
        }
        Write-Host "[$Severity] $Title : $Message" -ForegroundColor $color
    }
}

# Export-ModuleMember only valid inside modules. Guard for dot-source usage.
if ($MyInvocation.MyCommand.ScriptBlock.Module) {
    Export-ModuleMember -Function Send-Notify
}
