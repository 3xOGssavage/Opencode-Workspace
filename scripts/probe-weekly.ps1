# probe-weekly.ps1 — Sunday model-audit loop (design: docs/model-audit.md).
# Flow: git guard -> node probers (core + rotating tail + pins/pending)
#   -> classify -> stage warranted changes on rolling branch -> report -> toast.
# Exit 0 = ran (findings are data). Secrets live in-process only, never logged.
# Usage: powershell -ExecutionPolicy Bypass -File scripts\probe-weekly.ps1 [-DryRun]
param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
$root = (Get-Item -Path $PSScriptRoot).Parent.FullName
Set-Location $root
$tools = Join-Path $root '.opencode\tools\model-verify'
$od = Join-Path $tools 'output'
$repDir = Join-Path $tools 'reports'
New-Item -ItemType Directory -Path $repDir -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$log = @()
function Say($s){ $script:log += $s; Write-Host $s }

function Get-State {
    $sp = Join-Path $tools 'state.json'
    if (Test-Path -LiteralPath $sp) { return Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json }
    return $null
}

# ---- phase 0: git guard (mutation needs a clean tree apart from known-runtime files)
$canMutate = $true
if (-not $DryRun) {
    $tracked = @(git diff --name-only) + @(git diff --cached --name-only)
    $allowed = @('.opencode/memory.jsonl')
    $bad = @($tracked | Where-Object {
        ($_ -ne '') -and ($_ -notin $allowed) -and ($_ -notlike '.opencode/tools/model-verify/*')
    })
    if ($bad.Count -gt 0) { Say ('GUARD: working tree dirty, mutation disabled: ' + ($bad -join ', ')); $canMutate = $false }
}

# ---- phase 1: probes (core lists + hcnsec + ah sample + auth spots)
Say 'phase 1: core probes'
if (-not $DryRun) {
    & node (Join-Path $tools 'probe.mjs') 2>&1 | Select-Object -Last 5 | ForEach-Object { Say ('  ' + $_) }
    # rotating tail over aihubmix indices 10..N (user chose rotation over quota wall)
    $st0 = Get-State
    $prevOff = 10
    if ($st0 -and $st0.nextTailOffset) { $prevOff = [int]$st0.nextTailOffset }
    $cfg0 = Get-Content -LiteralPath (Join-Path $root 'opencode.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $tailTotal = ($cfg0.provider.aihubmix.models.PSObject.Properties | Measure-Object).Count - 10
    if ($tailTotal -lt 1) { $tailTotal = 1 }
    $off = 10 + (($prevOff - 10) % $tailTotal)
    $env:PROBE_AH_OFFSET = "$off"; $env:PROBE_AH_COUNT = '12'
    Say ("phase 1b: rotating tail offset=$off")
    & node (Join-Path $tools 'probe-ah.mjs') 2>&1 | Select-Object -Last 8 | ForEach-Object { Say ('  ' + $_) }
    Remove-Item Env:\PROBE_AH_OFFSET -ErrorAction SilentlyContinue
    Remove-Item Env:\PROBE_AH_COUNT -ErrorAction SilentlyContinue
} else { Say 'DRYRUN: skipping live probes' }

# ---- phase 2: classify (taxonomy + two-week rule + rotation state)
Say 'phase 2: classify'
$stateBak = $null
if ($DryRun) {
    $stateBak = Join-Path $tools 'state.json.drybak'
    Copy-Item -LiteralPath (Join-Path $tools 'state.json') -Destination $stateBak -Force
}
$sumJson = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tools 'classify-model-probes.ps1') -ToolsDir $tools 2>&1 | Where-Object { $_ -match '^\{' } | Select-Object -Last 1
$sum = $sumJson | ConvertFrom-Json
if ($script:nextOffset) {
    $sp = Join-Path $tools 'state.json'
    $sj = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json
    $sj | Add-Member -NotePropertyName 'nextTailOffset' -NotePropertyValue $script:nextOffset -Force
    [IO.File]::WriteAllText($sp, ($sj | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
}
if ($DryRun -and $stateBak) {
    Copy-Item -LiteralPath $stateBak -Destination (Join-Path $tools 'state.json') -Force
    Remove-Item -LiteralPath $stateBak -Force
    Say 'DRYRUN: state.json restored'
}
$counts = @()
foreach ($k in $sum.counts.PSObject.Properties) { $counts += ($k.Name + '=' + $k.Value) }
Say ('verdicts: ' + ($counts -join ' '))

# ---- phase 3: stage warranted changes on rolling branch (never main, never push)
if ($canMutate -and (-not $DryRun) -and $sum.quarantineDue.Count -gt 0) {
    Say 'phase 3: staging quarantine renames on auto/model-audit'
    git checkout -B auto/model-audit main 2>&1 | Out-Null
    $cfgPath = Join-Path $root 'opencode.json'
    $txt = [IO.File]::ReadAllText($cfgPath, [Text.Encoding]::UTF8)
    $today = Get-Date -Format 'yyyy-MM-dd'
    foreach ($id in $sum.quarantineDue) {
        $prov = $id.Split(':')[0]; $mid = $id.Split(':')[1]
        $cfgNow = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $cur = $cfgNow.provider.$prov.models.$mid.name
        if ($cur -match '\[DEAD') { continue }
        $new = $cur + ' [DEAD ' + $today + ']'
        $txt = $txt.Replace('"name": "' + $cur + '"', '"name": "' + $new + '"')
        Say ('  tagged: ' + $id)
    }
    [IO.File]::WriteAllText($cfgPath, $txt, (New-Object Text.UTF8Encoding $false))
    $chk = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $chk.provider) { throw 'post-edit validation failed, aborting (working tree left dirty for inspection)' }
    git add -- opencode.json
    git commit -m ("[auto] model audit " + (Get-Date -Format 'yyyy-MM-dd') + ": quarantine tags") 2>&1 | Out-Null
    Say 'staged on auto/model-audit (PR happens next chat session)'
} else { Say 'phase 3: nothing to stage (or guard/DryRun)' }

# ---- phase 4: report (local-only) + toast (always, full counts)
$rep = Join-Path $repDir ("run-" + $stamp + ".md")
$body = @('# Weekly model audit ' + $stamp, '', 'Verdicts: ' + ($counts -join ' '), '',
    'Quarantine due: ' + (($sum.quarantineDue -join ', ') | Out-String).Trim(),
    '', 'Mutated this run: ' + $canMutate, 'Next tail offset: ' + $script:nextOffset) -join "`n"
[IO.File]::WriteAllText($rep, $body, (New-Object Text.UTF8Encoding $false))
Say ('report: ' + $rep)
$toast = 'Model audit ' + $stamp + ': ' + ($counts -join ' ')
if ($DryRun) { Say 'DRYRUN: toast suppressed' }
else {
try {
    if (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue) {
        Import-Module BurntToast -ErrorAction Stop
        New-BurntToastNotification -Text 'Opencode model audit', $toast -ErrorAction Stop
        Say 'toast: BurntToast sent'
    } else { throw 'no BurntToast' }
} catch {
    . (Join-Path $root 'scripts\_notify-fallback.ps1')
    Send-Notify -Title 'Opencode model audit' -Message $toast -Severity 'Info'
    Say 'toast: EventLog fallback used'
}
}
Say 'DONE exit 0'
exit 0
