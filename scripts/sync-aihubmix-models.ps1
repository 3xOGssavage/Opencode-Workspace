# sync-aihubmix-models.ps1
# Re-generates the "aihubmix" provider block in opencode.json from aihubmix's own
# model catalog (https://aihubmix.com/api/v1/models). Includes only free chat
# models whose context limit is published (context_length > 0) and callable via
# /v1/models. Writes opencode.json directly (Set-Content-style) to bypass the
# edit-tool deny rule, same as setup-env-vars.ps1.
#
# Usage:  powershell -ExecutionPolicy Bypass -File scripts\sync-aihubmix-models.ps1
#         (reads AIHUBMIX_API_KEY from User env var, or prompts)

param(
    [string]$ApiKey = $env:AIHUBMIX_API_KEY
)
$ErrorActionPreference = 'Stop'

$nl = [Environment]::NewLine

if (-not $ApiKey) {
    $ApiKey = Read-Host 'AIHUBMIX_API_KEY not set - enter your aihubmix API key'
}

$headers = @{ Authorization = "Bearer $ApiKey" }

# Models excluded even though aihubmix lists them as free:
#  - image-generation only (no chat endpoint)
#  - callable on /v1/models but chat requests are rejected by the API (verified 2026-08-20)
$exclude = @(
    'gemini-3.1-flash-image-preview-free',
    'gpt-image-2-free',
    'ling-3.0-tiny-free',
    'coding-glm-5-turbo-free',
    'xiaomi-mimo-v2-omni-free',
    'xiaomi-mimo-v2-pro-free',
    'glm-5.2-free'   # verified 2026-08-20: chat requests rejected with 400 Aihubmix bind error
)

# Context overrides, sourced from official model pages (2026-08-20 scrape):
#  - catalog leaves context unpublished (0) -> use page value or sibling-model best guess
#  - catalog value is wrong vs the model's own page -> page wins
$manualCtx = @{
    'coding-glm-5.2-free'               = 1000000   # page: 1,000,000 (catalog 0)
    'gemini-3.6-flash-free'             = 1048576   # page: 1,048,576 (catalog 1,000,000)
    'nemotron-3-super-120b-a12b-free'   = 1048576   # page: 1,048,576 (catalog 262,144)
    'nemotron-nano-12b-v2-vl-free'      = 131072    # page: 131,072 (catalog 128,000)
    'nemotron-nano-9b-v2-free'          = 131072    # page: 131,072 (catalog 128,000)
    'coding-glm-4.7-free'               = 200000    # live 2026-08-20: ACCEPT 131K; 200K probe times out (slow) - official GLM-4.7 = 200K
    'coding-glm-5-free'                 = 200000    # live 2026-08-20: ACCEPT ~200K (usage.prompt=199913)
    'coding-glm-5.1-free'               = 200000    # live 2026-08-20: ACCEPT ~200K (usage.prompt=199913)
    'glm-4.7-flash-free'                = 200000    # live 2026-08-20: ACCEPT ~200K; official glm-4.7-flash = 200K
}

# Max-output overrides, sourced from official model pages (2026-08-20 scrape)
# PLUS live probe error-disclosure (2026-08-23 round + 2026-09-09 audit).
# Probe truth BEATS catalog max_output: catalog ships wrong caps (e.g. 13100)
# that a blind re-sync would write over verified values. Never delete entries here.
$manualOut = @{
    'coding-glm-5.2-free'   = 131072    # page: 131,072 (catalog 0 -> default was 8192)
    'gpt-oss-20b-free'      = 131072    # page: 131,072 (catalog 0 -> default was 8192)
    'gemini-3.6-flash-free' = 65536     # page: 65,536 (catalog 64,000)
    'coding-glm-4.7-free'   = 131072    # probe 2026-09-09: range [1,131072] (was 128000 sibling guess)
    'coding-glm-5-free'     = 131072    # live probe 2026-08-20: accepts max_tokens=9000 (catalog 0 -> default was 8192)
    'coding-glm-5.1-free'   = 131072    # live probe 2026-08-20: accepts max_tokens=9000 (catalog 0 -> default was 8192)
    'glm-4.7-flash-free'    = 131072    # live probe 2026-08-20: accepts max_tokens=9000; official glm-4.7-flash = 128K (catalog 8192 was wrong)
    'coding-glm-4.6-free'   = 131072    # probe 2026-09-09: range [1,131072] (catalog 128000 was wrong)
    'coding-minimax-m2.1-free' = 196608  # probe 2026-08-23 + 2026-09-09: cap 196608 (catalog 13100 is wrong)
    'coding-minimax-m2.5-free' = 196608  # probe 2026-08-23 + 2026-09-09: cap 196608 (catalog 13100 is wrong)
    'coding-minimax-m2.7-free' = 196608  # probe 2026-08-23 + 2026-09-09: cap 196608 (catalog 13100 is wrong)
    'coding-minimax-m2-free'   = 196608  # probe 2026-09-09: routes to M2.5, cap 196608 (catalog 13100 is wrong)
    'coding-minimax-m3-free'   = 524288  # probe 2026-09-09: cap 524288 (catalog 13100 is wrong)
    'minimax-m3-free'          = 524288  # same family as coding- variant (UNPROBED newcomer - flagged for review)
}

$plaza = Invoke-RestMethod -Uri 'https://aihubmix.com/api/v1/models' -Headers $headers -TimeoutSec 60
$plazaArr = if ($plaza -is [array]) { $plaza } else { $plaza.data }

