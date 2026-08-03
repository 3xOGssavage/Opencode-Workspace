# Opencode-Workspace

Enterprise opencode workspace backup — 17 agents, 16 MCPs, 117 skills, parallel subagent dispatch. Snapshot dated 2026-08-02. See `ENTERPRISE_OPENCODE_SETUP.md` for the full interactive re-deployment guide, and `AGENTS.md` for the operating manual.

---

## What's in this repo

| Path                                        | Purpose                                                                                                                    |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `AGENTS.md`                                 | Operating manual (auto-loaded by opencode every session)                                                                   |
| `ENTERPRISE_OPENCODE_SETUP.md`              | 1737-line interactive re-deployment guide                                                                                  |
| `VISION-TOOL-MCP-DOCUMENTATION.md`          | Reference doc for the vision-tool MCP                                                                                      |
| `skills-lock.json`                          | Integrity hashes for 4 Vercel skills                                                                                       |
| `opencode.json`                             | Main workspace config (17 agents, 16 MCPs, 81 bash perms, 2 LSPs, compaction, formatter)                                   |
| `.opencode/agents/`                         | 7 custom agent definitions (architect, reviewer, tester, code-reviewer, security-auditor, test-engineer, web-perf-auditor) |
| `.opencode/commands/`                       | 5 command definitions (/ship, /verify, /test, etc.)                                                                        |
| `.opencode/skills/`                         | 2 workspace skills (enterprise-pipeline, playwright-best-practices)                                                        |
| `.opencode/memory.jsonl`                    | Knowledge graph (20 entities, 25 KB) — preserves accumulated decisions                                                     |
| `.opencode/memory-mcp-wrapper.bat`          | Launches memory MCP with `MEMORY_FILE_PATH` override                                                                       |
| `.opencode/opencode-auto-vision.json`       | Auto-vision plugin config                                                                                                  |
| `.opencode/verify-inheritance.ps1`          | Verifies config inheritance is active                                                                                      |
| `.opencode/tools/vision-tool/`              | Vendored vision MCP server (Python) — demo media + `__pycache__` gitignored                                                |
| `.agents/skills/`                           | 4 workspace-local skills (deploy, logs, setup, vercel-cli) — gitignored, auto-reinstallable                                |
| `docs/adrs/`                                | 6 Architecture Decision Records (ADR-001 through ADR-006)                                                                  |
| `global-config/`                            | Snapshot of `~/.config/opencode/` — 5 files that activate OMO-Slim + 3 plugins                                             |
| `scripts/setup-env-vars.ps1`                | Idempotent setup script (env vars, global-config copy, npm install, path normalization)                                    |
| `Projects/.gitkeep` + `Projects/.gitignore` | Preserves the `Projects/` folder; contents gitignored (each project has its own repo)                                      |

**Tracked size after cleanup:** ~1 MB.

## What's NOT in this repo (by design)

| Excluded                                                                                              | Why                                                                       |
| ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `session-*.md`                                                                                        | Chat export files — may contain secrets. NEVER commit.                    |
| `Projects/*`                                                                                          | Each project has its own `.git` + repo. Only the folder is preserved.     |
| `.opencode/backups/`                                                                                  | Historical config snapshots — runtime state, not portable.                |
| `.opencode/{agent-skills,anthropic-skills,last30days-skill,vercel-agent-skills,playwright-bp-skill}/` | Vendored skill packs (auto-reinstallable, large, not config).             |
| `.opencode/github-mcp-server/`                                                                        | 23 MB binary — reinstall via `opencode mcp add`.                          |
| `.opencode/node_modules/`                                                                             | Auto-regenerated by `npm install`.                                        |
| `.opencode/tools/vision-tool/{docs/demo,__pycache__}/`                                                | Demo media (20 MB) + compiled bytecode — not config.                      |
| `.agents/`                                                                                            | Recreated by `npx skills add vercel-deploy-claude-code-plugin`.           |
| `*.bak`, `*.zip`, `*.db*`                                                                             | OS cruft, backups, chat history DB.                                       |
| `~/.local/share/opencode/auth.json`                                                                   | 4 provider API keys — SECRET. Set up manually on new machine.             |
| `~/.local/share/opencode/mcp-auth.json`                                                               | 4 OAuth MCP tokens — SECRET. Re-auth via `opencode mcp auth <name>`.      |
| `~/.local/share/opencode/opencode.db` (1.43 GB)                                                       | Chat history — not portable.                                              |
| `~/.cache/opencode/` (766 MB)                                                                         | Binaries + cached packages — auto-regenerated.                            |
| `~/.agents/skills/` (56 skills)                                                                       | User-installed skills outside workspace — reinstall via `npx skills add`. |
| `~/.config/opencode/skills/` (19 skills)                                                              | User-installed skills outside workspace — reinstall via `npx skills add`. |

