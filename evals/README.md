# Eval Harness

> **v1 — smoke-test only.** This harness detects REGRESSIONS in skill loading/behavior, not full quality. LLM-judge scoring is v2.

## What this does

Runs each case in `evals/cases/*.yaml` by invoking `opencode run --pure <prompt>` and checking that the output contains expected substrings (and doesn't contain forbidden ones). Writes a JSON summary to `evals/latest-summary.json`.

This is "grade the output, not the path" per the Anthropic eval framework principle: we don't check _how_ the skill produced its output, only _whether_ the output looks right.

## What this does NOT do

- ❌ Does NOT use `opencode export` (schema is unstable across versions — GitHub issue #21941)
- ❌ Does NOT do LLM-as-judge scoring (deferred to v2)
- ❌ Does NOT run in CI (GitHub-hosted runners lack opencode binary + Ollama Cloud quota concerns)
- ❌ Does NOT test multi-turn skills like brainstorming beyond the first response
- ❌ Does NOT benchmark model quality across providers

## Running

```powershell
# Run all 5 cases
pwsh -File evals\run.ps1

# Run single case
pwsh -File evals\run.ps1 -Case brainstorming

# Custom timeout
pwsh -File evals\run.ps1 -Timeout 60
```

**Output:** `evals/latest-summary.json` — aggregate pass/fail counts + per-case breakdown.

## Case YAML format

```yaml
skill: "skill-name" # skill being tested (for grouping)
description: > # human-readable description
  What this test catches.
prompt: "prompt to send to opencode run"
expected_outputs: # substrings that MUST appear in output
  - "?"
  - "scope"
forbidden_outputs: # substrings that MUST NOT appear
  - "Here's the implementation"
timeout_seconds: 120 # max time to wait for opencode
```

## Exit codes

- `0` — all cases passed (or all skipped in dry mode)
- `1` — at least one case failed
- `2` — error (case dir missing, opencode not found, etc.)

## Automation

Add a weekly Task Scheduler entry:

| Setting                        | Value                                             |
| ------------------------------ | ------------------------------------------------- |
| Program                        | `powershell`                                      |
| Arguments                      | `-NoProfile -File "F:\CD\Opencode\evals\run.ps1"` |
| Trigger                        | Weekly, Sunday 22:00                              |
| "Run as"                       | current user                                      |
| "Run only when user logged on" | yes                                               |

If exit code is non-zero, `scripts/backup-verify.ps1`-style notification fires (requires BurntToast via `scripts/setup-burnttoast.ps1`).

## Adding new cases

1. Create `evals/cases/<skill-name>.yaml`
2. Pick a prompt that should reliably trigger the skill
3. List 1-3 expected substrings (specific enough to be meaningful)
4. List 1-3 forbidden substrings (catches the regression)
5. Set realistic timeout (60-300s for most skills)
6. Test locally: `pwsh -File evals\run.ps1 -Case <skill-name>`

## When results are meaningful

| Result                       | Means                                                          |
| ---------------------------- | -------------------------------------------------------------- |
| All 5 pass                   | Skills loaded and behaving as expected. Continue.              |
| 1 case fails, others pass    | Skill probably regressed. Investigate that skill's SKILL.md.   |
| All 5 fail with empty output | opencode binary missing or `--pure` flag breaks skill loading. |
| All 5 fail with timeout      | Provider unreachable. Check `docs/active-models.md`.           |

## Related

- `scripts/check-model-health.ps1` — verify providers before running evals
- `.opencode/skills/` — the skills being tested
- `AGENTS.md` — quality standards
