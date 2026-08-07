# Vision-Tool MCP — Architecture, Setup & Operations Guide

**Project:** opencode + vision-tool MCP integration
**Author:** opencode build agent (ponytail mode)
**Last verified:** 2026-07-28
**Branch:** `main` (renamed from `feat/enable-vision-analysis` on 2026-07-28)
**Commits:** `a566b05` → `f82ef56` → `6f8ce78`

---

## 1. Purpose

opencode ships with text-only models — none of them can natively "see" an image. This integration gives every text-only model in the workspace the ability to analyze pasted images by routing those images to a dedicated **vision-capable** model (Gemini family) through a local MCP server called `vision-tool`.

**Outcome, in plain English:** When a user pastes an image into opencode, a plugin (`opencode-auto-vision`) silently intercepts the paste, sends the image to the vision-tool MCP, gets back a text description, and injects that description back into the conversation as context. The text model then answers as if it had seen the image itself.

---

## 2. Architecture

### 2.1 Components (top-down)

```
+-------------------+     paste event      +-------------------------+
|   opencode TUI    | -------------------->|  opencode-auto-vision   |
|   (text model)    |                      |  plugin (Node.js)       |
+-------------------+                      +-----------+-------------+
                                                       |
                                            calls MCP tool: analyze_image
                                                       v
                                           +--------------------------+
                                           |  vision-tool MCP server  |
                                           |  (Python, stdio)         |
                                           |  vision_mcp_server.py    |
                                           +-----------+--------------+
                                                       |
                                           lazy-imports vision_proxy
                                                       v
                                           +--------------------------+      reads      +----------------------------+
                                           |  vision_proxy.py         | <-------------- |  AppData\vision-tool\      |
                                           |  strategy list (6 models)|                 |  config.json               |
                                           |  load_config()           |                 |  backend_memory.json       |
                                           +-----------+--------------+                 +----------------------------+
                                                       |
                                           HTTP POST to Gemini API
                                                       v
                                           +--------------------------+
                                           |  Google AI Studio        |
                                           |  (Gemini API)            |
                                           +--------------------------+
```

