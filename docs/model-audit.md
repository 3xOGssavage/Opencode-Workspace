# Model Audit — 2026-09-09 (Week W37)

Method: free catalog listings for all reachable providers, then paced sequential
chat probes (overshoot error-disclosure: a limit-revealing 400 proves aliveness).
Harness: `.opencode/tools/model-verify/` (probe.mjs crash-guard repaired,
probe-ah rewritten to structured JSON with quota guard, retry-queue added).
Raw JSON: `output/` (this run) + `output/archive-sep05-baseline/` (prior round).

## Headline

**hcnsec incident in progress.** 7 of 10 configured models return 503 no-channel,
including the flagship (MiniMax-M3) and the entire helper fleet model (Kimi-K2.6),
plus 5 catalog disappearances vs Sep-5. Per the two-bad-weeks rule this is
**week 1: flagged PROBLEM, zero quarantines.** Quarantine needs a second bad week.

## Verdict counts (54 configured)

- healthy: 19 (chat 200 or limit-disclosure alive)
- problem: 7 (all hcnsec: Kimi-K2.6, MiniMax-M3, DeepSeek-V4-Flash, DeepSeek-V4-Pro,
  kat-coder-pro-v2.5, sensenova-6.7-flash-lite, stepaudio-2.5-chat)
- problem-tier: 1 (coding-glm-5.2-free left the free tier; paid slug z-ai/glm-5.2)
- misconfigured: 1 (coding-kimi-k3-free: API says ID wrong; successors
  kimi-k3 / coding-kimi-k3 exist in catalog, verify next)
- unscanned: 26 (23 aihubmix: free-quota wall after ~20 probes; never counted as bad)

## hcnsec detail (10)

| Model                    | Catalog                     | Probe                | Verdict                                               |
| ------------------------ | --------------------------- | -------------------- | ----------------------------------------------------- |
| auto                     | listed                      | 400 limit disclosure | healthy (router alias, exempt from removal candidacy) |
| Kimi-K2.6                | GONE from catalog           | 503 x2               | problem week-1 (fleet model)                          |
| MiniMax-M3               | GONE from catalog           | 503 x2               | problem week-1 (flagship)                             |
| DeepSeek-V4-Flash        | GONE from catalog           | 503                  | problem week-1                                        |
| DeepSeek-V4-Pro          | listed                      | timeout x2           | problem week-1 (slow, was ok before)                  |
| kat-coder-pro-v2.5       | GONE from catalog           | 503                  | problem week-1                                        |
| sensenova-6.7-flash-lite | GONE from catalog           | 503                  | problem week-1                                        |
| step-3.7-flash           | listed                      | 200                  | healthy                                               |
| step-router-v1           | listed                      | 200                  | healthy                                               |
| stepaudio-2.5-chat       | not listed (audio endpoint) | 503                  | problem week-1, audio-modality note                   |

## aihubmix detail (21 probed)

Alive with disclosed caps: coding-glm-4.6-free [1,131072], coding-glm-4.7-free
[1,131072] (config manualOut corrected 128000->131072 in script tables),
coding-glm-5-free [1,131072], coding-glm-5.1-free [1,131072],
coding-minimax-m2.1/m2.5/m2.7/m2-free cap 196608 (m2 routes to M2.5),
coding-minimax-m3-free cap 524288, dots-3-note-preview-free ctx 512000,
gemini-3.5/3.6/3.7/flash-preview (range-capped, alive),
gemma-4-26b/31b ctx 262144.
Tier-changed: coding-glm-5.2-free (404, paid slug z-ai/glm-5.2).
Wrong-ID: coding-kimi-k3-free (successors in catalog).
Unscanned (23, quota wall, prior standing kept): glm-4.7-flash-free,
gpt-4.1-free/mini/nano, gpt-4o-free, gpt-5.5-free, gpt-oss-20b-free,
k2.6-code-preview-free, kimi-for-coding-free, laguna-s/xs-2.1-free,
lfm-2.5-2.6b-free, ling-3.0-flash-free, mimo-v2-flash-free,
nemotron-3.5-content-safety/lightning, nemotron-3-nano-30b/omni,
nemotron-3-super, nemotron-3-ultra, nemotron-nano-12b-v2-vl,
nemotron-nano-9b-v2, north-mini-code-free, qwen3.6-plus-preview-free,
xiaomi-mimo-v2.5-free/pro.

## Catalog newcomers (pending verification, NOT added — spotless rule)

- hcnsec (7): glm-5.3-flash, longcat-2.0, Qwen3.6-35B-A3B,
  sensenova-6.8-flash-lite, sensenova-u1.5-lite, spark-x2.5, step-explore
- aihubmix (4): gemini-3.8-flash-free, hy3-free, minimax-m2.7-free, minimax-m3-free
- Both sync scripts now exist, tested (dry-run + revert), gated on probe proof.

## Pins and dangling references (report-only, nothing changed)

- Fleet + OMO + neodev-portal hcnsec/Kimi-K2.6 pins: DOWN with the storm.
- neodev-portal + eyesight ollama-cloud/minimax-m3: billing-blocked (402, re-confirmed;
  free models like gpt-oss:20b work on same account).
- smoke-test opencode-go/glm-5.2: MissingSessionID via plain API (works only
  inside opencode sessions); opencode-zen/mimo-v2.5-free: provider absent.
- OMO openai/gpt-5.5 + gpt-5.4-mini: no OPENAI key anywhere (dangling).
- google vision model gemini-3.5-flash-lite: still listed (50-model catalog).
- nvidia catalog shrank 102 -> 80 (example: llama-3.3-70b-instruct EOL 2026-08-26).
- Evals P0 (unchanged, needs user word): workspace headless resolves to
  billing-blocked minimax-m3, so the Sunday suite fails at the wallet.

## Quota wall (design driver)

Free-tier 429s after ~20 probes. Unscanned models keep prior standing and never
accrue bad weeks. Weekly loop uses rotation: hot ~20 (fleet, primary, pins,
flagged, pending newcomers) every week, tail rotates for monthly full coverage.

## Changes shipped with this audit (see PR)

1. `opencode.json`: coding-glm-5.2-free display renamed to
   `Coding GLM 5.2 (free) [PAID 2026-09-09]` (keys/pins/limits untouched).
2. `scripts/sync-aihubmix-models.ps1`: backup+validate, [DEAD]-preserve,
   probe-verified limit table (caught a 7-limit regression pre-harm), byte-exact format.
3. `scripts/sync-hcnsec-models.ps1`: new, tested dry-run, gated on probes.
4. `.opencode/tools/model-verify/`: tokenrouter guard, probe-ah JSON+quota-guard,
   retry-queue; fresh probe outputs committed as evidence baseline.
5. `state.json` (gitignored, local): week-1 statuses for all 54.
6. AGENTS.md untouched by design (storm statuses too volatile to bake in).

## Next

Weekly Sunday 17:30 task (rotation design); newcomer verification when quota
allows; kimi-k3 successor probe; Kimi/MiniMax storm watch; evals P0 on user word.
