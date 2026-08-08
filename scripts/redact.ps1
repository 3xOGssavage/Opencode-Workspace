#Requires -Version 5.1
<#
.SYNOPSIS
  Redacts PII and API keys from text using tiered patterns (regex + Luhn).

.DESCRIPTION
  Reads guardrails/regex-patterns.yaml and applies patterns to input text.
  Tier 1 = exact-format API keys (high confidence, no context needed).
  Tier 2 = SSN/phone/email with context keywords.
  Tier 3 = credit cards (regex + Luhn checksum + network-aware length).
  Audit-logs all redactions to scripts/.redact-audit.log.

  Designed for output-side use (after model response, before display/log).
  NEVER apply to user prompts - breaks legitimate user intent.

.PARAMETER InputPath
  Path to file containing text to redact. Mutually exclusive with -InputString.

.PARAMETER InputString
  Direct text to redact. Mutually exclusive with -InputPath.

.PARAMETER PatternsPath
  Path to YAML patterns file (default: guardrails/regex-patterns.yaml).

.PARAMETER OutputPath
  Write redacted text to file. If omitted, writes to stdout.

.PARAMETER NoAudit
  Skip audit logging.

.PARAMETER DryRun
  Show what would be redacted (counts only), don't write output.

.EXAMPLE
  pwsh -File scripts\redact.ps1 -InputString "My key is sk-ant-abc123..." -DryRun
  Get-Content log.txt | pwsh -File scripts\redact.ps1 -InputPath log.txt -OutputPath log.redacted.txt
  pwsh -File scripts\redact.ps1 -InputPath error.json -OutputPath error.redacted.json
