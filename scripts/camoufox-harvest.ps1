param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Output = "",
    [int]$MaxScrolls = 8,
    [switch]$Escalate
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$py = Join-Path $root ".opencode\browser_use\.venv\Scripts\python.exe"
$harvester = Join-Path $root ".opencode\browser_use\camoufox_harvest.py"
$profile = Join-Path $root ".opencode\browser_use\profiles\$Name"
New-Item -ItemType Directory -Force -Path $profile | Out-Null

& $py $harvester --url "$Url" --name "$Name" --profile-dir "$profile" --max-scrolls $MaxScrolls
$code = $LASTEXITCODE
if ($code -eq 2 -and $Escalate) {
    Write-Host "Blocked -> escalating to Mode A (headed Patchright + AI agent)"
    & (Join-Path $PSScriptRoot "browser-use-run.ps1") -Task "Visit $Url and extract the main visible content, saving it under $Output if provided." -Name $Name
    $code = $LASTEXITCODE
}
exit $code