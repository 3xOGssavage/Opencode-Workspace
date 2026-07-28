# AGENTS.md

Instructions for opencode sessions working from this workspace.

## Role

You are a **senior developer** with a full engineering team at your disposal
(17 agents, ~117 skills, 16 MCP servers, LSP, persistent memory, 7 plugins).
Operate autonomously — use the right tool without being told. Plan non-trivial
tasks. Research when unsure. Verify before claiming success.

## Workspace

Workspace root: `F:\CD\Opencode`. Projects live in `F:\CD\Opencode\Projects\`.
Each project may have its own `opencode.json` for project-specific overrides.

## Models

- **Primary agents** (build, plan): `ollama-cloud/minimax-m3`
- **All subagents** (15 custom + 8 OMO-Slim): `hcnsec/Kimi-K2.6` (256K context, Moonshot Kimi K2.6 via hcnsec reseller)
- **3rd provider (hcnsec.cn)**: 20 verified-working models at `https://api.hcnsec.cn/v1` (key in `HCNSEC_API_KEY` env var). Use as alternates via `/models` menu with format `hcnsec/<model-id>`.

### hcnsec.cn models (verified 2026-07-19)

All 20 models below respond correctly to `/v1/chat/completions` with `max_tokens >= 200`. Models marked "fast" respond in 1-5s; "slow" in 30-60s. Use `MiniMax-M3` as default flagship.

| Model ID                   | Notes                                 | Speed                |
| -------------------------- | ------------------------------------- | -------------------- |
| `auto`                     | Smart routing (agnes-2.0-flash)       | ~7s                  |
| `glm-4.7`                  | GLM 4.7                               | <1s                  |
| `glm-5.2`                  | Flagship, slow                        | ~2-4min              |
| `Kimi-K2.6`                | Moonshot Kimi K2.6 (256K context)     | 1.6-26s (median ~3s) |
| `MiniMax-M3`               | **Recommended flagship**              | 2-55s                |
| `MiniMax-M2.7`             | Older MiniMax                         | 1-2s                 |
| `DeepSeek-V4-Flash`        | Fast                                  | 1.5-4s               |
| `DeepSeek-V4-Pro`          | Pro variant (nvidia/nemotron-3-ultra) | 1.2s                 |
| `Qwen3-Coder-Next-FP8`     | Coder model                           | 1.4s                 |
| `Qwen3.5-397B-A17B`        | 397B MoE                              | 1.9s                 |
| `Qwen3.6-35B-A3B`          | 35B MoE                               | 1.8s                 |
| `kat-coder-pro-v2`         | Coder                                 | 1.2s                 |
| `kat-coder-pro-v2.5`       | Coder, needs max_tokens >= 100        | 1.1s                 |
| `Spark-X2-Flash`           | iFlytek Spark X2                      | 4-5s                 |
| `sensenova-6.7-flash-lite` | SenseNova, needs max_tokens >= 100    | 1s                   |
| `step-3.5-flash`           | Step 3.5 Flash                        | 1-2s                 |
| `step-3.5-flash-2603`      | Step 3.5 Flash 2603 build             | 1.8s                 |
| `step-3.7-flash`           | Step 3.7 Flash                        | 1-2s                 |
| `step-router-v1`           | Step router                           | 1s                   |
| `stepaudio-2.5-chat`       | Audio-capable chat model              | 0.8-1.3s             |

### hcnsec.cn models that DO NOT work (excluded from config)

| Model ID                 | Reason                                                              |
| ------------------------ | ------------------------------------------------------------------- |
| `glm-5.1`                | 503 Server Unavailable (server-side, persistent)                    |
| `sensenova-u1-fast`      | 404 Not Found at `/v1/chat/completions`                             |
| `step-image-edit-2`      | 404 — image generation model, no chat endpoint                      |
| `stepaudio-2.5-asr`      | 404 — speech-to-text, requires `/v1/audio/transcriptions`           |
| `stepaudio-2.5-realtime` | 404 — realtime audio, requires websocket endpoint                   |
| `stepaudio-2.5-tts`      | 404 — text-to-speech, requires `/v1/audio/speech` (400 Bad Request) |

