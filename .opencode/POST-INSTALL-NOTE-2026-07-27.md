# Post-Install Note — 2026-07-27

## Event: Added `hcnsec/Kimi-K2.6` to model catalog

**Date:** 2026-07-27
**Scope:** Catalog-only addition. No agent model reassignments.
**Risk profile:** Low — single new entry in `provider.hcnsec.models`. No other config blocks touched.

---

## What was added

A new model entry was inserted into `F:\CD\Opencode\opencode.json` under
`provider.hcnsec.models`, alphabetically between `glm-5.2` and `MiniMax-M3`
(lines 150-155 in the post-edit file):

```jsonc
"Kimi-K2.6": {
  "name": "Kimi K2.6 (Moonshot via hcnsec)",
  "limit": {
    "context": 256000,
    "output": 16384
  }
},
```

After this addition, `provider.hcnsec.models` contains **20** models
(was 19). The new model is visible in opencode's `/models` picker as
`hcnsec/Kimi-K2.6` after the next opencode process restart.

## Why Kimi-K2.6 was previously excluded

The 2026-07-19 audit (`AGENTS.md` "DO NOT work" table) marked Kimi-K2.6 as
**"Connection timeout (>90s, then closed)"** and excluded it from the
catalog. That conclusion was wrong.

On 2026-07-27, six read-only live probes against
`https://api.hcnsec.cn/v1/chat/completions` (model: `Kimi-K2.6`,
`HCNSEC_API_KEY` from USER-scope env var) demonstrated the model is
reliable when `max_tokens >= 200`:

| Probe | max_tokens | Result                                   | Latency | finish_reason |
| ----- | ---------: | ---------------------------------------- | ------: | ------------- |
| 1     |         50 | empty content                            |  3.71 s | `length`      |
| 2     |        500 | `"OK"`                                   | 26.35 s | `stop` (cold) |
| 3     |        800 | real coding answer (`shutil.copytree()`) |  1.60 s | `stop`        |
| 4     |       1500 | 3-step architectural plan returned       |  3.38 s | `stop`        |
| 5     |       4096 | full content                             |  2.72 s | `stop`        |
| 6     |       4096 | full content                             |  3.32 s | `stop`        |
| 7     |       4096 | full content (median run)                |  3.61 s | `stop`        |

Median latency at `max_tokens=4096`: **3.22 s**.

The original 90s+ "timeout" was almost certainly an opencode-side default
behavior at the time of the 2026-07-19 audit, not a server-side issue.
Today the model responds reliably and well under opencode's 600 s default
timeout.

## Why the `output: 16384` floor

Kimi-K2.6 returns empty content with `finish_reason: "length"` when
`max_tokens` is below ~200. Setting `limit.output: 16384` (the same value
used by `MiniMax-M3`) ensures opencode auto-requests an output budget 80x
above that floor on every call, eliminating the empty-response failure
mode entirely.

## Files changed

| File                                              | Change                                                                                                               |
| ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `F:\CD\Opencode\opencode.json`                    | +6 lines (new `Kimi-K2.6` entry in `provider.hcnsec.models`)                                                         |
| `F:\CD\Opencode\AGENTS.md`                        | Added Kimi row to verified-working table; deleted from DO-NOT-work table; updated 19→20 model counts (2 spots)       |
| `F:\CD\Opencode\ENTERPRISE_OPENCODE_SETUP.md`     | 5 in-place edits: 3 occurrences of "19 models" → "20 models"; 1 row added to model list table; updated count comment |
| `F:\CD\Opencode\.opencode\verify-inheritance.ps1` | Updated final print line: "hcnsec provider (19 models)" → "hcnsec provider (20 models)"                              |

**Not touched:**

