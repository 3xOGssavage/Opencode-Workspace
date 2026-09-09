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
# ---- phase 2b: pending newcomers (catalog minus config) -> probe -> selective insert
# Spotless rule: only clean-200 probes get added. Quota-wall leftovers retry later.
Say 'phase 2b: pending newcomers'
$pendingH = @(); $pendingA = @(); $script:ahMeta = @{}
try {
    $liveH = (Get-Content -LiteralPath (Join-Path $od 'hcnsec-live-models.json') -Raw -Encoding UTF8 | ConvertFrom-Json).data
    $cfgIds = @{}
    $cfgAll = Get-Content -LiteralPath (Join-Path $root 'opencode.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($p in $cfgAll.provider.hcnsec.models.PSObject.Properties) { $cfgIds[$p.Name] = $true }
    foreach ($m in $liveH) {
        if ($m.id -and (-not $cfgIds.ContainsKey($m.id)) -and ($m.supported_endpoint_types -contains 'openai')) { $pendingH += [string]$m.id }
    }
} catch { Say ('  hcnsec pending compute failed') }
try {
    $ahk = [Environment]::GetEnvironmentVariable('AIHUBMIX_API_KEY', 'User')
    $ph = @{ Authorization = ('Bearer ' + $ahk) }
    $plaza = Invoke-RestMethod -Uri 'https://aihubmix.com/api/v1/models' -Headers $ph -TimeoutSec 60
    $parr = if ($plaza -is [array]) { $plaza } else { $plaza.data }
    $vl = Invoke-RestMethod -Uri 'https://aihubmix.com/v1/models' -Headers $ph -TimeoutSec 60
    $vd = if ($vl -is [array]) { $vl } else { $vl.data }
    $call = @{}; foreach ($m in $vd) { $call[$m.id] = $true }
    $ahCfg = @{}
    foreach ($p in $cfgAll.provider.aihubmix.models.PSObject.Properties) { $ahCfg[$p.Name] = $true }
    # Mirror of sync-aihubmix-models.ps1 $exclude - keep in sync if that list changes.
    $excl = @('gemini-3.1-flash-image-preview-free', 'gpt-image-2-free', 'ling-3.0-tiny-free', 'coding-glm-5-turbo-free', 'xiaomi-mimo-v2-omni-free', 'xiaomi-mimo-v2-pro-free', 'glm-5.2-free')
    foreach ($m in $parr) {
        if ($m.model_id -match '-free$' -and $m.context_length -gt 0 -and $call.ContainsKey($m.model_id) -and (-not $ahCfg.ContainsKey($m.model_id)) -and ($m.model_id -notin $excl)) {
            $pendingA += [string]$m.model_id
            $script:ahMeta[$m.model_id] = @{ ctx = [int]$m.context_length; out = [int]$m.max_output; name = [string]$m.model_name }
        }
    }
} catch { Say ('  aihubmix pending compute failed') }
Say ('  pending hcnsec(' + $pendingH.Count + '): ' + ($pendingH -join ', '))
Say ('  pending aihubmix(' + $pendingA.Count + '): ' + ($pendingA -join ', '))
$verifiedH = @(); $verifiedA = @(); $flaggedLimits = @()
if ((($pendingH.Count + $pendingA.Count) -gt 0) -and (-not $DryRun)) {
    $pargs = @(); foreach ($i in $pendingH) { $pargs += ('hcnsec:' + $i) }; foreach ($i in $pendingA) { $pargs += ('aihubmix:' + $i) }
    & node (Join-Path $tools 'retry-queue.mjs') @pargs 2>&1 | Select-Object -Last 4 | ForEach-Object { Say ('  ' + $_) }
    $rq = Get-Content -LiteralPath (Join-Path $od 'retry-queue.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($e in $rq) {
        if ($e.probe.ok) { if ($e.provider -eq 'hcnsec') { $verifiedH += $e.id } else { $verifiedA += $e.id } }
        else { Say ('  newcomer not spotless, skipped: ' + $e.provider + ':' + $e.id) }
    }
} elseif ($DryRun) { Say 'DRYRUN: newcomer probes skipped' }
if ((($verifiedH.Count + $verifiedA.Count) -gt 0) -and $canMutate -and (-not $DryRun)) {
    $wbak = Join-Path $root ('.opencode\backups\pre-weekly-' + $stamp)
    New-Item -ItemType Directory -Path $wbak -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $root 'opencode.json') -Destination (Join-Path $wbak 'opencode.json') -Force
    Say ('  backup: ' + $wbak)
    if ($verifiedH.Count -gt 0) {
        & (Join-Path $root 'scripts\sync-hcnsec-models.ps1') -AllowIds $verifiedH 2>&1 | ForEach-Object { Say ('  ' + $_) }
    }
    foreach ($nid in $verifiedA) {
        $meta = $script:ahMeta[$nid]
        $octx = 128000; $oout = 8192
        if ($meta) {
            if ($meta.ctx -gt 0) { $octx = $meta.ctx }
            if ($meta.out -gt 0) { $oout = $meta.out } else { $flaggedLimits += $nid }
            $onm = $meta.name; if (-not $onm) { $onm = ($nid -replace '-', ' ') }
        } else { $onm = ($nid -replace '-', ' '); $flaggedLimits += ($nid + ' (no catalog meta)') }
        $enm = $onm -replace '\\', '\\' -replace '"', '\"'
        $cfgT = Join-Path $root 'opencode.json'
        $tx = [IO.File]::ReadAllText($cfgT, [Text.Encoding]::UTF8)
        $aIdx = $tx.IndexOf('"aihubmix"'); $moIdx = $tx.IndexOf('"models"', $aIdx)
        $keyPat = '(?m)^        "([^"]+)": \{\r?$'
        $ms = [regex]::Matches($tx.Substring($moIdx), $keyPat)
        $insAt = -1
        foreach ($mm in $ms) {
            if ([string]::Compare($nid, $mm.Groups[1].Value, $true) -lt 0) { $insAt = $moIdx + $mm.Index; break }
        }
        $block = '        "' + $nid + '": {' + "`n" + '          "limit": { "output": ' + $oout + ', "context": ' + $octx + ' },' + "`n" + '          "name": "' + $enm + '"' + "`n" + '        }'
        if ($insAt -lt 0) {
            $closePat = '(?m)^      \}\r?$'
            $cm = [regex]::Matches($tx.Substring($moIdx), $closePat) | Select-Object -First 1
            if ($null -eq $cm) { throw ('aihubmix block close not found for ' + $nid) }
            $prevEnd = $moIdx + $cm.Index - 1
            while ($prevEnd -gt 0 -and ($tx[$prevEnd] -eq "`n" -or $tx[$prevEnd] -eq "`r")) { $prevEnd-- }
            if ($tx[$prevEnd] -ne '}') { throw ('unexpected block tail for ' + $nid) }
            $tx = $tx.Substring(0, $prevEnd + 1) + ',' + "`n" + $block + $tx.Substring($moIdx + $cm.Index)
        } else {
            $tx = $tx.Substring(0, $insAt) + $block + ',' + "`n" + $tx.Substring($insAt)
        }
        [IO.File]::WriteAllText($cfgT, $tx, (New-Object Text.UTF8Encoding $false))
        Say ('  inserted: aihubmix:' + $nid)
    }
    $chk2 = Get-Content -LiteralPath (Join-Path $root 'opencode.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $chk2.provider) { throw 'post-insert validation failed, aborting (backup at pre-weekly dir)' }
    Say '  inserts validated (JSON parses)'
}
if ($flaggedLimits.Count -gt 0) { Say ('  NEEDS-LIMITS review: ' + ($flaggedLimits -join ', ')) }
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
        if ($cur -match '\[DEAD') { Say ('  already tagged, skip: ' + $id); continue }
        # Uniqueness assert: two entries share some display names (e.g. Minimax M3
        # twice). A blind replace would mistag both, so non-unique names are
        # skipped loudly for manual handling instead of guessed.
        $needle = '"name": "' + $cur + '"'
        $hits = ([regex]::Matches($txt, [regex]::Escape($needle))).Count
        if ($hits -ne 1) { Say ('  SKIP non-unique name (' + $hits + 'x), needs human: ' + $id); continue }
        $new = $cur + ' [DEAD ' + $today + ']'
        $txt = $txt.Replace($needle, '"name": "' + $new + '"')
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