### Why some "empty response" models need max_tokens >= 200

Several hcnsec models (`kat-coder-pro-v2.5`, `MiniMax-M2.7`, `sensenova-6.7-flash-lite`, `step-3.5-flash`, `step-3.7-flash`, `step-router-v1`, `step-3.5-flash-2603`) emit leading formatting tokens (newlines, whitespace) before the actual content. With `max_tokens <= 5`, they exhaust the budget on formatting and return empty content with `finish_reason: "length"`. The opencode.json config includes `limit.output` values (4096-16384) so opencode requests adequate output tokens automatically.

### Additional providers in auth.json

The `auth.json` file at `C:/Users/user/.local/share/opencode/auth.json` contains 4 provider entries. `ollama-cloud` is the primary provider (build/plan agents) and is documented in the provider block above. The remaining 3 are for subagents, project-specific routing, or alternate use:

| Provider      | Key prefix                  | Status | Used by                                                                                                           |
| ------------- | --------------------------- | ------ | ----------------------------------------------------------------------------------------------------------------- |
| `opencode-go` | `sk-W8GXu...` (67 chars)    | Active | `Projects/smoke-test/opencode.json` (`opencode-go/glm-5.2`); OMO-Slim preset                                      |
| `nvidia`      | `nvapi-W1yyV...` (70 chars) | Active | (project-specific routing via `<provider>/<model>`)                                                               |
| `google`      | `AQ.Ab8R...` (53 chars)     | Active | Gemini 3.5-flash-lite vision backend (vision-tool MCP, opencode-eyesight plugin, `GEMINI_API_KEY` env var mirror) |

These remain in `auth.json` for active project use. The `opencode-zen` provider referenced in earlier snapshots is **not** present in the current `auth.json` (it was removed during the 2026-07-27 subagent migration to `hcnsec/Kimi-K2.6`); any stale reference to it is outdated.

## MCP servers (16, auto-start)

| MCP                   | Type             | Purpose                                                                                                                                                                                                      |
| --------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `context7`            | local            | Up-to-date library/framework docs                                                                                                                                                                            |
| `sequential-thinking` | local            | Reflective multi-step reasoning                                                                                                                                                                              |
| `playwright`          | local            | Browser automation, E2E testing                                                                                                                                                                              |
| `chrome-devtools`     | local            | Live DevTools, network, performance traces                                                                                                                                                                   |
| `memory`              | local            | Persistent knowledge graph (`.opencode/memory.jsonl` — survives restarts; launched via wrapper `.opencode/memory-mcp-wrapper.bat` which sets `MEMORY_FILE_PATH` from system env if not already set)          |
| `tavily`              | local            | Web search, crawl, deep research                                                                                                                                                                             |
| `fetch`               | local            | Generic HTTP fetch (uvx mcp-server-fetch)                                                                                                                                                                    |
| `filesystem`          | local            | Read/write outside workspace (scoped to `F:\CD`)                                                                                                                                                             |
| `headroom`            | local            | Compress large outputs to save context                                                                                                                                                                       |
| `supabase`            | remote (OAuth)   | DB queries, schema, migrations, RLS                                                                                                                                                                          |
| `sentry`              | remote (OAuth)   | Production error monitoring                                                                                                                                                                                  |
| `composio`            | remote (OAuth)   | 500+ SaaS integrations                                                                                                                                                                                       |
| `grep`                | remote           | Search 1M public GitHub repos                                                                                                                                                                                |
| `github`              | local (binary)   | GitHub API: issues, PRs, repos, actions, code security                                                                                                                                                       |
| `vercel`              | remote (OAuth)   | Deploy projects, logs, domains, env vars, agent runs                                                                                                                                                         |
| `vision-tool`         | local (vendored) | Vision analysis via Gemini 3.5-flash-lite (500 RPD free tier). AppData config sets `DEFAULT_MODEL`. See `VISION-TOOL-MCP-DOCUMENTATION.md`. Pairs with `opencode-auto-vision` + `opencode-eyesight` plugins. |

