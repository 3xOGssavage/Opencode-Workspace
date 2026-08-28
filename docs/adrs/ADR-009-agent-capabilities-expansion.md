# ADR-009: Agent capabilities expansion (2026-08-29)

## Status

Accepted (pending PR merge)

## Context

A 20-repo candidate research pass (18 unique repos) was filtered through 30
adversarial critique cycles against the existing stack (17 MCPs, 26 agents,
~117 skills, browser-use stealth stack, memory MCP, 5-key tavily rotator).
Six items passed: they fill demonstrated gaps, are free, Windows/PS 5.1-safe,
actively maintained, and non-overlapping with existing capability.

## Decision

1. **graft MCP** (`@nanonets/graft`, local MCP via `npx -y`) - prebuilt
   code-graph for `Projects/neodev-portal` (948 nodes / 2,617 edges / 305
   files). Telemetry disabled (`graft telemetry disable` + `DO_NOT_TRACK=1`).
   `graft init` is forbidden (writes `.claude/`, edits AGENTS.md). A workspace
   graph was attempted and **dropped**: graft 0.15.0 has no PowerShell parser
   and this repo is PS/JSON/MD - its 5-node output was misleading. A
   `Projects/website` graph was also dropped: the folder contains assets only
   (PNG/YAML). Agents use AGENTS.md + codemap for workspace context.
2. **planning-with-files skill** (user lane, tier 7) - disk-persistent task
   plans surviving compaction/clear. Scripts: PS variants preferred; `.sh`
   variants via `F:\Git\bin\bash.exe`.
3. **humanizer skill** (user lane) - de-AI-ifies prose via 35 documented
   patterns.
4. **crawl4ai** (pip, CLI `crwl`) - free unlimited bulk web->markdown;
   complements the quota-limited tavily MCP. No MCP registration (context
   budget).
5. **obscura v0.2.1 stealth** (`%LOCALAPPDATA%\Programs\obscura`, SHA-256
   pinned `05872180...d597`) - lightweight stealth fetch tier between fetch
   MCP and full Camoufox sessions. Its 32-tool MCP deliberately not
   registered. Enforces robots.txt.
6. **agent-reach v1.5.0** (isolated venv `~\.agent-reach-venv`) - zero-config
   channels only: Web (Jina), YouTube (yt-dlp + `--js-runtimes node`), RSS,
   V2EX, Bilibili-basic. Login channels, gh, and Exa/mcporter deliberately
   excluded (github + tavily MCPs cover those). A thin authored skill
   (`.opencode/skills/agent-reach/SKILL.md`) documents usage - their
   auto-installer path was not used.

## Consequences

- All items inherit to all 9 `Projects/*` children via the existing env-var
  mechanism (2 new skills via tier-7 lane; graft MCP via parent config merge).
- `scripts/skills-snapshot.json` gains 2 entries (drives
  `install-user-skills.ps1` automatically - script itself unchanged).
- Rollback: revert this PR + `npm rm -g @nanonets/graft` + `pip uninstall
crawl4ai` + delete obscura dir + PATH entry + delete `~\.agent-reach-venv`
  - `~\.agent-reach` + 2 skill folders. Pre-change backup:
    `.opencode/backups/pre-agent-expansion-2026-08-29-0050/`.
- Known limitations: yt-dlp signature-solver warnings (metadata/subtitles
  unaffected); graft PS support pending upstream (revisit workspace graph);
  p-w-f session-catchup SQLite read limited on opencode (manual catchup
  fallback documented in its skill).