---

## Restore Guide

### Scenario A: Same-machine restore

If the workspace was lost but this machine is still in use (same drive letters, same env vars):

1. Extract `F:\CD\Backup\opencode-workspace-2026-08-02.zip` to `F:\CD\Opencode\` (overwrite).
   - Or `git clone https://github.com/3xOGssavage/Opencode-Workspace.git F:\CD\Opencode`
2. The absolute paths in `opencode.json` already point to `F:\CD\Opencode\` — no path normalization needed.
3. Run `scripts\setup-env-vars.ps1` to re-set the 4 User env vars (idempotent — safe to re-run).
4. Run `npm install` in `%USERPROFILE%\.config\opencode\` if `node_modules\` is missing.
5. Reinstall workspace skills:
   ```
   npx skills add vercel-deploy-claude-code-plugin
   ```
6. Restart opencode. Done.

### Scenario B: New-machine setup

If migrating to a new machine (different drive letters, no env vars, no auth):

#### Prerequisites

- Node.js 18+ (for npm + opencode)
- Python 3.10+ (for the vision-tool MCP)
- opencode CLI installed (`npm install -g opencode-ai` or per opencode docs)
- Git for Windows
- PowerShell 5.1+ (built into Windows 10/11)

#### Steps

1. **Clone the repo anywhere** (e.g. `D:\Code\Opencode` or `C:\Users\you\Opencode`):

   ```
   git clone https://github.com/3xOGssavage/Opencode-Workspace.git <your-path>
   cd <your-path>
   ```

2. **Run the setup script** (auto-detects `<your-path>` as `$WorkspaceRoot`):

   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts\setup-env-vars.ps1
   ```

   This will:
   - Set 4 User env vars: `OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `MEMORY_FILE_PATH`, `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`
   - Copy `global-config\*` to `%USERPROFILE%\.config\opencode\`
   - Run `npm install` in that target dir
   - Regex-replace the old `F:\CD\Opencode` path in `opencode.json` with `<your-path>` (so the 12 absolute paths in skills.paths / permission.edit.deny / mcp.command resolve correctly)

3. **Set 6 API-key env vars** (User scope — persists across restarts):

   ```powershell
   setx HCNSEC_API_KEY                  "sk-..."                    # hcnsec.cn reseller key (51 chars)
   setx TOKENROUTER_API_KEY              "sk-..."                    # tokenrouter.com (51 chars)
   setx GEMINI_API_KEY                   "AQ...."                    # Google AI Studio (53 chars)
   setx TAVILY_API_KEY                   "tvly-..."                  # tavily.com
   setx SENTRY_AUTH_TOKEN                "sntrys_..."               # sentry.io
   setx GITHUB_PERSONAL_ACCESS_TOKEN     "ghp_..."                   # github.com/settings/tokens (repo scope)
   ```

4. **Re-auth 4 OAuth MCP servers** (interactive — opens browser):

   ```
   opencode mcp auth composio
   opencode mcp auth sentry
   opencode mcp auth supabase
   opencode mcp auth vercel
   ```

5. **Log in 4 auth.json providers** — either:
   - Use opencode's `/models` menu to log in each provider (opencode-go, ollama-cloud, nvidia, google), OR
   - Manually restore a secure backup of `auth.json` to `%USERPROFILE%\.local\share\opencode\auth.json`
   - `auth.json` shape (4 entries, each with `key` field):
     ```json
     [
       { "id": "opencode-go", "key": "sk-W8GXu..." },
       { "id": "ollama-cloud", "key": "..." },
       { "id": "nvidia", "key": "nvapi-W1yyV..." },
       { "id": "google", "key": "AQ.Ab8R..." }
     ]
     ```

6. **Reinstall user skill packs** (75 skills across 2 directories outside the workspace). Run these in any shell (they install to `~/.agents/skills/` by default):

   **From `~/.agents/skills/` (56 skills):**

   ```
   npx skills add agentic-workflow-designer
   npx skills add agentic-workflows
   npx skills add awf-release-integrator
   npx skills add checkout-credential-review
   npx skills add console-rendering
   npx skills add copilot-review
   npx skills add create-canvas
   npx skills add custom-agents
   npx skills add debugging-workflows
   npx skills add deploy
   npx skills add design-md
   npx skills add developer
   npx skills add documentation
   npx skills add enhance-prompt
   npx skills add error-messages
   npx skills add error-pattern-safety
   npx skills add find-skills
   npx skills add gepeto
   npx skills add gh-agent-session
   npx skills add gh-agent-task
   npx skills add gh-stack
   npx skills add github-copilot-agent-tips-and-tricks
   npx skills add github-discussion-query
   npx skills add github-issue-query
   npx skills add github-labels-query
   npx skills add github-mcp-server
   npx skills add github-pr-query
   npx skills add github-script
   npx skills add github-workflows-query
   npx skills add go-codemod
   npx skills add go-linters
   npx skills add http_mcp_headers
   npx skills add javascript-refactoring
   npx skills add jqschema
   npx skills add logs
   npx skills add messages
   npx skills add optimize-agentic-workflow
   npx skills add otel-queries
   npx skills add pinokio
   npx skills add playwright-cli
   npx skills add pr-finisher
   npx skills add pr-to-go-linter
   npx skills add prompt-token-efficiency
   npx skills add react-components
   npx skills add remotion
   npx skills add reporting
   npx skills add sergo-examples
   npx skills add setup
   npx skills add shadcn-ui
   npx skills add ssl-skill-normalizer
   npx skills add stitch-design
   npx skills add stitch-loop
   npx skills add temporary-id-safe-output
   npx skills add ui-ux-pro-max
   npx skills add vercel-cli
   npx skills add workflow-step-summaries
   ```

   **From `~/.config/opencode/skills/` (19 skills):**

   ```
   npx skills add clonedeps
   npx skills add codemap
   npx skills add deepwork
   npx skills add design-taste-frontend
   npx skills add gsap-core
   npx skills add gsap-frameworks
   npx skills add gsap-performance
   npx skills add gsap-plugins
   npx skills add gsap-react
   npx skills add gsap-scrolltrigger
   npx skills add gsap-timeline
   npx skills add gsap-utils
   npx skills add oh-my-opencode-slim
   npx skills add reflect
   npx skills add seo
   npx skills add simplify
   npx skills add transitions-dev
   npx skills add transitions-polish
   npx skills add worktrees
   ```

   **Workspace-local skills** (auto-reinstalled in one command):

   ```
   npx skills add vercel-deploy-claude-code-plugin
   ```

   This recreates `.agents/skills/{deploy,logs,setup,vercel-cli}` in the workspace.

   > If any skill is unavailable (source archived/renamed), skip it — opencode continues without it. The skill list is refreshed each session; missing skills are inert.

7. **Install Python deps for vision-tool MCP** (only if you use vision features):

   ```powershell
   pip install google-generativeai mcp
   ```

   Set `GEMINI_API_KEY` (already done in step 3) + `DEFAULT_MODEL` env var if needed (see `VISION-TOOL-MCP-DOCUMENTATION.md`).

8. **Restart opencode** — env vars are only read at session start.

9. **Verify setup**:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .opencode\verify-inheritance.ps1
   ```
   Should report: HuanCheng provider visible, 15+ MCPs connected, parent agents loaded.