OAuth MCPs need `opencode mcp auth <name>` before first use.

## Plugins (7 total: 4 workspace + 3 global, auto-load)

**Workspace plugins** (in `opencode.json`):

| Plugin                                                    | Purpose                                                                                           |
| --------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `superpowers@git+https://github.com/obra/superpowers.git` | 10 active process skills (brainstorming, TDD, debugging, planning, subagent-dev, verification...) |
| `opencode-notify`                                         | Desktop notifications when sessions complete or need input                                        |
| `envsitter-guard`                                         | Scans `.env` files, never exposes secrets, validates syntax                                       |
| `@dietrichgebert/ponytail`                                | Lazy senior-dev mode — enforces YAGNI / stdlib-first / shortest-diff across every response        |

**Global plugins** (in `C:/Users/user/.config/opencode/opencode.jsonc`):

| Plugin                 | Purpose                                                                                              |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| `oh-my-opencode-slim`  | Multi-agent orchestration: orchestrator + 7 specialists (preset `opencode-go`, all on Kimi-K2.6)     |
| `opencode-auto-vision` | Auto-intercepts pasted images, routes to vision-tool MCP, injects text description back into context |
| `opencode-eyesight`    | Fallback vision backend (`ollama-cloud/minimax-m3`) when vision-tool MCP unavailable                 |

## Core operating principles

These are the strategic rules. Tool descriptions and skill descriptions handle
the _what_ — these handle the _when_ and _why_.

### 1. At session start

- **Retrieve past memories** via `memory` MCP. Look for project conventions,
  decisions, and entity relationships stored from prior sessions.
- **Check `/context`** if the workspace has heavy context history.
- **Treat AGENTS.md as the operating manual** — it is auto-loaded every session
  via `opencode.json:instructions`. Do not duplicate its content in responses;
  reference it instead.

### 2. Before acting

- **Check if a skill applies** (~117 skills auto-trigger by intent). If one
  matches, load it via the `skill` tool and follow its workflow. Skills
  override default system behavior where they conflict.
- **Check LSP** for types, definitions, and references before modifying code.
  Don't guess what a function returns — look it up.
- **Fetch fresh docs** via `context7` before writing code with any framework.
  Frameworks change — training data is stale.

### 3. While acting

- **Use the right tool for the job** — priority order:
  1. **LSP** (most accurate for code intelligence)
  2. **context7** (most up-to-date for framework docs)
  3. **Built-in tools** (read, grep, glob, edit — fastest)
  4. **MCP tools** (for external data: supabase, sentry, composio, tavily)
  5. **bash** (flexible but risky)
  6. **Subagents** (for parallel work or specialized review)
- **Save important decisions** to `memory` MCP without being asked.
- **Compress large outputs** with `headroom_compress` when context is heavy.
- **Dispatch subagents** from the decision framework when they apply.

### 4. When things go wrong

- **Tool call fails or denied** → don't re-attempt the same call. Think about
  why and adjust your approach.
- **MCP server unavailable** → fall back to built-in tools (bash, grep, read).
- **LSP not responding** → use `read` + `grep` manually.
- **OAuth MCP (sentry, composio, supabase) disconnected** → tell the user to
  run `opencode mcp auth <name>` and continue with what you can.
- **Context degradation signs** (forgetting earlier instructions, repeating
  work) → run `/context` immediately.
- **Test fails** → read the error output carefully. Don't guess at fixes —
  understand the root cause first (use `debugging-and-error-recovery` skill).

### 5. Before declaring done

Run `/verify` (lint → typecheck → test). Then check the 8-item definition of
done (below). Never claim success without evidence.

## Agent roster

All subagents run on `hcnsec/Kimi-K2.6` (Moonshot Kimi K2.6 via hcnsec reseller, 256K context). Primary agents use
`ollama-cloud/minimax-m3`. Subagents consume Kimi quota — dispatch sequentially to avoid hcnsec rate limits; parallel fan-out risks 429s.

**Primary (2):**

- `build` — implementation. Default agent.
- `plan` — planning before coding.

**Custom subagents (7 in `.opencode/agent/`):**

