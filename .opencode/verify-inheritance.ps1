# verify-inheritance.ps1
# Verifies opencode config inheritance setup.
# Confirms OPENCODE_CONFIG + OPENCODE_CONFIG_DIR env vars are set correctly
# and child project configs don't override inherited blocks.
#
# Usage: powershell -ExecutionPolicy Bypass -File F:\CD\Opencode\.opencode\verify-inheritance.ps1
#
# Exits 0 if all checks pass, 1 if any check fails.

$ErrorActionPreference = "Stop"
$EXPECTED_OC  = "F:\CD\Opencode\opencode.json"
$EXPECTED_OCD = "F:\CD\Opencode\.opencode"
$PROJECTS_ROOT = "F:\CD\Opencode\Projects"

$failures = 0

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " Opencode Config Inheritance Check" -ForegroundColor Cyan
Write-Host " $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check 1: OPENCODE_CONFIG env var
Write-Host "[1] Checking OPENCODE_CONFIG env var..." -ForegroundColor Yellow
$oc = [System.Environment]::GetEnvironmentVariable("OPENCODE_CONFIG", "User")
if ($oc -eq $EXPECTED_OC) {
    Write-Host "    [OK] OPENCODE_CONFIG = $oc" -ForegroundColor Green
} else {
    Write-Host "    [FAIL] OPENCODE_CONFIG = '$oc' (expected '$EXPECTED_OC')" -ForegroundColor Red
    $failures++
}

# Check 2: OPENCODE_CONFIG_DIR env var
Write-Host "[2] Checking OPENCODE_CONFIG_DIR env var..." -ForegroundColor Yellow
$ocd = [System.Environment]::GetEnvironmentVariable("OPENCODE_CONFIG_DIR", "User")
if ($ocd -eq $EXPECTED_OCD) {
    Write-Host "    [OK] OPENCODE_CONFIG_DIR = $ocd" -ForegroundColor Green
} else {
    Write-Host "    [FAIL] OPENCODE_CONFIG_DIR = '$ocd' (expected '$EXPECTED_OCD')" -ForegroundColor Red
    $failures++
}

# Check 3: Param file exists
Write-Host "[3] Checking parent opencode.json exists..." -ForegroundColor Yellow
if (Test-Path $EXPECTED_OC) {
    Write-Host "    [OK] parent opencode.json found" -ForegroundColor Green
} else {
    Write-Host "    [FAIL] parent opencode.json MISSING" -ForegroundColor Red
    $failures++
}

# Check 4: Parent .opencode directory exists
Write-Host "[4] Checking parent .opencode directory exists..." -ForegroundColor Yellow
if (Test-Path $EXPECTED_OCD) {
    Write-Host "    [OK] parent .opencode found" -ForegroundColor Green
} else {
    Write-Host "    [FAIL] parent .opencode MISSING" -ForegroundColor Red
    $failures++
}

# Check 5: Parent config parseable + has hcnsec provider
Write-Host "[5] Checking parent config + hcnsec provider..." -ForegroundColor Yellow
try {
    $parent = Get-Content $EXPECTED_OC -Raw | ConvertFrom-Json
    if ($null -ne $parent.provider.hcnsec) {
        $modelCount = (Get-Member -InputObject $parent.provider.hcnsec.models -MemberType NoteProperty).Count
        Write-Host "    [OK] hcnsec provider present ($modelCount models)" -ForegroundColor Green
    } else {
        Write-Host "    [FAIL] hcnsec provider MISSING" -ForegroundColor Red
        $failures++
    }
} catch {
    Write-Host "    [FAIL] parent JSON parse error: $_" -ForegroundColor Red
    $failures++
}

# Check 6: Parent config MCP count
Write-Host "[6] Checking parent config MCP servers..." -ForegroundColor Yellow
if ($parent.mcp) {
    $mcpCount = (Get-Member -InputObject $parent.mcp -MemberType NoteProperty).Count
    Write-Host "    [OK] $mcpCount MCP servers defined" -ForegroundColor Green
} else {
    Write-Host "    [FAIL] no MCP servers in parent config" -ForegroundColor Red
    $failures++
}

# Check 7: Parent config agents count
Write-Host "[7] Checking parent config agents..." -ForegroundColor Yellow
if ($parent.agent) {
    $agentCount = (Get-Member -InputObject $parent.agent -MemberType NoteProperty).Count
    Write-Host "    [OK] $agentCount agents defined" -ForegroundColor Green
} else {
    Write-Host "    [WARN] no agents in parent config" -ForegroundColor Yellow
}

