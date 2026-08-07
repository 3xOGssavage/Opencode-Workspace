# ADR-001: Subagent Migration to hcnsec/Kimi-K2.6

- **Status:** Accepted
- **Date:** 2026-07-27
- **Deciders:** Workspace owner
- **Commit:** This ADR accompanies the opencode.json commit on feat/subagent-migration-hcnsec-kimi.

## Context

Prior to 2026-07-27, opencode subagents (15 custom + 8 OMO-Slim) ran on
`opencode-zen/mimo-v2.5-free`, and the primary `build`/`plan` agents used
`ollama-cloud/minimax-m3`. The `opencode-zen` provider backed the
`mimo-v2.5-free` model.

Two problems motivated the migration:

1. **Provider deprecation risk.** `opencode-zen` was removed from `auth.json`
   on 2026-07-27. Keeping subagents pinned to a removed provider's model
   would silently break every subagent dispatch on the next session restart.
2. **Context ceiling.** Subagents handling large file review or multi-file
   reasoning were bumping the 32K context limit of `mimo-v2.5-free`,
   forcing premature context compaction and losing detail.

## Decision

Migrate all subagent models to `hcnsec/Kimi-K2.6` (Moonshot Kimi K2.6 via
the hcnsec reseller). Keep `ollama-cloud/minimax-m3` as the primary
`build`/`plan` agent model.

### Changes in opencode.json

- `agent.architect.model` -> `hcnsec/Kimi-K2.6`
- `agent.reviewer.model` -> `hcnsec/Kimi-K2.6`
- `agent.tester.model` -> `hcnsec/Kimi-K2.6`
- `agent.addy-*` (5 agents) `.model` -> `hcnsec/Kimi-K2.6`
- `agent.orchestrator|oracle|council|librarian|explorer|designer|fixer|observer.model` -> `hcnsec/Kimi-K2.6`
- `provider.hcnsec` block retained (baseURL `https://api.hcnsec.cn/v1`, 20 models)

### Untouched (intentionally)

- Top-level `model` and `small_model` (session defaults) remain
  `opencode-zen/mimo-v2.5-free`. This is **known drift** — the
  `opencode-zen` provider is no longer in `auth.json`, so the session
  default will fall back to opencode's built-in model resolution. Acceptable
  because every real workload is dispatched through a named subagent
  (`architect`, `reviewer`, etc.) whose `model` field IS migrated. A future
  ADR will address session defaults if built-in resolution proves unstable.
- `auth.json` — edit-deny protected, not touched.
- `MCP` servers — no change (vision-tool MCP was added in a separate
  2026-07-27 change; see commit `6f8ce78`).

## Alternatives Considered

1. **Migrate to `hcnsec/MiniMax-M3`** — same flagship as the primary agents.
   Rejected: would have concentrated all agents on one model, leaving no
   diversity for adversarial review (architect vs reviewer should differ).
2. **Migrate to `hcnsec/glm-5.2`** — slow (~2-4 min/response), unacceptable
   latency for interactive subagent dispatch.
3. **Keep `opencode-zen/mimo-v2.5-free` and re-add the provider** —
   rejected: the provider removal was intentional (rate limits, reliability),
   and re-adding it would undo the cleanup.
4. **Stay on `ollama-cloud/minimax-m3` for subagents too** — rejected: same
   concentration concern as Alt 1, plus minimax-m3 is the primary build
   agent model and we wanted layer separation.

## Consequences

- **Positive:** 256K context window for subagents (8x previous 32K ceiling);
  Kimi K2.6 median response ~3s per AGENTS.md benchmark; provider diversity
  (subagents on hcnsec, primary agents on ollama-cloud).
- **Negative:** hcnsec rate limits are not configurable in opencode (see
  AGENTS.md env/gotchas). Parallel subagent fan-out risks 429s. Mitigation:
  dispatch subagents sequentially, not in parallel.
- **Neutral:** Memory MCP remains broken (`draft-07` schema dialect — server
  bug, unrelated to this migration).

## Evidence

- `verify-inheritance.ps1` passes end-to-end after the migration
  (Output: `ALL CHECKS PASSED`, `16 MCP servers active`).
- Audit commit `12ece08` aligned AGENTS.md, ENTERPRISE_OPENCODE_SETUP.md,
  ../operational-history/POST-INSTALL-NOTE-2026-07-27-subagents.md, and verify-inheritance.ps1
  with the post-migration state.
- 121 active SKILL.md files across 9 packs confirmed by filesystem
  enumeration (~117 unique after dedup).

## Verification

This ADR is merged with `--no-ff` so the merge commit is visible in
`git log --oneline`. To verify the migration is intact at any future date:

```powershell
# 1. Confirm all subagent models point to hcnsec/Kimi-K2.6
Select-String -Path opencode.json -Pattern '"model":\s*"hcnsec/Kimi-K2.6"' | Measure-Object | Select-Object Count

# 2. Confirm no subagent still references opencode-zen/mimo
Select-String -Path opencode.json -Pattern 'opencode-zen/mimo' | ForEach-Object { $_.Line }

# 3. Run end-to-end inheritance check
powershell -ExecutionPolicy Bypass -File .opencode/verify-inheritance.ps1
```

## References

- `AGENTS.md` — "Models" section (L82-87) and hcnsec model table
- `../operational-history/POST-INSTALL-NOTE-2026-07-27-subagents.md` — migration note
- `ENTERPRISE_OPENCODE_SETUP.md` L1746 — Post-snapshot update footnote
