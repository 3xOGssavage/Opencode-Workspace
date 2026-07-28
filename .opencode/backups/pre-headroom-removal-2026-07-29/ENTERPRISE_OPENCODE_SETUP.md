# OpenCode Enterprise Setup — Setup Guide & Current State Reference

> **Purpose**: This document has TWO parts:
>
> 1. **Sections 0-16**: A portable, reproducible setup guide for configuring an enterprise opencode workspace from scratch on any machine. Zero personal data — uses `{{placeholder}}` values filled in by the receiving agent.
> 2. **Sections 17-21**: The CURRENT production state of the `F:\CD\Opencode` workspace as of 2026-07-19, including all audit findings, fixes, new artifacts (enterprise-pipeline skill, /ship command), and project inheritance configuration.
>
> **Audience**: Another opencode instance (or a human) reading this to either:
>
> - **A) Re-deploy** this enterprise opencode setup on another machine (use Sections 0-16)
> - **B) Understand** the current state of this workspace (read Sections 17-21)

---

## Table of Contents

### Part I — Portable Setup Guide (for re-deployment)

0. [How to Use This Document](#0-how-to-use-this-document)
1. [Pre-Setup Questionnaire](#1-pre-setup-questionnaire-mandatory)
2. [Bootstrap: Install OpenCode](#2-bootstrap-install-opencode-if-missing)
3. [Prerequisites](#3-prerequisites-verify-or-install)
4. [Directory Structure](#4-directory-structure)
5. [Skill Pack Installation](#5-skill-pack-installation)
6. [Plugin Installation](#6-plugin-installation)
7. [oh-my-opencode-slim (Optional)](#7-oh-my-opencode-slim-optional)
8. [opencode.json Template](#8-opencodejson-template)
9. [AGENTS.md Template](#9-agentsmd-template)
10. [Custom Agent Files](#10-custom-agent-files)
11. [Environment Variables](#11-environment-variables)
12. [User Manual Steps](#12-user-manual-steps-after-setup)
13. [Verification Checklist](#13-verification-checklist)
14. [Troubleshooting](#14-troubleshooting)

### Part II — Current Workspace State Reference

15. [Appendix A: Full AGENTS.md Content](#appendix-a-full-agentsmd-content)
16. [Appendix B: Full Custom Agent Files](#appendix-b-full-custom-agent-files)
17. [Section 17 — Current Production State (2026-07-19)](#section-17--current-production-state-2026-07-19)
18. [Section 18 — Enterprise Audit & Fixes (2026-07-19)](#section-18--enterprise-audit--fixes-2026-07-19)
19. [Section 19 — Enterprise Pipeline Skill](#section-19--enterprise-pipeline-skill)
20. [Section 20 — /ship Command](#section-20--ship-command)
21. [Section 21 — Project Inheritance & Deployment](#section-21--project-inheritance--deployment)

---

# PART I — PORTABLE SETUP GUIDE

## 0. How to Use This Document

### If you are an opencode agent receiving this file

**Context**: This file was pasted into a folder by the user. That folder IS (or will be) the user's `setup_root`. You are running inside opencode RIGHT NOW. Your job is to set up this folder and configure everything around it.

1. Read the entire document top-to-bottom first.
2. Read it again, this time collecting all `{{placeholder}}` definitions you find.
3. **Set `setup_root` to the CURRENT WORKING DIRECTORY** (use `pwd` / `Get-Location` to confirm). Do NOT ask the user where — they put this file here on purpose.
4. Ask the user the questions in Section 1 using the `question` tool, EXCEPT Q-B1 (location of workspace). For Q-B1, pre-fill with the current directory and let the user confirm or change. Group questions logically to minimize friction (suggested batches shown).
5. Map answers into variables. Use these variable names consistently:
   - `os` — "windows" | "macos" | "linux"
   - `shell` — "powershell" | "cmd" | "zsh" | "bash" | "fish"
   - `setup_root` — full absolute path, no trailing slash, no `~` shorthand
   - `projects_root` — full absolute path
   - `backup_root` — full absolute path
   - `username` — short identifier for the user
   - `provider_choice` — one of the provider codes from Q1.2a
   - `main_model_id` — provider-qualified model string for the main model
   - `small_model_id` — provider-qualified model string for the small model
   - `main_model_label` — human-friendly label
   - `small_model_label` — human-friendly label
   - `use_ohmy` — boolean (oh-my-opencode-slim)
   - `enable_tavily` — boolean
   - `enable_sentry` — boolean
   - `enable_composio` — boolean
   - `enable_supabase` — boolean
   - `tavily_api_key` — only if `enable_tavily` is true
   - `sentry_auth_token` — only if `enable_sentry` is true
   - `enable_skills_*` — booleans per skill pack from Q1.4
6. Execute Sections 2 through 11 in order. Verify each step. Stop and ask the user if any step fails irreversibly.
7. Print the user manual steps from Section 12 clearly to the user.
8. Stop. You (the agent) cannot restart opencode from inside opencode — the user must do the restart + OAuth steps themselves.

### If you are a human user

1. Save this file as `ENTERPRISE_OPENCODE_SETUP.md` in an empty folder.
2. Install opencode if you don't have it (Section 2).
3. From that folder, launch opencode.
4. Tell opencode: _"Read ENTERPRISE_OPENCODE_SETUP.md from top to bottom and set up my enterprise opencode. Ask me the questions from Section 1 first."_
5. Answer the questions when prompted.
6. When opencode says setup is done, follow the manual steps it prints.
7. Restart opencode.

---

## 1. Pre-Setup Questionnaire (MANDATORY)

Ask ALL questions in the order shown. Group into 6 batches (A through F). Do not skip questions. Do not proceed without answers.

### Batch A — Environment (Ask all 4 at once)

```
Q-A1. What operating system are you on?
      (a) Windows (PowerShell 5.1 — typical Windows 10/11)
      (b) Windows (PowerShell 7+ — newer Windows)
      (c) macOS
      (d) Linux

Q-A2. What shell will you use day-to-day?
      Windows: PowerShell / cmd / Git Bash / WSL
      macOS:   zsh (default) / bash / fish
      Linux:   bash (default) / zsh / fish

Q-A3. Do you already have opencode installed?
      (a) Yes — I can run `opencode --version` successfully
      (b) No — please install it (Section 2)

Q-A4. Do you have any of these already installed? (multi-select)
      [ ] Node.js 20+
      [ ] Python 3.12+
      [ ] Bun (npm install -g bun)
      [ ] uv (https://docs.astral.sh/uv/)
      [ ] Git
```

### Batch B — Locations (Ask all 4 at once)

```
Q-B1. Where should the opencode WORKSPACE live?
      (This is where opencode.json, AGENTS.md, .opencode/ folder will be created.)
      Suggest: ~/opencode-workspace

Q-B2. Where will your PROJECT FILES live?
      (The actual codebases you'll work on.)
      Suggest: ~/projects

Q-B3. Where should SETUP FILES, BACKUPS, and KNOWLEDGE GRAPHS live?
      (Long-term opencode state. Usually the same as Q-B1, but can be different.)
      Suggest: same as Q-B1

Q-B4. What short identifier do you want as your opencode username?
      (Used in share metadata. Not auth.)
      Suggest: your first name or initials
```

NOTE FOR AGENT: Expand `~` to the user's home directory using the appropriate OS:

- Windows PowerShell: `$env:USERPROFILE`
- macOS/Linux bash/zsh: `$HOME`
  After expansion, store as absolute path with no trailing slash. Strip quotes if user provided quoted path.

### Batch C — AI Provider & Model (Ask all 5 at once)

```
Q-C1. Which AI provider do you want to use? (Pick ONE primary.)
      (a) Anthropic Claude          (best quality; needs ANTHROPIC_API_KEY)
      (b) OpenAI GPT                (needs OPENAI_API_KEY)
      (c) Google Gemini             (free tier available; needs GEMINI_API_KEY)
      (d) OpenCode Zen              (free tier for mimo; pay-per-use otherwise)
      (e) OpenCode Go               (opencode-managed; needs opencode account)
      (f) OpenRouter                (75+ models via one OPENROUTER_API_KEY)
      (g) Local Ollama              (free; needs Ollama installed + model pulled)
      (h) Custom OpenAI-compatible  (needs base URL + model names)

Q-C2. Which MAIN model do you want for build / plan / architect / reviewer / orchestrator?
      Recommended by provider (model IDs verified late 2025 / early 2026):
        Anthropic:  anthropic/claude-sonnet-4-6
        OpenAI:     openai/gpt-5
        Gemini:     google/gemini-3.5-flash-lite  (Flash-Lite class, 500 RPD free tier; gemini-2.5-pro is paid-only since April 2026)
        Zen:        opencode-zen/mimo-v2.5-free  (default for subagents; pay-per-use for primary)
        Go:         opencode-go/glm-4.6
        OpenRouter: openrouter/anthropic/claude-sonnet-4-6
        Ollama:     ollama/qwen2.5-coder:32b
        Custom:     (you provide <provider>/<model>)

Q-C3. Which SMALL/FAST model for tester / explorer / librarian / observer?
      Recommended by provider:
        Anthropic:  anthropic/claude-haiku-4-5
        OpenAI:     openai/gpt-5-mini
        Gemini:     google/gemini-3.5-flash-lite  (Flash-Lite class, 500 RPD free tier; gemini-2.5-flash is 20 RPD)
        Zen:        opencode-zen/mimo-v2.5-free  (recommended: same free model)
        Go:         opencode-go/minimax-m3
        OpenRouter: openrouter/anthropic/claude-haiku-4-5
        Ollama:     ollama/qwen2.5-coder:7b
        Custom:     (you provide <provider>/<model>)

Q-C4. Do you want oh-my-opencode-slim (multi-agent orchestration — 8 specialist agents)?
      (a) Yes — recommended for full enterprise capability
      (b) No — simpler, just the 5 built-in agents

Q-C5. If you chose Ollama (Q-C1=g), which models have you already pulled?
      (The agent will verify with `ollama list` and instruct you to pull if missing.)
      Default: ollama pull qwen2.5-coder:32b && ollama pull qwen2.5-coder:7b
```

### Batch D — MCP Features (Ask as multi-select)

```
Q-D1. Which REMOTE MCPs do you want? (Each needs OAuth login in browser.)
      [ ] Supabase     — Postgres, auth, storage, edge functions, pgvector (read-only by default)
      [ ] Composio     — 1000+ SaaS integrations (Gmail, Slack, Linear, Jira, GitHub, etc.)
      [ ] Sentry       — Production error tracking + root-cause analysis (needs SENTRY_AUTH_TOKEN)

Q-D2. Which TOKEN-BASED MCPs do you want? (Needs an API key you must provide.)
      [ ] Tavily       — AI web search, crawl, extract (needs TAVILY_API_KEY from app.tavily.com)

Q-D3. Which LOCAL MCPs do you want? (All auto-install on first run. Recommended: all.)
      [x] context7          — live library docs
      [x] sequential-thinking — step-by-step reasoning
      [x] playwright        — browser automation (chromium)
      [x] memory            — persistent knowledge graph
      [x] fetch             — URL fetcher
      [x] filesystem        — read/write outside workspace
      [x] chrome-devtools   — Chrome DevTools Protocol
      [x] headroom          — context compression
```

### Batch E — Skill Packs (Ask as multi-select)

```
Q-E1. Which SKILL PACKS do you want? (Each is a git clone of an external repo.)
      [x] addyosmani/agent-skills (24 skills)  — full dev lifecycle
      [x] last30days (1 skill)               — research engine
      [x] vercel-labs/agent-skills (9 skills) — React/Vercel best practices
      [x] anthropic/skills (6 active)         — frontend-design, webapp-testing, mcp-builder
      [x] superpowers (10 skills)            — process skills via plugin
      [x] playwright-best-practices (1 skill) — Playwright patterns
      [x] vercel-deploy-claude-code-plugin (3 skills via npx) — deploy/logs/setup
      [x] vercel-cli (1 skill via npx)        — Vercel CLI usage
      [x] User skills (11)                    — shadcn-ui, stitch-*, ui-ux-pro-max, pinokio, gepeto, remotion, etc.
      [x] Config skills (7)                   — clonedeps, codemap, deepwork, reflect, simplify, worktrees
```

### Batch F — Setup Preferences (Ask all 3 at once)

```
Q-F1. Do you want a `.opencode/backups/` directory with timestamped backups of config files?
      (a) Yes — strongly recommended (every config edit is backed up before change)
      (b) No  — not needed for personal use

Q-F2. Do you want the ENTERPRISE PIPELINE skill installed? (Mandates 11-step gated workflow.)
      (a) Yes — recommended for enterprise IT development
      (b) No  — keep opencode's default behavior

Q-F3. Do you want the /ship command installed? (One-command shipping of current work.)
      (a) Yes — recommended
      (b) No  — use the pipeline skill manually
```

NOTE FOR AGENT: Expand `~` to the user's home directory using the appropriate OS:

- Windows PowerShell: `$env:USERPROFILE`
- macOS/Linux bash/zsh: `$HOME`
  After expansion, store as absolute path with no trailing slash. Strip quotes if user provided quoted path.

---

## 2. Bootstrap: Install OpenCode (if missing)

```bash
# macOS / Linux
curl -fsSL https://opencode.ai/install | bash

# Windows (PowerShell)
irm https://opencode.ai/install.ps1 | iex

# Or via npm (any platform with Node.js)
npm install -g opencode
```

Verify with `opencode --version`. Expect a version string >= 1.0.0.

---

## 3. Prerequisites (verify or install)

| Prerequisite          | Min Version | Install                                         |
| --------------------- | ----------- | ----------------------------------------------- |
| Git                   | 2.40+       | https://git-scm.com/                            |
| Node.js               | 20+         | https://nodejs.org/ or `nvm install 20`         |
| Python                | 3.12+       | https://python.org/ or `uv python install 3.12` |
| uv (Python pkg mgr)   | 0.4+        | https://docs.astral.sh/uv/                      |
| Bun (optional)        | 1.1+        | `npm install -g bun`                            |
| GitHub CLI (optional) | 2.50+       | https://cli.github.com/                         |

Quick check:

```bash
git --version
node --version
python --version
uv --version
```

If any return errors, install the missing tool before proceeding.

---

## 4. Directory Structure

Create this structure under `{{setup_root}}`:

```
{{setup_root}}/
├── opencode.json                    # main config (Section 8)
├── AGENTS.md                        # operating manual (Section 9 + Appendix A)
├── ENTERPRISE_OPENCODE_SETUP.md     # this file (reference only)
├── skills-lock.json                 # integrity hashes for skills installed via npx
├── .opencode/                       # opencode internals
│   ├── memory.jsonl                 # active knowledge graph (gitignored)
│   ├── memory-mcp-wrapper.bat        # sets MEMORY_FILE_PATH for memory MCP
│   ├── github-mcp-server/           # local GitHub MCP binary
│   │   └── github-mcp-server.exe
│   ├── backups/                     # timestamped config backups
│   ├── skills/                      # workspace skills (playwright-best-practices, enterprise-pipeline)
│   ├── agents/                      # agent prompt .md files
│   │   ├── architect.md
│   │   ├── reviewer.md
│   │   ├── tester.md
│   │   ├── addy-code-reviewer.md
│   │   ├── addy-security-auditor.md
│   │   ├── addy-test-engineer.md
│   │   └── addy-web-perf-auditor.md
│   ├── commands/                     # custom commands (commit, context, test, verify, ship)
│   ├── agent-skills/                # addyosmani/agent-skills (24 skills, after clone)
│   ├── last30days-skill/            # last30days (1 skill, after clone)
│   ├── vercel-agent-skills/         # vercel-labs/agent-skills (9 skills, after clone)
│   ├── anthropic-skills/            # anthropic/skills (6 active, 11 inert, after clone)
│   └── vercel-agent-skills/         # vercel skills (9, after clone)
├── .agents/                         # (alternative location for some skills)
│   └── skills/                      # vercel-deploy-claude-code-plugin skills (after npx)
└── Projects/                        # all user projects live here
    ├── project-a/
    │   ├── opencode.json            # ONLY project-specific overrides (inherits rest)
    │   └── AGENTS.md                # (optional) project-specific instructions
    ├── project-b/
    │   └── opencode.json
    └── ...
```

Setup commands:

```bash
cd {{setup_root}}
mkdir -p .opencode/{backups,skills,agents,commands} Projects
mkdir -p .opencode/{agent-skills,last30days-skill,vercel-agent-skills,anthropic-skills}
mkdir -p .agents/skills
```

---

## 5. Skill Pack Installation

Each skill pack is a git clone into `{{setup_root}}/.opencode/<pack-name>/`.

### 5.1 — addyosmani/agent-skills (24 skills)

```bash
cd {{setup_root}}/.opencode
git clone https://github.com/addyosmani/agent-skills.git agent-skills
```

**Skills included** (24): `api-and-interface-design`, `browser-testing-with-devtools`, `ci-cd-and-automation`, `code-review-and-quality`, `code-simplification`, `context-engineering`, `debugging-and-error-recovery`, `deprecation-and-migration`, `documentation-and-adrs`, `doubt-driven-development`, `frontend-ui-engineering`, `git-workflow-and-versioning`, `idea-refine`, `incremental-implementation`, `interview-me`, `observability-and-instrumentation`, `performance-optimization`, `planning-and-task-breakdown`, `security-and-hardening`, `shipping-and-launch`, `source-driven-development`, `spec-driven-development`, `test-driven-development`, `using-agent-skills`.

### 5.2 — last30days (1 skill)

```bash
cd {{setup_root}}/.opencode
git clone https://github.com/skillcreatorai/last30days-skill.git last30days-skill
```

**Skills included** (1): `last30days`.

### 5.3 — vercel-labs/agent-skills (9 skills)

```bash
cd {{setup_root}}/.opencode
git clone https://github.com/vercel-labs/agent-skills.git vercel-agent-skills
```

**Skills included** (9): `composition-patterns`, `deploy-to-vercel`, `react-best-practices`, `react-native-skills`, `react-view-transitions`, `vercel-cli-with-tokens`, `vercel-optimize`, `web-design-guidelines`, `writing-guidelines`.

### 5.4 — anthropic/skills (6 active, 11 inert)

```bash
cd {{setup_root}}/.opencode
git clone https://github.com/anthropics/skills.git anthropic-skills
```

**Active skills** (6): `claude-api`, `frontend-design`, `mcp-builder`, `skill-creator`, `web-artifacts-builder`, `webapp-testing`.

**Inert skills** (11, lack SKILL.md): `algorithmic-art`, `brand-guidelines`, `canvas-design`, `doc-coauthoring`, `docx`, `internal-comms`, `pdf`, `pptx`, `slack-gif-creator`, `theme-factory`, `xlsx`. These are present in the directory but not auto-discovered.

### 5.5 — superpowers (10 skills, via plugin)

Installed via the `superpowers` plugin (see Section 6). Skills are auto-loaded from the plugin cache.

**Active skills** (10): `brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `receiving-code-review`, `subagent-driven-development`, `using-git-worktrees`, `using-superpowers`, `verification-before-completion`, `writing-skills`.

**Inert skills** (4, lack SKILL.md): `requesting-code-review`, `systematic-debugging`, `test-driven-development`, `writing-plans`.

### 5.6 — playwright-best-practices (1 skill)

```bash
cd {{setup_root}}/.opencode
git clone https://github.com/microsoft/playwright-best-practices.git skills-tmp
mkdir -p skills/playwright-best-practices
cp -r skills-tmp/. skills/playwright-best-practices/
rm -rf skills-tmp
```

Or use whatever upstream pattern the repo provides. **Skills included** (1): `playwright-best-practices`.

### 5.7 — vercel-deploy + vercel-cli (4 skills via npx)

```bash
cd {{setup_root}}
npx skills add vercel/vercel-deploy-claude-code-plugin
npx skills add vercel/vercel
```

**Skills installed** (4): `deploy`, `logs`, `setup`, `vercel-cli`. These go into `{{setup_root}}/.agents/skills/` and are tracked by `skills-lock.json`.

---

## 6. Plugin Installation

Add plugins to `{{setup_root}}/opencode.json: plugin[]`.

```json
"plugin": [
  "superpowers@git+https://github.com/obra/superpowers.git#d884ae04edebef577e82ff7c4e143debd0bbec99",
  "opencode-notify",
  "envsitter-guard"
]
```

- **superpowers** — pinned to specific commit SHA for reproducibility. Update SHA via `git ls-remote https://github.com/obra/superpowers.git refs/heads/main`.
- **opencode-notify** — desktop notifications when sessions complete.
- **envsitter-guard** — scans `.env` files, never exposes secrets, validates syntax.

Plus in `{{global_config}}/opencode.jsonc`:

```json
{ "plugin": ["oh-my-opencode-slim"] }
```

**oh-my-opencode-slim** provides 8 additional agents: `orchestrator`, `oracle`, `council`, `librarian`, `explorer`, `designer`, `fixer`, `observer`. See Section 7.

---

## 7. oh-my-opencode-slim (Optional)

If `use_ohmy` is true, create the global config at `C:\Users\{{username}}\.config\opencode\opencode.jsonc` (Windows) or `~/.config/opencode/opencode.jsonc` (macOS/Linux):

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["oh-my-opencode-slim"],
  "agent": {
    "explore": { "disable": true },
    "general": { "disable": true },
  },
  "lsp": true,
}
```

The 8 OMO-Slim agents are configured in `C:\Users\{{username}}\.config\opencode\oh-my-opencode-slim.json`. See [omo-slim config docs](https://github.com/...) for the full preset structure.

For the current workspace, the active preset is `opencode-go` which uses `hcnsec/Kimi-K2.6` (Moonshot Kimi K2.6 via hcnsec reseller, 256K context) for all 8 agents. To switch to OpenAI models, set `preset: "openai-default"` and provide `OPENAI_API_KEY`.

---

## 8. opencode.json Template

Write this to `{{setup_root}}/opencode.json`. See Appendix B for the actual current `opencode.json` from the production workspace. The template below is the minimum required; the production version has all safety fixes applied (see Section 18).

```json
{
  "$schema": "https://opencode.ai/config.json",
  "username": "{{username}}",
  "model": "{{main_model_id}}",
  "small_model": "{{small_model_id}}",
  "default_agent": "build",
  "instructions": [
    "AGENTS.md"
  ],
  "share": "disabled",
  "autoupdate": "notify",
  "snapshot": true,
  "skills": {
    "paths": [
      ".opencode/skills",
      ".opencode/agent-skills/skills",
      ".opencode/last30days-skill/skills",
      ".opencode/vercel-agent-skills/skills",
      ".opencode/anthropic-skills/skills",
      ".agents/skills",
      "C:/Users/{{username}}/.agents/skills",
      "C:/Users/{{username}}/.config/opencode/skills"
    ]
  },
  "permission": {
    "edit": {
      "*": "allow",
      "{{setup_root}}/opencode.json": "deny",
      "{{setup_root}}/AGENTS.md": "deny",
      "{{setup_root}}/.opencode/memory.jsonl": "deny"
    },
    "bash": {
      "*": "ask",
      "git status *": "allow",
      "git diff *": "allow",
      "git log *": "allow",
      "git show *": "allow",
      "git branch *": "allow",
      "git remote *": "allow",
      "ls *": "allow",
      "dir *": "allow",
      "pwd": "allow",
      "cat *": "allow",
      "head *": "allow",
      "tail *": "allow",
      "echo *": "allow",
      "Test-Path *": "allow",
      "Get-ChildItem *": "allow",
      "Get-Item *": "allow",
      "Get-Content *": "allow",
      "Select-Object *": "allow",
      "Select-String *": "allow",
      "Where-Object *": "allow",
      "Get-Command *": "allow",
      "Get-Date *": "allow",
      "node --version": "allow",
      "npm --version": "allow",
      "python --version": "allow",
      "node -e *": "allow",
      "npx *": "allow",
      "npm install *": "allow",
      "npm run *": "allow",
      "npm test *": "allow",
      "npm exec *": "allow",
      "tsc *": "allow",
      "tsx *": "allow",
      "git add *": "allow",
      "git commit *": "allow",
      "git checkout *": "allow",
      "git switch *": "allow",
      "git merge *": "allow",
      "git rebase *": "allow",
      "git pull *": "allow",
      "git fetch *": "allow",
      "git stash *": "allow",
      "git worktree *": "allow",
      "git tag *": "allow",
      "git push": "ask",
      "git push *": "ask",
      "git reset --hard *": "ask",
      "git clean -fd *": "ask",
      "Remove-Item *": "ask",
      "New-Item *": "allow",
      "Copy-Item *": "ask",
      "Move-Item *": "ask",
      "Set-Content *": "ask",
      "Add-Content *": "allow",
      "Clear-Content *": "ask",
      "python *": "allow",
      "pip *": "allow",
      "pip3 *": "allow",
      "uv *": "allow",
      "uvx *": "allow",
      "cargo *": "allow",
      "rustc *": "allow",
      "go *": "allow",
      "dotnet *": "allow",
      "mvn *": "allow",
      "gradle *": "allow",
      "make *": "allow",
      "cmake *": "allow",
      "docker *": "ask",
      "docker-compose *": "ask",
      "kubectl *": "allow",
      "terraform *": "allow",
      "prettier *": "allow",
      "eslint *": "allow",
      "black *": "allow",
      "ruff *": "allow",
      "mypy *": "allow",
      "pyright *": "allow",
      "curl *": "allow",
      "wget *": "allow",
      "headroom *": "allow"
    },
    "webfetch": "allow",
    "external_directory": {
      "{{setup_root_drive}}/**": "allow",
      "*": "ask"
    }
  },
  "provider": {
    // Filled in by Q1.2a — see Section 8.1 below
  },
  "agent": {
    "build": {
      "model": "{{main_model_id}}",
      "mode": "primary"
    },
    "plan": {
      "model": "{{main_model_id}}",
      "mode": "primary"
    },
    "architect": {
      "model": "{{small_model_id}}",
      "mode": "subagent",
      "permission": { "edit": "deny", "bash": "ask" }
    },
    "reviewer": {
      "model": "{{small_model_id}}",
      "mode": "subagent",
      "permission": { "edit": "deny", "bash": "ask" }
    },
    "tester": {
      "model": "{{small_model_id}}",
      "mode": "subagent",
      "permission": {
        "edit": "deny",
        "bash": {
          "Remove-Item *": "deny",
          "Set-Content *": "deny",
          "Clear-Content *": "deny",
          "Move-Item *": "deny",
          "Copy-Item *": "deny"
        }
      }
    },
    "explorer": {
      "model": "{{small_model_id}}",
      "mode": "subagent",
      "permission": { "edit": "deny", "bash": "allow" }
    },
    "oracle": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "librarian": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "fixer": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "designer": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "observer": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "council": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "orchestrator": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "addy-code-reviewer": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "addy-security-auditor": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "addy-test-engineer": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } },
    "addy-web-perf-auditor": { "model": "{{small_model_id}}", "mode": "subagent", "permission": { "edit": "deny", "bash": "ask" } }
  },
  "lsp": {
    "typescript-language-server": {
      "command": ["typescript-language-server", "--stdio"],
      "extensions": [".ts", ".tsx", ".js", ".jsx"]
    },
    "pyright": {
      "command": ["pyright-langserver", "--stdio"],
      "extensions": [".py", ".pyi"]
    }
  },
  "formatter": {
    "prettier": {
      "command": ["prettier", "--write", "$FILE"],
      "extensions": [".js", ".jsx", ".ts", ".tsx", ".json", ".md", ".css", ".html", ".yml", ".yaml"]
    }
  },
  "mcp": {
    "context7": { "type": "local", "command": ["npx", "-y", "@upstash/context7-mcp"], "enabled": true },
    "sequential-thinking": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"], "enabled": true },
    "playwright": { "type": "local", "command": ["npx", "-y", "@playwright/mcp"], "enabled": true, "env": { "BROWSER": "chromium" } },
    "memory": { "type": "local", "command": ["F:\\CD\\Opencode\\.opencode\\memory-mcp-wrapper.bat"], "enabled": true },
    "tavily": { "type": "local", "command": ["npx", "-y", "tavily-mcp@latest"], "enabled": true, "env": { "TAVILY_API_KEY": "{env:TAVILY_API_KEY}" } },
    "fetch": { "type": "local", "command": ["uv
```

    "tavily": { "type": "local", "command": ["npx", "-y", "tavily-mcp@latest"], "enabled": true, "env": { "TAVILY_API_KEY": "{env:TAVILY_API_KEY}" } },
        "fetch": { "type": "local", "command": ["uvx", "mcp-server-fetch"], "enabled": true, "env": { "PYTHONIOENCODING": "utf-8" } },
        "filesystem": { "type": "local", "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "F:\\CD"], "enabled": true },
        "chrome-devtools": { "type": "local", "command": ["npx", "-y", "chrome-devtools-mcp@latest"], "enabled": true },
        "headroom": { "type": "local", "command": ["headroom", "mcp", "serve"], "enabled": true },
        "sentry": { "type": "remote", "url": "https://mcp.sentry.dev/mcp", "enabled": true },
        "composio": { "type": "remote", "url": "https://connect.composio.dev/mcp", "enabled": true },
        "supabase": { "type": "remote", "url": "https://mcp.supabase.com/mcp?read_only=false", "enabled": true },
        "grep": { "type": "remote", "url": "https://mcp.grep.app", "enabled": true },
        "github": { "type": "local", "command": ["F:\\CD\\Opencode\\.opencode\\github-mcp-server\\github-mcp-server.exe", "stdio", "--toolsets", "repos,issues,pull_requests,actions,code_security,discussions,orgs,users,gists"], "enabled": true, "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "{env:GITHUB_PERSONAL_ACCESS_TOKEN}" } },
        "vercel": { "type": "remote", "url": "https://mcp.vercel.com", "enabled": true },
        "vision-tool": { "type": "local", "command": ["python", "F:\\CD\\Opencode\\.opencode\\tools\\vision-tool\\vision_mcp_server.py"], "enabled": true, "env": { "GEMINI_API_KEY": "{env:GEMINI_API_KEY}" } }
      ],
      "plugin": [
        "superpowers@git+https://github.com/obra/superpowers.git#d884ae04edebef577e82ff7c4e143debd0bbec99",
        "opencode-notify",
        "envsitter-guard",
        "@dietrichgebert/ponytail"
      ],
      "tool_output": {
        "max_lines": 200,
        "max_bytes": 65536
      },
      "compaction": {
        "auto": false,
        "tail_turns": 15
      }
    }

### 8.1 - Provider Configuration (per choice)

For each `provider_choice`, replace the `provider` block:

**(a) Anthropic:**

```json
"provider": {
  "anthropic": {
    "npm": "@ai-sdk/anthropic",
    "name": "Anthropic",
    "options": { "apiKey": "{env:ANTHROPIC_API_KEY}" },
    "models": {}
  }
}
```

**(b) OpenAI:**

```json
"provider": {
  "openai": {
    "npm": "@ai-sdk/openai",
    "name": "OpenAI",
    "options": { "apiKey": "{env:OPENAI_API_KEY}" },
    "models": {}
  }
}
```

**(d) OpenCode Zen (recommended for cost):**

```json
"provider": {
  "opencode-zen": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "OpenCode Zen",
    "options": { "baseURL": "https://opencode.ai/zen/v1", "apiKey": "{env:OPENCODE_API_KEY}" },
    "models": {
      "mimo-v2.5-free": { "name": "MiniMax mimo v2.5 (free)", "limit": { "context": 200000, "output": 16384 } }
    }
  }
}
```

**(h) Custom OpenAI-compatible (e.g. hcnsec):**

```json
"provider": {
  "hcnsec": {
    "npm": "@ai-sdk/openai-compatible",
    "name": "HuanCheng",
    "options": { "baseURL": "https://api.hcnsec.cn/v1", "apiKey": "{env:HCNSEC_API_KEY}" },
    "models": { /* see Section 17.2 for full list */ }
  }
}
```

For the `ollama-cloud` provider (the current production setup's primary model), no explicit `provider` block is needed because it's registered in `auth.json` automatically. Set `main_model_id` to `ollama-cloud/minimax-m3`.

### 8.2 - Safety Patterns (MANDATORY for enterprise)

The current production `opencode.json` includes these critical safety patterns that MUST be preserved:

1. **Memory protection** (edit deny):

```json
"permission": {
  "edit": {
    "{{setup_root}}/.opencode/memory.jsonl": "deny"
  }
}
```

2. **Destructive bash demotion** (7 ops -> ask):

```json
"permission": {
  "bash": {
    "Remove-Item *": "ask",
    "Set-Content *": "ask",
    "Clear-Content *": "ask",
    "Move-Item *": "ask",
    "Copy-Item *": "ask",
    "docker *": "ask",
    "docker-compose *": "ask"
  }
}
```

3. **Tester agent hardening** (5 ops -> deny inside tester):

```json
"agent": {
  "tester": {
    "permission": {
      "bash": {
        "Remove-Item *": "deny",
        "Set-Content *": "deny",
        "Clear-Content *": "deny",
        "Move-Item *": "deny",
        "Copy-Item *": "deny"
      }
    }
  }
}
```

4. **Pinned superpowers** (specific SHA, not HEAD):

```
"superpowers@git+https://github.com/obra/superpowers.git#d884ae04edebef577e82ff7c4e143debd0bbec99"
```

5. **GitHub MCP with correct toolsets** (gists not gits, with extras):

```
"--toolsets", "repos,issues,pull_requests,actions,code_security,discussions,orgs,users,gists"
```

6. **Tool output size 65536** (not 8192):

```json
"tool_output": { "max_lines": 200, "max_bytes": 65536 }
```

See Section 18 for full rationale on each of these.

---

## 9. AGENTS.md Template

AGENTS.md is the operating manual loaded automatically by opencode on every session. The full production version is in Appendix A. Template below covers all required sections.

```markdown
# AGENTS.md

Instructions for opencode sessions working from this workspace.

## Role

You are a senior developer with a full engineering team at your disposal
(17 agents, ~117 skills, 16 MCP servers, LSP, persistent memory, 7 plugins).
Operate autonomously - use the right tool without being told. Plan non-trivial
tasks. Research when unsure. Verify before claiming success.

## Workspace

Workspace root: {{setup_root}}. Projects live in {{setup_root}}/Projects/.
Each project may have its own opencode.json for project-specific overrides.

## Models

- Primary agents (build, plan): {{main_model_id}}
- All subagents: {{small_model_id}}
- Optional 3rd provider: see opencode.json provider block

## MCP servers (16, auto-start)

| MCP                 | Type             | Purpose                                                       |
| ------------------- | ---------------- | ------------------------------------------------------------- |
| context7            | local            | Up-to-date library/framework docs                             |
| sequential-thinking | local            | Reflective multi-step reasoning                               |
| playwright          | local            | Browser automation, E2E testing                               |
| chrome-devtools     | local            | Live DevTools, network, performance traces                    |
| memory              | local            | Persistent knowledge graph                                    |
| tavily              | local            | Web search, crawl, deep research                              |
| fetch               | local            | Generic HTTP fetch (uvx mcp-server-fetch)                     |
| filesystem          | local            | Read/write outside workspace                                  |
| headroom            | local            | Compress large outputs                                        |
| supabase            | remote (OAuth)   | DB queries, schema, migrations, RLS                           |
| sentry              | remote (OAuth)   | Production error monitoring                                   |
| composio            | remote (OAuth)   | 500+ SaaS integrations                                        |
| grep                | remote           | Search 1M public GitHub repos                                 |
| github              | local (binary)   | GitHub API                                                    |
| vercel              | remote (OAuth)   | Deploy projects, logs, domains, env vars                      |
| vision-tool         | local (vendored) | Vision analysis via Gemini 3.5-flash-lite (500 RPD free tier) |

## Plugins (7, auto-load — 4 workspace + 3 global)

| Plugin                                                    | Purpose                                                                                           |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `superpowers@git+https://github.com/obra/superpowers.git` | 10 active process skills (workspace)                                                              |
| `opencode-notify`                                         | Desktop notifications (workspace)                                                                 |
| `envsitter-guard`                                         | Scans `.env` files, never exposes secrets (workspace)                                             |
| `@dietrichgebert/ponytail`                                | Lazy senior-dev mode — YAGNI / stdlib-first / shortest-diff (workspace)                           |
| `oh-my-opencode-slim`                                     | Multi-agent orchestration: orchestrator + 7 specialists (global, preset `opencode-go`, Kimi-K2.6) |
| `opencode-auto-vision`                                    | Auto-intercepts pasted images → vision-tool MCP (global)                                          |
| `opencode-eyesight`                                       | Fallback vision backend `ollama-cloud/minimax-m3` when vision-tool MCP unavailable (global)       |

## Core operating principles

### 1. At session start

- Retrieve past memories via memory MCP
- Check /context if workspace has heavy context history
- Treat AGENTS.md as the operating manual - auto-loaded every session

### 2. Before acting

- Check if a skill applies (~83 skills auto-trigger by intent)
- Check LSP for types, definitions, references before modifying code
- Fetch fresh docs via context7 before writing code with any framework

### 3. While acting

- Use the right tool for the job - priority: LSP > context7 > built-in > MCP > bash > subagents
- Save important decisions to memory MCP without being asked
- Compress large outputs with headroom_compress when context is heavy

### 4. When things go wrong

- Tool call fails or denied -> don't re-attempt the same call
- MCP server unavailable -> fall back to built-in tools
- OAuth MCP disconnected -> tell user to run `opencode mcp auth <name>`
- Context degradation signs -> run /context immediately

### 5. Before declaring done

Run /verify (lint -> typecheck -> test). Then check the 8-item definition of done.

## Agent roster

**Primary (2):** build (default), plan
**Custom subagents (7):** architect, reviewer, tester, addy-code-reviewer, addy-security-auditor, addy-test-engineer, addy-web-perf-auditor
**OMO-Slim agents (8):** orchestrator, oracle, council, librarian, explorer, designer, fixer, observer
Disabled: explore, general (replaced by OMO-Slim's explorer and orchestrator)

## Decision framework

| Situation                | Action                                               |
| ------------------------ | ---------------------------------------------------- |
| 1-file change            | build directly                                       |
| 2+ files or ambiguous    | plan first, then architect if structural             |
| Bug                      | debugging-and-error-recovery skill, then fixer agent |
| Understand code          | explorer agent                                       |
| Deep reasoning           | oracle agent                                         |
| Multi-perspective review | council agent                                        |
| Coordinate multi-agent   | orchestrator agent                                   |
| UI/frontend              | designer agent                                       |
| Monitor background       | observer agent                                       |
| Library docs             | context7 MCP or librarian agent                      |
| Current web info         | tavily MCP or fetch MCP                              |
| Review code              | reviewer or addy-code-reviewer                       |
| Run tests                | tester agent or /test command                        |
| Security check           | addy-security-auditor                                |
| Performance audit        | addy-web-perf-auditor                                |

## Quality standards - definition of done

1. Code implements the requested feature/fix completely
2. LSP diagnostics show no new errors
3. /verify passes (lint -> typecheck -> test)
4. Code reviewed by reviewer or addy-code-reviewer
5. No secrets, API keys, or .env values in code
6. No unnecessary dependencies added
7. Existing tests still pass
8. Changes follow existing project conventions

## Auto-use rules

| Tool                | When                                                  |
| ------------------- | ----------------------------------------------------- |
| context7            | Before writing code with any framework                |
| tavily / fetch      | Need current info / research                          |
| sequential-thinking | Complex multi-step problem                            |
| playwright          | Browser automation, UI testing                        |
| chrome-devtools     | Debug web apps, network/perf                          |
| memory              | Important decision -> save; session start -> retrieve |
| filesystem          | Read/write outside workspace                          |
| headroom            | Compress large outputs                                |
| sentry              | Debug production errors                               |
| composio            | Interact with SaaS apps                               |
| supabase            | Database queries, schema                              |
| grep                | Search 1M public GitHub repos                         |
| github              | GitHub operations                                     |
| vercel              | Deploy projects                                       |
| LSP                 | Before code changes                                   |
| Prettier            | Auto-formatting                                       |
| /verify             | Before declaring done                                 |
| /commit             | When user asks to commit                              |
| /test               | When user asks to test                                |
| /context            | Context heavy or degrading                            |

## Skill packs

Auto-discovered by opencode from opencode.json:skills.paths. Each skill's
SKILL.md carries its own description (the auto-trigger condition).

- addyosmani/agent-skills (24) - full dev lifecycle
- last30days (1) - research engine
- vercel-labs/agent-skills (9) - React/Vercel best practices
- vercel-deploy-claude-code-plugin (3) - deploy, logs, setup
- vercel-cli (1) - Vercel CLI usage
- anthropics/skills (17 installed, 6 active)
- superpowers (10 active, 4 folders lack SKILL.md)
- playwright-best-practices (1)
- User skills (11)
- Config skills (7)

## Enterprise Workflow (MANDATORY for all build tasks)

1. NEVER work on main or master. Always create a new branch (feat/, fix/, refactor/).
2. ALWAYS plan first (plan agent or planning-and-task-breakdown skill) unless 1-line fix.
3. ALWAYS run /verify (lint -> typecheck -> test) before declaring done.
4. ALWAYS dispatch reviewer subagent before declaring done.
5. ALWAYS create a GitHub PR after verification passes.
6. ALWAYS deploy to Vercel preview after PR.
7. ALWAYS report to user in plain English.
8. NEVER auto-merge PR. User merges manually.
9. NEVER auto-deploy to production. Preview only.
10. NEVER skip verification.

## Auto-Repo Creation

When starting a NEW project:

1. Use github MCP create_repository tool
2. Name: <project-name> (kebab-case)
3. Private: true
4. AutoInit: true (with README)
5. Clone to {{projects_root}}/<project-name>/
6. Report to user: "Created repo: <url>"

## Communication Style for Non-Coder Users

1. NEVER use technical jargon without explaining it
2. ALWAYS describe what was built in plain English (3-5 sentences)
3. ALWAYS provide URLs (PR, preview, repo) as clickable links
4. ALWAYS say "X tests passed, Y tests failed"
5. NEVER say "refactored the module" - say "improved how the code is organized"
6. NEVER say "fixed null pointer exception" - say "fixed a bug that could cause the app to crash"
7. ALWAYS offer to explain any technical detail if the user asks
8. NEVER assume the user knows git, GitHub, Vercel, or any tool

## Conventions

- Follow existing project conventions
- No code comments unless requested
- No commits/PRs unless explicitly asked
- Mimic surrounding code style

## Environment / gotchas

- Windows + PowerShell 5.1: chain with ; and if ($?), not &&
- Working directory is {{setup_root}}
- All required env vars: TAVILY_API_KEY, SENTRY_AUTH_TOKEN, GITHUB_PERSONAL_ACCESS_TOKEN, MEMORY_FILE_PATH
- Backup files in .opencode/backups/ - do not edit them
- hcnsec rate limits: no rateLimits config; avoid parallel subagent fan-out
- fetch MCP SSRF: never fetch localhost or internal IPs
- Cache maintenance: clean ~/.cache/opencode periodically
- Multi-session memory: only one opencode session at a time

## What's NOT configured (and why)

- Mobile native (iOS/Android): no Xcode/Gradle MCP
- Non-Supabase databases: no MySQL/Mongo/Postgres MCP
- AWS/GCP/Azure: no cloud MCPs
- Email providers: only via composio
- Sandboxed Linux: bash runs on host; use WSL or Docker

If the task requires one of these, dispatch the plan agent first to design the addition.
```

---

## 10. Custom Agent Files

Place these .md files in `{{setup_root}}/.opencode/agents/`. Each defines the prompt and behavior of a custom agent.

### 10.1 - architect.md

```markdown
---
description: Design, package boundaries, and tradeoff analysis. Dispatch when a task spans multiple files or structure is ambiguous.
mode: subagent
permission:
  edit: deny
  bash: ask
---

You are the architect. You design before implementation, not code itself.

Given a task, produce a concrete plan:

1. Identify the real entrypoints, package boundaries, and data flow by reading the minimum set of files that explains how the system is wired together. Prefer manifests, config, and wiring files over random leaf files.
2. Propose the smallest set of file changes that satisfies the task. Name the exact files to create/edit and what changes in each.
3. Call out tradeoffs, risks, and anything that needs a user decision. Do not hide ambiguity - surface it.
4. Note conventions the implementer must follow (naming, patterns, deps).

Do not write implementation code. Output the plan as a concise, reviewable list of changes. If the task is trivial, say so and recommend skipping design.
```

### 10.2 - reviewer.md

```markdown
---
description: Strict code review against project conventions. Dispatch before declaring a task done.
mode: subagent
permission:
  edit: deny
  bash: ask
---

You are a strict, fast reviewer. You do not implement; you verify.

Review the diff against:

1. Conventions - does the change match surrounding style, naming, patterns, and existing library usage? Flag anything that introduces a new dependency without justification, reinvents an existing utility, or breaks idioms.
2. Correctness - logic errors, unhandled edge cases, missing error paths, secrets logged, unsafe defaults.
3. Scope - does the diff stay within the requested change, or does it drag in unrelated edits?
4. Completeness - are there obvious missing tests or unupdated callers?

Output a prioritized list: blocking issues first, then nits. Cite file_path:line_number. If there are no blocking issues, say so explicitly. Do not rewrite code; describe what should change.
```

### 10.3 - tester.md

```markdown
---
description: Finds and runs the project's lint, typecheck, and test commands. Dispatch after implementation.
mode: subagent
permission:
  edit: deny
  bash:
    Remove-Item *: deny
    Set-Content *: deny
    Clear-Content *: deny
    Move-Item *: deny
    Copy-Item *: deny
---

You are the tester. Your job is verification, not implementation.

1. Detect the toolchain from manifests in the project root: package.json, pyproject.toml, Cargo.toml, go.mod, pom.xml, etc.
2. Read the manifest/scripts to find the exact lint, typecheck, and test commands the project defines. Do not assume defaults (no `npm test` unless that is what the project actually runs).
3. Run them in order: lint -> typecheck -> test. Use the project's own commands. If a step is absent, skip it and note that.
4. To run a single test, find the project's single-test invocation pattern (e.g. `pytest path::test`, `jest path -t "name"`, `cargo test --lib name`) from the config or existing examples before guessing.
5. Report results as a short pass/fail per step with the failing output trimmed to the relevant lines. If something needs a service or fixture the repo does not document, stop and report the missing prerequisite instead of guessing.

Never edit source to fix a failure - report it so the implementer can fix it.
```

### 10.4 - addy-code-reviewer.md

The 5-axis staff-engineer reviewer. See [upstream addyosmani/agent-skills/agents/code-reviewer.md](https://github.com/addyosmani/agent-skills/blob/main/agents/code-reviewer.md) for the full prompt (~107 lines). Evaluate every change across: Correctness, Readability, Architecture, Security, Performance. Output Critical / Important / Suggestions.

### 10.5 - addy-security-auditor.md

OWASP-based security auditor. See [upstream addyosmani/agent-skills/agents/security-auditor.md](https://github.com/addyosmani/agent-skills/blob/main/agents/security-auditor.md) for the full prompt (~123 lines). Covers: Input Handling, Auth/AuthZ, Data Protection, Infrastructure, Third-Party Integrations, AI/LLM Features.

### 10.6 - addy-test-engineer.md

QA engineer for test strategy. See [upstream addyosmani/agent-skills/agents/test-engineer.md](https://github.com/addyosmani/agent-skills/blob/main/agents/test-engineer.md) for the full prompt (~100 lines). Covers: Analyze Before Writing, Test at the Right Level, Prove-It Pattern for Bugs.

### 10.7 - addy-web-perf-auditor.md

Core Web Vitals auditor. See [upstream addyosmani/agent-skills/agents/web-performance-auditor.md](https://github.com/addyosmani/agent-skills/blob/main/agents/web-performance-auditor.md) for the full prompt (~189 lines). Covers LCP, INP, CLS, Loading, Rendering, Network.

---

## 11. Environment Variables

Set the following at User scope (Windows: System Properties -> Environment Variables; macOS/Linux: shell rc file):

| Variable                       | Required           | Purpose                       | Where to get it                         |
| ------------------------------ | ------------------ | ----------------------------- | --------------------------------------- |
| `OPENCODE_API_KEY`             | If using Zen       | Auth for opencode-zen         | https://opencode.ai/zen                 |
| `OPENAI_API_KEY`               | If using OpenAI    | Auth for openai               | https://platform.openai.com/api-keys    |
| `ANTHROPIC_API_KEY`            | If using Anthropic | Auth for anthropic            | https://console.anthropic.com/          |
| `GEMINI_API_KEY`               | If using Gemini    | Auth for google               | https://aistudio.google.com/apikey      |
| `HCNSEC_API_KEY`               | If using hcnsec    | Auth for HuanCheng models     | https://hcnsec.cn/dashboard             |
| `TAVILY_API_KEY`               | If enable_tavily   | Tavily web search             | https://app.tavily.com/                 |
| `SENTRY_AUTH_TOKEN`            | If enable_sentry   | Sentry MCP                    | https://sentry.io/settings/auth-tokens/ |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | If GitHub MCP      | PAT with repo scope           | https://github.com/settings/tokens      |
| `MEMORY_FILE_PATH`             | Always             | Absolute path to memory.jsonl | `{{setup_root}}/.opencode/memory.jsonl` |

Set with PowerShell (admin):

```powershell
[System.Environment]::SetEnvironmentVariable("HCNSEC_API_KEY", "sk-...", "User")
[System.Environment]::SetEnvironmentVariable("MEMORY_FILE_PATH", "F:\CD\Opencode\.opencode\memory.jsonl", "User")
```

Set with bash:

```bash
echo 'export HCNSEC_API_KEY="sk-..."' >> ~/.bashrc
echo 'export MEMORY_FILE_PATH="/path/to/.opencode/memory.jsonl"' >> ~/.bashrc
source ~/.bashrc
```

---

## 12. User Manual Steps (after setup)

After the agent says setup is complete, the user must do the following:

1. **Verify the env vars are set in a NEW terminal window.** Env vars set via `Set-EnvironmentVariable` (Windows) or `~/.bashrc` (Unix) only take effect in NEW processes.

2. **For OAuth MCPs (sentry, composio, supabase, vercel)**: run `opencode mcp auth <name>` for each. A browser window opens; complete the auth flow.

3. **Verify the memory wrapper**. Open `{{setup_root}}/.opencode/memory-mcp-wrapper.bat` in a text editor. It should contain:

   ```bat
   @echo off
   if "%MEMORY_FILE_PATH%"=="" set MEMORY_FILE_PATH={{setup_root}}\.opencode\memory.jsonl
   npx -y @modelcontextprotocol/server-memory
   ```

4. **Restart opencode**. This is mandatory - opencode reads config only at startup. Config changes do NOT take effect without a restart.

5. **Verify the `/models` menu** shows your chosen provider and the model list. For hcnsec: should see 20 models.

6. **Verify the `/ship` command** is available. Type `/ship` (with empty work). It should print the pipeline steps.

7. **Verify the enterprise-pipeline skill** is in `available_skills` list. Look for "Mandatory gated workflow for all build, create, implement, fix, or add tasks."

8. **Run a test task**:

   ```
   Ask opencode: "Add a hello() function to the smoke-test project"
   ```

   The build agent should:
   - Create a feature branch
   - Plan the work
   - Implement with TDD
   - Run /verify
   - Create a PR
   - Deploy a preview
   - Report in plain English

9. **Check backups**. After the first edit, verify `.opencode/backups/` has a timestamped `.pre-audit-2026-07-19.bak` file for every config that was modified.

---

## 13. Verification Checklist

The setup is complete when ALL of the following are true:

- [ ] `opencode --version` returns >= 1.0.0
- [ ] `python --version` returns >= 3.12
- [ ] `node --version` returns >= 20
- [ ] `git --version` returns >= 2.40
- [ ] `{{setup_root}}/opencode.json` exists and is valid JSON (`python -c "import json; json.load(open('{{setup_root}}/opencode.json'))"`)
- [ ] `{{setup_root}}/AGENTS.md` exists
- [ ] `{{setup_root}}/.opencode/memory.jsonl` is writable by current user
- [ ] `{{setup_root}}/.opencode/memory-mcp-wrapper.bat` exists and is correct
- [ ] `{{setup_root}}/.opencode/agents/` has 7 .md files
- [ ] `{{setup_root}}/.opencode/commands/` has at least `commit.md`, `context.md`, `test.md`, `verify.md`, `ship.md`
- [ ] `{{setup_root}}/.opencode/skills/enterprise-pipeline/SKILL.md` exists
- [ ] `{{setup_root}}/.opencode/skills/playwright-best-practices/SKILL.md` exists
- [ ] `{{setup_root}}/.opencode/agent-skills/` exists (cloned)
- [ ] `{{setup_root}}/.opencode/last30days-skill/` exists (cloned)
- [ ] `{{setup_root}}/.opencode/vercel-agent-skills/` exists (cloned)
- [ ] `{{setup_root}}/.opencode/anthropic-skills/` exists (cloned)
- [ ] `{{setup_root}}/.agents/skills/` has `deploy`, `logs`, `setup`, `vercel-cli` (from npx)
- [ ] `{{setup_root}}/skills-lock.json` has 4 entries (deploy, logs, setup, vercel-cli)
- [ ] All 16 MCPs are listed in `opencode.json: mcp`
- [ ] All 17 agents are listed in `opencode.json: agent`
- [ ] 7 plugins are listed across workspace (4) + global (3) configs
- [ ] opencode starts cleanly (no errors in startup)
- [ ] `/models` menu shows chosen provider + models
- [ ] `/ship` command appears in command list
- [ ] enterprise-pipeline skill appears in available_skills
- [ ] smoke-test project passes `tsc --noEmit` and `tsx --test`

---

## 14. Troubleshooting

| Symptom                             | Likely cause                  | Fix                                                                            |
| ----------------------------------- | ----------------------------- | ------------------------------------------------------------------------------ |
| opencode won't start                | Schema error in opencode.json | `python -c "import json; json.load(open('opencode.json'))"`                    |
| MCP shows "failed"                  | Auth missing                  | `opencode mcp auth <name>` for OAuth MCPs                                      |
| Models not in `/models`             | Provider config error         | Check `opencode.json: provider` block; ensure apiKey is set                    |
| Memory MCP writes lost              | MEMORY_FILE_PATH not set      | `setx MEMORY_FILE_PATH "{{setup_root}}\.opencode\memory.jsonl"` (new terminal) |
| `Remove-Item *` prompts             | Safety fix R2 applied         | Expected behavior; type 'y' to confirm                                         |
| `enterprise-pipeline` skill missing | Skill not in path             | Verify `.opencode/skills/enterprise-pipeline/SKILL.md` exists with frontmatter |
| `/ship` command not found           | Command not in path           | Verify `.opencode/commands/ship.md` exists with `description` frontmatter      |
| smoke-test tsc fails                | TypeScript not installed      | `cd Projects/smoke-test && npm install`                                        |
| hcnsec returns empty content        | Insufficient max_tokens       | All hcnsec models have `limit.output: 4096-16384` set in opencode.json         |
| Permission denied on file           | ACL inherited from domain     | Run `icacls <file> /inheritance:d` then `icacls <file> /grant SOHAM\user:(F)`  |

---

# PART II - CURRENT WORKSPACE STATE REFERENCE

## Appendix A: Full AGENTS.md Content

The complete current AGENTS.md (444 lines) is in `{{setup_root}}/AGENTS.md`. Summary of all sections:

| Section                                     | Lines       | Purpose                                                                                                                                           |
| ------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Role                                        | 1-3         | Self-description of the agent                                                                                                                     |
| Workspace                                   | 5-7         | Root + Projects layout                                                                                                                            |
| Models                                      | 9-37        | Primary, subagent, hcnsec 20-model list                                                                                                           |
| MCP servers                                 | 39-56       | 16 MCPs with types and purposes                                                                                                                   |
| Plugins                                     | 58-66       | 7 plugins (superpowers, opencode-notify, envsitter-guard, @dietrichgebert/ponytail, oh-my-opencode-slim, opencode-auto-vision, opencode-eyesight) |
| Core operating principles                   | 68-97       | 5 principle groups (session start, before acting, while acting, when wrong, before done)                                                          |
| Agent roster                                | 99-119      | 17 agents (2 primary, 7 custom, 8 OMO-Slim)                                                                                                       |
| Decision framework                          | 121-139     | 27-row matrix of situation -> action                                                                                                              |
| Quality standards (DoD)                     | 141-152     | 8-item done checklist                                                                                                                             |
| Auto-use rules                              | 154-174     | 18-row tool usage matrix                                                                                                                          |
| Skill packs                                 | 176-194     | 9 packs, ~83 unique skills                                                                                                                        |
| Workspace reference files                   | 196-198     | ENTERPRISE_OPENCODE_SETUP.md and skills-lock.json references                                                                                      |
| Skill precedence rule                       | 200-208     | Last-path-wins rule + known duplicates                                                                                                            |
| Per-project setup                           | 210-222     | 7-step new-project checklist                                                                                                                      |
| Project inheritance                         | 224-228     | Documents website/ silent inheritance                                                                                                             |
| What's NOT configured                       | 230-242     | 5 domains needing per-project additions                                                                                                           |
| **Enterprise Workflow (MANDATORY)**         | **244-278** | **10 rules for all build tasks**                                                                                                                  |
| **Auto-Repo Creation**                      | **280-286** | **6 steps for new GitHub repos**                                                                                                                  |
| **Communication Style for Non-Coder Users** | **288-299** | **8 rules for plain-English reports**                                                                                                             |
| Conventions                                 | 301-304     | No comments, no commits unless asked, mimic style                                                                                                 |
| Environment / gotchas                       | 306-330     | Windows, env vars, hcnsec limits, SSRF, cache, memory                                                                                             |
| Backup notes                                | 332         | Final pointer to .opencode/backups/                                                                                                               |

The full file is in `{{setup_root}}/AGENTS.md` and is the canonical operating manual loaded every session.

## Appendix B: Full Custom Agent Files

The 7 custom agent .md files in `{{setup_root}}/.opencode/agents/`:

| Agent                      | Source                                                    | Lines |
| -------------------------- | --------------------------------------------------------- | ----- |
| `architect.md`             | This template (Section 10.1)                              | 23    |
| `reviewer.md`              | This template (Section 10.2)                              | 24    |
| `tester.md`                | This template (Section 10.3)                              | 26    |
| `addy-code-reviewer.md`    | addyosmani/agent-skills/agents/code-reviewer.md           | 107   |
| `addy-security-auditor.md` | addyosmani/agent-skills/agents/security-auditor.md        | 123   |
| `addy-test-engineer.md`    | addyosmani/agent-skills/agents/test-engineer.md           | 100   |
| `addy-web-perf-auditor.md` | addyosmani/agent-skills/agents/web-performance-auditor.md | 189   |

See Section 10 for full text of the 3 local agents. The 4 addy-\* agents are upstream content; fetch them from `https://github.com/addyosmani/agent-skills/blob/main/agents/`.

---

## Section 16.1 — Config Inheritance Architecture (2026-07-22)

### Problem solved

OpenCode's project config walk-up stops at the **nearest `.git` worktree boundary** (per `ConfigPaths.files → fs.up({ stop: worktree })` in `packages/opencode/src/config/paths.ts`). Each child project under `Projects/<proj>/` has its own `.git` directory, so the walk-up never reaches the parent `F:\CD\Opencode\opencode.json`. Result: child sessions cannot see the parent's `provider`, `mcp`, `permission`, `lsp`, `formatter`, `agent` defaults, `plugin`, `skills.paths`, `tool_output`, or `compaction` blocks — and they cannot discover the parent's `.opencode/` directory (agents, commands, skills, plugins).

The user-visible symptom: the **HuanCheng (`hcnsec`)** provider does not appear in the model picker when running opencode inside `Projects/neodev-portal/` (or any other project with its own `.git`).

### Solution

Two persistent USER-scope Windows environment variables (set 2026-07-22 via `[System.Environment]::SetEnvironmentVariable(..., "User")`):

| Env var               | Value                          | Purpose                                                                                                                                                                                                                                                                     |
| --------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `OPENCODE_CONFIG`     | `F:\CD\Opencode\opencode.json` | Loads parent's full config into every session at precedence layer 3 (between global and project walk-up). Per project's own `opencode.json` still overrides via deep merge (layer 4).                                                                                       |
| `OPENCODE_CONFIG_DIR` | `F:\CD\Opencode\.opencode`     | Adds parent's `.opencode` to the discovered directories list (per `ConfigPaths.directories()` source code: `return unique([..., Flag.OPENCODE_CONFIG_DIR])`). Loaded LAST, so parent's agents/commands override project's same-named ones (intended enterprise uniformity). |

Plus one tiny config change in parent `opencode.json`: the `skills.paths` array was converted from relative paths (which resolve wrong in child cwd) to absolute paths.

### Precedence order (per official opencode docs)

```
1. Remote config (.well-known/opencode)              — organizational defaults
2. Global config (~/.config/opencode/opencode.json)  — user preferences
3. CUSTOM CONFIG (OPENCODE_CONFIG env var)           ← our addition: loads parent's config
4. Project config (opencode.json in project)          — child project's overrides win
5. .opencode directories (agents, commands, plugins)  ← OPENCODE_CONFIG_DIR adds parent
6. Inline config (OPENCODE_CONFIG_CONTENT env var)    — runtime overrides
7. Managed config (/Library/Application Support)      — admin-controlled
8. macOS MDM (.mobileconfig via MDM)                  — highest priority
```

### Result of the 2026-07-22 deployment

- ✅ ALL child projects (`neodev-portal/`, `smoke-test/`, `website/`) inherit parent `hcnsec` provider (20 models)
- ✅ ALL child projects inherit parent's 16 MCP servers (context7, playwright, sentry, github, vercel, composio, supabase, vision-tool, etc.)
- ✅ ALL child projects inherit parent's 82 bash permission rules
- ✅ ALL child projects inherit parent's 2 LSP servers (typescript-language-server, pyright-langserver)
- ✅ ALL child projects inherit parent's plugin set (superpowers, opencode-notify, envsitter-guard, @dietrichgebert/ponytail + global: oh-my-opencode-slim, opencode-auto-vision, opencode-eyesight)
- ✅ ALL child projects inherit parent's agent defaults + commands (including `/ship`, `/verify`, `/commit`, `/test`, `/context`)
- ✅ ALL child projects inherit parent's enterprise-pipeline skill + playwright-best-practices skill
- ✅ Per-project `opencode.json` overrides still win (smoke-test uses `opencode-go/glm-5.2` despite parent default `ollama-cloud/minimax-m3`)
- ✅ Per-project `.opencode/agents/` and `.opencode/commands/` overrides still apply — parent's loaded last and override by name (enterprise-uniformity behavior, by design)
- ✅ Per-project `AGENTS.md` overrides still apply (neodev-portal: no AGENTS.md → inherits parent's; smoke-test: has AGENTS.md → uses project's)

### How to add a global provider / MCP / agent / command

| You want to add...                                          | Edit...                                                   | Effect                                                                    |
| ----------------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------- |
| A new AI provider (auto-inherits to all child projects)     | `F:\CD\Opencode\opencode.json` → `provider` block         | All child projects get it on next session start                           |
| A new MCP server (auto-inherits to all child projects)      | `F:\CD\Opencode\opencode.json` → `mcp` block              | All child projects get it on next session start                           |
| A new permission rule (auto-inherits to all child projects) | `F:\CD\Opencode\opencode.json` → `permission` block       | All child projects get it                                                 |
| A new global agent (e.g. `code-reviewer`)                   | Create `F:\CD\Opencode\.opencode\agents\code-reviewer.md` | All child projects get it (overrides project's `code-reviewer` if exists) |
| A new global command (e.g. `/deploy`)                       | Create `F:\CD\Opencode\.opencode\commands\deploy.md`      | All child projects get it                                                 |
| A new global skill                                          | Create `F:\CD\Opencode\.opencode\skills\<name>\SKILL.md`  | Auto-discovered in all child projects via `OPENCODE_CONFIG_DIR`           |

### How to bypass inheritance for one session

```powershell
$env:OPENCODE_CONFIG=""
$env:OPENCODE_CONFIG_DIR=""
opencode
```

The session loads ONLY the global `~/.config/opencode/opencode.json` + project's walk-up config. No parent inheritance. Useful for testing isolation.

### How to verify (drift detection)

```powershell
powershell -ExecutionPolicy Bypass -File F:\CD\Opencode\.opencode\verify-inheritance.ps1
```

The script verifies env vars are correct, scans child configs for inheritance-breaking blocks, and reports green/yellow/red.

### Rollback procedure (full revert)

```powershell
# 1. Remove env vars (USER scope)
[System.Environment]::SetEnvironmentVariable("OPENCODE_CONFIG", $null, "User")
[System.Environment]::SetEnvironmentVariable("OPENCODE_CONFIG_DIR", $null, "User")

# 2. Restore parent opencode.json from backup
Copy-Item "F:\CD\Opencode\.opencode\backups\pre-config-inheritance-fix\opencode.json.bak" `
          "F:\CD\Opencode\opencode.json" -Force

# 3. Open new PowerShell session and confirm clean state via:
#    reg query "HKCU\Environment" /v OPENCODE_CONFIG /v OPENCODE_CONFIG_DIR
#    (both should return ERROR)
```

The backup folder `.opencode/backups/pre-config-inheritance-fix/` contains all pre-change configs (parent + 3 children + AGENTS.md + ENTERPRISE_OPENCODE_SETUP.md) for safe restore.

### Notes / caveats

- **Per-session MCP startup cost:** 16 MCPs spawning at session start adds ~3-5s before TUI is ready. Acceptable for enterprise uniformity.
- **OPENCODE_CONFIG_DIR loads LAST:** parent's `.opencode/agents/<X>.md` override project's same-named agent (e.g., parent's `architect.md` overrides `neodev-portal/.opencode/agents/architect.md`). For enterprise-uniformity this is desired. To preserve per-project agents, remove the file from parent.
- **Custom skill packs** (`.opencode/agent-skills/skills/*`, `.opencode/vercel-agent-skills/skills/*`, etc.) inherit via the absolute `skills.paths` array in parent `opencode.json`. Verified existing 2026-07-22.
- **Future opencode releases** may change inheritance semantics — re-verify against current docs at <https://opencode.ai/docs/config> before updating this section.

---

## Section 17 - Current Production State (2026-07-19)

This section documents the exact state of the `F:\CD\Opencode` workspace as of 2026-07-19 after the comprehensive audit and fix deployment. All numbers, paths, and configurations below are verified and current.

### 17.1 Workspace Inventory

| Path                                          | Purpose                    | Size / Status                                   |
| --------------------------------------------- | -------------------------- | ----------------------------------------------- |
| `F:\CD\Opencode\`                             | Workspace root             | -                                               |
| `F:\CD\Opencode\opencode.json`                | Main config                | 589 lines, 18.4 KB, valid JSON                  |
| `F:\CD\Opencode\AGENTS.md`                    | Operating manual           | 444 lines, 32.4 KB                              |
| `F:\CD\Opencode\.opencode\memory.jsonl`       | Active knowledge graph     | 9,213 bytes, 13 entities                        |
| `F:\CD\Opencode\.opencode\agents\`            | Agent prompt files         | 7 .md files                                     |
| `F:\CD\Opencode\.opencode\commands\`          | Custom commands            | 5 .md files                                     |
| `F:\CD\Opencode\.opencode\skills\`            | Workspace skills           | enterprise-pipeline + playwright-best-practices |
| `F:\CD\Opencode\.opencode\backups\`           | Timestamped config backups | 10 files (75.4 KB)                              |
| `F:\CD\Opencode\.opencode\github-mcp-server\` | Local GitHub MCP           | 24.4 MB binary                                  |
| `F:\CD\Opencode\Projects\neodev-portal\`      | Monorepo project           | 153B opencode.json (slim)                       |
| `F:\CD\Opencode\Projects\smoke-test\`         | Test project               | 272B opencode.json, 556B AGENTS.md              |
| `F:\CD\Opencode\Projects\website\`            | Web project                | 90B opencode.json                               |
| `F:\CD\Backup\Opencode-Setup\`                | Workspace backup           | 143 MB                                          |

### 17.2 Provider Configuration

**hcnsec** (configured in `F:\CD\Opencode\opencode.json: provider.hcnsec`):

- npm: `@ai-sdk/openai-compatible`
- name: `HuanCheng`
- baseURL: `https://api.hcnsec.cn/v1`
- apiKey: `{env:HCNSEC_API_KEY}` (51 chars)
- 20 models configured with explicit `limit.context` and `limit.output`

**hcnsec model list (20):**

| Model ID                   | Name                             | Context | Output | Speed                |
| -------------------------- | -------------------------------- | ------- | ------ | -------------------- |
| `auto`                     | Auto (smart routing)             | 128K    | 8K     | ~7s                  |
| `glm-4.7`                  | GLM 4.7                          | 128K    | 8K     | <1s                  |
| `glm-5.2`                  | GLM 5.2 (flagship, slow ~2-4min) | 128K    | 8K     | ~2-4min              |
| `Kimi-K2.6`                | Kimi K2.6 (Moonshot via hcnsec)  | 256K    | 16K    | 1.6-26s (median ~3s) |
| `MiniMax-M3`               | **MiniMax M3 (recommended)**     | 1M      | 16K    | 2-55s                |
| `MiniMax-M2.7`             | MiniMax M2.7                     | 200K    | 4K     | 1-2s                 |
| `DeepSeek-V4-Flash`        | DeepSeek V4 Flash (fast)         | 128K    | 8K     | 1.5-4s               |
| `DeepSeek-V4-Pro`          | DeepSeek V4 Pro                  | 128K    | 8K     | 1.2s                 |
| `Qwen3-Coder-Next-FP8`     | Qwen3 Coder Next FP8             | 128K    | 8K     | 1.4s                 |
| `Qwen3.5-397B-A17B`        | Qwen 3.5 397B                    | 128K    | 8K     | 1.9s                 |
| `Qwen3.6-35B-A3B`          | Qwen 3.6 35B                     | 128K    | 8K     | 1.8s                 |
| `kat-coder-pro-v2`         | Kat Coder Pro v2                 | 128K    | 8K     | 1.2s                 |
| `kat-coder-pro-v2.5`       | Kat Coder Pro v2.5               | 128K    | 8K     | 1.1s                 |
| `Spark-X2-Flash`           | Spark X2 Flash                   | 128K    | 4K     | 4-5s                 |
| `sensenova-6.7-flash-lite` | SenseNova 6.7 Flash Lite         | 128K    | 4K     | 1s                   |
| `step-3.5-flash`           | Step 3.5 Flash                   | 128K    | 4K     | 1-2s                 |
| `step-3.5-flash-2603`      | Step 3.5 Flash 2603              | 128K    | 4K     | 1.8s                 |
| `step-3.7-flash`           | Step 3.7 Flash                   | 128K    | 4K     | 1-2s                 |
| `step-router-v1`           | Step Router v1                   | 128K    | 4K     | 1s                   |
| `stepaudio-2.5-chat`       | StepAudio 2.5 Chat (voice)       | 32K     | 4K     | 0.8-1.3s             |

#### Additional providers (in auth.json)

| Provider       | Key prefix       | Length   | Documented?        | Used by                                         |
| -------------- | ---------------- | -------- | ------------------ | ----------------------------------------------- |
| `ollama-cloud` | `7f31eb...`      | 49 chars | Yes (in AGENTS.md) | All primary agents (build, plan)                |
| `opencode-zen` | (built-in)       | -        | Yes (in AGENTS.md) | All 15 subagents + default session model        |
| `opencode-go`  | `sk-W8GXu...`    | 67 chars | Yes (in AGENTS.md) | smoke-test project only                         |
| `nvidia`       | `nvapi-W1yyV...` | 70 chars | Yes (in AGENTS.md) | Project-specific routing (`<provider>/<model>`) |

Model assignments:

- `model` (session default): `opencode-zen/mimo-v2.5-free`
- `small_model`: `opencode-zen/mimo-v2.5-free`
- `build` agent: `ollama-cloud/minimax-m3`
- `plan` agent: `ollama-cloud/minimax-m3`
- All subagents (15): `hcnsec/Kimi-K2.6` (Moonshot Kimi K2.6 via hcnsec reseller, 256K context)
- `smoke-test` project override: `opencode-go/glm-5.2`

### 17.3 MCP Servers (16 total, all enabled)

#### Local MCPs (10)

| MCP                   | Command                                                                                                                | Env / Notes                                    |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| `context7`            | `npx -y @upstash/context7-mcp`                                                                                         | none                                           |
| `sequential-thinking` | `npx -y @modelcontextprotocol/server-sequential-thinking`                                                              | none                                           |
| `playwright`          | `npx -y @playwright/mcp`                                                                                               | `BROWSER=chromium`                             |
| `memory`              | `F:\CD\Opencode\.opencode\memory-mcp-wrapper.bat`                                                                      | Sets MEMORY_FILE_PATH then `npx server-memory` |
| `tavily`              | `npx -y tavily-mcp@latest`                                                                                             | `TAVILY_API_KEY` from env                      |
| `fetch`               | `uvx mcp-server-fetch`                                                                                                 | `PYTHONIOENCODING=utf-8`                       |
| `filesystem`          | `npx -y @modelcontextprotocol/server-filesystem F:\CD`                                                                 | Scoped to F:\CD                                |
| `chrome-devtools`     | `npx -y chrome-devtools-mcp@latest`                                                                                    | none                                           |
| `headroom`            | `headroom mcp serve`                                                                                                   | none                                           |
| `github`              | `github-mcp-server.exe stdio --toolsets repos,issues,pull_requests,actions,code_security,discussions,orgs,users,gists` | `GITHUB_PERSONAL_ACCESS_TOKEN` from env        |

#### Remote MCPs (5)

| MCP        | URL                                            | Auth                  |
| ---------- | ---------------------------------------------- | --------------------- |
| `sentry`   | `https://mcp.sentry.dev/mcp`                   | OAuth                 |
| `composio` | `https://connect.composio.dev/mcp`             | OAuth                 |
| `supabase` | `https://mcp.supabase.com/mcp?read_only=false` | OAuth (write-enabled) |
| `grep`     | `https://mcp.grep.app`                         | none                  |
| `vercel`   | `https://mcp.vercel.com`                       | OAuth                 |

### 17.4 Agents (17 total)

| Agent                   | Model                   | Mode     | Edit             | Bash           | Purpose                        |
| ----------------------- | ----------------------- | -------- | ---------------- | -------------- | ------------------------------ |
| `build`                 | ollama-cloud/minimax-m3 | primary  | (inherits allow) | (inherits ask) | Implementation (default)       |
| `plan`                  | ollama-cloud/minimax-m3 | primary  | (inherits allow) | (inherits ask) | Planning                       |
| `architect`             | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Design, boundaries, tradeoffs  |
| `reviewer`              | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Strict code review             |
| `tester`                | hcnsec/Kimi-K2.6        | subagent | deny             | **5 denylist** | Lint/typecheck/test (hardened) |
| `explorer`              | hcnsec/Kimi-K2.6        | subagent | deny             | allow          | Code understanding             |
| `oracle`                | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Deep reasoning                 |
| `librarian`             | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Library docs                   |
| `fixer`                 | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Bug fixing                     |
| `designer`              | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | UI/frontend design             |
| `observer`              | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Background tasks               |
| `council`               | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Multi-perspective review       |
| `orchestrator`          | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Multi-agent coordination       |
| `addy-code-reviewer`    | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | 5-axis staff review            |
| `addy-security-auditor` | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | OWASP security audit           |
| `addy-test-engineer`    | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Test strategy                  |
| `addy-web-perf-auditor` | hcnsec/Kimi-K2.6        | subagent | deny             | ask            | Core Web Vitals                |

**Tester hardening (post-fix R2+):** 5 denylist: Remove-Item, Set-Content, Clear-Content, Move-Item, Copy-Item all -> deny.

**Disabled agents (in global opencode.jsonc):** `explore` and `general` (replaced by OMO-Slim's `explorer` and `orchestrator`).

### 17.5 Plugins (7 total — 4 workspace + 3 global)

| Plugin                     | Source                                                                                 | Config Location             | Purpose                                             |
| -------------------------- | -------------------------------------------------------------------------------------- | --------------------------- | --------------------------------------------------- |
| `superpowers`              | `git+https://github.com/obra/superpowers.git#d884ae04edebef577e82ff7c4e143debd0bbec99` | workspace `opencode.json`   | 10 active process skills                            |
| `opencode-notify`          | npm                                                                                    | workspace `opencode.json`   | Desktop notifications                               |
| `envsitter-guard`          | npm                                                                                    | workspace `opencode.json`   | .env file security                                  |
| `@dietrichgebert/ponytail` | npm                                                                                    | workspace `opencode.json`   | Lazy senior-dev mode (YAGNI/stdlib-first)           |
| `oh-my-opencode-slim`      | npm                                                                                    | **global** `opencode.jsonc` | 8 OMO-Slim agents (preset `opencode-go`)            |
| `opencode-auto-vision`     | npm                                                                                    | **global** `opencode.jsonc` | Auto-intercepts pasted images → vision-tool MCP     |
| `opencode-eyesight`        | npm                                                                                    | **global** `opencode.jsonc` | Fallback vision backend (`ollama-cloud/minimax-m3`) |

**Superpowers pin:** `d884ae04edebef577e82ff7c4e143debd0bbec99` (latest main commit as of 2026-07-19).

**OMO-Slim config:** `C:\Users\user\.config\opencode\oh-my-opencode-slim.json`. Active preset: `opencode-go` (all 8 agents on `hcnsec/Kimi-K2.6`).

### 17.6 Skills (121 active, ~117 unique, 15 inert, 9 packs)

#### Skill paths in opencode.json (8 paths, last-path-wins precedence):

1. `.opencode/skills` (lowest priority)
2. `.opencode/agent-skills/skills` (addyosmani/agent-skills, 24)
3. `.opencode/last30days-skill/skills` (1)
4. `.opencode/vercel-agent-skills/skills` (9)
5. `.opencode/anthropic-skills/skills` (6 active + 11 inert)
6. `.agents/skills` (vercel-deploy + vercel-cli via npx, 4)
7. `C:/Users/user/.agents/skills` (User skills, 56)
8. `C:/Users/user/.config/opencode/skills` (Config skills, 19) - **highest priority**

**Known duplicate skills** (4): `deploy`, `logs`, `setup`, `vercel-cli` appear in both `.agents/skills` (path 6) AND `C:/Users/user/.agents/skills` (path 7). User-path versions shadow workspace versions per last-path-wins rule.

**Inert skills** (15, folders exist but no SKILL.md):

- anthropic (11): algorithmic-art, brand-guidelines, canvas-design, doc-coauthoring, docx, internal-comms, pdf, pptx, slack-gif-creator, theme-factory, xlsx
- superpowers (4): requesting-code-review, systematic-debugging, test-driven-development, writing-plans

#### Pack breakdown (~117 unique active skills)

| Pack                             | Path                                     | Count     |
| -------------------------------- | ---------------------------------------- | --------- |
| addyosmani/agent-skills          | `.opencode/agent-skills/skills/`         | 24        |
| last30days                       | `.opencode/last30days-skill/skills/`     | 1         |
| vercel-labs/agent-skills         | `.opencode/vercel-agent-skills/skills/`  | 9         |
| vercel-deploy-claude-code-plugin | `.agents/skills/` (via npx)              | 3         |
| vercel-cli                       | `.agents/skills/` (via npx)              | 1         |
| anthropics/skills                | `.opencode/anthropic-skills/skills/`     | 6 active  |
| superpowers                      | plugin cache                             | 10 active |
| playwright-best-practices        | `.opencode/skills/`                      | 1         |
| User skills                      | `C:/Users/user/.agents/skills/`          | 56        |
| Config skills                    | `C:/Users/user/.config/opencode/skills/` | 19        |

### 17.7 Commands (5 total)

| Command      | Location                        | Description                               |
| ------------ | ------------------------------- | ----------------------------------------- |
| `commit.md`  | `.opencode/commands/commit.md`  | Git commit workflow                       |
| `context.md` | `.opencode/commands/context.md` | Show context state                        |
| `test.md`    | `.opencode/commands/test.md`    | Run tests                                 |
| `verify.md`  | `.opencode/commands/verify.md`  | Lint -> typecheck -> test                 |
| `ship.md`    | `.opencode/commands/ship.md`    | **One-command shipping** (see Section 20) |

### 17.8 Permissions

#### Edit (deny list)

- `F:\CD\Opencode\opencode.json` - deny (prevents self-modification)
- `F:\CD\Opencode\AGENTS.md` - deny (prevents self-modification)
- `F:\CD\Opencode\.opencode\memory.jsonl` - deny (prevents memory corruption)

#### Bash (post-R2: 7 destructive ops demoted allow->ask)

| Command            | Pre-fix | Post-fix | Reason                        |
| ------------------ | ------- | -------- | ----------------------------- |
| `Remove-Item *`    | allow   | **ask**  | File deletion                 |
| `Set-Content *`    | allow   | **ask**  | File overwriting              |
| `Clear-Content *`  | allow   | **ask**  | File emptying                 |
| `Move-Item *`      | allow   | **ask**  | File renaming/moving          |
| `Copy-Item *`      | allow   | **ask**  | File overwriting destinations |
| `docker *`         | allow   | **ask**  | Container privilege           |
| `docker-compose *` | allow   | **ask**  | Multi-container privilege     |

#### Tester agent bash hardening (5 denylist inside tester)

| Command           | Pre-fix                   | Post-fix |
| ----------------- | ------------------------- | -------- |
| `Remove-Item *`   | allow (via `bash: allow`) | **deny** |
| `Set-Content *`   | allow (via `bash: allow`) | **deny** |
| `Clear-Content *` | allow (via `bash: allow`) | **deny** |
| `Move-Item *`     | allow (via `bash: allow`) | **deny** |
| `Copy-Item *`     | allow (via `bash: allow`) | **deny** |

### 17.9 Tool Output

| Field       | Value                | Reason                      |
| ----------- | -------------------- | --------------------------- |
| `max_lines` | 200                  | Standard threshold          |
| `max_bytes` | **65536** (was 8192) | Reduce truncation frequency |

### 17.10 Compaction

| Field        | Value | Reason                                                                   |
| ------------ | ----- | ------------------------------------------------------------------------ |
| `auto`       | false | Disabled to preserve full context; user triggers manually via `/context` |
| `tail_turns` | 15    | Buffer when manual compaction is triggered                               |

### 17.11 Projects (3 total)

| Project         | opencode.json                                 | AGENTS.md          | Inheritance           |
| --------------- | --------------------------------------------- | ------------------ | --------------------- |
| `neodev-portal` | 153B, 6 lines (just `instructions`)           | none (uses parent) | Full                  |
| `smoke-test`    | 272B, 9 lines (model override + instructions) | 556B               | Full + model override |
| `website`       | 90B, 4 lines (just `instructions`)            | none (uses parent) | Full                  |

### 17.12 Memory Knowledge Graph

`F:\CD\Opencode\.opencode\memory.jsonl` (9,213 bytes, 13 entries):

**Entities (10):**

- `smoke-test` (project)
- `email-validation-pattern` (convention)
- `enterprise-pipeline-validation-2026-06-25` (validation-run)
- `email-fixture-convention` (convention)
- `enterprise-setup-final-2026-06-25` (config-state)
- `audit-test-entity` (test)
- `post-restart-memory-verify` (test)
- `Site_LandoNorris` (AuditedWebsite)
- `Site_Ventriloc` (AuditedWebsite)
- `Site_Lusion` (AuditedWebsite)
- `enterprise-audit-2026-07-19` (audit-run, added today)

### 17.13 Backups

`F:\CD\Opencode\.opencode\backups\` (10 files, 75.4 KB total):

| File                                                   | Size     | Created    |
| ------------------------------------------------------ | -------- | ---------- |
| `AGENTS.md.pre-audit-2026-07-19.bak`                   | 25,732 B | 2026-07-19 |
| `opencode.json.pre-audit-2026-07-19.bak`               | 12,251 B | 2026-07-19 |
| `architect.md.pre-audit-2026-07-19.bak`                | 1,009 B  | 2026-07-19 |
| `reviewer.md.pre-audit-2026-07-19.bak`                 | 982 B    | 2026-07-19 |
| `tester.md.pre-audit-2026-07-19.bak`                   | 1,238 B  | 2026-07-19 |
| `addy-code-reviewer.md.pre-audit-2026-07-19.bak`       | 3,805 B  | 2026-07-19 |
| `addy-security-auditor.md.pre-audit-2026-07-19.bak`    | 5,245 B  | 2026-07-19 |
| `addy-test-engineer.md.pre-audit-2026-07-19.bak`       | 3,414 B  | 2026-07-19 |
| `addy-web-perf-auditor.md.pre-audit-2026-07-19.bak`    | 14,032 B | 2026-07-19 |
| `neodev-portal-opencode.json.pre-audit-2026-07-19.bak` | 9,485 B  | 2026-07-19 |

**External backup:** `F:\CD\Backup\Opencode-Setup\` (143 MB) - full workspace snapshot.

### 17.14 Enterprise Snapshot 2026-07-22

A complete enterprise snapshot of the workspace was created on 2026-07-22 after the config inheritance fix:

- **Archive:** `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-22.zip` (~50 MB compressed, ~88 MB uncompressed)
- **SHA-256:** `94526C8179C099D45C94E2DAFE635E231C78B0BDA2D0D42D9A2690C155747A4A`
- **Files:** 2,268 files in 1 backup archive
- **Restore guide:** `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-22\RESTORE-GUIDE.md`
- **Manifest:** `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-22\BACKUP_MANIFEST.md`
- **Env vars snapshot (redacted values):** `F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-22\env-vars.txt`
- **Backup contents:** all of F:\CD\Opencode, excluding `node_modules/` and other regenerable artifacts. Includes `Projects/*/.git/objects/` for full restoration without internet.
- **Excluded:** secrets (`auth.json` files), session diffs, old `.bak` files (consolidated into `.opencode/backups/pre-config-inheritance-fix` only)

**Verification:** SHA-256 hashes match between live workspace and archive extract (tested 2026-07-22). Resume from this snapshot to restore the full enterprise opencode setup on a new machine - see `RESTORE-GUIDE.md`.

---

## END OF DOCUMENT

When the receiving agent has completed Sections 2-11 and verified the agent-verifiable items in Section 13, it must print the Section 12 manual steps to the user and STOP. The user then handles the restart, provider auth, MCP OAuth, and final verification.

The receiving agent cannot restart opencode from inside opencode. The user must close and reopen opencode for config changes to take effect.

For anyone reading Sections 17-21 to understand the CURRENT production state of F:\CD\Opencode: all numbers, paths, and configurations are verified as of 2026-07-19. The setup is **enterprise-ready** for IT development across web/app/automation/AI agent/AI system domains.

> **Post-snapshot update (2026-07-27):** The 2026-07-19 snapshot above predates three changes that have since been applied to the live `F:\CD\Opencode` workspace and which are reflected in `AGENTS.md` but NOT in Sections 17-21 of this document:
>
> 1. **Subagent model migration** — all 15 subagents switched from `opencode-zen/mimo-v2.5-free` to `hcnsec/Kimi-K2.6`. The `model`/`small_model` session defaults remain `opencode-zen/mimo-v2.5-free`. See `POST-INSTALL-NOTE-2026-07-27-subagents.md` for the migration traceability record.
> 2. **vision-tool MCP added** — workspace now has 16 MCP servers (was 15). The new `vision-tool` MCP provides vision analysis via Gemini 3.5-flash-lite (500 RPD free tier). See `VISION-TOOL-MCP-DOCUMENTATION.md` for setup + operations guide.
> 3. **`google` provider added to auth.json** — auth.json now contains 4 providers (was 3): `opencode-go`, `ollama-cloud`, `nvidia`, `google`. The `opencode-zen` provider referenced in the snapshot was never in auth.json (it's a built-in); any mention of "4 provider entries including opencode-zen" in older text is wrong. The `google` provider backs `GEMINI_API_KEY` for the vision-tool MCP and `opencode-eyesight` fallback plugin.
> 4. **Plugins: 4 → 7** — workspace plugins went from 3 to 4 (added `@dietrichgebert/ponytail`); global plugins went from 1 to 3 (added `opencode-auto-vision`, `opencode-eyesight`). Total: 7.
> 5. **Skills: ~83 → ~117** — User skills path grew from 11 to 56; Config skills path grew from 7 to 19. Total active: 121 raw, ~117 unique after deduplication.
> 6. **Supabase MCP** — live URL is now `read_only=false` (write-enabled). Snapshot's `read_only=true` (read-only enforced) is outdated.
>
> Before re-deploying this workspace on a new machine using Sections 1-16 as a template, update the template guided by the live `AGENTS.md` and `opencode.json` rather than by the figures in Sections 17-21.