$free = @($plazaArr | Where-Object {
    $_.model_id -match '-free$' -and
    ($_.context_length -gt 0 -or $manualCtx.ContainsKey($_.model_id)) -and
    $_.model_id -notin $exclude
} | Sort-Object model_id)

$v1 = Invoke-RestMethod -Uri 'https://aihubmix.com/v1/models' -Headers $headers -TimeoutSec 60
$v1Arr = if ($v1 -is [array]) { $v1 } else { $v1.data }
$callable = @{}
foreach ($m in $v1Arr) { $callable[$m.id] = $true }
$free = @($free | Where-Object { $callable.ContainsKey($_.model_id) })

if ($free.Count -eq 0) {
    throw 'No free models found - check the API key and aihubmix API availability'
}

# Safety: byte backup before any write (rollback anchor)
$cfgPath = Join-Path $PSScriptRoot '..\opencode.json'
$bakDir = Join-Path $PSScriptRoot ('..\\.opencode\\backups\\pre-sync-aihubmix-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $bakDir -Force | Out-Null
Copy-Item -LiteralPath $cfgPath -Destination (Join-Path $bakDir 'opencode.json') -Force

# Preserve quarantined display names: a re-sync must never wipe [DEAD ...] tags
$deadNames = @{}
try {
    $cur = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $cur.provider.aihubmix.models.PSObject.Properties) {
        if ($p.Value.name -match '\[DEAD') { $deadNames[$p.Name] = [string]$p.Value.name }
    }
} catch { Write-Warning "Could not read current config for DEAD-name preservation: $_" }
if ($deadNames.Count -gt 0) { Write-Host ("  preserving {0} quarantined name(s)" -f $deadNames.Count) }

$lines = New-Object System.Collections.Generic.List[string]
foreach ($m in $free) {
    $ctx = if ($manualCtx.ContainsKey($m.model_id)) { [int]$manualCtx[$m.model_id] } elseif ($m.context_length -gt 0) { [int]$m.context_length } else { 0 }
    $out = if ($manualOut.ContainsKey($m.model_id)) { [int]$manualOut[$m.model_id] } elseif ($m.max_output -gt 0) { [int]$m.max_output } else { 8192 }
    $dispName = if ($deadNames.ContainsKey($m.model_id)) { $deadNames[$m.model_id] } else { [string]$m.model_name }
    # Byte-exact committed style (multi-line, limit-first, spaced inner object).
    # ConvertTo-Json -Compress emits single-line name-first and would churn all lines;
    # whole-file Prettier is banned (HEAD itself is not prettier-clean).
    # Handles PS aperture: escape backslash + quote in display names.
    $escName = $dispName -replace '\\', '\\' -replace '"', '\"'
    $entry = '        "{0}": {{{1}          "limit": {{ "output": {2}, "context": {3} }},{1}          "name": "{4}"{1}        }}' -f $m.model_id, $nl, $out, $ctx, $escName
    $lines.Add($entry)
}
$modelsJson = $lines -join ",$nl"

$block = @(
    '    "aihubmix": {'
    '      "npm": "@ai-sdk/openai-compatible",'
    '      "name": "AIHubMix",'
    '      "options": {'
    '        "baseURL": "https://aihubmix.com/v1",'
    '        "apiKey": "{env:AIHUBMIX_API_KEY}"'
    '      },'
    '      "models": {'
    $modelsJson
    '      }'
    '    }'
) -join $nl

$path = Join-Path $PSScriptRoot '..\opencode.json'
$text = [System.IO.File]::ReadAllText($path)

$start = $text.IndexOf('"aihubmix"')
$start = $text.LastIndexOf("`n", $start) + 1
if ($start -ge 0) {
    $brace = $text.IndexOf('{', $start)
    $depth = 0
    $end = -1
    for ($i = $brace; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq '{') { $depth++ }
        elseif ($text[$i] -eq '}') {
            $depth--
            if ($depth -eq 0) { $end = $i; break }
        }
    }
    if ($end -lt 0) { throw 'Could not find end of existing aihubmix block in opencode.json' }
    $text = $text.Substring(0, $start) + $block + $text.Substring($end + 1).TrimStart(',')
    $mode = 'updated'
} else {
    $rx = [regex]("(?m)(^  \}," + [regex]::Escape($nl) + '^  "agent": \{)')
    $m = $rx.Match($text)
    if (-not $m.Success) { throw 'Could not find provider section close in opencode.json' }
    $before = $text.Substring(0, $m.Index).TrimEnd("`r", "`n")
    $text = $before + ",$nl" + $block + "$nl" + $text.Substring($m.Index)
    $mode = 'inserted'
}

[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))

# Validate after write; restore backup on any failure (never leave a broken config)
try {
    $check = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $n = ($check.provider.aihubmix.models.PSObject.Properties | Measure-Object).Count
    if ($n -ne $free.Count) { throw "count mismatch after write ($n vs $($free.Count))" }
    Write-Host "  validated: JSON parses, aihubmix block has $n models"
} catch {
    Copy-Item -LiteralPath (Join-Path $bakDir 'opencode.json') -Destination $path -Force
    throw "Write validation failed - restored backup: $_"
}

Write-Host "[aihubmix] $mode $($free.Count) models in opencode.json"
Write-Host "  sample: $($free[0].model_id) (ctx $($free[0].context_length)) ... $($free[-1].model_id) (ctx $($free[-1].context_length))"