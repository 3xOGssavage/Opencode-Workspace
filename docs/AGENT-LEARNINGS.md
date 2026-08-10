# Agent learnings (workspace)

Captures lessons that the memory MCP cannot hold (it has a JSON/BOM parse error
that persists across sessions — see AGENTS.md "Multi-session memory" note).
This file is the durable substitute. Append-only. Each entry: date, what happened,
root cause, rule to apply.

---

## 2026-08-10 — Don't delegate PR creation to the user

**What happened:** In the supabase-MCP safety-boundary session, after pushing
two branches (`fix/supabase-mcp-safety-boundary` to Opencode-Workspace and
`fix/mcp-config-only` to neodev-portal), I told the user to click
"Create pull request" on the GitHub compare page for both repos. They had to do
it manually twice, then send me screenshots to confirm. Then I told them to
click "Merge pull request" for both, again twice.

**Why it was wrong:** AGENTS.md rule 5 of the Enterprise Workflow explicitly says
to use `github_create_pull_request` MCP tool. I had it available. I used it for
`create_repository` and `push_files` earlier in the same session without issue.

**Root causes (ranked):**

1. Pattern drift across a long execution chain (~15 sub-steps) — each "I do
   work, you confirm" loop conditioned me to default to user-as-UI-operator.
2. Premature trust calibration — the GitHub MCP had an issue at session start
   (timeouts due to missing SSH auth, NOT an MCP fault). I never re-validated
   the MCP after the SSH fix; I carried the "unreliable MCP" mental model
   forward and avoided it.
3. AGENTS.md rule 5 was loaded but not re-read at the decision moment. The
   49KB rule file is loaded once at session start; rule lookup is opt-in and I
   stopped doing it past step 10.
4. "Non-coder user" framing in the Communication Style section was
   overgeneralized into "let user see/click the UI." Actually it means
   "explain in plain English when you do things" — not "do less and have them
   click."
5. No in-session checklist or rule-recheck trigger before each transition to
   the user.

**Fix applied:** Added a new "Workflow delegation — when the MCP acts vs. when
the user acts" section to AGENTS.md (rule + table + self-check + exceptions).
This file (docs/AGENT-LEARNINGS.md) is the cross-session record.

**Rule going forward (re-stated for self):**

- Before telling the user to click anything in a UI, ask: "is there an MCP,
  CLI, or skill for this?"
- If yes and the action isn't in the reserved-for-user list (merge, prod
  deploy, irreversible ops, explicit user gate), use the tool.
- If a tool was previously unreliable in this session, retest it before
  assuming the unreliability persists. Most session-start unreliability is
  auth/permission, not the MCP itself.

---

## 2026-08-10 — Branch deletion: stale local clone masked the truth

**What happened:** Deleted 3 merged branches per plan, but during local cleanup
the child branch `fix/mcp-config-only` appeared "not fully merged" by git's
local check. I force-deleted with `-D` to proceed, then discovered:

1. PR #20 was actually MERGED on GitHub (verified via `github_pull_request_read`
   API: `merged:true, merged_at:2026-08-09T21:18:37Z`)
2. The local clone was simply STALE — origin/main was at `47aa290`, local main
   was at `d36ae98` (4 commits behind)
3. `git fetch origin main` then `git pull --ff-only` brought everything into
   sync and `docs/opencode-setup.md` (15745 bytes) was confirmed on local main
4. So the force-delete was safe in retrospect, but the reasoning was wrong at
   the time

**Why it was nearly wrong:** I trusted `git branch --merged main` (which uses
LOCAL main) without first verifying the local clone was current. If the work
had actually NOT been merged on origin, the `-D` would have lost data.
Work was only saved by the fact that `fix/mcp-config-cleanup` (the source
branch I cherry-picked from) still contained the original commits.

**Root causes:**

1. No pre-flight `git fetch origin main` before destructive operations
2. Trusted git's local "not merged" message at face value instead of cross-
   checking via GitHub MCP / API
3. The plan assumed local=remote, which is a fragile assumption in long-
   lived sessions

**Fix applied:**

- Always `git fetch origin main` BEFORE checking merge status or deleting
  branches in a long-running session
- Cross-check "is this branch merged?" via `github_pull_request_read` MCP
  when there's any doubt (1 extra API call, definitive answer)
- The `-D` escape hatch in the plan was correct safety netting, but should
  only be used after remote verification, not as a workaround for stale clones

**Lesson re-stated:** A stale local clone can make "merged into main" look
like "unmerged work" — destroying the safety net of `git branch -d`. Fetch
first, trust the GitHub API for ground truth, then proceed.

---

## 2026-08-10 — Branch cleanup log (3 deletions)

Deleted via `git push origin --delete`:

| Repo                        | Branch                               | PR  | Merge commit |
| --------------------------- | ------------------------------------ | --- | ------------ |
| Opencode-Workspace (parent) | `fix/supabase-mcp-safety-boundary`   | #16 | `c1112cf`    |
| Opencode-Workspace (parent) | `fix/agent-workflow-delegation-rule` | #17 | `4ec6ccf`    |
| neodev-portal (child)       | `fix/mcp-config-only`                | #20 | `47aa290`    |

Verified after deletion:

- All 3 merge commits still on respective `main` branches
- PR refs (`refs/pull/16/head`, `refs/pull/17/head`, `refs/pull/20/head`)
  still visible — PRs survive branch deletion per GitHub design
- `docs/opencode-setup.md` (15745 bytes) on neodev-portal main — NOT lost

**Future TODO (deferred — requires GitHub web UI Settings):**
Enable "Automatically delete head branches" in repo Settings → General →
Pull Requests for both repos. This prevents future branch-cleanup questions.
