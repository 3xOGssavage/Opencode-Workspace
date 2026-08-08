---
name: structured-log
description: >-
  Capture opencode session output to dated log files with 30-day rotation, and
  use opencode's built-in log flags for structured output. Wraps
  scripts/launch-with-logs.ps1. Use when you want a persistent record of an
  opencode session (for debugging, audit, or handoff to another session).
---

# Structured Log

When you need a durable record of what opencode did — for debugging a recurring failure, handing context off to another session, or auditing agent actions — use `scripts/launch-with-logs.ps1` instead of calling `opencode run` directly.

## When to use

- Running a session whose output you want to review later
- Debugging a flaky workflow that needs multiple attempts
- Auditing what the agent did in production-like conditions
- Handing session output to another agent/session for follow-up

## When NOT to use

- Interactive use where you're watching the screen (just run `opencode` normally)
- Quick throwaway tests where you don't need persistence
- When the log file would itself contain secrets (use `redact-output` skill first to scrub)

## Quick start

```powershell
# Capture a prompt + response to a dated log file
pwsh -File scripts\launch-with-logs.ps1 -Prompt "refactor scripts/audit-secrets.ps1"

# Capture with verbose logging (DEBUG level)
pwsh -File scripts\launch-with-logs.ps1 -LogLevel DEBUG

# Specify custom log directory
pwsh -File scripts\launch-with-logs.ps1 -LogDir "D:\logs\opencode" -RetentionDays 7
```

## What the wrapper does

1. Ensures `$env:LOCALAPPDATA\opencode\logs` exists
2. Rotates logs older than 30 days (configurable)
3. Invokes `opencode run --print-logs --log-level <LEVEL> <prompt>`
4. Captures stdout → `opencode-YYYY-MM-DD-HHmmss.log`
5. Captures stderr → `opencode-YYYY-MM-DD-HHmmss.log.err` (only if non-empty)
6. Returns opencode's exit code

## Built-in opencode log flags (verified in `opencode --help`)

| Flag                  | Purpose                                        |
| --------------------- | ---------------------------------------------- |
| `--print-logs`        | Print logs to stdout (in addition to log file) |
| `--log-level <LEVEL>` | Set minimum log level (DEBUG/INFO/WARN/ERROR)  |

## Related built-ins (not wrapped, use directly)

| Command                     | Purpose                                     |
| --------------------------- | ------------------------------------------- |
| `opencode stats`            | Usage stats (tokens, cost, model breakdown) |
| `opencode export <session>` | Export session to JSON or markdown          |
| `opencode import <file>`    | Import a previously-exported session        |

> **CAUTION:** `opencode export` schema is NOT stable across versions (see GitHub issue #21941, Apr 2026). Don't rely on it for critical backups — use the `backup-workspace.ps1` workflow instead.

## Related

- `scripts/launch-with-logs.ps1` — the wrapper script
- `AGENTS.md` — Core operating principles (logging + observability)
- `.opencode/skills/redact-output/SKILL.md` — scrub PII before logging
