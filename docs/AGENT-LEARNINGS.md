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
