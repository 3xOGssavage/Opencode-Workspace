param(
    [string]$Python = "python"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$bu = Join-Path $root ".opencode\browser_use"
$venv = Join-Path $bu ".venv"
$marker = Join-Path $bu ".setup-done"
New-Item -ItemType Directory -Force -Path $bu, (Join-Path $root "logs") | Out-Null

Write-Host "Creating venv at $venv"
& $Python -m venv $venv
if ($LASTEXITCODE -ne 0) { throw "venv creation failed" }
$py = Join-Path $venv "Scripts\python.exe"

Write-Host "Installing core deps"
& $py -m pip install --upgrade pip
& $py -m pip install browser-use==0.13.5 patchright camoufox ddddocr pyautogui mcp
if ($LASTEXITCODE -ne 0) { throw "core pip install failed" }

Write-Host "Installing seleniumbase separately (combined resolution back-solves it to ancient 1.x; isolated it picks modern 4.x)"
& $py -m pip install seleniumbase
if ($LASTEXITCODE -ne 0) { throw "seleniumbase install failed" }

Write-Host "Installing Patchright Chromium"
& $py -m patchright install chromium
if ($LASTEXITCODE -ne 0) { throw "patchright install failed" }

Write-Host "Fetching Camoufox"
& $py -m camoufox fetch
if ($LASTEXITCODE -ne 0) { throw "camoufox fetch failed" }

Write-Host "Verifying imports"
& $py -c "import browser_use, patchright, camoufox, ddddocr, seleniumbase, pyautogui, mcp; print('imports OK')"
if ($LASTEXITCODE -ne 0) { throw "import verification failed" }

Set-Content -Path $marker -Value (Get-Date -Format "yyyy-MM-dd HH:mm") -Encoding utf8
Write-Host "Setup complete (marker: $marker)"