---

### Restore Playbook (quick reference)

When you need to recreate secrets, this table shows each credential's source, shape, and whether the pre-commit/CI secret scanner will catch an accidental leak. **Placeholders use ≤8 trailing chars — well under the scanner's regex thresholds, so this README is safe to commit.**

| Credential           | Where to re-issue                                                             | Shape                    | Scanner covers?                                                            |
| -------------------- | ----------------------------------------------------------------------------- | ------------------------ | -------------------------------------------------------------------------- |
| GitHub PAT (classic) | github.com → Settings → Developer settings → Personal access tokens (classic) | `ghp_xxxx…` (40 chars)   | yes — regex `ghp_[0-9A-Za-z]{36}`                                          |
| Anthropic API key    | console.anthropic.com → API keys                                              | `sk-ant…` (~100 chars)   | yes — regex `sk-[0-9A-Za-z]{20,}`                                          |
| hcnsec key           | hcnsec.cn reseller dashboard                                                  | `sk-xxxx…` (51 chars)    | yes — same regex as above                                                  |
| TokenRouter key      | tokenrouter.com → dashboard                                                   | `sk-xxxx…` (51 chars)    | yes — same regex                                                           |
| Google / Gemini      | aistudio.google.com → API key                                                 | `AIza…` (39 chars)       | yes — regex `AIza[0-9A-Za-z_-]{35}`                                        |
| Tavily key           | app.tavily.com → API key                                                      | `tvly-xxxx…`             | no — scanner gap; manual discipline + GitHub Push Protection (server-side) |
| Sentry auth token    | sentry.io → Settings → Auth tokens                                            | `sntrys_xxxx…`           | no — scanner gap; manual discipline + GitHub Push Protection               |
| Google OAuth refresh | AI Studio (auto-generated, long-lived)                                        | `AQ.Ab8R...` (~53 chars) | partial — allowlisted prefix only                                          |