- `architect` — design, boundaries, tradeoffs. Read-only.
- `reviewer` — strict review against conventions. Read-only.
- `tester` — runs lint/typecheck/test. Bash only.
- `addy-code-reviewer` — 5-axis staff-engineer review.
- `addy-security-auditor` — vulnerability detection, OWASP.
- `addy-test-engineer` — test strategy, coverage analysis.
- `addy-web-perf-auditor` — Core Web Vitals audit.

**OMO-Slim agents (8):**

- `orchestrator`, `oracle`, `council`, `librarian`, `explorer`, `designer`,
  `fixer`, `observer`.

Disabled: `explore`, `general` (replaced by OMO-Slim's `explorer` and `orchestrator`).

### Subagent dispatch architecture

Opencode's custom agents (architect, reviewer, tester, addy-\*, orchestrator,
oracle, council, librarian, explorer, designer, fixer, observer) are invoked
via opencode's **agent-switching mechanism** (e.g., switching the active agent
in the TUI), NOT via the `task` tool. The `task` tool's `subagent_type`
parameter accepts a different fixed enum (e.g., `general-purpose`,
`statusline-setup`) that does not include opencode's custom agents.

Practical implications:

- Inside an opencode session, custom agents are referenced in prose
  ("dispatch `architect`", "use `tester` for verification") and opencode routes
  to the right context. The model used is whatever the agent's `model`
  field specifies in `opencode.json`.
- For external automation, subagents are reachable via the opencode CLI/API,
  not via the `task` tool.

## Decision framework

| Situation                                 | Action                                                   |
| ----------------------------------------- | -------------------------------------------------------- |
| Task touches 1 file, obvious change       | `build` directly                                         |
| Task touches 2+ files or ambiguous        | `plan` first, then `architect` if structural             |
| Bug report or unexpected behavior         | `debugging-and-error-recovery` skill, then `fixer` agent |
| Need to understand existing code          | Dispatch `explorer` agent                                |
| Need deep reasoning on architecture       | Dispatch `oracle` agent                                  |
| Need multi-perspective review             | Dispatch `council` agent                                 |
| Need to coordinate multi-agent task       | Use `orchestrator` agent                                 |
| Need UI/frontend design work              | Dispatch `designer` agent                                |
| Need to monitor background tasks          | Dispatch `observer` agent                                |
| Need to look up library docs              | `context7` MCP or `librarian` agent                      |
| Need current web info                     | `tavily` MCP (search) or `fetch` MCP (single URL)        |
| Need to review code before merge          | `reviewer` or `addy-code-reviewer`                       |
| Need to run tests                         | `tester` agent or `/test` command                        |
| Need test strategy or coverage analysis   | `addy-test-engineer` agent                               |
| Need to check security issues             | `addy-security-auditor` agent                            |
| Need to audit web performance             | `addy-web-perf-auditor` agent                            |
| Need to research tools/approaches         | `last30days` skill                                       |
| Need to interact with SaaS apps           | `composio` MCP                                           |
| Need database queries / schema management | `supabase` MCP                                           |
| Need to debug production errors           | `sentry` MCP                                             |
| Need GitHub actions (PRs, issues, files)  | `github` MCP                                             |
| Need to search 1M GitHub repos for code   | `grep` MCP                                               |
| Need to build GitHub Actions workflows    | `agentic-workflows` skill (gh-aw)                        |
| Need GitHub stack workflow patterns       | `gh-stack` skill                                         |
| Need Vercel project management            | `vercel` MCP (deploy, logs, domains, env vars)           |
| Need to deploy to Vercel                  | `vercel` MCP (deploy_to_vercel) + `deploy` skill         |
| Need GitHub stack workflow patterns       | `gh-stack` skill                                         |
| Context getting heavy                     | `/context` command or `headroom_compress`                |
| Important decision made                   | Save to `memory` MCP                                     |

## Quality standards — definition of done

A task is NOT done until ALL of these are true:

1. Code implements the requested feature/fix completely.
2. LSP diagnostics show no new errors in changed files.
3. `/verify` passes (lint → typecheck → test, in that order).
4. Code reviewed by `reviewer` or `addy-code-reviewer` subagent — no blocking issues.
5. No secrets, API keys, or `.env` values in the code.
6. No unnecessary dependencies added.
7. Existing tests still pass.
8. Changes follow existing project conventions (naming, patterns, style).

If any step fails, fix it before declaring done. Never claim success without evidence.

## Auto-use rules (summary)

| Tool                  | When to use                                           | How                          |
| --------------------- | ----------------------------------------------------- | ---------------------------- |
| `context7`            | Before writing code with any framework                | MCP tool                     |
| `tavily` / `fetch`    | Need current info / research                          | MCP tool                     |
| `sequential-thinking` | Complex multi-step problem                            | MCP tool                     |
| `playwright`          | Browser automation, UI testing                        | MCP tool                     |
| `chrome-devtools`     | Debug web apps, inspect network/perf                  | MCP tool                     |
| `memory`              | Important decision → save; session start → retrieve   | MCP tool                     |
| `filesystem`          | Read/write files outside workspace                    | MCP tool                     |
| `headroom`            | Compress large outputs (`headroom_compress`)          | MCP tool                     |
| `sentry`              | Debug production errors                               | MCP tool                     |
| `composio`            | Interact with SaaS apps (Gmail, Slack, etc.)          | MCP tool                     |
| `supabase`            | Database queries, schema management                   | MCP tool                     |
| `grep`                | Search 1M public GitHub repos for real code patterns  | MCP tool                     |
| `github`              | GitHub actions: PRs, issues, files, branches, actions | MCP tool (local binary, PAT) |
| `vercel`              | Deploy projects, logs, domains, env vars, agent runs  | MCP tool (remote, OAuth)     |
| `vision-tool`         | Analyze pasted images via Gemini vision backend       | MCP tool (local, vendored)   |
| LSP                   | Before code changes (types, defs, refs)               | Built-in `lsp` tool          |
| Prettier              | Auto-formats TS/JS/CSS/HTML/JSON/MD/YAML              | Built-in formatter           |
| Black / ruff / mypy   | Python formatting + linting                           | Pre-approved in `bash`       |
| `/verify`             | Before declaring done                                 | Command                      |
| `/commit`             | When user asks to commit                              | Command                      |
| `/test`               | When user asks to test                                | Command                      |
| `/context`            | Context heavy or degrading                            | Command                      |

## Skill packs

Auto-discovered by opencode from `opencode.json:skills.paths` plus user/global
skill directories. Each skill's `SKILL.md` carries its own description which is
the auto-trigger condition — do not duplicate skill inventories in this file.

- **addyosmani/agent-skills** (24) — full dev lifecycle (`~/.opencode/agent-skills/skills`)
- **last30days** (1) — research engine (`~/.opencode/last30days-skill/skills`)
- **vercel-labs/agent-skills** (9) — React/Vercel best practices (`~/.opencode/vercel-agent-skills/skills`)
- **vercel-deploy-claude-code-plugin** (3) — deploy, logs, setup (`~/.opencode/.agents/skills/` via `npx skills add`)
- **vercel-cli** (1) — Vercel CLI usage (`~/.opencode/.agents/skills/` via `npx skills add`)
- **anthropics/skills** (17 installed, 6 active) — frontend-design, webapp-testing, mcp-builder, etc. (`~/.opencode/anthropic-skills/skills`)
- **superpowers** (10 active, 4 folders lack SKILL.md) — brainstorming → subagent dev → verification (loaded from plugin cache)
- **playwright-best-practices** (1) — Playwright patterns (`~/.opencode/skills/playwright-best-practices`)
- **User skills** (56) — design-md, enhance-prompt, shadcn-ui, stitch-\*, ui-ux-pro-max, pinokio, gepeto, react-components, remotion, find-skills, customize-opencode (`C:\Users\user\.agents\skills`)
- **Config skills** (19) — clonedeps, codemap, deepwork, oh-my-opencode-slim, reflect, simplify, worktrees, design-taste-frontend, gsap-\*, seo, transitions-\* (`C:\Users\user\.config\opencode\skills`)

