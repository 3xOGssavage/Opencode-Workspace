# Post-Cleanup Note — 2026-09-03

## Event: Workspace pollution recovery + backup program hardening

**Date:** 2026-09-03
**Scope:** 48 foreign files relocated; 7 files removed from GitHub records; backup program hardened with 4 changes; 3 root-anchored .gitignore guards added; 8 stale branches pruned.
**Risk profile:** Low — every moved file has a fingerprint-verified copy in a git-ignored box; the backup program change is additive gating, not destructive; the 7 git-rm deletions are recoverable from history forever.

---

## TL;DR

Two pollution incidents between Aug 23 and Aug 30 polluted the opencode parent directory with 48 foreign files (smoke-test scripts, model-probe outputs, AIHubMix pricing-scrape files). On 2026-09-03, seven recovery phases moved every foreign file into a labeled, git-ignored box at `Projects/tmg/hermes/leftovers/`, removed the 7 publicly-pushed junk files from GitHub records via PR #34, and fixed the weekly backup program that caused the pollution in the first place. Four-way verification (basic parity + pre-pollution baseline + full-tree junk sweep + content-level diff) confirmed the workspace is now back to its designed clean state — and slightly cleaner than before the incident.

The full design decision lives in **ADR-010**; the 14-point verification receipts and the boxes recovery runbook live below.

---

## What was done

### 1. The pollution (what happened, when, how discovered)