**Secrets never in repo (manual USB attachment):**

- `%USERPROFILE%\.local\share\opencode\auth.json` (468 B, 4 provider keys)
- `%USERPROFILE%\.local\share\opencode\mcp-auth.json` (2.4 KB, 4 OAuth tokens)
- Copy both files to an offline USB stick / password-manager attachment after a fresh OAuth re-auth. These are NOT touched by any script in this repo (by design — keeping secrets out of git).

**Projects/ subdirectories** manage their own backups (each project has its own repo). See each project's README if you need to back those up.

---

### Restore drill cadence

Untested backups are assumptions, not controls. Following the CISA / NIST SP 800-34 cadence scaled for a personal Tier-2 setup:

| Frequency          | What to run                                                                                                                                                                                                         | What success looks like                                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Weekly (automatic) | scheduled task runs `backup-workspace.ps1` (push) + `backup-bundle.ps1` (bundle to D:\Backups\)                                                                                                                     | Event Viewer → Application → Source="Windows PowerShell", EventId=100. New `opencode-YYYY-MMDD.bundle` exists in D:\Backups\. |
| Monthly            | `git bundle verify D:\Backups\opencode-<latest>.bundle`                                                                                                                                                             | Prints "OK" (or "The bundle contains 73 refs"). Confirms integrity without unpacking.                                         |
| Quarterly          | Spot-restore 3 one-liners (no script): `git clone D:\Backups\opencode-<latest>.bundle $env:TEMP\oc-restore` then `Test-Path $env:TEMP\oc-restore\AGENTS.md` then `Remove-Item $env:TEMP\oc-restore -Recurse -Force` | Second command prints `True`. Workspace restores from bundle cleanly.                                                         |
| Annually           | Full fresh-dir drill: clone the latest bundle to a new directory, start opencode there, confirm MCP servers + agents load. Then delete the drill clone.                                                             | opencode boots, MCP servers connect, agents appear in `/agents`.                                                              |

---

### Known issue: mcp-auth.json corruption (opencode issue #29804)

opencode has an active bug where every OAuth token refresh appends an extra `}` to `mcp-auth.json`, eventually producing invalid JSON and breaking **all 4 remote MCP servers** (sentry, composio, supabase, vercel). Symptom: `SSE error: Unexpected non-whitespace character after JSON at position N`.

**Quick fix** (PowerShell one-liner, strips trailing braces):

```powershell
$f = "$env:USERPROFILE\.local\share\opencode\mcp-auth.json"
$c = Get-Content $f -Raw
while ($true) { try { $c | ConvertFrom-Json | Out-Null; break } catch { $c = $c -replace '(\})\s*\}+\s*$','$1' } }
$c | Set-Content $f -NoNewline
```

**Clean fix** (re-authenticates all 4 OAuth flows):

```
opencode mcp auth sentry
opencode mcp auth composio
opencode mcp auth supabase
opencode mcp auth vercel
```

