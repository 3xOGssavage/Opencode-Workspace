# ADR-010: Backup-workspace allowlist + deny-check + branch-from-main (2026-09-03)

## Status

Accepted (shipped via PR #34, merged commit 3c2e93c, on 2026-09-03)

## Context

The weekly backup script `scripts/backup-workspace.ps1` (the v7 design documented in README "Backup hardening v7") was designed to snapshot workspace state to a dated branch on the GitHub remote. Its design had three structural flaws that turned it from a useful backup into a pollution vector:

1. **`git add -A`** — a single command staged every file the index didn't already track, with no scope filter. Any file dropped at the repo root between runs (whether deliberate or accidental) was swept into the next commit.
2. **Branch from current HEAD** — `git checkout -b $branchName` created the dated branch from wherever the previous run had left the working tree, not from `main`. An interrupted run left a dirty working tree; the next run branched from that dirty state.
3. **No deny-check** — once staged, anything went into the commit. There was no last-line check for known junk patterns (tmp**, smoke-*, check*_.py, jwts, _.tmp) to abort the run.

The two pollution incidents that motivated this fix:

- **2026-08-23:** the script's `git add -A` swept 7 AIHubMix pricing-scrape files (extract\_\*.py ×4, final_output.py, mistral_pricing_table.md, zen_models_table.md) into a real commit (2b3a550) and pushed it to `origin/main`. Visible to anyone browsing the repo for ~11 days.
- **2026-08-30:** the same script was interrupted between staging 594 foreign Hermes/OpenWebUI smoke-test files and committing, leaving the index half-loaded on `chore/auto-backup-2026-08-30` with no unique commits and no recovery path short of `git reset`.

Together: 48 foreign files at the repo root, 7 already on the public GitHub history, no script-level guardrail to prevent recurrence.

## Decision

Four surgical changes to `scripts/backup-workspace.ps1` (now committed in 493e9a7 on origin/main), plus three root-anchored `.gitignore` rules as defense-in-depth (also in 493e9a7):

1. **`git add -A` → explicit allowlist.** Stage only:
   - 10 root config files (AGENTS.md, README.md, ONBOARDING.md, SECURITY.md, CODEOWNERS, skills-lock.json, opencode.json, .gitignore, .gitattributes, .ignore)
   - 8 config directories (.opencode, scripts, docs, evals, global-config, guardrails, .github, .githooks)
   - 2 explicit project files (Projects/.gitignore, Projects/.gitkeep)

   Each path is `Test-Path`-checked before `git add` so absent files (e.g., `.ignore` not present on a fresh clone) don't fail the script.

2. **`git reset -q` before the allowlist.** Clears any pre-staged entries left by an interrupted previous run. Prevents the half-loaded-index class of failure (the 594-staged-no-commit incident on 2026-08-30).

3. **Deny-check after staging, before commit.** If any staged path matches `(^|/)tmp_|^smoke-|(^|/)check_.*\.py$|jwts|\.tmp$`, the script throws with the offending list and the run aborts. Loud failure, not silent corruption.

4. **Always branch from `main`.** Changed `git checkout -b $branchName` to `git checkout -b $branchName main` so the dated backup branch starts from the known-clean main tip, not from whatever dirty state the previous run left behind.

`.gitignore` additions (root-anchored per gitignore docs, verified zero collateral on all 151 tracked files at the time of the PR):

```
/tmp_*
/smoke-*/
/check_*.py
```

These are belt-and-braces: even if the allowlist were ever bypassed or fat-fingered, these three patterns physically prevent sweep-ups of the three most common junk-naming classes from getting into any future commit.

## Consequences

**Positive:**

- Future foreign files at the repo root can no longer be swept into the backup commit (allowlist doesn't include them; gitignore guards them).
- Interrupted runs can no longer leave the index half-loaded (reset -q at the start clears whatever was staged).
- The backup program aborts loudly (not silently) if a future config mistake ever stages a junk-pattern path.
- A live test of the fix runs automatically at the next scheduled backup: **2026-09-06 14:00** (the "Opencode monthly backup" scheduled task).

**Accepted trade-offs:**

- A new root-level config file (e.g., a future top-level LICENSE) won't be in the allowlist until added. Cost: one-line edit. Mitigation: the script's deny-check + the `.gitignore` guards catch junk, and the new file will show as untracked in `git status` on first commit, making it visible to add deliberately.
- Adding a path to the allowlist is a small recurring cost. The list is short (20 entries) and lives in one place.

**Collateral findings (preserved in operational note):**

- 48 foreign files relocated to `Projects/tmg/hermes/leftovers/` in three labeled subfolders, with a SHA-256 manifest at `_manifest.txt`. Not deleted; preserved per the user's "move, don't delete" directive.
- 701 unreachable git objects in `.git/` (the orphaned smoke-test blobs from the 2026-08-30 interrupted `git add`, plus historical debris from pre-existing deleted branches). Safe to prune with `git gc --prune=now` at any time. Deferred per user instruction to keep the cleanup diff minimal.

## Rollback

If the new behavior causes problems:

1. **One-commit revert:** `git revert -m 1 3c2e93c` (the merge commit). Drops the allowlist, deny-check, reset, branch-from-main, and the 3 gitignore rules in one shot.
2. **Pre-merge alternative:** close PR #34 + delete branch `chore/repo-cleanup`. No effect on main.
3. **Emergency workaround without reverting:** if only the deny-check is misfiring, edit `scripts/backup-workspace.ps1` and broaden the regex (or remove the deny-check step) — the allowlist and gitignore guards remain in force as defense in depth.

## References

- **PR #34** — `https://github.com/3xOGssavage/Opencode-Workspace/pull/34` (merged 2026-09-03, 4 checks passed)
- **Commits:** 493e9a7 (the hardening + 7 deletions + 3 gitignore rules) and 6a86385 (the graft rule under Projects/)
- **Operational note:** `docs/operational-history/POST-CLEANUP-NOTE-2026-09-03-workspace-depollution.md` — the full incident narrative + verification receipts + boxes recovery runbook
- **Related:** `README.md` "Backup hardening v7" section (v7 design that this ADR supersedes in part)
- **Manifest:** `Projects/tmg/hermes/leftovers/_manifest.txt` — SHA-256 receipt of the 48 preserved foreign files