#>
[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$InputString,
    [string]$PatternsPath = "guardrails\regex-patterns.yaml",
    [string]$OutputPath,
    [switch]$NoAudit,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$repoRoot = (Get-Item -Path $PSScriptRoot).Parent.FullName
Set-Location $repoRoot

if ($InputPath -and $InputString) { throw "Specify only ONE of -InputPath or -InputString" }
if (-not $InputPath -and -not $InputString) {
    # Try stdin
    if ($Host.Name -eq "ConsoleHost" -and -not [Console]::IsInputRedirected) {
        throw "Specify -InputPath or -InputString"
    }
    $InputString = [Console]::In.ReadToEnd()
}
if (-not (Test-Path $PatternsPath)) { throw "Patterns file not found: $PatternsPath" }

# 1. Read input
if ($InputPath) {
    $inputText = Get-Content -LiteralPath $InputPath -Raw -ErrorAction Stop
} else {
    $inputText = $InputString
}

$inputLength = $inputText.Length

# 2. Simple YAML parser for this file's flat-ish structure.
#    (Avoids dependency on powershell-yaml module.)
function Get-YamlValue {
    param([string]$Text, [string]$Key)
    $pattern = "^\s*${Key}:\s*(.+)$"
    if ($Text -match "(?m)$pattern") { return $Matches[1].Trim() }
    return $null
}

$patternsRaw = Get-Content -LiteralPath $PatternsPath -Raw

# 3. Tier 1: high-confidence API keys
$tier1Count = 0
$tier1Patterns = @(
    @{ Name = "anthropic_key";    Regex = 'sk-ant-[A-Za-z0-9_-]{32,}';     Repl = "[REDACTED-API-KEY]" },
    @{ Name = "openai_key";       Regex = 'sk-[A-Za-z0-9]{20,}T3BlbkFJ[A-Za-z0-9]{20,}'; Repl = "[REDACTED-API-KEY]" },
    @{ Name = "openai_project";   Regex = 'sk-proj-[A-Za-z0-9_-]{40,}';    Repl = "[REDACTED-API-KEY]" },
    @{ Name = "opencode_key";     Regex = 'sk-W[A-Za-z0-9]{20,}';          Repl = "[REDACTED-API-KEY]" },
    @{ Name = "github_pat";       Regex = 'gh[pousr]_[A-Za-z0-9]{36,}';    Repl = "[REDACTED-API-KEY]" },
    @{ Name = "github_oauth";     Regex = 'gho_[A-Za-z0-9]{36,}';          Repl = "[REDACTED-API-KEY]" },
    @{ Name = "hcnsec_key";       Regex = 'sk-[A-Za-z0-9_-]{48,}';         Repl = "[REDACTED-API-KEY]" },
    @{ Name = "gemini_key";       Regex = 'AIza[A-Za-z0-9_-]{35}';         Repl = "[REDACTED-API-KEY]" },
    @{ Name = "nvidia_nim_key";   Regex = 'nvapi-[A-Za-z0-9_-]{20,}';      Repl = "[REDACTED-API-KEY]" },
    @{ Name = "jwt_token";        Regex = 'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'; Repl = "[REDACTED-JWT]" }
)
foreach ($p in $tier1Patterns) {
    $before = $inputText
    $inputText = [regex]::Replace($inputText, $p.Regex, $p.Repl)
    $diff = ($before.Length - $inputText.Length)
    if ($diff -gt 0) {
        # Approximate count: each match removes at least the matched length - replacement length
        $matches = [regex]::Matches($before, $p.Regex)
        $tier1Count += $matches.Count
    }
}

# 4. Tier 2: context-required patterns (SSN/phone/email)
$tier2Count = 0
$contextWindow = 30
function Test-Context {
    param([string]$Text, [int]$MatchIndex, [string[]]$Keywords)
    $start = [Math]::Max(0, $MatchIndex - $contextWindow)
    $window = $Text.Substring($start, [Math]::Min($contextWindow, $MatchIndex - $start))
    foreach ($kw in $Keywords) {
        if ($window -match [regex]::Escape($kw)) { return $true }
    }
    return $false
}

# SSN with context
$ssnRegex = '\b\d{3}-\d{2}-\d{4}\b'
$ssnMatches = [regex]::Matches($inputText, $ssnRegex)
for ($i = $ssnMatches.Count - 1; $i -ge 0; $i--) {
    $m = $ssnMatches[$i]
    if (Test-Context -Text $inputText -MatchIndex $m.Index -Keywords @("ssn", "social security", "tax id")) {
        $inputText = $inputText.Substring(0, $m.Index) + "[REDACTED-SSN]" + $inputText.Substring($m.Index + $m.Length)
        $tier2Count++
    }
}

# US Phone with context
$phoneRegex = '\b(?:\+?1[-.\s]?)?\(?[2-9]\d{2}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'
$phoneMatches = [regex]::Matches($inputText, $phoneRegex)
for ($i = $phoneMatches.Count - 1; $i -ge 0; $i--) {
    $m = $phoneMatches[$i]
    if (Test-Context -Text $inputText -MatchIndex $m.Index -Keywords @("phone", "tel", "mobile", "cell", "call")) {
        $inputText = $inputText.Substring(0, $m.Index) + "[REDACTED-PHONE]" + $inputText.Substring($m.Index + $m.Length)
        $tier2Count++
    }
}

# Email with context
$emailRegex = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'
$emailMatches = [regex]::Matches($inputText, $emailRegex)
for ($i = $emailMatches.Count - 1; $i -ge 0; $i--) {
    $m = $emailMatches[$i]
    if (Test-Context -Text $inputText -MatchIndex $m.Index -Keywords @("email", "mail to", "contact", "from:", "to:")) {
        $inputText = $inputText.Substring(0, $m.Index) + "[REDACTED-EMAIL]" + $inputText.Substring($m.Index + $m.Length)
        $tier2Count++
    }
}

# 5. Tier 3: Luhn-validated credit cards
$tier3Count = 0
function Test-Luhn {
    param([string]$Number)
    # [int]$char gives ASCII code; need [int]::Parse or -as [int] for digit value
    $digits = $Number.ToCharArray() | ForEach-Object { [int]::Parse($_) }
    $sum = 0
    $alt = $false
    for ($i = $digits.Count - 1; $i -ge 0; $i--) {
        $d = $digits[$i]
        if ($alt) {
            $d *= 2
            if ($d -gt 9) { $d -= 9 }
        }
        $sum += $d
        $alt = -not $alt
    }
    return ($sum % 10 -eq 0)
}

# CC patterns with network/length awareness
# Allow optional hyphens or spaces between digit groups: "4111-1111-1111-1111" or "4111111111111111"
# Anchors use (?<!\d) and (?!\d) instead of \b (hyphens are non-word so \b works at boundaries)
$ccPatterns = @(
    @{ Name = "amex";       Regex = '(?<!\d)3[47](?:[\s-]?\d){13}(?!\d)';    Repl = "[REDACTED-CC]"; Length = 15 },
    @{ Name = "visa";       Regex = '(?<!\d)4(?:[\s-]?\d){12}(?:[\s-]?\d{3}){0,2}(?!\d)'; Repl = "[REDACTED-CC]"; Length = @(13, 16, 19) },
    @{ Name = "mastercard"; Regex = '(?<!\d)(?:5[1-5](?:[\s-]?\d){14}|2(?:2(?:2[1-9]|[3-9]\d)|[3-6]\d{2}|7(?:[01]\d|20))(?:[\s-]?\d){12})(?!\d)'; Repl = "[REDACTED-CC]"; Length = 16 },
    @{ Name = "discover";   Regex = '(?<!\d)6(?:011|5\d{2})(?:[\s-]?\d){12}(?!\d)'; Repl = "[REDACTED-CC]"; Length = 16 },
    @{ Name = "diners";     Regex = '(?<!\d)3(?:0[0-5]|[68]\d)(?:[\s-]?\d){11}(?!\d)'; Repl = "[REDACTED-CC]"; Length = 14 }
)
foreach ($p in $ccPatterns) {
    $matches = [regex]::Matches($inputText, $p.Regex)
    for ($i = $matches.Count - 1; $i -ge 0; $i--) {
        $m = $matches[$i]
        $digits = ($m.Value -replace '\D', '')
        # Network/length check (count only digits)
        $lengthOk = if ($p.Length -is "array") { $digits.Length -in $p.Length } else { $digits.Length -eq $p.Length }
        if ($lengthOk -and (Test-Luhn -Number $digits)) {
            $inputText = $inputText.Substring(0, $m.Index) + $p.Repl + $inputText.Substring($m.Index + $m.Length)
            $tier3Count++
        }
    }
}

# 6. Output
$outputLength = $inputText.Length
$totalRedacted = $tier1Count + $tier2Count + $tier3Count

if ($DryRun) {
    Write-Host "=== redact (dry run) ==="
    Write-Host "  Input length    : $inputLength chars"
    Write-Host "  Tier 1 (API keys): $tier1Count"
    Write-Host "  Tier 2 (PII)    : $tier2Count"
    Write-Host "  Tier 3 (CCs)    : $tier3Count"
    Write-Host "  Total redacted  : $totalRedacted"
    exit 0
}

if ($OutputPath) {
    Set-Content -LiteralPath $OutputPath -Value $inputText -Encoding UTF8 -NoNewline
    Write-Host "Wrote: $OutputPath ($outputLength chars, $totalRedacted redacted)"
} else {
    Write-Output $inputText
}

# 7. Audit log
if (-not $NoAudit) {
    $auditPath = Join-Path $repoRoot "scripts\.redact-audit.log"
    $entry = @(
        (Get-Date -Format "o"),
        "input=$inputLength",
        "output=$outputLength",
        "tier1=$tier1Count",
        "tier2=$tier2Count",
        "tier3=$tier3Count",
        "total=$totalRedacted"
    ) -join " | "
    Add-Content -LiteralPath $auditPath -Value $entry -Encoding UTF8
}
