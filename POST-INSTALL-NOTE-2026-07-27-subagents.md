# Post-Install Note — Subagent Model Switch to Kimi K2.6

**Date:** 2026-07-27
**Operator:** SOHAM (user) + opencode assistant (model: glm-5.2 via hcnsec)
**Plan version:** v6 bulletproof (after 6 critique cycles)
**Pre-edit backup:** `Opencode-Enterprise-Snapshot-2026-07-27-0420-subagents-kimi-pre.zip`
**Plan mode enforced** through all 6 cycles; promotion executed only after explicit user "go".

## 1. Objective

Switch all subagent models from `opencode-zen/mimo-v2.5-free` (parent + OMO-Slim) and `ollama-cloud/minimax-m3` (neodev-portal) to `hcnsec/Kimi-K2.6` (Moonshot Kimi K2.6 via hcnsec reseller, 256K context). Inheritance into child projects is automatic via the `OPENCODE_CONFIG` + `OPENCODE_CONFIG_DIR` env vars (set 2026-07-22).

## 2. Files Edited (3 config + 2 docs)

| File                                                      | Edits                                  | Notes                                                                                                                                           |
| --------------------------------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `F:\CD\Opencode\opencode.json`                            | 15 subagent model fields               | `build` + `plan` (primary) stay `ollama-cloud/minimax-m3`. Top-level `model`/`small_model` untouched.                                           |
| `F:\CD\Opencode\Projects\neodev-portal\opencode.json`     | 15 subagent model fields               | Same — `neodev-portal` previously used `minimax-m3` for subagents.                                                                              |
| `C:\Users\user\.config\opencode\oh-my-opencode-slim.json` | 8 model fields in `opencode-go` preset | `openai` preset (6 agents) untouched — uses OpenAI, not mimo.                                                                                   |
| `F:\CD\Opencode\AGENTS.md`                                | 2 mentions                             | Line 20 + lines 164-165.                                                                                                                        |
| `F:\CD\Opencode\ENTERPRISE_OPENCODE_SETUP.md`             | 17 mentions across 4 sections          | OMO-Slim preset line, subagent summary, subagent table (15 rows), OMO-Slim config desc. 6 general/provider-catalog mentions intentionally left. |

**Total: 38 model-field edits + 19 doc-line edits.**

## 3. Unchanged (Verified at 2026-07-27)

- `build` and `plan` primary agents: still `ollama-cloud/minimax-m3`
- Top-level `model` and `small_model` (session defaults): untouched (still `opencode-zen/mimo-v2.5-free`)
- `auth.json` (4 provider keys): untouched — `opencode-go`, `ollama-cloud`, `nvidia`, `google` (the `google` key was added in a separate 2026-07-27 vision-tool MCP change, not this subagent migration)
- `openai` preset in OMO-Slim: untouched
- `verify-inheritance.ps1`: untouched at the time of this note (a later 2026-07-27 edit updated its MCP count from 15 to 16 to match the vision-tool MCP addition)
- Agent count: 17 (unchanged)
- Model count: 20 (unchanged)
- MCP count: 15 at the time of this note (vision-tool MCP added in a separate 2026-07-27 change brought total to 16)

> **Post-note update (2026-07-27):** A separate change on the same day added the `vision-tool` MCP (bringing MCP count to 16), added the `google` provider to auth.json (bringing provider count to 4), and added the `@dietrichgebert/ponytail`, `opencode-auto-vision`, `opencode-eyesight` plugins (bringing total plugins to 7). The subagent migration documented in this note was not affected by those additions. The `opencode-zen/mimo-v2.5-free` provider entry referenced in the original L29 ("`auth.json` (5 provider keys): untouched") was stale even at the time of writing — `opencode-zen` is a built-in provider, not stored in auth.json; auth.json has always contained only explicit `<provider, key>` pairs (3 before the google addition, 4 after). The "5" count was wrong; it is corrected to "4" here and in `AGENTS.md`.

## 4. SHA-256 Verification (post-promotion)

```
parent opencode.json:        BC14F0ADD5B64DC71E3DEC6DEEDD240485E2FC3273B36E8008B63381C20D06F3
neodev-portal opencode.json: 2EDE50E56DEDEF17C4DF99F6E653EABFEF5D3D1D0296830AA45F7C2DEA7EEB81
oh-my-opencode-slim.json:    528970DF1CC34D99372B56337E1691FD0F0DE0129B0A23EDFB0E1DF29B471690
```

## 5. Risks Acknowledged

