---
name: redact-output
description: >-
  Redacts API keys, PII (SSN, phone, email), and credit card numbers from text
  output before logging or display. Wraps scripts/redact.ps1. Use proactively
  whenever a tool response, log line, or error message is about to be written
  to disk, included in another prompt, or persisted to memory. NEVER apply to
  user prompts - redaction must not break legitimate user intent (e.g., user
  explicitly types their own email to sign up).
---

# Redact Output

You MUST run `scripts/redact.ps1` on text that contains third-party credentials, error messages with user identifiers, or any structured data that may include PII **before**:

- Writing to disk
- Including in another prompt to a different agent/model
- Persisting to memory (`.opencode/memory.jsonl`)
- Displaying to the user in chat output (the script is fast — use `-DryRun` first to preview)

## When to invoke

| Situation                                         | Apply? |
| ------------------------------------------------- | ------ |
| Model output that echoes a tool response          | YES    |
| Log line containing a stack trace with user data  | YES    |
| Error message from API that includes request body | YES    |
| User's own prompt content                         | **NO** |
| Code snippets in skill descriptions               | **NO** |
| Test fixtures explicitly marked as safe           | **NO** |
| Skill definitions and YAML patterns themselves    | **NO** |

## Quick start

```powershell
# Preview what would be redacted (no file write, no audit log)
pwsh -File scripts\redact.ps1 -InputString $output -DryRun

# Apply and write to file
$output | pwsh -File scripts\redact.ps1 -InputString $output -OutputPath output.redacted.txt

# Apply and capture to variable (writes to stdout)
$clean = pwsh -File scripts\redact.ps1 -InputString $output -NoAudit
```

## Patterns applied (see `guardrails/regex-patterns.yaml` for full details)

**Tier 1 — high confidence, exact format, no context:**

- Anthropic, OpenAI, OpenAI-Project, opencode, GitHub PAT/OAuth, hcnsec, Gemini, NVIDIA NIM API keys
- JWT tokens

**Tier 2 — context-required (keyword within 30 chars before match):**

- US SSN with `SSN:`/`social security:`/`tax id:` keyword
- US phone with `phone:`/`tel:`/`mobile:`/`cell:`/`call:` keyword
- Email with `email:`/`mail to:`/`contact:`/`from:`/`to:` keyword

**Tier 3 — Luhn-validated credit cards:**

- American Express (15 digits, starts 34/37)
- Visa (13/16/19 digits, starts 4)
- Mastercard (16 digits, starts 51-55 or 2221-2720)
- Discover (16 digits, starts 6011/65)
- Diners Club (14 digits, starts 300-305/36-38)
- All checked against the Luhn checksum algorithm

## False-positive rates (from `guardrails/regex-patterns.yaml`)

- Tier 1: ~0.5% (JWT-vs-base64 collision is the main case)
- Tier 2: ~0.5% with context keywords
- Tier 3: <0.01% after Luhn + network-aware filtering

## Audit trail

Every redaction is logged to `scripts/.redact-audit.log` with timestamp, input length, tier breakdown, and total count. Disable with `-NoAudit` for one-off uses; do NOT disable for production data flows.

## Related

- `guardrails/regex-patterns.yaml` — pattern definitions with FP-rate documentation
- `scripts/redact.ps1` — the underlying script
- `AGENTS.md` — Security Model section
- `SECURITY.md` — vulnerability reporting channel
