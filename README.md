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

## Backup hardening (v6)

The base backup (PR #1) established the 3-2-1 architecture: workspace + zip + GitHub. PR #2 added these **defense-in-depth** layers:

### 1. Pre-commit secret guard (local)

`.githooks/pre-commit` runs `scripts/audit-secrets.ps1` on every staged file. Commits are **blocked** if any of these patterns are detected:

- `sk-[A-Za-z0-9]{20,}` (OpenAI/Anthropic/hcnsec/TokenRouter)
- `ghp_[A-Za-z0-9]{36}` (GitHub classic PAT)
- `github_pat_[A-Za-z0-9_]{82}` (GitHub fine-grained PAT)
- `nvapi-[A-Za-z0-9]{20,}` (NVIDIA)
- `AQ\.[A-Za-z0-9_\-]{20,}` (Google AI Studio)
- `xox[baprs]-...` (Slack)
- `AKIA[0-9A-Z]{16}` (AWS access key)
- `sntrys_...` (Sentry auth token)

The hook is activated by `git config core.hooksPath .githooks` (set automatically by `setup-env-vars.ps1`, or run manually once after cloning).

**Bypass in emergencies:** `git commit --no-verify` (use sparingly — the CI scan still catches it on push).

**Test it yourself:**

```powershell
pwsh scripts/audit-secrets.ps1
```

### 2. GitHub Actions secret scan (cloud, defense in depth)

`.github/workflows/secret-scan.yml` runs `gitleaks/gitleaks-action@v2` on every push and PR to every branch. This is the cloud safety net for the local pre-commit hook — independent of GitHub's paid Advanced Security (which private repos don't get for free).

**If the workflow fails on a push:** a secret was detected in the diff. Remove the secret from the file, re-commit, and push again. There's no bypass for CI scans — by design.

**Config:** `.github/gitleaks.toml` extends default rules with allow-lists for our `{env:VAR}` placeholders and partial-key documentation patterns (`sk-W8GXu...`, `nvapi-W1yyV...`, `AQ.Ab8R...`).

**View scan history:** https://github.com/3xOGssavage/Opencode-Workspace/actions/workflows/secret-scan.yml

### 3. Semi-automated backup runner

`scripts/backup-workspace.ps1` automates the "manual backup" workflow:

```powershell
pwsh scripts/backup-workspace.ps1                                    # auto message
pwsh scripts/backup-workspace.ps1 -Message "chore: post-vX.Y.Z snapshot"
pwsh scripts/backup-workspace.ps1 -SkipPush                          # commit locally only
```

It:

1. Refuses to run if `git status` shows uncommitted changes (safer than auto-stashing; user stays in control)
2. Creates a `chore/auto-backup-YYYY-MM-DD` branch
3. Stages tracked-only changes (`git add -A` respects .gitignore)
4. Commits + pushes via inline credential helper using `GITHUB_PERSONAL_ACCESS_TOKEN`
5. Prints the URL for you to merge the resulting PR

**Monthly auto-run (Windows Task Scheduler):**

1. Open Task Scheduler → Create Basic Task
2. Name: `opencode-backup-monthly`, Trigger: Monthly (1st of month), Action: Start a program
3. Program: `pwsh.exe`, Arguments: `-NoProfile -ExecutionPolicy Bypass -File F:\CD\Opencode\scripts\backup-workspace.ps1`
4. Finish. The script will silently commit + push on the 1st of each month. You get a PR notification from GitHub — merge when convenient.

### 4. Setup script -DryRun (safe restore testing)

`setup-env-vars.ps1` now accepts a `-DryRun` switch that simulates every action, modifies nothing:

```powershell
pwsh scripts/setup-env-vars.ps1 -DryRun
```

Use it before running the real setup on a new machine to preview what will happen — no env vars are set, no files are copied, no `opencode.json` paths are rewritten, no `core.hooksPath` is configured.

### 5. Known risk: opencode issue #9086

opencode v1.1.25 had a bug where `{env:VAR_NAME}` placeholders in `opencode.json` were overwritten with the actual secret values on startup. The current workspace runs v1.18.11 (the bug is fixed upstream), but to be safe:

- The pre-commit secret guard (section 1 above) catches the leak if it ever recurs on a future opencode version.
- The GitHub Actions secret scan (section 2) catches it on push.
- Manually: `pwsh scripts/audit-secrets.ps1` after any opencode session to verify `opencode.json` placeholders are intact.

### 6. Restore test verified (2026-08-02)

Restore of this backup was end-to-end tested on 2026-08-02:

- **Zip extracted** to temp folder — 83 files, 864 KB uncompressed, structure matches expected layout (root .md files, `.opencode/{agents,commands,skills,...}`, `global-config/`, `docs/adrs/`)
- **GitHub repo cloned** to temp folder — all 8 branches came down cleanly
- **`setup-env-vars.ps1 -DryRun` executed** — output sensible, no errors, path normalization would correctly rebase `F:\CD\Opencode` → current clone path
- **Pre-commit hook tested** — `pwsh scripts/audit-secrets.ps1` returned 0 (clean) on the tracked tree

Re-test any time: `pwsh scripts/setup-env-vars.ps1 -DryRun` + `pwsh scripts/audit-secrets.ps1`.

## License

Private repo. Internal use only.