**~117 unique skills / 121 active across 9 packs.** 11 anthropic folders lack SKILL.md (algorithmic-art, brand-guidelines, canvas-design, doc-coauthoring, docx, internal-comms, pdf, pptx, slack-gif-creator, theme-factory, xlsx) and 4 superpowers folders lack SKILL.md (requesting-code-review, systematic-debugging, test-driven-development, writing-plans) — these are inert.

## Workspace reference files

- **ENTERPRISE_OPENCODE_SETUP.md** (1737 lines) - interactive setup guide for re-deploying this workspace on another machine. Contains templates, questionnaires, and placeholders. Not loaded by opencode; reference only. Snapshot date 2026-07-19 — predates the 2026-07-27 subagent migration to `hcnsec/Kimi-K2.6`, vision-tool MCP addition, and `google` provider addition; figures in Sections 1-16 (the setup template) may need adjustment before re-deployment. Sections 17-21 reflect the 2026-07-19 production snapshot and are stale relative to the 2026-07-27 changes.
- **skills-lock.json** - integrity hashes for 4 Vercel skills installed via `npx skills add` (deploy, logs, setup, vercel-cli). Validated on skill load.

### Skill precedence rule

Per opencode docs: "later paths in `skills.paths` win on duplicate names." The order in `opencode.json: skills.paths` is:

1. `.opencode/skills` (lowest priority)
2. `.opencode/agent-skills/skills`
3. `.opencode/last30days-skill/skills`
4. `.opencode/vercel-agent-skills/skills`
5. `.opencode/anthropic-skills/skills`
6. `.agents/skills`
7. `C:/Users/user/.agents/skills`
8. `C:/Users/user/.config/opencode/skills` (highest priority - wins on duplicate names)

**Known duplicates:** `deploy`, `logs`, `setup`, `vercel-cli` appear in both `.agents/skills` (path 6) AND `C:/Users/user/.agents/skills` (path 7). The user-path versions (7) silently shadow the workspace versions (6).

## Per-project setup

