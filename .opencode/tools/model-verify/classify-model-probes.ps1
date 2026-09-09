# classify-model-probes.ps1 — turns probe JSONs + prior state into verdicts.
# Pure function of evidence: same inputs -> same outputs. Never calls APIs.
# Taxonomy (locked): ok/informative-400 = healthy; channel/EOL/timeout = problem
# (flap + billing frozen, never accrue); quota = unscanned (frozen); tier/misconfig flagged.
# Two-week rule: badWeeks increments only on consecutive bad weeks for
# dead-class errors; EOL fast-tracks immediately.
param(
    [string]$ToolsDir = '',
    [string]$Week = ''
)
$ErrorActionPreference = 'Stop'
if (-not $ToolsDir) { $ToolsDir = Join-Path $PSScriptRoot '' }
$od = Join-Path $ToolsDir 'output'
$cfg = Get-Content -LiteralPath 'F:\CD\Opencode\opencode.json' -Raw -Encoding UTF8 | ConvertFrom-Json
function LoadJson($n){ $p = Join-Path $od $n; if (Test-Path -LiteralPath $p) { return Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json }; return @() }
$byId = @{}
foreach ($e in ((LoadJson 'hcnsec-probe.json') + (LoadJson 'aihubmix-probe.json') + (LoadJson 'aihubmix-probe-rest.json'))) { $byId[$e.id] = $e }
foreach ($e in (LoadJson 'retry-queue.json')) { $byId[$e.provider + ':' + $e.id] = $e; $byId[$e.id] = $e }
if (-not $Week) { $Week = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd') }
$sp = Join-Path $ToolsDir 'state.json'
$prior = @{}
if (Test-Path -LiteralPath $sp) {
    $ps = Get-Content -LiteralPath $sp -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($k in $ps.models.PSObject.Properties.Name) { $prior[$k] = $ps.models.$k }
}
function Verdict($e) {
    # A probe object with error text IS evidence (classify by error).
    # Only a missing probe object means unscanned. (Status-less timeouts from
    # catch-paths must count as problem, not unscanned.)
    if ($null -eq $e -or $null -eq $e.probe) { return @('unscanned', 'no probe', 'freeze') }
    $p = $e.probe
    if ($p.ok) { return @('healthy', 'chat 200', 'reset') }
    $er = [string]$p.error
    if ($er -match 'end of life|Gone') { return @('dead-fasttrack', 'EOL/410', 'now') }
    if ($er -match 'incorrect') { return @('misconfigured', 'bad ID', 'flag') }
    if ($er -match 'MissingSessionID') { return @('problem', 'session-only', 'count') }
    if ($er -match 'No available channel|model_not_found|no_available_channel') { return @('problem', 'no channel', 'count') }
    if ($er -match 'max_tokens.*illegal|does not support max tokens|maximum context length|maxOutputTokens|Input should be less than') { return @('healthy', 'limit disclosure', 'reset') }
    if ($er -match 'unavailable for free|paid version') { return @('problem-tier', 'left free tier', 'flag') }
    if ($er -match 'requires a subscription|402') { return @('blocked-billing', 'wallet', 'freeze') }
    if ($er -match 'aborted|imeout') { return @('problem', 'timeout/slow', 'count') }
    if ($er -match 'quota|429') { return @('unscanned', 'quota wall', 'freeze') }
    return @('problem', 'unclassified', 'count')
}
$models = @{}
$dueQuarantine = @()
foreach ($pr in @('hcnsec', 'aihubmix')) {
    foreach ($m in $cfg.provider.$pr.models.PSObject.Properties.Name) {
        $k = $pr + ':' + $m
        $v = Verdict($byId[$m])
        $prev = $prior[$k]
        $bw = 0
        if ($v[0] -eq 'healthy') { $bw = 0 }
        elseif ($v[2] -eq 'freeze') { if ($prev) { $bw = $prev.badWeeks } }
        elseif ($v[2] -eq 'flag') { if ($prev) { $bw = $prev.badWeeks } }
        elseif ($v[0] -eq 'dead-fasttrack') { $bw = 99 }
        else {
            if ($prev -and $prev.lastProbeWeek -ne $Week -and $prev.status -eq 'problem') { $bw = [int]$prev.badWeeks + 1 }
            elseif ($prev -and $prev.lastProbeWeek -eq $Week) { $bw = [int]$prev.badWeeks }
            else { $bw = 1 }
        }
        $models[$k] = @{ status = $v[0]; badWeeks = $bw; lastProbeWeek = $Week; lastProbe = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); note = $v[1] }
        if (($bw -ge 2 -and $v[0] -eq 'problem') -or ($v[0] -eq 'dead-fasttrack')) {
            if ($cfg.provider.$pr.models.$m.name -notmatch '\[DEAD') { $dueQuarantine += $k }
        }
    }
}
$state = @{ generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); week = $Week; models = $models }
[IO.File]::WriteAllText($sp, ($state | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
$counts = @{}
foreach ($k in $models.Keys) { $s = $models[$k].status; if (-not $counts.ContainsKey($s)) { $counts[$s] = 0 }; $counts[$s]++ }
$result = @{ counts = $counts; quarantineDue = $dueQuarantine; week = $Week }
$result | ConvertTo-Json -Depth 3 -Compress
