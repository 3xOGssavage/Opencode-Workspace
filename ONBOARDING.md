# Onboarding — Opencode Workspace

Two flows, one file. **Members (teammates)**: start at Step 0, use every
`-Member` flag, skip every line marked OWNER ONLY. **Owner**: Steps 1-9 as
written (answer `yes` to the machine question), plus the
"Owner moves machines" section at the bottom.
Pinned versions: opencode **1.18.30** (verified 2026-09-11), pwsh 7+ on
Linux/macOS. For full context (disaster recovery, manual secrets, monthly
backup procedure), see **README.md → Restore Guide** (Scenario B).

## Step 0 (members): access before clone

The repo is private. Before anything else:

1. Owner adds you as a collaborator (small groups, GitHub invite limits).
2. You log into GitHub (free account) and open the repo page to confirm access.
3. Only then `git clone` below. Cloning without access fails — that is normal.

## 9-step happy path

```powershell
# Step 1: Clone the workspace
git clone https://github.com/3xOGssavage/Opencode-Workspace.git <dir>
cd <dir>
git config core.hooksPath .githooks

# Step 2: Verify prerequisites (~5s; exits 1 if any required tool missing)
# pwsh 7+ must exist FIRST. Windows: winget install Microsoft.PowerShell
# Ubuntu/Debian: Microsoft apt repo (see Microsoft Learn "Install PowerShell on Linux")
# Fedora/RHEL: Microsoft dnf .rpm (same page) | Arch: community package `powershell`
pwsh scripts/check-prerequisites.ps1

# Step 3: env vars + global-config + npm install + normalize paths (+ blank notebook for members)
pwsh scripts/setup-env-vars.ps1 -Member   # members (installer also asks; default is member)
# pwsh scripts/setup-env-vars.ps1         # owner (answer "yes")
# Windows: restart the shell after this step. Linux: `source ~/.bashrc` (lines were printed).

# Step 4: Install the 58 user skills (9 sources via `npx skills add`, ~5-15 min first run)
pwsh scripts/install-user-skills.ps1

# Step 5: Clone the 5 vendored skill packs into .opencode/
pwsh scripts/clone-vendored-skill-packs.ps1
# (the 6th pack, github-mcp-server, is a manual release download - see the script TODO)

# Step 6: Set API keys (interactive, hidden input, never printed)
# Members: GitHub token FIRST, then the studio-labeled HCNSEC key (owner hands it
# over, never in chat), then your own Google + Tavily + optional Sentry keys.
# SKIP the aihubmix key (owner only - the checker will not ask for it).
pwsh scripts/set-secrets.ps1

# Step 7: OAuth MCP logins (browser opens, one at a time)
# Members: sentry only (optional day one); supabase + vercel are OWNER ONLY.
pwsh scripts/auth-mcp-servers.ps1 -Skip 'supabase,vercel'

# Step 8: Restore auth.json to ~/.local/share/opencode/auth.json
#         (4 providers: opencode-go, ollama-cloud, nvidia, google)
#   From secure backup, OR launch `opencode` and log in each provider via /models menu.
#   Keys in auth.json are DIFFERENT from set-secrets.ps1's keys — they back the
#   opencode-go/ollama-cloud/nvidia/google providers that ship with opencode.

# Step 9: Verify (MUST be green) + restart opencode
pwsh scripts/verify-setup.ps1 -Member   # members (owner-only items skipped-by-design)
# pwsh scripts/verify-setup.ps1         # owner
# Restart any open opencode shells so new env vars take effect.
```

## Multi-project considerations

If you work on more than one project in `Projects/`, note these per-project
overrides you may need:

- **Supabase**: the parent `opencode.json` scopes both `supabase` and
  `supabase-admin` MCPs to `project_ref=iovbjaljwxwxchumnyoc` (the neodev-portal
  project). For other Supabase projects, override the `mcp.supabase.url` /
  `mcp.supabase-admin.url` field in the project's own `opencode.json` with a
  different `project_ref` query param.
- **Skill scope**: with 3 user skill directories (`~/.agents/skills`,
  `~/.config/opencode/skills`, plus workspace `.agents/skills`), same-named
  skills loaded LAST win per opencode's precedence (see AGENTS.md "Skill
  precedence rule"). Globally unique skills are unaffected.

## Prerequisites beyond scripts

- **SSH key on GitHub**: sub-repos inside `Projects/` (e.g. `neodev-portal`)
  use SSH URLs (`git@github.com:...`). Generate if missing:
  `ssh-keygen -t ed25519 -C 'you@email.com'` then add the public key at
  https://github.com/settings/keys.
- **GitHub Personal Access Token**: needs `repo`, `workflow`, `read:org`,
  `read:user`, `gist` scopes for the github MCP server.
- **AIHUBMIX API access**: this workspace uses 44 models on `api.aihubmix.com`.
  Get a key at https://aihubmix.com — required for `aihubmix/*` provider.