- `Projects/neodev-portal/opencode.json`, `Projects/smoke-test/opencode.json`, `Projects/website/opencode.json` — no `provider` block in any child project; Kimi inherits automatically via `OPENCODE_CONFIG` env var
- `.opencode/agents/*.md` (7 files) — no `model` field in YAML frontmatter
- `C:\Users\user\.config\opencode\oh-my-opencode-slim.json` — OMO-Slim does not set `model` per agent
- `auth.json` — hcnsec uses `{env:HCNSEC_API_KEY}` env-var resolution, no auth.json entry needed
- Top-level `model`, `small_model`, `default_agent` in opencode.json unchanged
- All 17 agent model assignments unchanged (`build`+`plan` = `ollama-cloud/minimax-m3`; remaining 15 = `opencode-zen/mimo-v2.5-free`)
- LSP, formatter, MCP, plugin, permission, skills, tool_output, compaction blocks unchanged

## SHA-256 audit trail

```
opencode.json pre-edit:  B75E79AB5DDB33FCF9BD5880D669DA8B11C3CA205F79D9A3A5815E51C7CB8014
opencode.json post-edit: 0A18BBFFEE65A6EC16FCE34C53AF2BA051E7952EDC292AC512034DD89D32C20A
Size delta:              13558 → 13737 bytes  (+179 bytes, +6 lines)
```

The 179-byte delta matches exactly the size of the new 6-line JSON entry
plus its surrounding whitespace.

## Backup snapshot

`F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-27-kimi-add-pre.zip`
(47,921 bytes) — created **before** the live edit. Contains:

- `opencode.json` (pre-edit version)
- `AGENTS.md` (pre-edit version)
- `ENTERPRISE_OPENCODE_SETUP.md` (pre-edit version)
- `.opencode/POST-INSTALL-NOTE-2026-07-23.md`
- `.opencode/verify-inheritance.ps1` (pre-edit version)

## Inheritance verification

`powershell -ExecutionPolicy Bypass -File F:\CD\Opencode\.opencode\verify-inheritance.ps1`
expected to report **11/11 PASS** with Check 5 printing
`hcnsec provider present (20 models)` (was 19).

All 3 child projects (`neodev-portal/`, `smoke-test/`, `website/`)
automatically inherit the new model via the parent config inheritance
mechanism (`OPENCODE_CONFIG` USER env var → `F:\CD\Opencode\opencode.json`).

## Model picker test recipe (post-restart)

1. Restart opencode process (close all sessions, reopen)
2. In any session, type `/models` and press Enter
3. In the model picker, expand `hcnsec` provider group
4. Verify `hcnsec/Kimi-K2.6` appears (label: "Kimi K2.6 (Moonshot via hcnsec)")
5. (Optional) Select `hcnsec/Kimi-K2.6` as the active model for the current session
6. Run a trivial prompt: "Reply with just OK"
7. Expected: response in 1.6-26 s (median ~3 s), non-empty content
8. If response is empty: check `limit.output: 16384` is set in opencode.json line 154

## Upstream provider id

hcnsec's `/v1/chat/completions` for `Kimi-K2.6` is routed through
Moonshot's API upstream. Observed `id` field in server responses:
`thinkingmachines/inkling` (Moonshot's internal routing label). This is
cosmetic only and has no impact on opencode's model ID or behavior.

## Rollback procedure

To revert this change:

```powershell
Expand-Archive -LiteralPath "F:\CD\Backup\Opencode-Enterprise-Snapshot-2026-07-27-kimi-add-pre.zip" -DestinationPath "F:\CD\Opencode" -Force
```

Then revert the doc files from the same zip into their respective paths.
After rollback, restart opencode. `verify-inheritance.ps1` will report
Check 5 as `hcnsec provider present (19 models)`.

## Related deferred tasks

- **Stale model entries in `provider.hcnsec.models`:** A separate live probe
  on 2026-07-27 found that 9 of the 20 catalog entries
  (`glm-4.7`, `Qwen3-Coder-Next-FP8`, `kat-coder-pro-v2`,
  `kat-coder-pro-v2.5`, `Spark-X2-Flash`, `step-3.5-flash`,
  `step-3.5-flash-2603`, `step-router-v1`, `stepaudio-2.5-chat`)
  are no longer served by hcnsec's `/v1/models` endpoint today.
  They remain in the catalog per user direction (deferred to a separate
  cleanup task). Kimi-K2.6 is one of two new models the server now serves
  that were not in the original audit (the other, `sensenova-u1-fast`,
  was tested and confirmed broken: 404 Not Found).