Prefer the clean fix if you have network access — the quick fix only unblocks the JSON, doesn't refresh stale tokens.

---

### GitHub Push Protection (server-side backstop)

The pre-commit hook (`scripts\audit-secrets.ps1`) scans for `ghp_`, `sk-`, `AIza`, `github_pat_` shapes locally. GitHub's server-side Push Protection is the second net — it blocks pushes that contain recognized token shapes regardless of local scanner coverage. Toggle it on:

1. Repo → **Settings** → **Code security and analysis**
2. Enable **Secret scanning** and **Push protection**

Verify (requires `gh` CLI in PATH):

```
gh api repos/3xOGssavage/Opencode-Workspace --jq '.security_and_analysis'
```

---

### Orphan backup file cleanup

The orphan file `auth.json.bak.20260725-170222` (595 B) exists in `%USERPROFILE%\.local\share\opencode\` — no script in this repo creates it; it's a stale artifact. Remove with:

```powershell
Remove-Item "$env:USERPROFILE\.local\share\opencode\auth.json.bak.*" -Force
```

Also note these minor items to verify after a restore:

- **`mcp-auth.json` ACL** — the live file has an extra `SOHAM\CodexSandboxUsers` ReadAndExecute principal. Non-default. Investigate whether your Codex sandbox install requires it; remove if not.
- **LogonType limitation** — the scheduled task uses `LogonType=Interactive`, so it only runs when you are logged in. Fine for an always-on home machine. For server-style 24/7 operation, switch to `S4ULogon` (requires SYSTEM account + elevation).
- **`Tavily` / `Sentry` scanner gap** — `audit-secrets.ps1` regex does not cover `tvly-` or `sntrys_` prefixes. Manual discipline + GitHub Push Protection cover the gap until the regex is extended.

---

## Maintenance: Updating the backup

To update this backup after future workspace changes:

1. Never commit directly to `main`. Create a branch:
   ```
   git checkout -b chore/update-YYYY-MM-DD
   ```
2. Make your changes (new ADRs, updated `AGENTS.md`, new agent definitions, etc.).
3. Commit + push:
   ```
   git add -A
   git commit -m "chore: update workspace backup YYYY-MM-DD"
   git push -u origin chore/update-YYYY-MM-DD
   ```
4. Open a PR via the GitHub UI or `gh pr create`.
5. Merge after review.
6. Sync local main:
   ```
   git checkout main
   git pull origin main
   git branch -d chore/update-YYYY-MM-DD
   ```

## Troubleshooting

| Symptom                                                           | Fix                                                                                                                                                                                          |
| ----------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `git push` returns 403 / "Authentication failed"                  | The PAT in `GITHUB_PERSONAL_ACCESS_TOKEN` expired. Generate a new one at github.com/settings/tokens (repo scope), then `setx GITHUB_PERSONAL_ACCESS_TOKEN "ghp_..."` and restart your shell. |
| opencode can't find skills / agents                               | Run `scripts\setup-env-vars.ps1` again. Confirm `OPENCODE_CONFIG` + `OPENCODE_CONFIG_DIR` env vars are set (`[Environment]::GetEnvironmentVariable('OPENCODE_CONFIG','User')`).              |
| MCP servers show "disconnected"                                   | Run `opencode mcp auth <name>` for each: composio, sentry, supabase, vercel.                                                                                                                 |
| `npm install` in `~/.config/opencode/` fails                      | Ensure Node 18+ is installed (`node --version`). Check network. Delete `node_modules\` + `package-lock.json` and retry.                                                                      |
| Vision-tool MCP won't start                                       | Check `GEMINI_API_KEY` is set. Install Python deps (`pip install google-generativeai mcp`). See `VISION-TOOL-MCP-DOCUMENTATION.md`.                                                          |
| Paths in opencode.json point to `F:\CD\Opencode` on a new machine | Re-run `scripts\setup-env-vars.ps1` — it regex-replaces the old path with the current clone path.                                                                                            |
| opencode.db is huge / chat history missing                        | `opencode.db` (1.43 GB) is NOT in this backup — it's chat history, not portable. A fresh one is created on first run.                                                                        |

## Backup hardening v7 (skills snapshot + script decoupling + disaster scenarios)

This section appends on top of the v6 init (the rest of this README). v7 adds:

- `scripts/skills-snapshot.json` — committed snapshot of `~/.agents/.skill-lock.json` (22 KB) so a new-machine restore knows exactly which 56 user skills to reinstall.
- `scripts/backup-workspace.ps1` — runtime backup runner. Decoupled from hardcoded GitHub username (now parses `git remote get-url origin`). Added `-DryRun`, `-SkipPush`, `.last-backup` marker (gitignored), and Windows Application Event Log entries on success (EventId 100) and failure (EventId 101) using the existing `"Windows PowerShell"` source (no admin required).
- `scripts/audit-secrets.ps1` — lightweight pre-commit secret scanner (AWS/GCP/GitHub/Slack/JWT/SSH key patterns + documentation-prefix allow-list).
- `.githooks/pre-commit` — invokes the audit script before every commit.
- `.github/workflows/secret-scan.yml` + `.github/gitleaks.toml` — gitleaks CI runs on every PR to `main`.
- Disaster scenarios table (below) — explicit coverage of what v7 handles and what it doesn't.

### Disaster scenarios and recovery

| Scenario                                     | v7 coverage                                     | Recovery procedure                                                                                                                                                                                            |
| -------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Disk failure (F: drive dies)                 | ✅ Re-clone from GitHub                         | `git clone https://github.com/3xOGssavage/Opencode-Workspace.git F:\CD\Opencode` → run `scripts\setup-env-vars.ps1` → re-install 56 skills (see "Refreshing skills-snapshot.json" below for the source list). |
| GitHub outage (hours)                        | ✅ Work locally                                 | All work continues against the local clone. Push when GitHub returns. Nothing is lost.                                                                                                                        |
| GitHub 2FA device lost                       | ⚠️ Recoverable ONLY with backup codes           | Use one of the 16 saved `github-recovery-codes.txt` (store offline). If those are also lost → GitHub Support verification (SLOW, days).                                                                       |
| GitHub account permanent ban                 | ⚠️ Code preserved locally; Issues/PRs/Wiki lost | Clone to a fresh account. Quarterly "Export account data" tar.gz (Settings → Account → Export) covers Issues/PRs/Wiki — see "Future hardening" below.                                                         |
| Both F: drive AND GitHub die on the same day | ❌ WORKSPACE IS GONE                            | This is an accepted risk per user choice (2 copies only). Mitigation = 16 GitHub 2FA recovery codes stored offline + `git bundle create --all` on a separate drive. NOT IMPLEMENTED in v7.                    |
| Ransomware encrypts F:                       | ❌ Local copy lost                              | Re-clone from GitHub. Gitleaks CI catches any pushed secrets.                                                                                                                                                 |
| Accidental commit of a secret                | ✅ gitleaks CI on PR + pre-commit hook          | Rotate the secret THEN run BFG to strip from history (see "Future hardening" below).                                                                                                                          |

