#Requires -Version 5.1
<#
.SYNOPSIS
  Probes the 5 configured model providers in parallel and writes a health snapshot.

.DESCRIPTION
  Reads the configured providers from opencode.json, probes each via a 5-second
  HTTP GET to the provider's /models endpoint (or similar), and writes results
  to docs/active-models.md (replacing the snapshot table only — never secrets).

  Uses Start-Job (not PowerShell 7-only ForEach-Object -Parallel) so it works on
  PowerShell 5.1. Secrets are read from $env and auth.json via API only — never
  echoed, logged, or written to disk.

.PARAMETER Output
  Output file path (default: docs/active-models.md relative to repo root).

.PARAMETER TimeoutSec
  Per-provider timeout in seconds (default: 5).

.EXAMPLE
  pwsh -File scripts\check-model-health.ps1
  pwsh -File scripts\check-model-health.ps1 -TimeoutSec 10
#>
[CmdletBinding()]
param(
    [string]$Output = "docs/active-models.md",
    [int]$TimeoutSec = 5
)

$ErrorActionPreference = "Stop"
$repoRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
Set-Location $repoRoot

# 1. Load configured providers from opencode.json
$cfgPath = Join-Path $repoRoot "opencode.json"
if (-not (Test-Path $cfgPath)) { throw "opencode.json not found at $cfgPath" }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json

# Build provider list from env vars + opencode.json
# Each provider tuple: { name, baseUrl, keyEnvVar }
$providers = @()

# ollama-cloud
if ($env:OLLAMA_CLOUD_API_KEY -or (Test-Path "$env:USERPROFILE\.local\share\opencode\auth.json")) {
    $providers += [pscustomobject]@{
        Name      = "ollama-cloud"
        BaseUrl   = "https://ollama.com/v1"
        KeyEnv    = "OLLAMA_CLOUD_API_KEY"
    }
}
# hcnsec
if ($env:HCNSEC_API_KEY) {
    $providers += [pscustomobject]@{
        Name      = "hcnsec"
        BaseUrl   = "https://api.hcnsec.cn/v1"
        KeyEnv    = "HCNSEC_API_KEY"
    }
}
# nvidia
if ($env:NVIDIA_API_KEY) {
    $providers += [pscustomobject]@{
        Name      = "nvidia"
        BaseUrl   = "https://integrate.api.nvidia.com/v1"
        KeyEnv    = "NVIDIA_API_KEY"
    }
}
# google
if ($env:GEMINI_API_KEY) {
    $providers += [pscustomobject]@{
        Name      = "google"
        BaseUrl   = "https://generativelanguage.googleapis.com/v1beta"
        KeyEnv    = "GEMINI_API_KEY"
    }
}
# opencode-go (always has key in auth.json)
$providers += [pscustomobject]@{
    Name      = "opencode-go"
    BaseUrl   = "https://opencode.ai/zen/v1"
    KeyEnv    = ""
}

if ($providers.Count -eq 0) {
    Write-Warning "No providers configured (no env vars set, no auth.json found)"
    exit 1
}

Write-Host "Probing $($providers.Count) provider(s) in parallel (timeout ${TimeoutSec}s each)..."

