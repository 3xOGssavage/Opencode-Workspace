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

# Function defined at TOP to avoid PowerShell 5.1 hoisting quirks when
# called before definition in same script scope.
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
'@
    Set-Content -Path $Path -Value $content -Encoding UTF8
    Write-Output "  wrote fallback: $Path"
}

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

# 2. Trust PSGallery if not already trusted (best-effort: skip on error since
#    Install-Module will give a clearer error if trust is actually missing)
try {
    $repo = Get-PSRepository -Name PSGallery -ErrorAction Stop
    if ($repo.InstallationPolicy -ne "Trusted") {
        Write-Output "  Setting PSGallery installation policy to Trusted..."
        try {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
            Write-Output "  PSGallery: Trusted"
        } catch {
            Write-Warning "  Could not set PSGallery trust: $($_.Exception.Message)"
        }
    } else {
        Write-Output "  PSGallery: Trusted (already)"
    }
} catch {
    Write-Warning "Could not access PSGallery: $($_.Exception.Message)"
    Write-Output "  Will write .NET fallback notification function instead"
    New-NotifyFallback -Path $fallbackPath
    Write-Output "=== COMPLETE with .NET fallback (no PSGallery access) ==="
    exit 0
}

# 3. Install BurntToast - try PSGallery first, then direct nupkg download
#    (direct download covers machines where the NuGet provider for
#    PowerShellGet is missing - see scripts/setup-burnttoast.ps1 history)
function Install-BurntToastDirect {
    $findUri = "https://www.powershellgallery.com/api/v2/FindPackagesById()?id='BurntToast'"
    $response = Invoke-WebRequest -Uri $findUri -UseBasicParsing -TimeoutSec 30
    [xml]$xml = $response.Content
    $versions = @()
    foreach ($e in $xml.feed.entry) {
        if ($e.properties.version -notmatch "-") { $versions += [version]$e.properties.version }
    }
    $latest = ($versions | Sort-Object -Descending)[0]
    $targetEntry = $xml.feed.entry |
        Where-Object { $_.properties.version -eq $latest.ToString() } |
        Select-Object -First 1
    $nupkgUrl = $targetEntry.content.src

    $nupkgPath = Join-Path $env:TEMP "BurntToast.$latest.nupkg"
    Invoke-WebRequest -Uri $nupkgUrl -OutFile $nupkgPath -UseBasicParsing -TimeoutSec 120

    $userModulesPath = (($env:PSModulePath -split ";") |
        Where-Object { $_ -like "*WindowsPowerShell\Modules" } |
        Select-Object -First 1)
    if (-not $userModulesPath) {
        $userModulesPath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
    }
    $destDir = Join-Path $userModulesPath "BurntToast\$latest"
    if (Test-Path $destDir) { Remove-Item $destDir -Recurse -Force }
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($nupkgPath)
    foreach ($e in $zip.Entries) {
        $destPath = Join-Path $destDir $e.FullName
        if ($e.FullName.EndsWith("/")) {
            if (-not (Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath -Force | Out-Null }
        } else {
            $parent = Split-Path $destPath -Parent
            if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $destPath, $true)
        }
    }
    $zip.Dispose()
    Remove-Item $nupkgPath -Force
    Write-Output "  BurntToast $latest installed (direct download)"
}

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
    Write-Warning "Install-Module failed: $($_.Exception.Message)"
    Write-Output "  Falling back to direct nupkg download..."
    try {
        Install-BurntToastDirect
        $btVersion = (Get-Module -ListAvailable -Name BurntToast).Version
        Write-Output "  BurntToast $btVersion installed successfully"
    } catch {
        Write-Warning "BurntToast install failed (both methods): $($_.Exception.Message)"
        Write-Output "  Will write .NET fallback notification function instead"
        New-NotifyFallback -Path $fallbackPath
        Write-Output "=== COMPLETE with .NET fallback (BurntToast install failed) ==="
        exit 0
    }
}

Write-Output "=== setup-burnttoast complete ==="
