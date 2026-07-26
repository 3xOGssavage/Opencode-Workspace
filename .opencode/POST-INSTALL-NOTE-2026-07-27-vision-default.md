# Post-Install Note — 2026-07-27 (Vision Default Model)

## Event: Set Gemini 3.5 Flash Lite as vision-tool default

**Date:** 2026-07-27
**Scope:** Single config file outside the repo. No code changes.
**Risk profile:** Zero — uses vision_proxy.py's built-in DEFAULT_MODEL mechanism.

---

## What was added

A new config file at `C:\Users\user\AppData\Roaming\vision-tool\config.json`
containing exactly:

```json
{ "DEFAULT_MODEL": "gemini/gemini-3.5-flash-lite" }
```

vision_proxy.py's `load_config()` (line 289 in vision_proxy.py) reads this
file via `_find_config()` (line 261) — `CONFIG_PATH` (AppData) takes
precedence over `CONFIG_PATH_LOCAL` (script dir). The `DEFAULT_MODEL`
key, when set, is inserted at position 0 (★ priority) in the strategy
list by `_insert_model_strategies()` (line 2350), causing Gemini 3.5
Flash Lite to be the FIRST backend attempted on every `analyze_image`/`analyze`
call that does NOT pass an explicit `model` parameter.

## Why Gemini 3.5 Flash Lite

| Model                 | RPD (free tier) | Notes                         |
| --------------------- | --------------: | ----------------------------- |
| gemini-2.5-flash      |              20 | Current fallback, limited RPD |
| gemini-3.5-flash-lite |             500 | New model released 2026-07-21 |

Gemini 3.5 Flash Lite is natively multimodal (image+video+text+audio+PDF),
$0.0014 per sample, 2.7s average inference, 1M token context, and designed
specifically for high-throughput low-cost agentic workflows. 500 RPD is a
25x improvement over the previous fallback (2.5 Flash at 20 RPD).

## Fallback behavior

If Gemini 3.5 Flash Lite fails (quota exhaustion, API outage, rate limit),
vision_proxy.py falls back to its hardcoded strategy list (line 2213-2235)
which contains Gemini 2.5 Flash, 3 Flash Preview, 2.0 Flash, etc. This
graceful degradation was verified live:

```
KEYS: 3 backends available
  ★ Gemini: gemini/gemini-3.5-flash-lite: OK    ← position 0, priority
  ☆ Gemini 2.5 Flash: OK                         ← position 1, fallback 1
FALLBACK: 1 backends in parallel
  ☆ Gemini 3 Flash Preview: OK                   ← position 2, fallback 2
```

## What was NOT touched

- `vision_proxy.py` — no code patches. The hardcoded strategy list still
  lacks `gemini-3.5-flash-lite` (only 6 older models). This is intentional
  — the DEFAULT_MODEL mechanism bypasses the hardcoded list entirely via
  `_insert_model_strategies`. Patching the list would be redundant (YAGNI)
  and would be lost on `git pull`.
- `vision_mcp_server.py` — no changes (readline() patch from prior commit
  preserved).
- `opencode.json` — MCP env var passthrough (`{env:GEMINI_API_KEY}`) unchanged.
- `opencode-auto-vision.json` — plugin config unchanged (plugin has no `model`
  field in its schema).
- `backend_memory.json` — unchanged. 3.5 Flash Lite will be added to backend
  memory automatically on first successful call.
- `AGENTS.md` — no doc updates needed (vision-tool is not documented in
  AGENTS.md beyond the MCP table).

## Verification

Direct call to `vision_proxy.analyze()` with no `model` parameter, with
GEMINI_API_KEY set to the new 53-char key (prefix `AQ.Ab8`):

```
SEARCH: File exists at C:\Users\user\AppData\Local\Temp\opencode\vision-test.png
KEYS: Google Gemini ✓
KEYS: 3 backends available
  ★ Gemini: gemini/gemini-3.5-flash-lite: OK
=== RESULT ===
[vision-test.png]
Bright solid red color background.
```

Gemini 3.5 Flash Lite responded correctly on the first attempt, no fallback
needed.

## Environment note

The MCP `env` block in `opencode.json` uses `{env:GEMINI_API_KEY}` which
reads from the SESSION environment at opencode launch time. After updating
the User-level GEMINI_API_KEY env var (from 39-char `AIzaSy...` to 53-char
`AQ.Ab8...`), opencode must be **restarted** from a fresh PowerShell window
for the MCP subprocess to inherit the new env. Run `opencode mcp list` after
restart to confirm vision-tool is still connected.

## Rollback procedure

To revert this change:

```powershell
Remove-Item "C:\Users\user\AppData\Roaming\vision-tool\config.json"
```

vision_proxy.py will fall back to its hardcoded strategy list (Gemini 2.5
Flash first, 20 RPD). The rollback placeholder file at
`.opencode/backups/config.original.json` (empty `{}`) documents the
pre-change state.

## Files in this commit

| File                                                       | Change                                   |
| ---------------------------------------------------------- | ---------------------------------------- |
| `.opencode/POST-INSTALL-NOTE-2026-07-27-vision-default.md` | This file (new)                          |
| `.opencode/backups/config.original.json`                   | Empty `{}` placeholder (rollback marker) |

**Not touched:** Any source code, opencode.json, AGENTS.md, auth.json,
provider config, agents, MCP servers, plugins, or skills.

## Related prior work (same branch: feat/enable-vision-analysis)

- Commit `a566b05`: vision-tool MCP setup, readline() patch, timeout bump,
  opencode.json MCP entry, plugin installs, old Gemini key swap.
- This commit: PREVIOUSLY mentioned config.json — actually lives outside
  the repo in AppData (user-data, not tool-data). Documented here for
  traceability.