| Risk                                                                                           | Mitigation                                                                                                         |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| hcnsec Kimi rate limits (Tier 1: 50 concurrent / 200 RPM upstream Moonshot)                    | Documented in AGENTS.md line 165: "dispatch sequentially to avoid hcnsec rate limits; parallel fan-out risks 429s" |
| Cold-start TTFT P99 ~32s on first Kimi call after restart                                      | Pre-warm by calling any subagent once before critical work                                                         |
| Subagent token cost (~7x multiplier for 3-agent team vs single agent per SSOJet/HN research)   | User accepts — Kimi K2.6 256K context + better quality justifies cost                                              |
| opencode retry bug (#30510): off-by-one backoff, indef 429 retries with 30s cap                | Avoid by sequential dispatch; no fix available upstream yet                                                        |
| Per-project `neodev-portal` switch — subagents there lose minimax-m3's stronger coding profile | User explicitly confirmed full global switch (not partial)                                                         |
| Config reload behavior: opencode does NOT auto-reload config on file change — requires restart | Noted: user must restart opencode to pick up new subagent models                                                   |

## 6. Rollback Recipe

```
Expand-Archive -Path "F:\CD\Opencode\Opencode-Enterprise-Snapshot-2026-07-27-0420-subagents-kimi-pre.zip" -DestinationPath "C:\Users\user\AppData\Local\Temp\opencode\restore" -Force
Copy-Item -LiteralPath "C:\Users\user\AppData\Local\Temp\opencode\restore\opencode.json" -Destination "F:\CD\Opencode\opencode.json" -Force
Copy-Item -LiteralPath "C:\Users\user\AppData\Local\Temp\opencode\restore\neodev-portal-opencode.json" -Destination "F:\CD\Opencode\Projects\neodev-portal\opencode.json" -Force
Copy-Item -LiteralPath "C:\Users\user\AppData\Local\Temp\opencode\restore\oh-my-opencode-slim.json" -Destination "C:\Users\user\.config\opencode\oh-my-opencode-slim.json" -Force
Copy-Item -LiteralPath "C:\Users\user\AppData\Local\Temp\opencode\restore\AGENTS.md" -Destination "F:\CD\Opencode\AGENTS.md" -Force
Copy-Item -LiteralPath "C:\Users\user\AppData\Local\Temp\opencode\restore\ENTERPRISE_OPENCODE_SETUP.md" -Destination "F:\CD\Opencode\ENTERPRISE_OPENCODE_SETUP.md" -Force
```

## 7. Verification Steps Performed

1. **Backup zip created** (43876 bytes, 5 files inside).
2. **Sandbox built** at `C:\Users\user\AppData\Local\Temp\opencode\sandbox-subagents\` with 3 edited config copies.
3. **Sandbox validation PASSED**: JSON parse OK for all 3 files; counts matched (parent 15 Kimi + 2 primary minimax; neodev-portal 15 Kimi + 2 primary minimax; OMO-Slim opencode-go preset 8 Kimi, openai preset 6 other).
4. **Live files overwritten** via `Copy-Item -Force`. SHA-256 changed for all 3 files.
5. **Live validation PASSED**: same checks run on promoted files. Counts match.
6. **Doc sync**: AGENTS.md 2 mentions swapped; ENTERPRISE_OPENCODE_SETUP.md 17 mentions swapped (15 subagent table rows + OMO-Slim preset + summary + config desc). 6 mentions intentionally left (provider descriptions + top-level `model`/`small_model`).
7. **verify-inheritance.ps1**: pending (Phase 8).
8. **Inheritance check**: child projects under `F:\CD\Opencode\Projects\*.opencode.json` will pick up the new parent subagent config via `OPENCODE_CONFIG` env var on next session restart. No override needed — child configs only override top-level fields, not agents.

## 8. Restart Required

opencode does NOT auto-reload config on file change. User must:

1. Exit opencode (`/exit` or close terminal)
2. Restart: `opencode`
3. Confirm new subagent models via `/agents` menu — all 15 subagents should show `hcnsec/Kimi-K2.6`
4. Pre-warm Kimi: dispatch `architect` (or any subagent) with a trivial prompt to trigger first-call token cache (~26s expected cold, ~3s warm after)

## 9. Test Recipe

After restart:

```
/agents
```

Expected: 15 subagents (architect, reviewer, tester, explorer, oracle, librarian, fixer, designer, observer, council, orchestrator, code-reviewer, security-auditor, test-engineer, web-perf-auditor) all show model `hcnsec/Kimi-K2.6`; 2 primary (build, plan) show `ollama-cloud/minimax-m3`.

Then:

```
@architect give me a one-sentence design principle
```

Expected: response in 3-30s (cold-start). Subsequent `@reviewer`/`@tester` calls: 1-5s warm.

## 10. Cost / Usage Notes

- All subagent dispatches now consume Kimi quota (not free like mimo-v2.5-free was).
- Tier 1 hcnsec/$10 recharge: 50 concurrent / 200 RPM upstream Moonshot.
- 15 subagents × sequential dispatch is safe; parallel fan-out of 3+ subagents may hit 429.
- AGENTS.md line 165 updated to warn: "Subagents consume Kimi quota — dispatch sequentially to avoid hcnsec rate limits; parallel fan-out risks 429s."

---

**Status:** COMPLETE. Awaiting user restart + verification.
