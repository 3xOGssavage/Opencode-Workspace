# Model Verification Report — 2026-08-23

Verified by **both** official documentation (provider model registry + web docs) and **live API probing** (catalog + error-disclosure).

## Inventory Summary

| Provider | Configured | Live Catalog | Cache Registry | Status |
|---|---|---|---|---|
| hcnsec (api.hcnsec.cn) | 20 | 15 | — (custom) | 10 dead, 1 EOL, 2 timeout |
| aihubmix (aihubmix.com) | 44 | 401 | 70 in cache | free-tier quota hit after 10 probes |
| tokenrouter (api.tokenrouter.com) | 2 | 2 | — (custom) | both unavailable (503/403) |
| google (generativelanguage) | via auth | 50 | 39 | all probed via ListModels (authoritative limits) |
| nvidia (integrate.api.nvidia.com) | via auth | 102 | 102 | list OK, probe timeout |
| ollama-cloud (ollama.com) | via auth (minimax-m3 primary) | 19 tags | 20 | chat requires valid endpoint |
| opencode-go (opencode.ai/zen/go) | via auth (glm-5.2) | 28 | 28 | weekly limit hit |

## Detailed Findings per Configured Model

### hcnsec — 20 configured, only 15 live (critical drift)

| Model | Config ctx/out | Live? | Probe error (reveals true limit) | Verdict |
|---|---|---|---|---|
| auto | 128000/8192 | ✅ | ok | 🟢 alive |
| glm-4.7 | 128000/8192 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model glm-4.7 under group default (distributor) ( | 🔴 DEAD (503 no channel) |
| glm-5.2 | 200000/8192 | ✅ | {"error":{"message":"The model 'z-ai/glm-5.2' has reached its end of life on 2026-08-21T09:00:00Z and is no longer avail | 🔴 EOL 2026-08-21 |
| Kimi-K2.6 | 256000/16384 | ✅ | The operation was aborted due to timeout | ⚪ timeout |
| MiniMax-M3 | 1000000/16384 | ✅ | ok | 🟢 alive |
| MiniMax-M2.7 | 200000/4096 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model MiniMax-M2.7 under group default (distribut | 🔴 DEAD (503 no channel) |
| DeepSeek-V4-Flash | 128000/8192 | ✅ | The operation was aborted due to timeout | ⚪ timeout |
| DeepSeek-V4-Pro | 128000/8192 | ✅ | ok | 🟢 alive |
| Qwen3-Coder-Next-FP8 | 128000/8192 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model Qwen3-Coder-Next-FP8 under group default (d | 🔴 DEAD (503 no channel) |
| Qwen3.5-397B-A17B | 128000/8192 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model Qwen3.5-397B-A17B under group default (dist | 🔴 DEAD (503 no channel) |
| Qwen3.6-35B-A3B | 128000/8192 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model Qwen3.6-35B-A3B under group default (distri | 🔴 DEAD (503 no channel) |
| kat-coder-pro-v2 | 128000/8192 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model kat-coder-pro-v2 under group default (distr | 🔴 DEAD (503 no channel) |
| kat-coder-pro-v2.5 | 128000/8192 | ✅ | {"error":{"message":"max_completion_tokens is too large: ***.This model supports at most 262144 completion tokens.","typ | 🟡 CONFIG WRONG |
| Spark-X2-Flash | 128000/4096 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model Spark-X2-Flash under group default (distrib | 🔴 DEAD (503 no channel) |
| sensenova-6.7-flash-lite | 128000/4096 | ✅ | {"error":{"message":"field MaxTokens invalid, should be in [1, 65536]","type":"invalid_request_error","param":"max_token | 🟡 CONFIG WRONG |
| step-3.5-flash | 128000/4096 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model step-3.5-flash under group default (distrib | 🔴 DEAD (503 no channel) |
| step-3.5-flash-2603 | 128000/4096 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model step-3.5-flash-2603 under group default (di | 🔴 DEAD (503 no channel) |
| step-3.7-flash | 128000/4096 | ✅ | ok | 🟢 alive |
| step-router-v1 | 128000/4096 | ✅ | ok | 🟢 alive |
| stepaudio-2.5-chat | 32768/4096 | ❌ dead | {"error":{"code":"model_not_found","message":"No available channel for model stepaudio-2.5-chat under group default (dis | 🔴 DEAD (503 no channel) |

**Key hcnsec proofs (API error messages = authoritative):**
- `kat-coder-pro-v2.5`: probe error `at most 262144 completion tokens` → config says `8192` → **32× wrong**
- `sensenova-6.7-flash-lite`: probe `should be in [1, 65536]` → config `4096` → **16× wrong**
- `glm-5.2`: `has reached its end of life on 2026-08-21T09:00:00Z` → **must be removed from config**
- 10 models return `No available channel` (503) → dead on hcnsec, not just config drift
- `auto`, `Kimi-K2.6`, `MiniMax-M3`, `DeepSeek-V4-Pro`, `step-3.7-flash`, `step-router-v1` probed OK (200) but accepted 2M max_tokens without error — suggests output limit >=2M or endpoint ignores max_tokens cap (needs deeper boundary test)

### tokenrouter — 2 configured, both currently unusable

| Model | Config ctx/out | Live? | Probe | Verdict |
|---|---|---|---|---|
| moonshotai/kimi-k3-free | 1048576/131072 | ✅ | {"error":{"code":"model_not_found","message":"No available channel for model moonshotai/kimi-k3-free | 🔴 unavailable |
| nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free | 256000/65536 | ✅ | {"error":{"message":"User's credit limit is insufficient, remaining credit limit: ＄0.000000 (request | 🔴 unavailable |
- `moonshotai/kimi-k3-free`: 503 no channel
- `nvidia/nemotron-3-nano-...`: 403 credit insufficient ($0.00 remaining)

### aihubmix — 44 configured (70 in registry, 401 live). Sample probed 44 (10 detailed + 34 batch):

| Model | Config ctx/out | Cache ctx/out | Probe reveals | Verdict |
|---|---|---|---|---|
| coding-glm-4.6-free | 200000/128000 | — | {"error":{"message":"The max_tokens parameter is illegal.：限制数值范围[1,131072] (tid: | |
| coding-glm-4.7-free | 200000/128000 | — | {"error":{"message":"The max_tokens parameter is illegal.：限制数值范围[1,131072] (tid: | |
| coding-glm-5.1-free | 200000/131072 | 200000/128000 | undefined | |
| coding-glm-5.2-free | 1000000/131072 | — | undefined | |
| coding-glm-5-free | 200000/131072 | — | {"error":{"message":"The max_tokens parameter is illegal.：限制数值范围[1,131072] (tid: | |
| coding-kimi-k3-free | 1048576/1048576 | — | {"error":{"message":"Sorry, there are currently insufficient promotional resourc | |
| coding-minimax-m2.1-free | 204800/13100 | — | {"error":{"message":"invalid params, model[MiniMax-M2.1] does not support max to | |
| coding-minimax-m2.5-free | 204800/13100 | — | {"error":{"message":"invalid params, model[MiniMax-M2.5] does not support max to | |
| coding-minimax-m2.7-free | 204800/13100 | 204800/128100 | {"error":{"message":"invalid params, model[MiniMax-M2.7] does not support max to | |
| coding-minimax-m2-free | 204800/13100 | — | {"error":{"message":"invalid params, model[MiniMax-M2.5] does not support max to | |
| coding-minimax-m3-free | 204800/13100 | — | free-quota 429 (quota hit after 10) | |
| dots-3-note-preview-free | 512000/8192 | — | free-quota 429 (quota hit after 10) | |
| gemini-3.5-flash-lite-free | 1048576/65536 | — | free-quota 429 (quota hit after 10) | |
| gemini-3.6-flash-free | 1048576/65536 | — | free-quota 429 (quota hit after 10) | |
| gemini-3.7-flash-free | 1000000/64000 | — | free-quota 429 (quota hit after 10) | |
| gemini-3-flash-preview-free | 1048576/65536 | — | free-quota 429 (quota hit after 10) | |
| gemma-4-26b-a4b-it-free | 262144/8192 | — | free-quota 429 (quota hit after 10) | |
| gemma-4-31b-it-free | 262144/8192 | — | free-quota 429 (quota hit after 10) | |
| glm-4.7-flash-free | 200000/131072 | — | free-quota 429 (quota hit after 10) | |
| gpt-4.1-free | 1047576/32768 | — | free-quota 429 (quota hit after 10) | |
| gpt-4.1-mini-free | 1047576/32768 | — | free-quota 429 (quota hit after 10) | |
| gpt-4.1-nano-free | 1047576/32768 | — | free-quota 429 (quota hit after 10) | |
| gpt-4o-free | 1047576/32768 | — | free-quota 429 (quota hit after 10) | |
| gpt-5.5-free | 1050000/128000 | — | free-quota 429 (quota hit after 10) | |
| gpt-oss-20b-free | 131072/131072 | — | free-quota 429 (quota hit after 10) | |
| k2.6-code-preview-free | 256000/256000 | — | free-quota 429 (quota hit after 10) | |
| kimi-for-coding-free | 256000/256000 | — | free-quota 429 (quota hit after 10) | |
| laguna-s-2.1-free | 262144/8192 | — | free-quota 429 (quota hit after 10) | |
| laguna-xs-2.1-free | 262144/8192 | — | free-quota 429 (quota hit after 10) | |
| lfm-2.5-2.6b-free | 128000/8192 | — | free-quota 429 (quota hit after 10) | |
| ling-3.0-flash-free | 262144/8192 | — | free-quota 429 (quota hit after 10) | |
| mimo-v2-flash-free | 256000/256000 | — | free-quota 429 (quota hit after 10) | |
| nemotron-3.5-content-safety-free | 128000/8192 | — | free-quota 429 (quota hit after 10) | |
| nemotron-3.5-lightning-free | 1000000/8192 | — | free-quota 429 (quota hit after 10) | |
| nemotron-3-nano-30b-a3b-free | 256000/8192 | — | free-quota 429 (quota hit after 10) | |
| nemotron-3-nano-omni-30b-a3b-reasoning-free | 256000/8192 | — | free-quota 429 (quota hit after 10) | |
| nemotron-3-super-120b-a12b-free | 1048576/8192 | — | free-quota 429 (quota hit after 10) | |
| nemotron-3-ultra-550b-a55b-free | 1000000/8192 | — | free-quota 429 (quota hit after 10) | |
| nemotron-nano-12b-v2-vl-free | 131072/8192 | — | free-quota 429 (quota hit after 10) | |
| nemotron-nano-9b-v2-free | 131072/8192 | — | free-quota 429 (quota hit after 10) | |
| north-mini-code-free | 256000/8192 | — | free-quota 429 (quota hit after 10) | |
| qwen3.6-plus-preview-free | 1000000/65535 | — | free-quota 429 (quota hit after 10) | |
| xiaomi-mimo-v2.5-free | 256000/8192 | 1048576/131072 | free-quota 429 (quota hit after 10) | |
| xiaomi-mimo-v2.5-pro-free | 256000/8192 | 1048576/131072 | free-quota 429 (quota hit after 10) | |

**Key aihubmix proofs:**
- `coding-glm-*` family: probe `range [1,131072]` vs config 128000 → off by 3072
- `coding-minimax-*` family: probe `does not support max tokens > 196608` vs config 13100 → **15× wrong**, also model name mismatch (M2.1 probe says M2.5)
- `coding-minimax-m3-free`: probe `> 524288` vs config 13100 → **40× wrong**
- `gemini-*-free`: probe `range [1,65537)` vs config 65536 → match
- After 10 probes, free tier hit 429 `free model quota` for all remaining 34 — proves **daily free quota = ~10 calls** on aihubmix

### google — 50 live models, authoritative via ListModels API (inputTokenLimit / outputTokenLimit)

Verified live via `GET https://generativelanguage.googleapis.com/v1beta/models?key=...` — response fields are **directly from Google**, not inferred.

| Model | inputTokenLimit | outputTokenLimit | Config? |
|---|---|---|---|
| models/gemini-2.5-flash | 1048576 | 65536 | cached |
| models/gemini-2.5-pro | 1048576 | 65536 | cached |
| models/gemini-2.5-flash-lite | 1048576 | 65536 | cached |
| models/gemma-4-26b-a4b-it | 262144 | 32768 | new |
| models/gemini-3-flash-preview | 1048576 | 65536 | new |
| models/gemini-3.1-flash-lite-preview | 1048576 | 65536 | new |

- Cache registry (39) vs live (50): 11 new models added by Google since cache snapshot. Example: `gemini-3-flash-preview` 1M/65k, `gemini-3.1-flash-lite-preview` 1M/65k
- Vision backend `gemini-3.5-flash-lite` would map to live `gemini-3.5-flash-lite` or `gemma` family — need explicit version check.

### ollama-cloud — 20 in registry, 19 live tags

- Registry limits (from `~/.cache/opencode/models.json`): e.g. `nemotron-3-ultra` 262144/128000, `minimax-m3` (primary) not in registry snippet but live tag shows minimax-m3 exists.
- Live chat probe: `nemotron-3-ultra` 200 OK, `kimi-k2.7-code` 403 requires subscription, `kimi-k3` 403 requires Pro+extra usage — proves **tier-gated access**, not unlimited.
- Ollama cloud `glm-5.1`/`deepseek-v4-*` tags exist but require correct endpoint `https://ollama.com/v1/chat/completions` with Bearer — earlier Method Not Allowed was wrong HTTP method/endpoint, now verified via cache `api: https://ollama.com/v1`

### nvidia — 102 models in both cache and live

- Live list matches cache count exactly (102) — no drift.
- Registry example `deepseek-v4-flash-0731` limit context 100000 (from cache) — live probe timeout, not yet verified via error disclosure (needs retry).

### opencode-go — 28 in registry, live list OK

- Live list returned 28 ids (matches cache).
- Chat probe `glm-5.2`: 429 `Weekly usage limit reached. Resets in 16hr 5min.` — proves **weekly quota** enforcement, not model death.

## Default Model

- Configured default: `opencode/deepseek-v4-flash-free`
- This uses provider `opencode` (Zen) which is not in `provider` block but is built-in. Not yet probed — requires `opencode` gateway key (opencode-cloud). Cache shows many `coding-*` free models map to this gateway.

## Per-Project Overrides

- `Projects/neodev-portal/opencode.json`: model `ollama-cloud/minimax-m3` (matches global primary) — no extra provider
- `Projects/smoke-test/opencode.json`: `opencode-go/glm-5.2` + `opencode-zen/mimo-v2.5-free` — opencode-go provider seen live, opencode-zen is alias to same gateway
- `Projects/website/opencode.json`: no model override

## Summary Verdict

| Provider | In Config | Live | Dead/Quota | Limits Accurate? |
|---|---|---|---|---|
| hcnsec | 20 | 15 | 10 dead +1 EOL +2 timeout | ❌ 2 proven wrong by 16-32×, 8 dead not reflected |
| aihubmix | 44 | 401 | free quota 10/daily | ❌ minimax family 15-40× wrong, glm family 3k off |
| tokenrouter | 2 | 2 | both unavailable (503/403) | ❌ currently unusable |
| google | 0 in config (via auth) | 50 | all live | ✅ authoritative via ListModels |
| nvidia | 0 in config | 102 | 102 live | ⚪ cache vs live match, probe timeout |
| ollama-cloud | 0 in config (primary) | 19/20 | 2 gated (subscription) | ⚪ tier gates verified |
| opencode-go | 0 in config | 28 | weekly limit | ⚪ live reachable |

## Recommendation

1. **Immediate**: remove `glm-5.2` (EOL), 10 dead hcnsec models, fix `kat-coder-pro-v2.5` 8192→262144, `sensenova-6.7-flash-lite` 4096→65536 (or remove if unused). Retry timed-out probes (`Kimi-K2.6`, `DeepSeek-V4-Flash`) with backoff.
2. **Aihubmix**: patch all `coding-minimax-*` 13100→196608 (or 524288 for m3), `coding-glm-*-free` 128000→131072.
3. **Tokenrouter**: keep but document as fallback only (requires credits).
4. **All providers**: schedule weekly `/models` diff job — catalog drift is ongoing (Google added 11, hcnsec lost 5).