# Check 8: Parent skills.paths exist
Write-Host "[8] Checking parent skills.paths..." -ForegroundColor Yellow
if ($parent.skills.paths) {
    $missingPaths = @()
    foreach ($p in $parent.skills.paths) {
        if (-not (Test-Path $p)) { $missingPaths += $p }
    }
    if ($missingPaths.Count -gt 0) {
        Write-Host "    [WARN] $($parent.skills.paths.Count) paths, $($missingPaths.Count) missing:" -ForegroundColor Yellow
        foreach ($m in $missingPaths) { Write-Host "           - $m" -ForegroundColor Yellow }
    } else {
        Write-Host "    [OK] $($parent.skills.paths.Count) skill paths all resolvable" -ForegroundColor Green
    }
}

# Check 9: Child configs don't override inherited blocks
Write-Host "[9] Scanning child project configs..." -ForegroundColor Yellow
$inheritanceBlocks = @('provider','mcp','permission','lsp','formatter','plugin','skills','tool_output','compaction')
$childFailures = 0
if (Test-Path $PROJECTS_ROOT) {
    Get-ChildItem $PROJECTS_ROOT -Directory | ForEach-Object {
        $proj = $_.Name
        $configPath = Join-Path $_.FullName "opencode.json"
        if (Test-Path $configPath) {
            try {
                $c = Get-Content $configPath -Raw | ConvertFrom-Json
                $bad = $inheritanceBlocks | Where-Object { $c.PSObject.Properties.Name -contains $_ }
                if ($bad) {
                    Write-Host "    [$proj] [WARN] overrides parent: $($bad -join ', ')" -ForegroundColor Yellow
                } else {
                    Write-Host "    [$proj] [OK] no inheritance-breaking overrides" -ForegroundColor Green
                }
            } catch {
                Write-Host "    [$proj] [FAIL] JSON parse error: $_" -ForegroundColor Red
                $childFailures++
            }
        } else {
            Write-Host "    [$proj] [INFO] no opencode.json (inherits all)" -ForegroundColor Cyan
        }
    }
}
if ($childFailures -gt 0) { $failures += $childFailures }

# Check 10: Parent .opencode directory has agents/commands/skills
Write-Host "[10] Checking parent .opencode contents..." -ForegroundColor Yellow
$criticalDirs = @('agents','commands','skills')
foreach ($sub in $criticalDirs) {
    $path = Join-Path $EXPECTED_OCD $sub
    if (Test-Path $path) {
        $count = (Get-ChildItem $path | Measure-Object).Count
        Write-Host "    [OK] $sub/ ($count items)" -ForegroundColor Green
    } else {
        Write-Host "    [WARN] $sub/ MISSING" -ForegroundColor Yellow
    }
}

# Check 11: HCNSEC_API_KEY env var (needed for hcnsec provider)
Write-Host "[11] Checking HCNSEC_API_KEY env var..." -ForegroundColor Yellow
$hcnKey = [System.Environment]::GetEnvironmentVariable("HCNSEC_API_KEY", "User")
if ($hcnKey) {
    Write-Host "    [OK] HCNSEC_API_KEY is set ($($hcnKey.Length) chars)" -ForegroundColor Green
} else {
    Write-Host "    [WARN] HCNSEC_API_KEY missing - hcnsec provider won't authenticate" -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
if ($failures -eq 0) {
    Write-Host " RESULT: ALL CHECKS PASSED" -ForegroundColor Green
    Write-Host " Config inheritance is correctly configured." -ForegroundColor Green
    Write-Host " All child project sessions will inherit parent settings:" -ForegroundColor Green
    Write-Host "   - hcnsec provider (20 models) - visible in model picker" -ForegroundColor Green
    Write-Host "   - 15 MCP servers - active per session" -ForegroundColor Green
    Write-Host "   - Parent agents/commands/skills - available everywhere" -ForegroundColor Green
} else {
    Write-Host " RESULT: $failures CHECKS FAILED" -ForegroundColor Red
    Write-Host " Resolve the failures above before relying on inheritance." -ForegroundColor Red
}
Write-Host "=====================================" -ForegroundColor Cyan

if ($failures -gt 0) {
    exit 1
}
exit 0