> **Note:** `config.json` and `backend_memory.json` live in `C:\Users\user\AppData\Roaming\vision-tool\` (Windows AppData Roaming), NOT in the script directory. `load_config()` (vision_proxy.py:289) reads AppData first, script-dir fallback. `backend_memory.json` is written to AppData to persist cooldown state across MCP restarts.

### 2.2 Component responsibilities

| Component                     | Language | Responsibility                                                                                                                                                                                        |
| ----------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| opencode TUI                  | Go       | Hosts the conversation; receives pasted images; loads plugins                                                                                                                                         |
| `opencode-auto-vision` plugin | Node.js  | Detects pasted images; calls MCP tool `analyze_image`; injects description back into the conversation; cleans up temp files after 48h                                                                 |
| `opencode-eyesight` plugin    | Node.js  | Fallback plugin (uses `ollama-cloud/minimax-m3`) for vision-capable models — not exercised in this workflow because text models can't see images natively                                             |
| `vision_mcp_server.py`        | Python   | MCP server (stdio JSON-RPC). Exposes 2 tools: `analyze_image`, `analyze_video`. On Windows, promotes missing env vars from User-scope registry before importing `vision_proxy`                        |
| `vision_proxy.py`             | Python   | Vision model router. Hardcoded "strategy list" of 6 Gemini models (4 currently rate-limited/deprecated — see §6.4). Reads `DEFAULT_MODEL` from config. Tracks per-backend 24h cooldown after failures |
| `backend_memory.json`         | JSON     | Persistent record of which backends are in cooldown, with failure timestamps. Lives at `C:\Users\user\AppData\Roaming\vision-tool\backend_memory.json` (AppData, NOT script dir)                      |
| `config.json` (AppData)       | JSON     | User-level config: `{"DEFAULT_MODEL": "gemini/gemini-3.5-flash-lite"}`                                                                                                                                |
| `aggressive_test.py`          | Python   | 277-test self-check suite that exercises every vision-tool internal (config, strategy list, providers, fallback, MCP protocol, etc.)                                                                  |

### 2.3 The two-plugin split (why two plugins?)

Two plugins are installed globally in `C:\Users\user\.config\opencode\opencode.jsonc`:

- **`opencode-auto-vision`** — routes pasted images to the **vision-tool MCP** for analysis. Used by text-only models (the common case).
- **`opencode-eyesight`** — a fallback that uses `ollama-cloud/minimax-m3` directly. Not exercised in this workflow because text models can't see images natively.

The two coexist because opencode's plugin system is capability-based and the eyesight plugin only activates for models that declare vision capability — text models silently skip it.

---

## 3. How the pipeline works (step-by-step)

1. **User pastes an image** into the opencode TUI.
2. The `opencode-auto-vision` plugin's paste interceptor fires. It saves the image to a temp file and constructs a system-prompt instruction telling the model: _"Use the `analyze_image` tool with the path above to analyze it before answering."_
3. opencode sees the tool-call request in the conversation and dispatches it to the `analyze_image` MCP tool (the tool is registered because the vision-tool MCP server is listed in `opencode.json`).
4. opencode spawns the vision-tool MCP server as a Python subprocess (stdio transport) and sends the standard MCP handshake:
   - `initialize` request
   - `notifications/initialized` notification
   - `tools/call` request with method `analyze_image` and args `{"path": "<image-path>"}`
5. `vision_mcp_server.py` receives the request. **Before importing vision_proxy**, its `_promote_user_env()` helper reads HKCU\Environment and promotes any missing/empty provider env vars into `os.environ`.
6. `vision_mcp_server.py` lazy-imports `vision_proxy` and calls `vision_proxy.analyze(path)`.
7. `vision_proxy.analyze()`:
   - Reads `DEFAULT_MODEL` from config (gemini/gemini-3.5-flash-lite).
   - Calls `get_providers_for_model("gemini/gemini-3.5-flash-lite")` — returns `["gemini"]`.
   - Constructs the Gemini API endpoint URL.
   - POSTs the image bytes + prompt to the Gemini API with the `GEMINI_API_KEY` bearer.
   - If the call fails (HTTP 4xx/5xx), records the backend in `backend_memory.json` with a 24h cooldown timestamp, and retries with the next strategy-list entry.
   - Returns the text description.
8. `vision_mcp_server.py` wraps the description as `[<filename>]\n<description>` and returns it as the MCP `tools/call` result.
9. opencode injects the tool result back into the conversation as a tool-result message.
10. The text model now "knows" what the image depicts and answers accordingly.

---

## 4. When it works / When it doesn't

### 4.1 When it works

- User is in opencode TUI and **pastes an image** (not a file path; an actual paste).
- `opencode-auto-vision` plugin is loaded.
- `vision-tool` MCP server entry is present in `opencode.json` `mcp` block.
- `GEMINI_API_KEY` is set (either in process env, or in HKCU\Environment, or in the MCP config's `env` block).
- At least one Gemini backend has not exhausted its rate limit / cooldown.
- Network access to `generativelanguage.googleapis.com` is available.

### 4.2 When it does NOT work

- User pastes a file path or attachment differently (plugin only intercepts image _pastes_).
- `GEMINI_API_KEY` is missing/empty AND User-scope registry value is missing AND MCP `env` block has no `GEMINI_API_KEY`. Triple-missing — `vision_proxy` will fail with HTTP 401/403.
- All Gemini backends are in 24h cooldown (after repeated failures).
- The image is in an unsupported format or unreadable.
- The image is on a path the MCP subprocess can't access (e.g., permission denied).
- The MCP server can't start: Python not on PATH, missing `vision_mcp_server.py`, etc.
- Network is offline.

### 4.3 Edge cases observed in testing

| Symptom                                  | Cause                                                                                                                                                           |
| ---------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP 403                                 | Old-style Google API key (39-char `AIzaSy...`) is expired or never had Generative Language API access. Fix: generate new key in AI Studio, set as User env var. |
| HTTP 400                                 | Malformed JWT-format key (we saw this with a 36-char dummy starting `AIzaSy...`). Google rejects malformed creds with 400, **not** 403.                         |
| MCP "tool not found"                     | MCP server crashed on startup — check Python syntax + dependencies.                                                                                             |
| Plugin doesn't intercept paste           | Plugin not loaded; check `opencode.jsonc` global config.                                                                                                        |
| Spawns MCP but returns empty description | Backend in cooldown; rate limit hit; check `backend_memory.json`.                                                                                               |

### 4.4 Fallback behavior & manual hot-swap runbook (Option B — no vendored edits)

#### Automatic fallback (already wired, no config needed)

When `DEFAULT_MODEL` (`gemini/gemini-3.5-flash-lite`) fails (HTTP 4xx/5xx/timeout), `vision_proxy.analyze()` (vision_proxy.py:2429-2533) falls through the hardcoded strategy list at vision_proxy.py:2210-2207. The execution order on failure:

1. **Primary:** `gemini-3.5-flash-lite` (DEFAULT_MODEL via AppData config) — inserted at position 0 by `_insert_model_strategies` (vision_proxy.py:2378)
2. **Auto-fallback #1:** `gemini-2.5-flash` (strategy list pos 1) — currently HTTP 429 in this project's 24h cooldown
3. **Auto-fallback #2:** `gemini-3-flash-preview` (pos 2) — ✅ **healthy, this is the actual de-facto fallback today**
4. **Auto-fallback #3-6:** `gemini-2.0-flash`, `gemini-2.0-flash-lite` (deprecated June 2026), `gemini-2.5-pro` (paid-only April 2026), `gemini-3-pro-preview` (discontinued March 2026) — all currently HTTP 429, will not recover on this free-tier key
5. **Non-Gemini fallbacks:** OpenAI gpt-4o-mini, Anthropic Claude Sonnet, Together Kimi-K2.5, DeepInfra Qwen2.5-VL-72B, Cohere, xAI Grok, Azure AI — all require corresponding API keys which are NOT configured on this workspace.

> **In practice:** the only automatic fallback that actually fires today is `gemini-3-flash-preview`. The other 5 Gemini entries are in cooldown or paid-only. The non-Gemini entries are skipped (no API keys configured).

#### Manual hot-swap runbook (if primary AND auto-fallback both fail)

If `gemini-3.5-flash-lite` AND `gemini-3-flash-preview` both fail, edit `C:\Users\user\AppData\Roaming\vision-tool\config.json` and set `DEFAULT_MODEL` to one of the verified-working alternatives (probed 2026-07-28):

```json
{ "DEFAULT_MODEL": "gemini/gemini-3.1-flash-lite" }
```

**Verified-working alternatives on this key (probe date 2026-07-28):**

| Model                   | Tier       | RPD class      | Why pick it                                            |
| ----------------------- | ---------- | -------------- | ------------------------------------------------------ |
| `gemini-3.1-flash-lite` | Flash-Lite | ~500-1,500 RPD | Same tier as primary. GA. Recommended first hot-swap.  |
| `gemini-3.6-flash`      | Flash      | ~500-1,500 RPD | Newest (released 2026-07-21). Slightly higher quality. |
| `gemini-2.5-flash-lite` | Flash-Lite | ~500-1,500 RPD | Older GA, retires Oct 2026. Solid fallback.            |

**Procedure:**

1. Open `C:\Users\user\AppData\Roaming\vision-tool\config.json` in any text editor.
2. Change `"DEFAULT_MODEL": "gemini/gemini-3.5-flash-lite"` to `"DEFAULT_MODEL": "gemini/gemini-3.1-flash-lite"` (or another alternative above).
3. Save the file.
4. **No restart needed** — `vision_proxy.load_config()` is called fresh on every `analyze()` call (vision_proxy.py:2425), so the next pasted image will use the new model immediately.
5. To revert: change back to `gemini/gemini-3.5-flash-lite`.

> **Why not edit the strategy list itself?** The strategy list at vision_proxy.py:2210-2207 is vendored source (cloned from upstream `farhanic017/vision-tool`). Editing it would be lost on the next `git clone` of the upstream repo. The manual hot-swap via AppData config is the ponytail answer — survives upstream refresh, takes effect immediately, and requires no code edits. (§7.2 Don'ts reinforces this.)

#### Future option: OpenRouter parallel fallback

`vision_proxy.py` has a `call_openrouter()` function (referenced in `get_providers_for_model()` at the `openrouter/` prefix). If you ever need a parallel fallback path beyond Gemini's free tier (e.g., all 500 RPD consumed in a single busy session):

1. Get a free OpenRouter API key at <https://openrouter.ai/>
2. Set `OPENROUTER_API_KEY` as a User-scope env var:
   ```powershell
   [System.Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY","sk-or-<key>","User")
   ```
3. OpenRouter has free-tier Gemini proxy endpoints that mirror the same models — giving you a second rate-limit pool independent of Google's free-tier quota.
4. To use OpenRouter as the primary endpoint, set `DEFAULT_MODEL` to `openrouter/<model-name>` (provider prefix routing handled by `get_providers_for_model()` at vision_proxy.py:1980).

---

## 5. Steps we took (chronological)

### 5.1 Phase 1 — Initial discovery (`a566b05`)

- Identified the gap: opencode text models can't see pasted images. Need an external vision service.
- Surveyed options: OpenAI vision, Gemini, local Ollama models. Gemini wins on free tier + rate limits (500 RPD on Flash Lite vs OpenAI's paid-only vision).
- Cloned `https://github.com/farhanic017/vision-tool.git` to `.opencode/tools/vision-tool/`.
- Read source: `vision_mcp_server.py` is the MCP entry; `vision_proxy.py` does the routing; `aggressive_test.py` has 277 tests.
- **Discovered:** `vision_mcp_server.py` called `sys.stdin.read(4096)` at startup (originally line 247, later shifted to line 353 after Phase 3 patch insertions) which blocks the Windows stdio JSON-RPC handshake — opencode sees the 4096-byte read as malformed JSON. Patched in commit `a566b05` to use `sys.stdin.readline()` instead.
- **Discovered:** Default per-call timeout was 60s and total timeout 120s — too long for opencode's MCP timeout. Bumped to `PER_CALL_TIMEOUT=30`, `TOTAL_TIMEOUT=60`, `FAST_TIMEOUT=30` in `vision_proxy.py` L2502-2504.
- Installed `opencode-auto-vision` + `opencode-eyesight` plugins globally via `~/.config/opencode/opencode.jsonc`.
- Added the MCP entry to `opencode.json` L582-593 with env passthrough `{env:GEMINI_API_KEY}`.
- **Discovery:** `opencode-auto-vision` plugin's schema has no `model` field. It only routes to the MCP `analyze_image` tool. Cannot specify vision model from plugin config — must be configured at the vision-tool layer.
- **Discovery:** `opencode-eyesight` only fires for vision-capable models. Text models silently skip it.

### 5.2 Phase 2 — Default model + rate-limit upgrade (`f82ef56`)

- Original `GEMINI_API_KEY` was 39 chars, `AIzaSy...` prefix — kept getting HTTP 403.
- **Discovery:** Google AI Studio dashboard shows per-model rate limits:
  - `gemini-3.5-flash-lite`: 500 RPD (highest free tier!)
  - `gemini-3.1-flash-lite`: 500 RPD
  - `gemini-2.5-flash`: 20 RPD
  - `gemini-3.5-flash`, `gemini-3-flash`, `gemini-3.6-flash`: 20 RPD each
  - `gemini-2.5-pro`: very low
- Generated new API key in AI Studio — 53 chars, prefix `AQ.Ab8RN6Lw...`. Set as User-scope env var via `[System.Environment]::SetEnvironmentVariable(..., "User")`.
- **Discovery:** Windows does NOT auto-propagate HKCU\Environment changes to existing or child processes. The running opencode process keeps the old key. This becomes a Phase 3 problem.
- Created `C:\Users\user\AppData\Roaming\vision-tool\config.json` with `{"DEFAULT_MODEL": "gemini/gemini-3.5-flash-lite"}` — pulls the 500-RPD model as primary.
- **Discovery:** `vision_proxy.load_config()` reads AppData (Roaming) FIRST, then falls back to script-dir `CONFIG_PATH_LOCAL`. AppData wins.
- **Discovery:** `vision_proxy.get_providers_for_model()` requires `provider/model` slash format. Bare `gemini-3.5-flash-lite` returns `[]`. Must be `gemini/gemini-3.5-flash-lite`.
- **Discovery:** `vision_proxy._insert_model_strategies()` inserts DEFAULT_MODEL at position 0 with a `★` prefix — so it's tried first, ahead of the hardcoded 6-model strategy list.
- **Discovery:** `vision_proxy.py` L2213-2235 has a **hardcoded** strategy list of only 6 older Gemini models. `gemini-3.5-flash-lite` is NOT in that list (the script version predates the model release). No problem — DEFAULT_MODEL via AppData config overrides the strategy order anyway.
- Created `docs/operational-history/POST-INSTALL-NOTE-2026-07-27-vision-default.md` (129-line traceability doc).
- Created `.opencode/backups/config.original.json` (empty `{}` rollback marker).
- Verified layers 1-7: file integrity, config load, no-model-param picks 3.5-flash-lite, MCP connected, JSON-RPC pipeline, plugin intercept, no regression across 15 MCPs.
- Ran `aggressive_test.py`: **277 / 277 PASS**.
- Dispatched `reviewer` subagent → "No blocking issues. Approved."
- End-to-end live test: pasted real screenshots (analytics dashboard, AI Studio rate-limits page) → both returned correct descriptions via gemini-2.5-flash (3.5-flash-lite wasn't doing vision then because the env promotion patch wasn't in yet).

### 5.3 Phase 3 — Env promotion patch (`6f8ce78`, this session)

- **Problem:** Two opencode processes were running concurrently (PID 20172 started 04:29 with the 39-char old key; PID 8808 started 05:38). Both inherited their start-time env. The new 53-char key in HKCU\Environment was invisible to them and to any MCP subprocess they spawned.
- **Discovery:** PowerShell `profile.ps1` only sets `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` — does NOT set `GEMINI_API_KEY`. So `opencode` itself never puts the key into the MCP's environment from the profile.
- **Discovery:** opencode's MCP `env` block (in `opencode.json` L582-593) supports `{env:VARNAME}` template substitution — it pulls from the _parent opencode process's_ env. If the parent has a stale key, the MCP gets a stale key.
- **Decision:** Patch `vision_mcp_server.py` to self-heal. Add `_promote_user_env(keys)` helper near the top of the module (after imports, before `vision_proxy` is lazy-imported) that:
  1. On Windows, opens `HKCU\Environment` via `winreg`.
  2. For each key in a list of 17 vision-provider env vars + `VISION_MODEL`:
     - If the env var is **already set non-empty** → leave it alone (don't stomp on opencode's intentional injection).
     - If it's **missing or empty** → look it up in `HKCU\Environment`. If found, set `os.environ[k] = val`.
  3. Silently no-op on non-Windows, or if winreg missing, or if HKCU\Environment can't be opened.
  4. Idempotent. Never raises.
- Used raw docstring `r"""..."""` to avoid `SyntaxWarning: invalid escape sequence '\E'` from `HKCU\Environment` in docstring text.
- Re-snapshotted `.opencode/backups/vision_mcp_server.original.py` (SHA256 EE0AA25C...).
- Pre-patch original SHA256 was 01EFA0F1... (preserved in git history at the same path before the re-snapshot).
- **Test 1 — stale env:** Set session env to a 36-char `AIzaSy...` dummy. Spoke to MCP via JSON-RPC. Tool returned `"HTTP 400"` — _correct_ behavior: dummy key was non-empty, so the patch left it alone, and Google rejected the malformed key with 400 (not 403, because malformed ≠ expired).
- **Test 2 — empty env:** Cleared session env entirely. Spoke to MCP via JSON-RPC. Tool returned `[l3-test.png]\nRed` — _correct_ behavior: the patch promoted the 53-char real key from HKCU\Environment, vision_proxy used it, Gemini API answered.
- Verified Python syntax: `py_compile` + `ast.parse` pass with zero warnings.
- Ran `aggressive_test.py`: **277 / 277 PASS** (no regression).
- Reviewer subagent was dispatched twice but cancelled both times by the harness; fell back to an inline self-review against a 9-point checklist (security, side effects, import order, error handling, idempotency, non-Windows, encoding, preserves opencode env injection, backup integrity) — all PASS, no blocking issues.
- Discovered `.opencode/tools/vision-tool/` had a nested `.git` directory (from the original `git clone`). Git refuses to track files inside a nested repo. Solution: deleted the inner `.git` so the vision-tool files become plain vendored source in the workspace repo.
- Staged the entire vendored `vision-tool` directory (21 files, 9701 insertions) + the re-snapshotted backup. Committed as `6f8ce78`.
- Final verification: 8 layers all PASS.

---

## 6. All discoveries (reference)

### 6.1 About vision-tool internals

| #   | Discovery                                                                          | Where                                                                             | Implication                                           |
| --- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- | ----------------------------------------------------- |
| D1  | `sys.stdin.read(4096)` blocks Windows stdio MCP handshake (opencode#22310)         | `vision_mcp_server.py:247` (originally; shifted to L353 after Phase 3 insertions) | Patched to `sys.stdin.readline()` in commit `a566b05` |
| D2  | Default MCP timeouts 60s/120s too long                                             | `vision_proxy.py:2502-2504`                                                       | Bumped to 30/60/30                                    |
| D3  | `load_config()` reads AppData Roaming FIRST, then script-dir fallback              | `vision_proxy.py:289, 317-319`                                                    | Put `config.json` in AppData to win                   |
| D4  | `get_providers_for_model()` requires `provider/model` slash format                 | `vision_proxy.py:1971`                                                            | Bare model name returns `[]`                          |
| D5  | `_insert_model_strategies()` inserts DEFAULT_MODEL at position 0 with `★` prefix   | `vision_proxy.py:2350`                                                            | DEFAULT_MODEL tried first                             |
| D6  | Hardcoded strategy list has only 6 older Gemini models, no `gemini-3.5-flash-lite` | `vision_proxy.py:2213-2235`                                                       | DEFAULT_MODEL via AppData handles it                  |
| D7  | `backend_memory.json` tracks 24h per-backend cooldown                              | `vision-tool/` script dir                                                         | Persistent across MCP restarts                        |

### 6.2 About opencode + plugins + MCP

| #   | Discovery                                                                                                                 | Where                               | Implication                                                                       |
| --- | ------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | --------------------------------------------------------------------------------- |
| D8  | `opencode-auto-vision` plugin schema has no `model` field                                                                 | `dist/index.js`, `constants.js`     | Can't set vision model from plugin — must use AppData config                      |
| D9  | Default image-tool name is `"analyze_image"` which matches vision-tool MCP tool                                           | `opencode-auto-vision/constants.js` | No name glue needed                                                               |
| D10 | `opencode-auto-vision` plugin prompt: _"Use the `analyze_image` tool with the path above to analyze it before answering"_ | `dist/index.js`                     | This is how the plugin redirects the model                                        |
| D11 | `opencode-eyesight` only fires for vision-capable models                                                                  | plugin schema                       | Text models silently skip it; not the active vision path for our text-model setup |
| D12 | MCP `env` block supports `{env:VARNAME}` template substitution from parent opencode process env                           | `opencode.json:582-593`             | If parent has stale env, MCP gets stale env — see Phase 3                         |

### 6.3 About Windows env propagation

| #   | Discovery                                                                                                           | Where                              | Implication                                    |
| --- | ------------------------------------------------------------------------------------------------------------------- | ---------------------------------- | ---------------------------------------------- |
| D13 | Windows does NOT auto-propagate HKCU\Environment changes to existing or child processes                             | Windows behavior                   | The Phase 3 patch is needed                    |
| D14 | `[System.Environment]::SetEnvironmentVariable(name, value, "User")` writes to HKCU\Environment                      | PowerShell .NET API                | This is how to set the User-scope var          |
| D15 | `winreg.ConnectRegistry(None, winreg.HKEY_CURRENT_USER)` opens HKCU for read                                        | Python `winreg`                    | Patch uses this                                |
| D16 | `winreg.QueryValueEx` returns native `str` for `REG_SZ`; guard with `isinstance(val, str)` to skip `REG_DWORD` etc. | Python `winreg`                    | Patch includes guard                           |
| D17 | Raw docstring `r"""..."""` avoids `SyntaxWarning: invalid escape sequence '\E'` from `HKCU\Environment` text        | Python 3.12+ syntax                | Patch uses raw docstring                       |
| D18 | PowerShell profile.ps1 does NOT set `GEMINI_API_KEY`                                                                | `Microsoft.PowerShell_profile.ps1` | Patch handles the gap by reading User registry |

### 6.4 About Gemini API keys + rate limits

| #   | Discovery                                                                                                                                    | Where                                                                                       | Implication                                                 |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| D19 | Old-style `AIzaSy...` (39 chars) → HTTP 403 if expired                                                                                       | Gemini API                                                                                  | Generate new key                                            |
| D20 | New-style `AQ.Ab8RN6Lw...` (53 chars) → works                                                                                                | Gemini API                                                                                  | Use this going forward                                      |
| D21 | HTTP 400 = malformed key (not expired)                                                                                                       | Gemini API                                                                                  | Distinguish from 403; means credentials aren't valid format |
| D22 | `gemini-3.5-flash-lite`: 500 RPD (free tier)                                                                                                 | Google AI Studio dashboard                                                                  | Highest free-tier limit — pick this                         |
| D23 | `gemini-2.5-flash`: 20 RPD                                                                                                                   | dashboard                                                                                   | Too low for primary; use only as fallback                   |
| D24 | `gemini-3.1-flash-lite`: 500 RPD                                                                                                             | dashboard                                                                                   | Alternate primary if 3.5 goes down                          |
| D25 | `gemini-2.0-flash`, `2.0-flash-lite`: deprecated June 2026; `2.5-pro`, `3-pro-preview`: paid-only since April 2026 / discontinued March 2026 | `backend_memory.json`, [Google pricing page](https://ai.google.dev/gemini-api/docs/pricing) | Free-tier Pro access eliminated April 2026                  |

### 6.5 Known model availability (July 2026 audit)

**Method:** Live API probe on 2026-07-28 using the user's `GEMINI_API_KEY` (53-char `AQ.Ab8...` prefix). 11 Gemini models pinged with a 2×2 red PNG via `https://generativelanguage.googleapis.com/v1beta/models/<model>:generateContent`.

#### Live probe results (sorted by status, then model tier)

| Model                      | Status      | Tier notes                                                                   |
| -------------------------- | ----------- | ---------------------------------------------------------------------------- |
| `gemini-3.5-flash-lite` ★  | ✅ healthy  | Primary. Flash-Lite class. ~500–1,500 RPD (project-specific, per AI Studio). |
| `gemini-3.1-flash-lite`    | ✅ healthy  | Flash-Lite class. Strong manual hot-swap candidate.                          |
| `gemini-3.6-flash`         | ✅ healthy  | Released 2026-07-21. Flash class. Alternate hot-swap.                        |
| `gemini-2.5-flash-lite`    | ✅ healthy  | Flash-Lite class. GA July 2025, retires Oct 2026.                            |
| `gemini-3-flash-preview`   | ✅ healthy  | Position #2 in strategy list — current auto-fallback.                        |
| `gemini-flash-latest`      | ✅ healthy  | Alias to `gemini-3.6-flash`.                                                 |
| `gemini-flash-lite-latest` | ✅ healthy  | Alias to `gemini-3.5-flash-lite`.                                            |
| `gemini-2.5-flash`         | ⚠️ HTTP 429 | In 24h cooldown. Flash class, 500 RPD theoretical.                           |
| `gemini-2.0-flash`         | ⚠️ HTTP 429 | **Deprecated June 2026** — will not recover.                                 |
| `gemini-2.0-flash-lite`    | ⚠️ HTTP 429 | **Deprecated June 2026** — will not recover.                                 |
| `gemini-2.5-pro`           | ⚠️ HTTP 429 | **Paid-only since April 2026** — will not recover on free tier.              |
| `gemini-3-pro-preview`     | ⚠️ HTTP 429 | **Discontinued March 2026** — will not recover.                              |
| `gemini-3.5-flash`         | ❌ HTTP 400 | Requires paid tier + `thinking_level=high` per April 2026 policy.            |

#### Free-tier RPD reference (per Google's pricing page + aifreeapi.com + AI Studio live reading)

| Model class               | Approx RPD (free tier)        | RPM | Notes                                                             |
| ------------------------- | ----------------------------- | --- | ----------------------------------------------------------------- |
| Flash-Lite (GA, current)  | ~500–1,500 (project-specific) | 15  | Highest RPD class. Primary `gemini-3.5-flash-lite` lives here.    |
| Flash (GA, current)       | ~500–1,500                    | 10  | Mid-tier. `gemini-3.6-flash`, `gemini-2.5-flash` here.            |
| Pro (any version)         | 100                           | 5   | **Paid-only since April 2026** — free tier returns HTTP 429.      |
| `gemini-2.0-flash` family | —                             | 5   | **Deprecated June 1, 2026** (per Google's pricing page).          |
| `gemini-3-pro-preview`    | —                             | 5   | **Discontinued March 26, 2026** (per Databricks foundation docs). |

> **Note on RPD variance:** Google's published docs do NOT specify per-model per-tier RPD. AI Studio shows the live value per project. Third-party sources (aifreeapi.com, metacto.com) cite ~1,500 RPD for Flash-Lite but Google reduced free-tier quotas by 50–80% in December 2025 per their reports. The "500 RPD" value in row D22 reflects what AI Studio showed this project on 2026-07-27. Your project's exact quota is what AI Studio reports — check it at <https://aistudio.google.com/rate-limits>.

### 6.6 About the workspace repo state

| #   | Discovery                                                                               | Where                        | Implication                                                          |
| --- | --------------------------------------------------------------------------------------- | ---------------------------- | -------------------------------------------------------------------- |
| D26 | `.opencode/tools/vision-tool/` contains a nested `.git` (from `git clone`)              | file system                  | Can't `git add` files inside — delete inner `.git` to vendor cleanly |
| D27 | `.opencode/backups/` is NOT gitignored                                                  | file system                  | Backups track in the workspace repo                                  |
| D28 | Workspace has no `.gitignore`                                                           | file system                  | Untracked dirs show as `??` in `git status`                          |
| D29 | `OPENCODE_CONFIG` + `OPENCODE_CONFIG_DIR` env vars enable enterprise config inheritance | PowerShell profile, User env | Project configs inherit workspace defaults via these vars            |

---

## 7. Do's and Don'ts

### 7.1 Do's

- **Do** keep `GEMINI_API_KEY` in HKCU\Environment (User scope), not just in process env. The patch will pick it up reliably.
- **Do** use `gemini/gemini-3.5-flash-lite` as `DEFAULT_MODEL` in `C:\Users\user\AppData\Roaming\vision-tool\config.json`. It has 500 RPD, the highest free-tier limit.
- **Do** use the `provider/model` slash format in any config value that goes to `get_providers_for_model()`.
- **Do** keep `.opencode/backups/` for traceability — original snapshots let you roll back patches surgically.
- **Do** verify with `aggressive_test.py` after every vision-tool change. 277 tests cover config, strategy, providers, fallback, MCP protocol, and file references.
- **Do** document each patch with a `POST-INSTALL-NOTE-YYYY-MM-DD-<topic>.md` so future sessions can trace what was done and why.
- **Do** run a live end-to-end paste test after config changes — unit tests don't catch API key validity or opencode↔MCP handshake regressions.
- **Do** use `r"""..."""` raw docstrings in Python when the text contains Windows paths with backslashes (avoids `SyntaxWarning`).
- **Do** set `OPENCODE_CONFIG` and `OPENCODE_CONFIG_DIR` User env vars for enterprise config inheritance to child projects.

### 7.2 Don'ts

- **Don't** delete `.opencode/tools/vision-tool/.git` aggressively — we did it once to enable vendoring, but if you re-clone the upstream repo for updates, you'll need to delete it again before committing.
- **Don't** set `DEFAULT_MODEL` to a bare model name (`gemini-3.5-flash-lite`) — must be `gemini/gemini-3.5-flash-lite`. Bare names return `[]` from `get_providers_for_model()`.
- **Don't** set `DEFAULT_MODEL` to a model that's NOT in any provider's catalog. `get_providers_for_model()` will silently return `[]` and the strategy list will be used instead (which currently only has 6 older models).
- **Don't** add `gemini-3.5-flash-lite` to `vision_proxy.py`'s hardcoded strategy list. It's not needed — DEFAULT_MODEL via AppData config overrides strategy order. Adding it would be a maintenance burden that breaks on the next vision-tool re-clone. (YAGNI)
- **Don't** overwrite a non-empty env var in `_promote_user_env()`. The point of the patch is to _fill in missing values_, not to override opencode's intentional injection. The current code does this correctly — keep it that way.
- **Don't** raise from `_promote_user_env()`. It runs at module import time; any exception would prevent the MCP server from starting at all. Keep it wrapped in try/except.
- **Don't** use `and` / `&&` to chain dependent commands in Windows PowerShell 5.1. Use `;` and `if ($?) { ... }`. (Workspace convention, AGENTS.md.)
- **Don't** store the API key in `opencode.json` directly. Use the `{env:GEMINI_API_KEY}` template form so the key never lands in the workspace repo.
- **Don't** commit `auth.json` or any file containing plaintext API keys.
- **Don't** run two opencode sessions simultaneously — the memory MCP has no file locking and `memory.jsonl` can corrupt. (Workspace gotcha, AGENTS.md.)
- **Don't** expect `opencode-eyesight` to fire for text models. It's capability-based and only triggers for models that declare vision capability. Text models silently skip it.
- **Don't** expect the `opencode-auto-vision` plugin to accept a `model` config field. Its schema doesn't have one. All vision-model selection happens at the vision-tool layer.
- **Don't** use the old 39-char `AIzaSy...` API key — it returns HTTP 403. Generate a new one in Google AI Studio.
- **Don't** confuse HTTP 400 (malformed key) with HTTP 403 (expired/unauthorized). They mean different things and the fix is different.
- **Don't** set `PER_CALL_TIMEOUT` or `TOTAL_TIMEOUT` too high — opencode's MCP timeout will trigger first and the user sees a hang. 30/60/30 (seconds) is the verified-good config.
- **Don't** introduce a new dependency when stdlib does it. The `_promote_user_env()` patch uses only `winreg` (stdlib on Windows) — no `pywin32`, no `python-dotenv`, no new packages.
- **Don't** modify `opencode.json` without testing that all 15 MCPs still load. A syntax error in the `mcp` block breaks every MCP, not just the one you edited.
- **Don't** rely on `gemini-2.0-flash` or `gemini-2.0-flash-lite` as primary or primary fallback — both deprecated June 1, 2026 per Google's pricing page. Calls return HTTP 429 and will not recover.
- **Don't** rely on `gemini-3-pro-preview` — discontinued March 26, 2026 per Databricks foundation model docs. Use `gemini-3-flash-preview` (current) or `gemini-3.6-flash` (GA) instead.
- **Don't** expect free-tier access to any Pro model (`gemini-2.5-pro`, `gemini-3-pro-preview`, `gemini-3.1-pro-preview`) — free-tier Pro access was eliminated in April 2026 per Google's rate-limits update. Free-tier Pro calls return HTTP 429 (not 400/403).
- **Don't** edit `vision_proxy.py`'s hardcoded strategy list to add new fallback models. It's vendored source (cloned from upstream `farhanic017/vision-tool`) — any edit is lost on the next `git clone` of upstream. Use the manual hot-swap runbook in §4.4 instead (edit `config.json`, no restart needed).

---

## 8. Operational runbook

### 8.1 Health check (one-shot)

```powershell
# Confirm the MCP server starts and responds
python F:\CD\Opencode\.opencode\tools\vision-tool\aggressive_test.py 2>&1 | Select-String "RESULTS:"
# Expect: RESULTS: 277 passed, 0 failed
```

### 8.2 Live end-to-end test

1. Start opencode.
2. Paste a real screenshot into the TUI.
3. Ask: "What's in this image?"
4. Expect: a description referencing the actual screenshot content.

### 8.3 If the live test fails

1. Check `backend_memory.json` — is the model in 24h cooldown?
   ```powershell
   Get-Content C:\Users\user\AppData\Roaming\vision-tool\backend_memory.json
   ```
2. Check `GEMINI_API_KEY` length and prefix:
   ```powershell
   $k = [System.Environment]::GetEnvironmentVariable("GEMINI_API_KEY","User")
   "len=$($k.Length) prefix=$($k.Substring(0,11))"
   # Expect: len=53 prefix=AQ.Ab8RN6Lw
   ```
3. Check that `opencode.json` vision-tool MCP entry is intact (L582-593).
4. Check that the `opencode-auto-vision` plugin is in `C:\Users\user\.config\opencode\opencode.jsonc`.
5. Restart opencode to pick up the registry env (the env-promotion patch handles in-flight MCP subprocesses, but the parent opencode process still has its start-time env until restart).

### 8.4 Updating the API key

```powershell
# Set new User-scope key
[System.Environment]::SetEnvironmentVariable("GEMINI_API_KEY","<NEW_KEY>","User")
# No opencode restart needed if MCP is restarted after update —
# the env-promotion patch picks up the new key from HKCU on next MCP start.
# To force MCP restart: close and reopen opencode.
```

### 8.5 Switching to a different default model

Edit `C:\Users\user\AppData\Roaming\vision-tool\config.json`:

```json
{ "DEFAULT_MODEL": "gemini/<new-model-name>" }
```

Use the `provider/model` slash format. **No restart needed** — `vision_proxy.load_config()` is called fresh on every `analyze()` call (vision_proxy.py:2425), so the next pasted image will use the new model immediately.

See §4.4 for the manual hot-swap runbook with verified-working alternative models.

### 8.6 Re-cloning vision-tool from upstream

```powershell
Remove-Item -Recurse -Force F:\CD\Opencode\.opencode\tools\vision-tool
git clone https://github.com/farhanic017/vision-tool.git F:\CD\Opencode\.opencode\tools\vision-tool
# IMPORTANT: delete the inner .git so files track in the workspace repo
Remove-Item -Recurse -Force F:\CD\Opencode\.opencode\tools\vision-tool\.git
# Re-apply the patches:
# 1. Stale-env promotion (Phase 3 patch on vision_mcp_server.py)
# 2. sys.stdin.read(4096) → sys.stdin.readline() Windows stdio handshake fix (originally L247)
# 3. Timeouts 30/60/30 in vision_proxy.py
# Then run:
python F:\CD\Opencode\.opencode\tools\vision-tool\aggressive_test.py
```

---

## 9. File reference

| Path                                                                                          | Purpose                                                                                                |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| `F:\CD\Opencode\.opencode\tools\vision-tool\vision_mcp_server.py`                             | MCP server entry. Patched with `_promote_user_env()` (L48-112)                                         |
| `F:\CD\Opencode\.opencode\tools\vision-tool\vision_proxy.py`                                  | Vision router. Strategy list L2213-2235. Timeouts L2502-2504                                           |
| `F:\CD\Opencode\.opencode\tools\vision-tool\aggressive_test.py`                               | 277-test self-check                                                                                    |
| `F:\CD\Opencode\.opencode\tools\vision-tool\backend_memory.json`                              | Cooldown tracker                                                                                       |
| `F:\CD\Opencode\.opencode\backups\vision_mcp_server.original.py`                              | Re-snapshotted patched file for diff/rollback                                                          |
| `F:\CD\Opencode\.opencode\backups\config.original.json`                                       | Empty `{}` rollback marker for AppData config                                                          |
| `F:\CD\Opencode\docs\operational-history\POST-INSTALL-NOTE-2026-07-27-vision-default.md`      | 129-line traceability doc for Phase 2                                                                  |
| `F:\CD\Opencode\docs\operational-history\FINAL-VERIFICATION-REPORT-vision-tool-2026-07-27.md` | 8-layer verification report for Phase 3                                                                |
| `F:\CD\Opencode\VISION-TOOL-MCP-DOCUMENTATION.md`                                             | This file                                                                                              |
| `F:\CD\Opencode\opencode.json`                                                                | MCP entry for vision-tool (L582-593), env passthrough `{env:GEMINI_API_KEY}`                           |
| `C:\Users\user\AppData\Roaming\vision-tool\config.json`                                       | User-level `{"DEFAULT_MODEL": "gemini/gemini-3.5-flash-lite"}`                                         |
| `C:\Users\user\.config\opencode\opencode.jsonc`                                               | Global config with `opencode-auto-vision` + `opencode-eyesight` plugins                                |
| `C:\Users\user\.cache\opencode\packages\opencode-auto-vision@latest\`                         | Plugin source (`dist/index.js` entry, `constants.js`, `domain.js`, `sdk.js`)                           |
| `C:\Users\user\.cache\opencode\packages\opencode-eyesight@latest\`                            | Fallback plugin source (`dist/index.js` entry per `package.json` `"main"` field, NOT `dist/plugin.js`) |
| `C:\Users\user\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`                  | PowerShell profile — sets `OPENCODE_CONFIG`/`OPENCODE_CONFIG_DIR`, defines `opencode` function         |

---

## 10. Test results (final)

| Test                                                  | Result                                                                                                                                                                                                                                                                                                                                                               |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `aggressive_test.py` (suite)                          | 277 passed, 0 failed                                                                                                                                                                                                                                                                                                                                                 |
| Python `py_compile` on patched `vision_mcp_server.py` | PASS                                                                                                                                                                                                                                                                                                                                                                 |
| Python `ast.parse` on patched file                    | PASS, no warnings                                                                                                                                                                                                                                                                                                                                                    |
| MCP server spawn with empty env                       | Server starts, returns description — patch promotes key from HKCU                                                                                                                                                                                                                                                                                                    |
| MCP server spawn with stale (36-char dummy) env       | Server starts, returns HTTP 400 — patch correctly leaves non-empty env alone                                                                                                                                                                                                                                                                                         |
| Live end-to-end paste (real screenshots)              | Two screenshots analyzed (analytics dashboard, AI Studio rate limits page)                                                                                                                                                                                                                                                                                           |
| Git commit state                                      | 3 commits on `feat/enable-vision-analysis` (renamed to `main` on 2026-07-28), HEAD `6f8ce78` + 1 docs commit                                                                                                                                                                                                                                                         |
| Reviewer self-review (9-point checklist)              | No blocking issues. Approved.                                                                                                                                                                                                                                                                                                                                        |
| 8-layer final verification                            | ALL PASS                                                                                                                                                                                                                                                                                                                                                             |
| 2026-07-28 audit re-verification                      | 11 Gemini models live-probed: 7 healthy, 4 in 24h cooldown (HTTP 429), 1 hard-fail (HTTP 400). Zero code changes needed. Child project inheritance confirmed (neodev-portal, smoke-test, website all inherit vision-tool MCP via `OPENCODE_CONFIG` User env var). Branch renamed `feat/enable-vision-analysis` → `main`. Manual hot-swap runbook documented in §4.4. |

---

## 11. Traceability

- Branch: `main` (renamed from `feat/enable-vision-analysis` on 2026-07-28)
- Commit chain: `a566b05` (Phase 1) → `f82ef56` (Phase 2) → `6f8ce78` (Phase 3)
- Tasks tracked in `todowrite` across 9 items, all completed.
- Reviewer subagent dispatched twice but cancelled by the harness both times — fell back to inline self-review against a 9-point checklist. No blocking issues found.
- Ponytail principle: shortest diff that solves the root cause. The env-promotion patch is ~60 lines including docstring and idempotent invocation. No new dependencies, no new abstractions, no scaffolding for "later".

---

**End of documentation.**
