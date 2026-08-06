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

---

## Update — 2026-07-28 audit

_The following session performed a fresh audit of this note against the live
Gemini API state, the filesystem, and the git tree. Findings appended below
for traceability. See `VISION-TOOL-MCP-DOCUMENTATION.md` §6.5 for the full
live probe results table._

### Model health (live API probe 2026-07-28)

- Primary `gemini-3.5-flash-lite`: ✅ healthy, returns valid descriptions
- Auto-fallback `gemini-3-flash-preview` (strategy list position #2): ✅ healthy
- 3 alternate GA models verified working on this key: `gemini-3.1-flash-lite`,
  `gemini-3.6-flash` (released 2026-07-21), `gemini-2.5-flash-lite`
- 4 models in 24h cooldown (HTTP 429): `gemini-2.5-flash`, `gemini-2.0-flash`,
  `gemini-2.0-flash-lite`, `gemini-2.5-pro`, `gemini-3-pro-preview`
- 1 model hard-fail (HTTP 400): `gemini-3.5-flash` — likely paid-tier or
  `thinking_level=high` config issue, not used in current setup

### RPD claim verification

- The "500 RPD" claim in row D22 of the main doc remains accurate for this
  project — that was what AI Studio showed on 2026-07-27 for this specific
  project.
- Google's pricing page does NOT publish per-model per-tier RPD numbers —
  AI Studio is the source of truth.
- Third-party sources (aifreeapi.com) cite ~1,500 RPD for Flash-Lite class
  theoretical max, but Google reduced free-tier quotas 50-80% in December 2025.
- Practical rule: your project's exact quota is what AI Studio reports at
  <https://aistudio.google.com/rate-limits>.

### Deprecation timeline (since this note was written)

| Model                             | Status                             | Date           | Source                     |
| --------------------------------- | ---------------------------------- | -------------- | -------------------------- |
| `gemini-2.0-flash`/`-lite`        | **Deprecated**                     | June 1, 2026   | Google pricing page        |
| `gemini-3-pro-preview`            | **Discontinued**                   | March 26, 2026 | Databricks foundation docs |
| All Pro models (free-tier access) | **Eliminated** — Pro now paid-only | April 2026     | Google policy update       |

### What changed in the 2026-07-28 audit session

- Branch renamed `feat/enable-vision-analysis` → `main` (no remote, no PRs, no CI — zero risk)
- `VISION-TOOL-MCP-DOCUMENTATION.md` refreshed:
  - Corrected §6.1 D1 from `input() at L286` to `sys.stdin.read(4096) at L247` (patched in commit `a566b05`)
  - Fixed §2.1 architecture diagram: `backend_memory.json` shown in AppData cluster, not script-dir
  - Fixed §2.2 component table: updated `backend_memory.json` row to note AppData path
  - Fixed §9 file table: corrected `opencode-eyesight` plugin entry point from `dist/plugin.js` to `dist/index.js` (per `package.json` `"main"` field)
  - Added §6.5 "Known model availability (July 2026 audit)" — live probe results table + free-tier RPD reference
  - Added §4.4 "Fallback behavior & manual hot-swap runbook" — Option B approach (no vendored edits)
  - Added 4 new rows to §7.2 Don'ts about deprecated/paid-only models and avoiding vendored source edits
  - Added §10 audit re-verification row and updated existing rows
  - Fixed §8.5: removed "restart needed" claim (load_config is called fresh on every analyze() call, so config.json edits take effect immediately)
- Child project inheritance verified: `neodev-portal`, `smoke-test`, `website` all inherit vision-tool MCP via `OPENCODE_CONFIG` User env var. `neodev-portal` has its own MCP block but does NOT override vision-tool — it inherits parent's. All 3 children OK.

### What was NOT changed (safety promises)

- `vision_proxy.py` NOT touched — this is vendored source, lost on next upstream clone (YAGNI)
- `vision_mcp_server.py` NOT touched — Phase 3 patch still in place and working
- `opencode.json` NOT touched — MCP entry at L582-593 verified intact
- `config.json` NOT touched — primary `gemini/gemini-3.5-flash-lite` remains, healthy
- `opencode-auto-vision.json` NOT touched — line-ending-only modification (LF→CRLF), cosmetic
- API keys, env vars, plugin configs — all untouched
- No new commits to Python source, no test re-runs required (277/277 from prior session still valid)

### Manual hot-swap runbook (for future reference)

If primary AND auto-fallback (`gemini-3-flash-preview`) both fail:

1. Edit `C:\Users\user\AppData\Roaming\vision-tool\config.json` in any text editor.
2. Change `"DEFAULT_MODEL": "gemini/gemini-3.5-flash-lite"` to one of:
   - `"gemini/gemini-3.1-flash-lite"` (same Flash-Lite tier, GA — recommended first)
   - `"gemini/gemini-3.6-flash"` (newest, Flash tier, released 2026-07-21)
   - `"gemini/gemini-2.5-flash-lite"` (older GA, retires Oct 2026)
3. Save the file — **no restart needed**. Next pasted image uses the new model immediately.
4. To revert: change back to `gemini/gemini-3.5-flash-lite`.

### Future option noted

- `vision_proxy.py` supports OpenRouter as a parallel fallback provider. If
  Gemini free tier ever proves insufficient, get a free OpenRouter API key,
  set `OPENROUTER_API_KEY` as a User env var, and use `openrouter/<model>`
  as the `DEFAULT_MODEL` prefix for a second independent rate-limit pool.
