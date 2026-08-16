param(
    [ValidateSet("camoufox", "patchright-headed", "patchright-headless")]
    [string]$Engine = "camoufox"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$py = Join-Path $root ".opencode\browser_use\.venv\Scripts\python.exe"
$botscore = Join-Path $root ".opencode\browser_use\botscore.py"

& $py $botscore --engine $Engine
exit $LASTEXITCODE