# 2. Launch parallel probes via Start-Job
$jobs = @()
foreach ($p in $providers) {
    $job = Start-Job -ScriptBlock {
        param($providerName, $baseUrl, $keyEnvName, $timeoutSec)
        $key = ""
        if ($keyEnvName) { $key = (Get-Item env:$keyEnvName -ErrorAction SilentlyContinue).Value }
        $headers = @{}
        if ($key) { $headers["Authorization"] = "Bearer $key" }
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $resp = Invoke-RestMethod -Uri "$baseUrl/models" -Headers $headers -TimeoutSec $timeoutSec -Method GET -ErrorAction Stop
            $sw.Stop()
            return [pscustomobject]@{
                Provider   = $providerName
                Status     = if ($sw.Elapsed.TotalSeconds -lt 3) { "Healthy" } else { "Slow" }
                LatencyMs  = [int]$sw.ElapsedMilliseconds
                ModelCount = if ($resp.data) { $resp.data.Count } elseif ($resp.models) { $resp.models.Count } else { 0 }
                Error      = $null
            }
        } catch {
            $sw.Stop()
            return [pscustomobject]@{
                Provider   = $providerName
                Status     = "Unreachable"
                LatencyMs  = [int]$sw.ElapsedMilliseconds
                ModelCount = 0
                Error      = $_.Exception.Message
            }
        }
    } -ArgumentList $p.Name, $p.BaseUrl, $p.KeyEnv, $TimeoutSec
    $jobs += $job
}

# 3. Wait for all jobs (with overall timeout = TimeoutSec + 5s buffer)
$overallTimeout = ($TimeoutSec + 5) * 1000
$waited = $jobs | Wait-Job -Timeout $overallTimeout
$timedOut = @($jobs | Where-Object { $_.State -eq "Running" })
foreach ($j in $timedOut) { Stop-Job $j }

$results = @()
foreach ($j in $jobs) {
    $r = Receive-Job -Job $j -Keep -ErrorAction SilentlyContinue
    if ($r) { $results += $r }
    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
}

# 4. Print summary (one line per provider, NO secrets)
Write-Host ""
Write-Host "=== Provider Health Summary ==="
foreach ($r in $results) {
    $icon = switch ($r.Status) {
        "Healthy"     { "[OK]" }
        "Slow"        { "[SLOW]" }
        "Unreachable" { "[DOWN]" }
        default       { "[--]" }
    }
    Write-Host ("  {0} {1,-15} {2,-12} {3,5}ms  {4} models" -f $icon, $r.Provider, $r.Status, $r.LatencyMs, $r.ModelCount)
    if ($r.Error) { Write-Host "      Error: $($r.Error)" -ForegroundColor Yellow }
}

# 5. Update docs/active-models.md (snapshot table only)
$outPath = Join-Path $repoRoot $Output
if (Test-Path $outPath) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    $lines = Get-Content $outPath
    $newTable = @()
    $newTable += "| Provider           | API Base                          | Status | Latency | Models Verified | Last Checked       |"
    $newTable += "| ------------------ | --------------------------------- | ------ | ------- | --------------- | ------------------ |"
    foreach ($r in $results) {
        $providerInfo = $providers | Where-Object { $_.Name -eq $r.Provider }
        $base = if ($providerInfo) { $providerInfo.BaseUrl } else { "n/a" }
        $newTable += "| ``$($r.Provider)`` | ``$base`` | $($r.Status) | $($r.LatencyMs)ms | $($r.ModelCount) | $ts |"
    }
    # Replace existing snapshot table (from "## Snapshot" header through next "## " header)
    $startIdx = ($lines | Select-String -Pattern "^## Snapshot" | Select-Object -First 1).LineNumber - 1
    if ($startIdx -ge 0) {
        $endIdx = $startIdx + 1
        while ($endIdx -lt $lines.Count -and $lines[$endIdx] -notmatch "^## ") { $endIdx++ }
        $before = $lines[0..($startIdx)]
        $after = $lines[$endIdx..($lines.Count - 1)]
        $newContent = ($before + $newTable + $after) -join "`n"
        Set-Content -Path $outPath -Value $newContent -Encoding UTF8
        Write-Host ""
        Write-Host "Updated: $outPath" -ForegroundColor Green
    } else {
        Write-Warning "Could not find '## Snapshot' header in $outPath - file NOT modified"
    }
}

# 6. Exit code: 0 if all healthy, 1 if any unreachable
$anyDown = $results | Where-Object { $_.Status -eq "Unreachable" }
if ($anyDown) { exit 1 } else { exit 0 }
