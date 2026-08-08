#Requires -Version 5.1
<#
.SYNOPSIS
  Runs all eval cases in evals/cases/*.yaml, captures opencode output for each,
  grades against deterministic checks, writes results to evals/latest-summary.json.

.DESCRIPTION
  Smoke-test eval harness. NOT a full eval suite - v1 is regression-detection
  only. One case per top-5 skill (5 cases total). Deterministic checks only;
  LLM-judge is v2.

  Each case YAML has:
    skill: "skill-name"
    description: "what this tests"
    prompt: "the prompt to send to opencode"
    expected_outputs: [list of substrings that MUST appear in output]
    forbidden_outputs: [list of substrings that MUST NOT appear]
    timeout_seconds: 300

  For each case:
    1. Invoke: opencode run --pure "<prompt>" 2>&1
    2. Capture stdout
    3. Check expected_outputs all present
    4. Check forbidden_outputs all absent
    5. Record pass/fail + timing

  Exit code: 0 if all pass, 1 if any fail.

.PARAMETER CaseDir
  Directory containing case YAML files (default: evals/cases).

.PARAMETER OutputFile
  Where to write results JSON (default: evals/latest-summary.json).

.PARAMETER Case
  Run a single case by skill name (default: all cases).

.PARAMETER Timeout
  Per-case timeout in seconds (default: from YAML, fallback 300).

.EXAMPLE
  pwsh -File evals\run.ps1
  pwsh -File evals\run.ps1 -Case brainstorming
  pwsh -File evals\run.ps1 -Timeout 60
#>
[CmdletBinding()]
param(
    [string]$CaseDir = "evals\cases",
    [string]$OutputFile = "evals\latest-summary.json",
    [string]$Case,
    [int]$Timeout = 300
)

$ErrorActionPreference = "Stop"
$repoRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
Set-Location $repoRoot

if (-not (Test-Path $CaseDir)) { throw "Case directory not found: $CaseDir" }

# 1. Discover cases
$caseFiles = Get-ChildItem -Path $CaseDir -Filter "*.yaml" -ErrorAction SilentlyContinue
if ($Case) {
    $caseFiles = $caseFiles | Where-Object { $_.BaseName -eq $Case }
    if (-not $caseFiles) { throw "Case not found: $Case" }
}
if ($caseFiles.Count -eq 0) {
    Write-Host "No case files found in $CaseDir"
    exit 0
}

# 2. Check opencode - pick the Application (binary), not Function/Alias shadows
#    When run from a workspace with `opencode.json`, PowerShell may resolve `opencode`
#    to a Function that wraps the binary. Use -All to see all matches and prefer
#    Application type to get the real executable.
$allOpencode = Get-Command opencode -All -ErrorAction SilentlyContinue
$opencodeCmd = $allOpencode | Where-Object { $_.CommandType -eq "Application" } | Select-Object -First 1
if (-not $opencodeCmd) {
    $opencodeCmd = $allOpencode | Where-Object { $_.CommandType -eq "ExternalScript" } | Select-Object -First 1
}
if (-not $opencodeCmd) {
    $opencodeCmd = Get-Command opencode -ErrorAction SilentlyContinue  # fallback
}
if (-not $opencodeCmd) {
    Write-Warning "opencode not found - skipping live runs (dry mode)"
    $dryMode = $true
} else {
    $dryMode = $false
    $opencodePath = $opencodeCmd.Source
    if (-not $opencodePath) { $opencodePath = $opencodeCmd.Path }
    $isPwshWrapper = $opencodePath -like '*.ps1'
    Write-Host "  opencode : $opencodePath (wrapper=$isPwshWrapper)"
}

Write-Host "=== eval harness ==="
Write-Host "  Case dir  : $CaseDir"
Write-Host "  Cases     : $($caseFiles.Count)"
Write-Host "  Dry mode  : $dryMode"
Write-Host "  Output    : $OutputFile"
Write-Host ""

$results = @()
$anyFail = $false

foreach ($caseFile in $caseFiles) {
    $caseName = $caseFile.BaseName
    Write-Host "--- $caseName ---"
    $caseContent = Get-Content $caseFile.FullName -Raw

    # Simple YAML extraction (this file's cases are flat-key: value)
    $skill = $null
    $prompt = $null
    foreach ($line in ($caseContent -split "`n")) {
        if (-not $skill -and $line -match '^skill:\s*"?([^"\n]+?)"?\s*$') {
            $skill = $Matches[1].Trim()
        } elseif (-not $prompt -and $line -match '^prompt:\s*"?(.+?)"?\s*$') {
            $prompt = $Matches[1].Trim()
        }
    }

    # Extract expected_outputs list (very simple - assumes format "- 'string'" or "- string")
    $expectedOutputs = @()
    $expectedSection = $false
    foreach ($line in ($caseContent -split "`n")) {
        if ($line -match '^expected_outputs:') { $expectedSection = $true; continue }
        if ($expectedSection -and $line -match '^\s*-\s*(.+)$') {
            # Strip surrounding quotes AND trailing whitespace/CR
            $val = $Matches[1].Trim() -replace '^["'']|["'']$', ''
            $expectedOutputs += $val
        } elseif ($expectedSection -and $line -match '^[a-z_]+:') {
            $expectedSection = $false
        }
    }

    $forbiddenOutputs = @()
    $forbiddenSection = $false
    foreach ($line in ($caseContent -split "`n")) {
        if ($line -match '^forbidden_outputs:') { $forbiddenSection = $true; continue }
        if ($forbiddenSection -and $line -match '^\s*-\s*(.+)$') {
            $val = $Matches[1].Trim() -replace '^["'']|["'']$', ''
            $forbiddenOutputs += $val
        } elseif ($forbiddenSection -and $line -match '^[a-z_]+:') {
            $forbiddenSection = $false
        }
    }

    if (-not $skill -or -not $prompt) {
        Write-Warning "  skipping: missing skill or prompt in YAML"
        continue
    }

    Write-Host "  skill    : $skill"
    Write-Host "  prompt   : $($prompt.Substring(0, [Math]::Min(60, $prompt.Length)))..."

    if ($dryMode) {
        Write-Host "  result   : SKIPPED (dry mode - opencode not available)"
        $results += @{
            skill = $skill
            case = $caseName
            deterministic_passed = 0
            deterministic_failed = 0
            llm_judge_score = $null
            status = "skipped"
            timestamp = (Get-Date -Format "o")
        }
        Write-Host ""
        continue
    }

    # 3. Run opencode
    $output = ""
    $exitCode = 0
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $argsList = @("run", "--pure", "--print-logs", "--log-level", "WARN", $prompt)
        if ($isPwshWrapper) {
            # opencode is a .ps1 wrapper; invoke via powershell -File <script> <args>.
            $fullArgs = @("-NoProfile", "-File", $opencodePath) + $argsList
            $proc = Start-Process -FilePath "powershell.exe" `
                -ArgumentList $fullArgs `
                -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput "evals\.tmp.stdout" `
                -RedirectStandardError "evals\.tmp.stderr"
            $exitCode = $proc.ExitCode
        } else {
            $proc = Start-Process -FilePath $opencodePath `
                -ArgumentList $argsList `
                -NoNewWindow -Wait -PassThru `
                -RedirectStandardOutput "evals\.tmp.stdout" `
                -RedirectStandardError "evals\.tmp.stderr"
            $exitCode = $proc.ExitCode
        }
        # Merge stdout + stderr (opencode with --print-logs writes model output
        # to stderr, not stdout). Check both for expected/forbidden patterns.
        $stdoutContent = Get-Content "evals\.tmp.stdout" -Raw -ErrorAction SilentlyContinue
        $stderrContent = Get-Content "evals\.tmp.stderr" -Raw -ErrorAction SilentlyContinue
        $output = ($stdoutContent + "`n" + $stderrContent)
    } catch {
        $output = "ERROR: $($_.Exception.Message)"
        $exitCode = 1
    } finally {
        Remove-Item "evals\.tmp.stdout" -ErrorAction SilentlyContinue
        Remove-Item "evals\.tmp.stderr" -ErrorAction SilentlyContinue
    }
    $sw.Stop()
    $elapsedMs = [int]$sw.ElapsedMilliseconds

    # 4. Grade - deterministic checks
    $detPassed = 0
    $detFailed = 0
    $failures = @()

    foreach ($expected in $expectedOutputs) {
        if ($output -match [regex]::Escape($expected)) {
            $detPassed++
        } else {
            $detFailed++
            $failures += "missing expected: $expected"
        }
    }
    foreach ($forbidden in $forbiddenOutputs) {
        if ($output -match [regex]::Escape($forbidden)) {
            $detFailed++
            $failures += "found forbidden: $forbidden"
        } else {
            $detPassed++
        }
    }

    $status = if ($detFailed -eq 0 -and $exitCode -eq 0) { "passed" } else { "failed" }
    if ($status -eq "failed") { $anyFail = $true }

    Write-Host "  passed   : $detPassed"
    Write-Host "  failed   : $detFailed"
    Write-Host "  exit     : $exitCode"
    Write-Host "  elapsed  : ${elapsedMs}ms"
    Write-Host "  status   : $status"
    if ($failures.Count -gt 0) {
        Write-Host "  failures :"
        foreach ($f in $failures) { Write-Host "    - $f" }
    }
    Write-Host ""

    $results += @{
        skill = $skill
        case = $caseName
        deterministic_passed = $detPassed
        deterministic_failed = $detFailed
        llm_judge_score = $null
        exit_code = $exitCode
        elapsed_ms = $elapsedMs
        status = $status
        timestamp = (Get-Date -Format "o")
    }
}

# 5. Write summary
$summary = @{
    run_timestamp = (Get-Date -Format "o")
    total_cases = $results.Count
    passed = ($results | Where-Object { $_.status -eq "passed" }).Count
    failed = ($results | Where-Object { $_.status -eq "failed" }).Count
    skipped = ($results | Where-Object { $_.status -eq "skipped" }).Count
    results = $results
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputFile -Encoding UTF8
Write-Host "Wrote: $OutputFile"
Write-Host ""
Write-Host "=== summary ==="
Write-Host "  total : $($summary.total_cases)"
Write-Host "  passed: $($summary.passed)"
Write-Host "  failed: $($summary.failed)"
Write-Host "  skipped: $($summary.skipped)"

if ($anyFail) { exit 1 } else { exit 0 }