### What v7 does NOT back up (explicit, by design)

| Not backed up                        | Why                                    | Where to get it back                                                              |
| ------------------------------------ | -------------------------------------- | --------------------------------------------------------------------------------- |
| `opencode.db` (1.43 GB chat history) | Runtime state, not portable            | Fresh one created on first opencode run                                           |
| `auth.json` (4 provider API keys)    | Secrets — never committed              | Re-issue from each provider (hcnsec, opencode-go, nvidia, google)                 |
| `mcp-auth.json` (4 OAuth tokens)     | Secrets — never committed              | `opencode mcp auth sentry\|composio\|supabase\|vercel`                            |
| 6 User API-key env vars              | Secrets — never committed              | `setx HCNSEC_API_KEY ...`, etc. (see "Secrets setup" below)                       |
| `smoke-test`, `website` projects     | Disposable sandboxes (per user choice) | Recreatable from the opencode enterprise setup                                    |
| `~/.cache/opencode/` (776 MB)        | Auto-regenerated                       | Run opencode; cache rebuilds itself                                               |
| GitHub Issues/PRs/Wiki/Releases      | Not in git objects                     | `Settings → Account → Export` tar.gz (manual, quarterly — see "Future hardening") |

### Secrets and credentials setup (on a new machine, manual)

