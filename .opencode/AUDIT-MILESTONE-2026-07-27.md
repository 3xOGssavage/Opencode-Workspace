# Audit Milestone — 2026-07-27 Doc-Drift Fix

**Date:** 2026-07-28
**Commit:** `12ece08d552010700539803efeca524132caf357`
**Branch:** `main`
**Parent:** `31a3241`

## Scope

Align workspace documentation with live 2026-07-27 state after:

1. Subagent migration to `hcnsec/Kimi-K2.6`
2. `vision-tool` MCP addition (15 → 16 MCPs)
3. `google` provider addition to `auth.json` (3 → 4 providers)
4. `opencode-zen` provider removal from `auth.json`

## Files Changed (4, all first-ever tracked commits)

| File                                        | Lines | Key Corrections                                                                                                                                                                                                                                                                                                                                |
| ------------------------------------------- | ----- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AGENTS.md`                                 | 475   | Header counts 15/4/~70 → 16/7/~117; auth.json 5→4 providers; opencode-zen note; MCP table +vision-tool row; plugins split workspace(4)+global(3); skills 71→~117; env vars HCNSEC/GEMINI/OPENCODE_CONFIG(\_DIR) added as SET, OPENAI/OPENROUTER/ANTHROPIC/OPENCODE noted as NOT SET; supabase advice flipped to read_only=false; edit-deny 4→3 |
| `ENTERPRISE_OPENCODE_SETUP.md`              | 1757  | gemini recs updated to gemini-3.5-flash-lite; template supabase read_only true→false; template added vision-tool MCP + ponytail plugin rows; §17.3 MCPs 15→16; §17.5 plugins 4→7; §17.6 skills 93/~83 → 121/~117 + User 11→56, Config 7→19; L1746 Post-snapshot update (2026-07-27) footnote                                                   |
| `POST-INSTALL-NOTE-2026-07-27-subagents.md` | 115   | "5 provider keys" → "4 provider keys" + opencode-zen note; MCP count "15 (unchanged)" clarified as accurate-at-the-time with vision-tool-addition post-note                                                                                                                                                                                    |
| `.opencode/verify-inheritance.ps1`          | 180   | L169 success message "15 MCP servers" → "16 MCP servers"                                                                                                                                                                                                                                                                                       |

## Verification (2026-07-28, post-completion)

- `git status` clean for the 4 audited files
- `git show --name-only 12ece08` confirms ONLY the 4 audit files touched — no protected files (opencode.json, auth.json, oh-my-opencode-slim.json) modified
- Live cross-checks:
  - **auth.json providers**: opencode-go, ollama-cloud, nvidia, google (4) — matches AGENTS.md ✓
  - **opencode.json MCP count**: 16, vision-tool present — matches AGENTS.md ✓
  - **Skill SKILL.md counts**: 2+24+1+9+6+4+56+19 = 121 active files, ~117 unique (4 known dups in .agents/skills shadowing user-path) — matches AGENTS.md L312 "~117 unique / 121 active" ✓
- Committed markers grep-verified in all 4 files

## Out of Scope (intentionally NOT touched)

- `opencode.json` working-tree diff (608+/554-): pre-existing subagent-migration, edit-deny protected
- `auth.json`, `oh-my-opencode-slim.json`: edit-deny protected
- `.opencode/opencode-auto-vision.json` modified: pre-existing, out of audit scope
- Numerous untracked files under `.opencode/` (skill packs, skill installs, backups): not part of doc-drift audit

## Known Issue

- `memory` MCP server fails with `JSON Schema declares an unsupported dialect draft-07` on every tool call — server-level bug, not workable around. This file is the fallback record.

## Conclusion

Documentation-drift audit task COMPLETE. All 4 target docs aligned with live 2026-07-27 workspace state. Verified end-to-end.