## What's NOT restored by automation (manual — by design)

- `~/.local/share/opencode/auth.json` — 4 provider keys (see Step 8)
- `~/.local/share/opencode/mcp-auth.json` — 3 OAuth MCP tokens (Step 7 generates this)
- `.opencode/memory.jsonl` — knowledge graph is per-user, gitignored; users
  accumulate their own memories
- `.opencode/backups/` — historical snapshots, workspace-only
- `.opencode/browser_use/.venv/` — Python venv, recreated by
  `scripts/setup-browser-use.ps1`

## Rollback

Per-script revert:

```powershell
git rm scripts/<broken-script>.ps1
git commit -m "chore: revert <script>"
```

Bulk rollback to pre-reproducibility state:

```powershell
# After merge, find the merge commit:
git log --merges --oneline | Select-String 'workspace reproducibility'
git revert <merge-commit-hash> --no-edit
```

Projects/ 4-layer guard piece-meal rollback:

- Delete the Layer A block in `.githooks/pre-commit`
- Delete `.github/workflows/projects-guard.yml` (Layer C)
- Strip the Layer D comment block from `.gitignore` (keep the rule itself)
- Strip the "Projects/ is local-only" subsection from AGENTS.md (Layer E)

## Cross-platform note

- **Windows (PowerShell 5.1+ / pwsh 7+)**: full automation via the steps above.
- **Linux/macOS (pwsh 7+)**: all 7 scripts are cross-platform. They auto-detect
  the OS (portable paths, memory launcher `.sh` twin, `export` lines for
  `~/.bashrc`). No manual workarounds; no "which system are you on?" questions.

### Step 5b - Agent-expansion CLI tools (2026-08-29)

- Skills: covered by install-user-skills.ps1 (snapshot now includes blader/humanizer + OthmanAdi/planning-with-files).
- graft: `npm install -g @nanonets/graft`, then `graft telemetry disable`. The graft MCP self-provisions via `npx -y @nanonets/graft mcp` even without the global install — the global CLI is only needed for `graft build` (per-repo code-graph generation).
- crawl4ai: `pip install crawl4ai` + `crawl4ai-setup` (CLI: `crwl`).
- obscura: download obscura-x86_64-windows-stealth.zip v0.2.1, verify SHA-256 05872180fd4c5bbb765e232b0d3bb3b183b47aaa25699dc017d622278a59d597, extract to %LOCALAPPDATA%\Programs\obscura, add to user PATH.
- agent-reach: py -3 -m venv %USERPROFILE%\.agent-reach-venv + pip install from GitHub main.zip; zero-config channels only (Web/YouTube/RSS/V2EX/Bilibili); yt-dlp config --js-runtimes node.

## Member done-checklist (each person, before "done")

- [ ] `verify-setup.ps1 -Member` ends `0 failures` (warnings on optional items OK).
- [ ] `opencode` starts; `/models` shows the studio AI home.
- [ ] Portal/app untouched; no database, hosting, or shared-secret access held.
- [ ] One tiny change merged through a review (owner merges).
- [ ] Knows: secrets never go in chat/email/screenshots; leaver rule below.

## Owner moves machines (Version 1 restore)

1. Fetch from your GitHub; run `setup-env-vars.ps1`, answer `yes`.
2. Keys from your own store (`set-secrets.ps1` or `OC_SECRETS_FILE`).
3. Memory from your backup (`.opencode/backups/` or Drive) into `.opencode/memory.jsonl`.
4. Logins (Step 7 all three + Step 8); `verify-setup.ps1` (owner mode) green.

## Leaver rule (personal machines can't be wiped)

When a coder leaves: owner cancels their labeled studio key(s), removes them
as collaborator, and asks them to delete the workspace copy. Safe by design:
they never held shared secrets, the database, or anyone else's keys — a
leftover copy of settings plus their own keys is useless to anyone else.

## Member rollback (undo an install)

```powershell
# Windows: delete the 4 settings lines (print them first to confirm)
[Environment]::SetEnvironmentVariable('OPENCODE_CONFIG', $null, 'User')
[Environment]::SetEnvironmentVariable('OPENCODE_CONFIG_DIR', $null, 'User')
[Environment]::SetEnvironmentVariable('MEMORY_FILE_PATH', $null, 'User')
[Environment]::SetEnvironmentVariable('OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS', $null, 'User')
# Linux: delete the 4 export lines from ~/.bashrc instead. Then:
cd ..; Remove-Item -Recurse -Force <dir>   # remove the clone
```

## Known quirk: Gemini sessions + vercel tools

Direct-Google Gemini models reject one vercel tool's schema (oneOf booleans;
proven Sep 2026 by bisection). Config-side, every Gemini-running agent carries
a `vercel_*` deny rule, so agents are unaffected. Manual `/models` sessions on
a Gemini model inherit the same protection only through those agents — if you
ever see `function_declarations` 400s in a manual session, switch back to a
non-Gemini model for that chat.
