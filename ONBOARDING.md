# Onboarding — Opencode Workspace

Short quickstart for a team member cloning this repo. For full context (disaster
recovery, manual secrets, monthly backup procedure), see **README.md →
Restore Guide** (Scenario B).

## 9-step happy path

```powershell
# Step 1: Clone the workspace
git clone https://github.com/3xOGssavage/Opencode-Workspace.git <dir>
cd <dir>
git config core.hooksPath .githooks

# Step 2: Verify prerequisites (~5s; exits 1 if any required tool missing)
pwsh scripts/check-prerequisites.ps1

# Step 3: Set 4 setup env vars + copy global-config + npm install + normalize paths
pwsh scripts/setup-env-vars.ps1
# Restart your shell after this step (setx scopes to User; current shell can't see it yet)

# Step 4: Install the 58 user skills (9 sources via `npx skills add`, ~5-15 min first run)
pwsh scripts/install-user-skills.ps1

# Step 5: Clone the 5 vendored skill packs into .opencode/
pwsh scripts/clone-vendored-skill-packs.ps1

# Step 6: Set the 7 API keys (interactive, redacted input)
pwsh scripts/set-secrets.ps1

# Step 7: Authenticate the 3 OAuth MCP servers (browser opens, one at a time)
pwsh scripts/auth-mcp-servers.ps1

# Step 8: Restore auth.json to ~/.local/share/opencode/auth.json
#         (4 providers: opencode-go, ollama-cloud, nvidia, google)
#   From secure backup, OR launch `opencode` and log in each provider via /models menu.
#   Keys in auth.json are DIFFERENT from set-secrets.ps1's keys — they back the
#   opencode-go/ollama-cloud/nvidia/google providers that ship with opencode.

# Step 9: Verify setup + restart opencode
pwsh scripts/verify-setup.ps1
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

- **Windows (PowerShell 5.1+ / pwsh 7+)**: full automation via the 9 steps above.
- **Linux/macOS (pwsh 7+)**: `check-prerequisites.ps1`, `verify-setup.ps1`,
  `verify-inheritance.ps1`, `install-user-skills.ps1`,
  `clone-vendored-skill-packs.ps1`, `auth-mcp-servers.ps1` are cross-platform.
- `setup-env-vars.ps1` and `set-secrets.ps1` are Windows-focused (use `setx`).
  Linux/macOS team members: read README Scenario B for the equivalent
  `export KEY=VALUE` lines to append to `~/.bashrc`/`~/.zshrc`.

### Step 5b - Agent-expansion CLI tools (2026-08-29)

- Skills: covered by install-user-skills.ps1 (snapshot now includes blader/humanizer + OthmanAdi/planning-with-files).
- graft: `npm install -g @nanonets/graft`, then `graft telemetry disable`. The graft MCP self-provisions via `npx -y @nanonets/graft mcp` even without the global install — the global CLI is only needed for `graft build` (per-repo code-graph generation).
- crawl4ai: `pip install crawl4ai` + `crawl4ai-setup` (CLI: `crwl`).
- obscura: download obscura-x86_64-windows-stealth.zip v0.2.1, verify SHA-256 05872180fd4c5bbb765e232b0d3bb3b183b47aaa25699dc017d622278a59d597, extract to %LOCALAPPDATA%\Programs\obscura, add to user PATH.
- agent-reach: py -3 -m venv %USERPROFILE%\.agent-reach-venv + pip install from GitHub main.zip; zero-config channels only (Web/YouTube/RSS/V2EX/Bilibili); yt-dlp config --js-runtimes node.