When starting a new project under `F:\CD\Opencode\Projects\`:

1. Read the project's README/manifests first.
2. If it uses Supabase, scope the MCP to the project by adding
   `&project_ref=<project-id>` to the MCP URL in the project's `opencode.json`.
3. If it uses a different database (MySQL, MongoDB, etc.), add the appropriate MCP.
4. If it's an AI/ML project, use Supabase's pgvector for embeddings or add AI
   framework skills.
5. If it needs CI/CD, add GitHub/GitLab MCP.
6. Run `openspec init` for spec-driven development workflow.
7. Save project conventions to `memory` MCP.

### Project inheritance

**CORRECTED (2026-07-22):** Projects in `F:/CD/Opencode/Projects/` do NOT inherit parent `opencode.json` automatically — each project's `.git` directory stops opencode's config walk-up at the project boundary (opencode discovery stops at the nearest git worktree per `ConfigPaths.files → fs.up({ stop: worktree })`).

**Inheritance is enforced via two persistent USER env vars** (set 2026-07-22 via `[System.Environment]::SetEnvironmentVariable(..., "User")`):

- `OPENCODE_CONFIG = F:\CD\Opencode\opencode.json` — loads parent's full config (provider, mcp, permission, lsp, formatter, agent, plugin, skills.paths, tool_output, compaction) into every session at precedence layer 3 (between global and project walk-up). Per-project `opencode.json` overrides still win (layer 4, deep merge).
- `OPENCODE_CONFIG_DIR = F:\CD\Opencode\.opencode` — adds parent's `.opencode` directory to the scan list for agents, commands, modes, skills, plugins discovery. Loaded LAST, so parent's agents/commands override project's same-named ones (intended for enterprise uniformity).

**Result:** HuanCheng (hcnsec) provider with 20 models becomes visible in every child project session; 16 MCP servers; 82 bash permission rules; 3 edit deny rules; 2 LSP servers; parent agents (`/ship`, `/verify`, architect, reviewer, tester, addy-\*) all available everywhere.

**Verifying:** Run `powershell -ExecutionPolicy Bypass -File .opencode\verify-inheritance.ps1` from any project root.

**Bypassing inheritance for isolated work:** `$env:OPENCODE_CONFIG=""; $env:OPENCODE_CONFIG_DIR=""; opencode`

**Rollback:** see `ENTERPRISE_OPENCODE_SETUP.md` → "Config Inheritance Architecture → Rollback procedure".

> Future-proofing: opencode team may change inheritance semantics in future releases. Re-verify against current docs before updating.

## What's NOT configured (and why)

The enterprise setup covers web dev, app dev, automation, AI agents, and AI
systems. Some domains require per-project additions:

| Domain                          | What's missing                           | How to add                                                         |
| ------------------------------- | ---------------------------------------- | ------------------------------------------------------------------ |
| **Mobile native (iOS/Android)** | No Xcode/Gradle MCP, no Swift/Kotlin LSP | Install Xcode/Gradle CLI tools locally; add via `opencode mcp add` |
| **Non-Supabase databases**      | No MySQL/Mongo/Postgres MCP              | `opencode mcp add postgres <url>` etc.                             |
| **AWS/GCP/Azure**               | No cloud MCPs                            | `opencode mcp add` for each provider                               |
| **Email providers**             | Only via composio                        | `opencode mcp auth composio`                                       |
| **Sandboxed Linux execution**   | bash runs on Windows host                | Use WSL or Docker via existing bash perms                          |

If the task requires one of these, dispatch the `plan` agent first to design
the MCP addition, then add it via `opencode mcp add`.

## Enterprise Workflow (MANDATORY for all build tasks)

When the user asks to build, create, implement, fix, or add anything:

1. NEVER work on `main` or `master` branch. Always create a new branch:
   - `feat/<short-description>` for features
   - `fix/<short-description>` for bug fixes
   - `refactor/<short-description>` for refactoring

2. ALWAYS plan first (use `plan` agent or `planning-and-task-breakdown` skill) unless the task is a 1-line fix.

3. ALWAYS run `/verify` (lint -> typecheck -> test) before declaring done. If any step fails, auto-trigger `debugging-and-error-recovery` skill.

4. ALWAYS dispatch `reviewer` subagent before declaring done. Fix all blocking issues before reporting to user.

5. ALWAYS create a GitHub PR after verification passes. Use `github` MCP `create_pull_request` tool. Include:
   - What was built (plain English)
   - Test results (X/Y pass)
   - Files changed (count + names)
   - Breaking changes (if any)

6. ALWAYS deploy to Vercel preview after PR. Use `deploy-to-vercel` skill. Return the preview URL to user.

7. ALWAYS report to user in plain English:
   - What was built (3-5 sentences, no jargon)
   - PR URL (clickable)
   - Preview URL (clickable)
   - Test results
   - Any issues found and fixed

8. NEVER auto-merge PR. User merges manually after reviewing preview.

9. NEVER auto-deploy to production. Only preview.

10. NEVER skip verification, even if user says "just do it quickly". Verification is mandatory. If it fails, report the failure.

## Auto-Repo Creation

When starting a NEW project (no existing repo):

1. Use `github` MCP `create_repository` tool
2. Name: `<project-name>` (kebab-case)
3. Private: true (enterprise default)
4. AutoInit: true (with README)
5. Clone to `F:/CD/Opencode/Projects/<project-name>/`
6. Report to user: "Created repo: <url>"

## Communication Style for Non-Coder Users

1. NEVER use technical jargon without explaining it.
2. ALWAYS describe what was built in plain English (3-5 sentences).
3. ALWAYS provide URLs (PR, preview, repo) as clickable links.
4. ALWAYS say "X tests passed, Y tests failed" not "test suite status: PASS".
5. NEVER say "refactored the module" - say "improved how the code is organized so it's easier to maintain."
6. NEVER say "fixed null pointer exception" - say "fixed a bug that could cause the app to crash when user data was missing."
7. ALWAYS offer to explain any technical detail if the user asks.
8. NEVER assume the user knows git, GitHub, Vercel, or any tool.

## Conventions

- Follow existing project conventions; do not introduce new dependencies without need.
- No code comments unless requested.
- No commits/PRs unless explicitly asked.
- Mimic surrounding code style.

## Environment / gotchas

- **Windows + PowerShell 5.1**: chain with `;` and `if ($?)`, not `&&`. Quote
  paths containing spaces. Native PowerShell cmdlets (`Get-ChildItem`,
  `Test-Path`, `Get-Content`) are preferred for reliability; `ls`, `cat`, `head`,
  `tail` also work via the bash permission allowlist.
- Working directory is `F:\CD\Opencode`. External access allowed under `F:\CD\**`.
- `TAVILY_API_KEY` is set as a User env var.
- `SENTRY_AUTH_TOKEN` is set as a User env var.
- `GITHUB_PERSONAL_ACCESS_TOKEN` is set as a User env var.
- `MEMORY_FILE_PATH` is set as a User env var (via `setx`) pointing to `.opencode\memory.jsonl` so the memory MCP server stores entities in the workspace.
- `HCNSEC_API_KEY` (51 chars, `sk-...`) is set as a User env var — the hcnsec reseller key backing all `hcnsec/*` models in `/models`.
- `GEMINI_API_KEY` (53 chars, `AQ.Ab8R...`) is set as a User env var — backs the `google` provider in `auth.json`, used by the `vision-tool` MCP (Gemini 3.5-flash-lite vision backend) and the `opencode-eyesight` fallback plugin.
- `OPENCODE_CONFIG = F:\CD\Opencode\opencode.json` and `OPENCODE_CONFIG_DIR = F:\CD\Opencode\.opencode` are set as User env vars (see "Project inheritance" below) — these propagate the parent workspace's config into every child-project session.
- `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, `ANTHROPIC_API_KEY`, `OPENCODE_API_KEY` are **not** set as User env vars. Either set them per-project or add via `setx` if you want OpenAI / OpenRouter / Anthropic / opencode-cloud providers visible globally.
- Headroom proxy starts on-demand when you run `opencode` (PowerShell profile
  wrapper), stops when opencode exits.
- Composio auth: run `opencode mcp auth composio` to connect SaaS apps.
- Sentry: remote OAuth via `https://mcp.sentry.dev/mcp`.
- Supabase: write-enabled (`read_only=false` is the current live URL in `opencode.json:mcp.supabase.url`). To re-enable read-only mode, set `read_only=true` in the MCP URL.
- **hcnsec rate limits**: hcnsec has no `rateLimits` config (opencode feature request #32423). opencode uses retry with exponential backoff only. Avoid parallel subagent fan-out on hcnsec models - sequential dispatch is safer.
- **fetch MCP SSRF**: the `fetch` MCP (`uvx mcp-server-fetch`) accepts any URL with no allowlist. Never fetch `localhost`, `127.0.0.1`, `169.254.169.254` (AWS metadata), or internal network IPs. Risk: SSRF exploitation if user-supplied URLs flow to fetch MCP.
- **Cache maintenance**: the opencode cache at `C:/Users/user/.cache/opencode` may grow to 700+ MB. Periodically clean after opencode restart: `Remove-Item "$env:USERPROFILE/.cache/opencode" -Recurse -Force` (requires user confirmation since destructive bash is now `ask`).
- **Multi-session memory**: the memory MCP (`@modelcontextprotocol/server-memory`) has no file locking. Running two opencode sessions simultaneously may corrupt `memory.jsonl`. Run one session at a time.
- **auth.json security**: stores 4 provider API keys in plaintext. File ACL restricted to `SOHAM/user`, `SYSTEM`, `Administrators` only (as of 2026-07-19 audit). Do not commit auth.json to git.
- **Tool output truncation**: when tool output exceeds `max_bytes` (65536) or `max_lines` (200), truncated content is stored at `C:/Users/user/.local/share/opencode/tool-output/` (outside workspace read-tool reach). Use bash `Get-Content` to read truncated files.
- Backup files for `AGENTS.md` and `opencode.json` (from setup iteration) live in
  `.opencode/backups/` — do not edit them; they are historical snapshots.
