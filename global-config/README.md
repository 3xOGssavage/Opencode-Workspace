# global-config

These 5 files are a snapshot of `~/.config/opencode/` (the opencode GLOBAL config directory, outside the workspace). They activate the OMO-Slim plugin (8 agents), the auto-vision + eyesight plugins, and disable the legacy `explore` + `general` agents.

## Files

- `opencode.jsonc` (313 B) — plugin list, agent disables, `lsp: true`
- `oh-my-opencode-slim.json` (2.1 KB) — 8 OMO-Slim agents, all on `hcnsec/Kimi-K2.6`, preset `opencode-go`
- `tui.json` (48 B) — `{"plugin": ["oh-my-opencode-slim"]}`
- `package.json` (65 B) — `@opencode-ai/plugin` dep
- `package-lock.json` (13.4 KB) — reproducible install lockfile

## Restore on a new machine

1. Copy these 5 files to `%USERPROFILE%\.config\opencode\` (create the directory if missing).
2. Run `npm install` in that directory (uses `package-lock.json` for reproducible versions).
3. Alternatively, run `scripts/setup-env-vars.ps1` from the workspace root — it does both steps automatically.

## Secrets audit

All 5 files were scanned for API keys (`sk-`, `ghp_`, `nvapi-`, `AQ.`, `xox`, `AKIA` patterns) on 2026-08-02 — zero hits. Safe to commit.
