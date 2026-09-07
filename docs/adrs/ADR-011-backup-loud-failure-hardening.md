# ADR-011: Backup loud-failure hardening (wrapper + schedule + diary)

Status: Accepted 2026-09-07. Implements safety jobs L1-L5. Follows ADR-010.

## Context

The Sep-06 14:00 backup committed and pushed correctly but the push FAILED
silently: the scheduled task runs 2 sequential actions and Task Scheduler
reports only the LAST action's exit code, so the passing bundle masked the
failed push (LastTaskResult 0). The failure was found only by manual
inspection. Separately, `secret-scan.yml` watches main/PRs only, so weekly
backup branches (which force-add the memory file) are never scanned.

A second incident during implementation (2026-09-07): `backup-workspace.ps1
-DryRun` was trusted as dry and went FULLY LIVE (branch + push + marker +
Event 100). The `-DryRun` flag is not honored by the script. Contained with
zero main-branch impact; see operational note.

## Decision

1. New `scripts/backup-task-runner.ps1`: single scheduled action. Runs both
   halves in CHILD processes (their `exit <n>` cannot kill the wrapper) and
   exits with the WORSE code. `-DryRun` is echo-only by construction (never
   invokes children) after the 2026-09-07 lesson. `-SkipPush` forwards to the
   workspace half only (bundle has no switches).
2. Push diary: per-half output captured to TEMP
   (`%LOCALAPPDATA%\Temp\opencode-backup-diary\`), `password=` redacted,
   keep-last-4 rotation. EventId 104 on any wrapper-level failure (100/101
   push and 102/103 bundle stay owned by the two scripts, which are UNTOUCHED).
3. `secret-scan.yml` gains a Sunday 17:30 IST schedule (`0 12 * * 0` UTC) +
   `workflow_dispatch`. Pins untouched (bot PR #14 owns versions).
4. Sunday lineup (all IST): 16:00 save → 16:30 verify → 17:00 model-health
   (moved from Mon 08:00) → 17:30 scan (GitHub side) → 18:30 eval-harness
   (moved from 22:00). All four tasks keep StartWhenAvailable (verified).
5. Key health: `GET /rate_limit` probe (zero quota cost) + yearly rolling
   rotation reminder. PAT expiry DATES are not exposed by any GitHub API;
   the date must come from the settings page or the fallback stands.
6. `fix-task-scheduler.ps1` retargeted to the 1-action layout (it would
   otherwise restore the masking bug if re-run). `verify-task` unchanged.

## Consequences

- No silent failures possible via exit-code masking; every failure carries
  a diary with the WHY. First live proof: Sep-13 16:00 run (watched).
- Weekly snapshots get scanned; findings playbook = rotate FIRST, history
  second (scan detects, never deletes).
- Model snapshot inside backups is ~1 week stale by construction
  (save 16:00 runs before the 17:00 model write). Live file is truth.
- Avoid editing allowlisted files 16:00–16:05; a loud failure that week
  means user edits collided with the snapshot (re-runs next Sunday).

## Rollback

- Revert the PR commit (code + docs). Restore the 4 exported task XMLs
  from `.opencode/backups/pre-safety-plan-2026-09-08/` via
  `Register-ScheduledTask -Xml … -Force` (2-action layout back in 1 min).