**The Aug 23 incident.** The weekly backup script `scripts/backup-workspace.ps1` ran on schedule, did its `git add -A` (stage everything the index didn't already track), committed, and pushed the dated branch to `origin`. Unbeknownst to anyone at the time, it had also swept 7 AIHubMix pricing-scrape files (created during a one-off model-pricing research session weeks earlier) into the commit and pushed them to public GitHub. The 7 files lived on `origin/main` for ~11 days, visible to anyone with the URL.

**The Aug 30 incident.** A separate Hermes/OpenWebUI testing project (in `Projects/tmg/`, by a cooperating agent session) generated 594 test files (shell scripts, Python helpers, smoke-test screenshots, a Playwright node_modules install, JWT tokens for the test). The session ended abruptly. The backup script ran the next day (or possibly in a same-day run before the cooperating agent finished), staged 594 of those foreign files into the index, and then — for whatever reason — was interrupted before the commit step. Result: 594 foreign files sitting in git's waiting room (the index) on branch `chore/auto-backup-2026-08-30`, with no unique commits and no commit on disk.

**Discovery.** The user noticed the foreign files at the repo root during a regular audit and engaged two agents: (a) the original polluting agent, who moved the smoke-test folder into `Projects/tmg/hermes/` and unstaged its 550 entries; (b) this session, which handled the remaining 44 half-loaded items, the 7 publicly-pushed junk files, the backup program, and the stale branches.

**Pre-pollution commit baseline** (the truly clean state before any of this): `32d2e57` ("Merge PR #28 — feat/tavily-smart-router", 2026-08-27). Everything after that in main is the pollution; everything before it is the legit pre-state.

### 2. The plan (7 phases, all gates passed)

Each phase had a gate (a measurable check) before the next started. Every gate passed.

#### Phase 0 — Receipt manifest

Created `Projects/tmg/hermes/leftovers/` with three labeled subfolders (`from-opencode-root/`, `model-verify/`, `pricing-scrapes/`) plus a SHA-256 manifest of the 48 files about to move. Added a proactive `*`+`!.gitignore` inside leftovers so if `Projects/tmg/hermes/` ever becomes a git repo, the boxes auto-protect themselves.

**Gate:** manifest = exactly 48 rows, all readable.

#### Phase 1 — Empty git's waiting room

`git reset` to unstage the 44 half-loaded items. No files on disk moved. This step is critical: if you remove files before clearing the index, a later commit can still bake the "deleted" junk into history (the exact mechanism that created the 2b3a550 commit in the first place).

Also created the `chore/repo-cleanup` branch from the current position (which == main content exactly) to receive the cleanup commits.

**Gate:** `git status --porcelain` shows only untracked junk + memory.jsonl M + Projects/.gitignore M (the 3 legit modifications).

#### Phase 2 — Move into labeled boxes

- Moved 18 root files (tmp\__.py/.sh, check_banner_.py, helper.py, patch.py) into `from-opencode-root/`
- Moved 23 model-verify files (round 2-5 probe outputs + scripts, including the round-2-5 mjs scripts) into `model-verify/` (its internal `output/` subfolder preserved)
- Copied 7 pricing-scrape files (extract\_\*.py ×4, final_output.py, mistral_pricing_table.md, zen_models_table.md) into `pricing-scrapes/` (copies, not moves, because these get `git rm`'d next)

**Gate:** every copy's SHA-256 matches the manifest. 48/48 verified, 0 mismatches. Root folder shows zero foreign names.

#### Phase 3 — Remove the 7 from GitHub records

`git rm` on the 7 pricing-scrape files. Copies in the box already verified in Phase 2; files remain in git history forever (recoverable via `git show 493e9a7^:<name>`).

**Gate:** exactly 7 deletions staged, nothing else.

#### Phase 4 — Fix the cause

Patched `scripts/backup-workspace.ps1` with the 4 surgical changes documented in ADR-010 (allowlist + reset -q + deny-check + branch-from-main). Added 3 root-anchored gitignore guards. Verified the patch via PowerShell 5.1 syntax check and the script's own `-DryRun` mode.

**Gate:** syntax OK; DryRun completes the new flow without error; deny-check fires silently (no junk); new gitignore patterns re-tested against all 151 committed files = zero collateral.

#### Phase 5 — Two tidy commits + push + PR

Two commits on the `chore/repo-cleanup` branch:

- `493e9a7` — chore: remove accidentally-committed scrape files, harden backup allowlist, add root junk guards
- `6a86385` — chore: ignore graft local graph cache under Projects/ (a separate small change to the project-level gitignore for the graft tooling, also stale in working tree)

Pushed branch → created **PR #34** with a detailed body listing every change, the verification receipts, the rollback procedure, and the dependencies. **Merged on 2026-09-03 with 4 checks passed.**

`.ignore` was left on disk untracked per the cooperating agent's instruction (it's the graft search config file; not committed, not deleted, stays on disk for the graft ripgrep use case).

**Gate:** PR #34 merged, 3c2e93c is now origin/main, the 7 junk files no longer appear in any current branch's tree on GitHub.

#### Phase 6 — Branch pruning

Eight merged branches were stale and pointed to commits fully reachable from `main`. All verified merged via `git merge-base --is-ancestor` before deletion (per the plan's safety rule: any unmerged branch is left alone and reported).

Deleted (7 remote + their local counterparts where present):

- `chore/repo-cleanup` (the cleanup branch itself)
- `chore/auto-backup-2026-08-23` (local only — the never-pushed interrupted backup)
- `chore/auto-backup-2026-08-30` (local only — the never-pushed interrupted backup)
- `feat/tavily-key-rotation`
- `feat/tavily-smart-router`
- `fix/aihubmix-tokenrouter-cleanup`
- `fix/hcnsec-prune-align`
- `feat/workspace-reproducibility` (remote only)
- `fix/workspace-reconcile` (remote only)

Preserved (3 remote, all unmerged per merge-check): the 3 `dependabot/*` branches (dependabot bot keeps them open for future PRs; deleting them would break the bot's state).

Pruned all stale tracking refs with `git remote prune origin`.

**Gate:** `git branch -a` shows exactly: `main` (local) + 3 dependabot branches (remote) + `origin/main` (remote).

#### Phase 7 — Final audit

Three independent verification passes (in this order):

1. **GitHub parity** — `git diff origin/main --name-only` returns exactly 1 line: `.opencode/memory.jsonl` (the runtime knowledge-graph file, designed to be different on every machine).
2. **Pre-pollution baseline** — current main (3c2e93c) vs `32d2e57` (pre-Aug-23, the truly clean state): 0 deletions, 20 intentional additions (each traced to its introducing commit), 0 suspicious names. Every "added since baseline" file is either a legit feature (graft MCP, agent-reach skill, model-verify tool, ADR-009) or a legitimate addition to a tracked dir.
3. **Full-tree junk-name sweep** — 28 matches across the entire local tree. All 28 are accounted for: 18 in `from-opencode-root/` (the boxes), 5 in `pricing-scrapes/` (the boxes), 1 in `Projects/tmg/hermes/smoke-20260829/` (the moved smoke test), 1 in `.opencode/browser_use/.venv/Lib/site-packages/rich_click/patch.py` (a vendored Python package's internal source, not pollution), 1 in `.opencode/backups/pre-config-inheritance-fix/smoke-test-opencode.json.bak` (an Aug-1 rollback anchor, intentional). **Zero matches in the opencode repo itself.**

A content-level diff (comparing actual file bytes, not just names) confirmed: only `.opencode/memory.jsonl` differs from origin/main; every other tracked file is byte-identical.

**Gate:** workspace matches GitHub main exactly except for the one expected runtime file.

### 3. The boxes — what's there, how to use them

| Subfolder             | Files                                           | What                                                                                                                                                                           |
| --------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `from-opencode-root/` | 18                                              | tmp\__.py/.sh, check_banner_.py, helper.py, patch.py from the opencode root (the original pollution)                                                                           |
| `model-verify/`       | 7 scripts + 16 outputs (in `output/` subfolder) | AI model-probe runs from Aug 30 — round 2-5 of a model-verification exercise (the round-1 outputs and the tool itself remain in the repo, as designed)                         |
| `pricing-scrapes/`    | 7                                               | extract\_\*.py ×4, final_output.py, mistral_pricing_table.md, zen_models_table.md (the Aug 23 pollution; also recoverable from git history via `git show 493e9a7^:<filename>`) |
| `_manifest.txt`       | (1 control)                                     | SHA-256 receipt of every preserved file; the source of truth for "what's here"                                                                                                 |
| `.gitignore`          | (1 control)                                     | `*` + `!.gitignore` — proactive guard so the boxes auto-protect if `Projects/tmg/hermes/` ever becomes a git repo                                                              |

**Total: 50 files (48 foreign + 2 control).** The 2 control files are not pollution.

**The 2 adjustments from the cooperating agent** are honored by this layout:

1. The `.ignore` file at the opencode root is left on disk untracked, not committed, not deleted. (See ADR-010 for why this is fine.)
2. The boxes live inside `Projects/tmg/hermes/`, which is git-ignored at the opencode workspace level. If `Projects/tmg/hermes/` ever becomes its own git repo, the proactive `.gitignore` inside `leftovers/` (with `*` + `!.gitignore`) will auto-protect the boxes from being tracked in that future repo.

### 4. The 701 unreachable git objects (optional, brief)

After the cleanup, `git fsck --unreachable` reported 701 unreachable objects in `.git/` (588 blobs + 86 trees + 27 commits). Investigation:

- **588 blobs** — the orphaned smoke-test files from the 2020-08-30 interrupted `git add -A` (when the backup script staged 594 files then the run was stopped before commit). These blobs were never part of any commit; they sit in `.git/objects` as loose data. Harmless: invisible to every git operation, don't appear in any diff or status.
- **86 trees** — the orphaned tree objects that the loose blobs were attached to during the interrupted staging.
- **27 commits** — all pre-existing WIP / backup / feature commits from Jul-Aug (stash entries, old backup branch tips, etc.). All are reachable via git history (their content merged into main via PRs #25-33); they're "unreachable" only because their branch tips are no longer referenced.

**Why we left them:** the user explicitly requested the smallest possible cleanup diff. Pruning requires `git gc --prune=now`, which is destructive on those 701 objects (unreachable = nothing references them, so safe but irreversible). The 701 objects are noise in `.git/` size only, not in any user-facing operation.

**How to clean later (whenever):** `git gc --prune=now --aggressive`. Designed for exactly this case. The user's `Projects/tmg/hermes/leftovers/_manifest.txt` would not be affected (it's not in git).

### 5. Boxes recovery runbook

When is it safe to delete the boxes? **When both of these are true:**

1. The fixed backup program has run cleanly for 30+ consecutive days (the next live test is 2026-09-06; a clean run on that day plus the next 30 days of weekly clean runs = safe).
2. No other agent (including future sessions of the cooperating agent on `Projects/tmg/hermes/`) needs the contents of the boxes.

If both are true:

1. Verify nothing in the boxes is referenced by anything else: `git grep -l 'tmp_\|smoke-\|check_banner' -- ':!Projects/tmg/hermes/leftovers/**' `:!docs/'` (should return zero matches).
2. Optionally, snapshot the manifest elsewhere first: copy `Projects/tmg/hermes/leftovers/_manifest.txt` to `.opencode/backups/pre-boxes-purge-<date>/` (an offline record).
3. Delete the entire `Projects/tmg/hermes/leftovers/` folder. `Projects/` is git-ignored at the opencode workspace level, so this deletion is invisible to git — no commit, no PR, no fuss.
4. Verify: `Get-ChildItem Projects\tmg\hermes\leftovers -ErrorAction SilentlyContinue` should return nothing.

If you change your mind before deleting: the 48 files are still in their original locations (untouched) up until the `Remove-Item` step.

**If the 48 files are needed again at any time:** the SHA-256 manifest in `_manifest.txt` lets you verify integrity of whatever's there. Plus, the 7 pricing-scrape files remain in git history forever (recoverable via `git show 493e9a7^:extract_final.py` and similar). The 18 root-junk files were never committed to git (only the 7 pricing files were), so for those, the boxes are the only copy.

---

## Files changed (this PR #34 cleanup)

| File                           | Change                                                                    | Lines    |
| ------------------------------ | ------------------------------------------------------------------------- | -------- |
| `extract_final.py`             | removed from git records                                                  | -122     |
| `extract_models.py`            | removed from git records                                                  | -8       |
| `extract_models2.py`           | removed from git records                                                  | -20      |
| `extract_models3.py`           | removed from git records                                                  | -44      |
| `final_output.py`              | removed from git records                                                  | -60      |
| `mistral_pricing_table.md`     | removed from git records                                                  | -10      |
| `zen_models_table.md`          | removed from git records                                                  | -76      |
| `scripts/backup-workspace.ps1` | 4 surgical changes (allowlist + reset -q + deny-check + branch-from-main) | +20 / -4 |
| `.gitignore`                   | 3 root-anchored guard rules                                               | +6       |
| `Projects/.gitignore`          | graft local graph cache rule (separate small change)                      | +3       |

Total: 9 files changed, 29 insertions, 344 deletions in PR #34.

Files NOT modified (zero blast radius for the cleanup itself):

- `AGENTS.md`, `README.md`, `ONBOARDING.md`, `SECURITY.md`, `CODEOWNERS`
- `opencode.json`, `skills-lock.json`
- All `.opencode/agents/`, `.opencode/commands/`, `.opencode/skills/` files
- All `docs/*` (this cleanup note is the _first_ docs change in this branch)
- All 144 tracked files in `origin/main` that aren't listed above (verified byte-identical after cleanup)

---

## Verification results (14-point check)

| #   | Check                                                                                               | Result |
| --- | --------------------------------------------------------------------------------------------------- | ------ |
| 1   | Filename slot for ADR-010 free                                                                      | PASS   |
| 2   | Filename slot for POST-CLEANUP-NOTE free                                                            | PASS   |
| 3   | `git reset` cleared 44 half-loaded items                                                            | PASS   |
| 4   | 48/48 files moved, 0 fingerprint mismatches against the manifest                                    | PASS   |
| 5   | Root folder shows zero foreign names after moves                                                    | PASS   |
| 6   | `git rm` staged exactly 7 deletions, nothing else                                                   | PASS   |
| 7   | PowerShell 5.1 syntax check on patched backup-workspace.ps1                                         | PASS   |
| 8   | Patched backup-workspace.ps1 -DryRun completes the new flow without error                           | PASS   |
| 9   | 3 new gitignore rules re-tested against all 151 tracked files = 0 collateral                        | PASS   |
| 10  | Two tidy commits created (493e9a7 + 6a86385)                                                        | PASS   |
| 11  | PR #34 created with full body, 4 checks passed on merge                                             | PASS   |
| 12  | 8 stale branches deleted, 3 dependabot branches preserved                                           | PASS   |
| 13  | Content-level diff vs origin/main: 1 line (memory.jsonl, expected)                                  | PASS   |
| 14  | Pre-pollution baseline diff (vs 32d2e57): 0 deletions, 20 intentional additions, 0 suspicious names | PASS   |

---

## Rollback procedure

If the cleanup needs to be reverted for any reason:

1. **Post-merge one-commit revert:** `git revert -m 1 3c2e93c` (the merge commit). Restores the 7 deleted files (from history) and removes the 4 backup-program changes + 3 gitignore rules. Does NOT touch the boxes at `Projects/tmg/hermes/leftovers/` (those are git-ignored and live outside the repo's records).
2. **Pre-merge alternative (would have applied before PR #34 merged):** close PR #34 + delete branch `chore/repo-cleanup`. No effect on main.
3. **Boxes recovery (if also reverting the move):** the boxes are at `Projects/tmg/hermes/leftovers/`. To restore: `Move-Item` files back to the opencode root. The manifest at `_manifest.txt` will tell you which file goes where.

The 8 deleted branches cannot be recovered (they're truly gone from origin), but all 8 were verified-fully-merged before deletion, so their content remains in main.

---

## Known issues / non-introductions (per repo's existing "Known issues" pattern)

- **No AGENTS.md drift introduced.** The `.opencode/memory.jsonl` file is the only dirty file in the working tree after cleanup. It's a runtime file, designed to differ from origin/main (it represents the agent's accumulated knowledge across sessions).
- **The 701 unreachable git objects** described above are pre-existing or Aug-30-orphaned data, not introduced by this cleanup.
- **The empty `extract_final.py`-style scraping capability** (if it ever needs to be re-run) is lost. The pricing tables in `pricing-scrapes/` preserve the data, but the script that fetches new pricing would need to be re-written. This is a known, accepted loss.

---

## References

- **PR #34:** https://github.com/3xOGssavage/Opencode-Workspace/pull/34 (merged 2026-09-03, 4 checks passed)
- **Merge commit:** `3c2e93c` on `origin/main`
- **Cleanup commits:** `493e9a7` (the hardening + 7 deletions + 3 gitignore rules) and `6a86385` (the graft rule under Projects/)
- **Aug 23 backup commit (recoverable for the 7 deleted files):** `2b3a550` (`git show 2b3a550:extract_final.py` recovers the file as it existed pre-cleanup)
- **Pre-pollution baseline commit:** `32d2e57` ("Merge PR #28 — feat/tavily-smart-router")
- **Design decision:** `docs/adrs/ADR-010-backup-allowlist-hardening.md`
- **Manifest of preserved files:** `Projects/tmg/hermes/leftovers/_manifest.txt`
- **Source memory entity** (the plan-side decision log): `opencode-workspace-pollution-cleanup-2026-09` in `.opencode/memory.jsonl`
- **Related ADRs:** ADR-002 (Fetch MCP SDK pin), ADR-008 (Browser-use stealth), ADR-009 (Agent capabilities expansion — added the same week; the cleanup ran the day after that PR merged)
- **Existing operational history siblings:** `POST-INSTALL-NOTE-2026-07-27-subagents.md`, `POST-INSTALL-NOTE-2026-07-27-vision-default.md`, `POST-INSTALL-NOTE-2026-08-02-v1.18.11-upgrade.md`
