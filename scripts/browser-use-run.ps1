param(
    [Parameter(Mandatory = $true)][string]$Task,
    [string]$Name = "default",
    [int]$MaxSteps = 20,
    [int]$Port = 9222
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$py = Join-Path $root ".opencode\browser_use\.venv\Scripts\python.exe"
$runner = Join-Path $root ".opencode\browser_use\agent_runner.py"
$profile = Join-Path $root ".opencode\browser_use\profiles\$Name"
New-Item -ItemType Directory -Force -Path $profile | Out-Null

& $py $runner --task "$Task" --profile-dir "$profile" --port $Port --max-steps $MaxSteps
exit $LASTEXITCODE