After cloning the repo and running `scripts\setup-env-vars.ps1`:

1. **`auth.json`** at `%USERPROFILE%\.local\share\opencode\auth.json` — 4 provider API keys (hcnsec, opencode-go, nvidia, google). Get fresh from each provider.
2. **`mcp-auth.json`** at the same path — re-auth each OAuth MCP:
   ```
   opencode mcp auth sentry
   opencode mcp auth composio
   opencode mcp auth supabase
   opencode mcp auth vercel
   ```
3. **6 env vars** via `setx` (User scope):
   ```
   setx HCNSEC_API_KEY "sk-..."
   setx GEMINI_API_KEY "AQ.Ab8R..."
   setx TOKENROUTER_API_KEY "sk-..."
   setx TAVILY_API_KEY "tvly-..."
   setx SENTRY_AUTH_TOKEN "sntryu_..."
   setx GITHUB_PERSONAL_ACCESS_TOKEN "ghp_..."   # scopes: repo, workflow, audit_log
   ```
4. **GitHub 2FA recovery codes** — restore `github-recovery-codes.txt` from your offline storage.

### Monthly backup procedure (Task Scheduler)

- **Trigger:** first Sunday monthly, 14:00 local
- **Action:** `pwsh -File F:\CD\Opencode\scripts\backup-workspace.ps1`
- **Settings:** "Run only when user is logged on" ✓, "Run task as soon as possible after a scheduled start is missed" ✓ (catches when the laptop is off — 10-min default delay before retry).
- **Precondition:** working tree MUST be clean (script refuses otherwise).
- **On failure:** check Event Viewer → Windows Logs → Application, filter Source=`Windows PowerShell`, EventId=`101`.
- **Success marker:** `scripts\.last-backup` (gitignored).

See `scripts\setup-scheduled-backup.ps1` (run once on a new machine to register the task) or register manually:

```powershell
$Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File F:\CD\Opencode\scripts\backup-workspace.ps1" -WorkingDirectory "F:\CD\Opencode"
$Trigger = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At 14:00
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -DontStopOnIdleEnd
Register-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -TaskName "Opencode monthly backup" -RunLevel Limited
```

### Refreshing `skills-snapshot.json` (after installing new skills)

```powershell
Copy-Item $env:USERPROFILE\.agents\.skill-lock.json F:\CD\Opencode\scripts\skills-snapshot.json
git add scripts/skills-snapshot.json
git commit -m "chore(skills): refresh skills-snapshot.json"
git push
```

### Future hardening (optional, NOT in v7)

- **3rd offline copy** via `git bundle create --all opencode-$(date).bundle` + `git bundle verify opencode-*.bundle`. Closes the "both F: and GitHub die same day" gap. Store the bundle on a separate drive or USB stick.
- **Quarterly GitHub Export tar.gz** — `Settings → Account → Export`. Captures Issues/PRs/Wiki/Releases metadata that `git bundle`/`git clone --mirror` don't. Download link expires in 7 days.
- **BFG public-release sweep** — if this repo is ever flipped public, run BFG to strip partial key prefixes (`sk-W8GXu...`, `nvapi-W1yyV...`, `AQ.Ab8R...`) from history, THEN rotate every key. Gitleaks CI is the live gate against new leaks.
- **Annual `git gc --aggressive --prune=now`** — monitor via `git count-objects -vH`. Keeps the repo lean when many backup branches accumulate.

### Acceptance criteria (this v7 release)

- ✅ `backup-workspace.ps1` syntactically valid PowerShell (parser lint passes)
- ✅ `backup-workspace.ps1 -DryRun -SkipPush` prints all steps without writing
- ✅ `scripts/.last-backup` is NOT created by `-DryRun`
- ✅ `scripts/skills-snapshot.json` valid JSON (22 KB, 56 skills)
- ✅ Clone repo to `$env:TEMP\opencode-restore-test` → `setup-env-vars.ps1 -DryRun` runs cleanly
- ✅ Diff clone vs live workspace: no missing tracked files
- ✅ Gitleaks CI runs green on this PR
- ✅ Hardcoded `3xOGssavage` absent from `scripts/*.ps1` (decoupled via `git remote get-url origin`)

## License

Private repo. Internal use only.
