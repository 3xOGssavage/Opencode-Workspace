# sync-hcnsec-models.ps1
# Adds hcnsec catalog models missing from opencode.json (ADD-ONLY, never removes/renames).
# Only IDs advertising the "openai" endpoint type are added (chat-completions capable).
# New entries get conservative limits (128000/8192) flagged NEEDS-PROBE in stdout;
# true limits come from the probe error-disclosure pass (see model-verify harness).
# Safety: byte backup before write + JSON validation after (restore on failure).
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts\sync-hcnsec-models.ps1 [-WhatIf]
#        (reads HCNSEC_API_KEY from User env var; throws if missing - automation-safe)

param([switch]$WhatIf)
$ErrorActionPreference = 'Stop'

$apiKey = [Environment]::GetEnvironmentVariable('HCNSEC_API_KEY', 'User')
if (-not $apiKey) { throw 'HCNSEC_API_KEY not set in User env - aborting (no prompt in automation)' }

$cfgPath = Join-Path $PSScriptRoot '..\opencode.json'
$cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$have = @{}
foreach ($p in $cfg.provider.hcnsec.models.PSObject.Properties) { $have[$p.Name] = $true }

$headers = @{ Authorization = "Bearer $apiKey" }
$cat = Invoke-RestMethod -Uri 'https://api.hcnsec.cn/v1/models' -Headers $headers -TimeoutSec 30
$arr = if ($cat -is [array]) { $cat } else { $cat.data }
$missing = @($arr | Where-Object {
    $_.id -and (-not $have.ContainsKey($_.id)) -and ($_.supported_endpoint_types -contains 'openai')
} | Sort-Object id)

Write-Host ("hcnsec catalog: {0} ids, {1} already configured, {2} small-new" -f $arr.Count, $have.Count, $missing.Count)
foreach ($m in $missing) { Write-Host ("  NEW (needs probe): " + $m.id) }
if ($WhatIf -or ($missing.Count -eq 0)) { exit 0 }

$nl = "`n"
$newLines = New-Object System.Collections.Generic.List[string]
foreach ($m in $missing) {
    $disp = [string]$m.id -replace '-', ' '
    $entry = '        "{0}": {{{1}          "name": "{2}",{1}          "limit": {{{1}            "context": 128000,{1}            "output": 8192{1}          }}{1}        }}' -f $m.id, $nl, $disp
    $newLines.Add($entry)
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$bakDir = Join-Path $PSScriptRoot ('..\\.opencode\\backups\\pre-sync-hcnsec-' + $ts)
New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
Copy-Item -LiteralPath $cfgPath -Destination (Join-Path $bakDir 'opencode.json') -Force

$text = [System.IO.File]::ReadAllText($cfgPath)
$hIdx = $text.IndexOf('"hcnsec"')
if ($hIdx -lt 0) { throw 'hcnsec block not found' }
$mIdx = $text.IndexOf('"models"', $hIdx)
if ($mIdx -lt 0) { throw 'hcnsec models block not found' }
$brace = $text.IndexOf('{', $mIdx)
$depth = 0; $end = -1
for ($i = $brace; $i -lt $text.Length; $i++) {
    if ($text[$i] -eq '{') { $depth++ }
    elseif ($text[$i] -eq '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
}
if ($end -lt 0) { throw 'Could not find end of hcnsec models block' }
$before = $text.Substring(0, $end).TrimEnd("`r", "`n") + ",$nl" + ($newLines -join ",$nl")
$text = $before + $text.Substring($end)
[System.IO.File]::WriteAllText($cfgPath, $text, (New-Object System.Text.UTF8Encoding($false)))

try {
    $check = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $n = ($check.provider.hcnsec.models.PSObject.Properties | Measure-Object).Count
    if ($n -ne ($have.Count + $missing.Count)) { throw "count mismatch ($n)" }
    Write-Host "  validated: JSON parses, hcnsec block has $n models"
} catch {
    Copy-Item -LiteralPath (Join-Path $bakDir 'opencode.json') -Destination $cfgPath -Force
    throw "Write validation failed - restored backup: $_"
}
Write-Host ("[hcnsec] added {0} models (conservative limits, NEEDS PROBE)" -f $missing.Count)
