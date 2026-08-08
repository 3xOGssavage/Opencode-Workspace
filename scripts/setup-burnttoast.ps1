#Requires -Version 5.1
<#
.SYNOPSIS
  Sets up BurntToast PowerShell module for desktop notifications, with a .NET
  fallback if BurntToast fails to install.

.DESCRIPTION
  Attempts to install BurntToast from PSGallery. If install fails (network,
  PSGallery untrusted, etc.), writes a .NET-based fallback notification function
  to scripts/_notify-fallback.ps1 which other scripts can dot-source.

  Idempotent: safe to run multiple times.

.PARAMETER Force
  Force reinstall even if BurntToast is already present.

.EXAMPLE
  pwsh -File scripts\setup-burnttoast.ps1
  pwsh -File scripts\setup-burnttoast.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$scriptDir = $PSScriptRoot
$fallbackPath = Join-Path $scriptDir "_notify-fallback.ps1"

Write-Output "=== setup-burnttoast ==="

# 1. Check if BurntToast already available
if (-not $Force -and (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue)) {
    $btVersion = (Get-Module -ListAvailable -Name BurntToast).Version
    Write-Output "  BurntToast $btVersion already installed - use -Force to reinstall"
    exit 0
}

# 2. Trust PSGallery if not already trusted (required for install on first run)
try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($repo.InstallationPolicy -ne "Trusted") {
        Write-Output "  Setting PSGallery installation policy to Trusted..."
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        Write-Output "  PSGallery: Trusted"
    } else {
        Write-Output "  PSGallery: Trusted (already)"
    }
} catch {
    Write-Warning "Could not access PSGallery: $($_.Exception.Message)"
    Write-Output "  Will write .NET fallback notification function instead"
    New-NotifyFallback -Path $fallbackPath
    Write-Output "=== COMPLETE with .NET fallback (no BurntToast) ==="
    exit 0
}

# 3. Install BurntToast
try {
    Write-Output "  Installing BurntToast..."
    if ($Force) {
        Install-Module -Name BurntToast -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    } else {
        Install-Module -Name BurntToast -Scope CurrentUser -ErrorAction Stop
    }
    $btVersion = (Get-Module -ListAvailable -Name BurntToast).Version
    Write-Output "  BurntToast $btVersion installed successfully"
} catch {
    Write-Warning "BurntToast install failed: $($_.Exception.Message)"
    Write-Output "  Will write .NET fallback notification function instead"
    New-NotifyFallback -Path $fallbackPath
    Write-Output "=== COMPLETE with .NET fallback (BurntToast install failed) ==="
    exit 0
}

Write-Output "=== setup-burnttoast complete ==="

function New-NotifyFallback {
    param([string]$Path)
    $content = @'
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
    # Write to Event Log as primary channel (always works, even in non-interactive sessions)
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
        # Fallback to console (Task Scheduler captures this)
        $color = switch ($Severity) {
            "Info"    { "Cyan" }
            "Warning" { "Yellow" }
            "Error"   { "Red" }
        }
        Write-Host "[$Severity] $Title : $Message" -ForegroundColor $color
    }
}

Export-ModuleMember -Function Send-Notify -ErrorAction SilentlyContinue
'@
    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Output "  wrote fallback: $Path"
}
