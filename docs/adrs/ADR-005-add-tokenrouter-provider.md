# ADR-005: Add TokenRouter as 4th Provider (Tier-3 Experimental)

- **Status:** Accepted
- **Date:** 2026-07-31
- **Deciders:** Workspace owner
- **Commit:** 98718d2 (bundled with addy- rename; tokenrouter provider block
  added to opencode.json)

## Context

The workspace had 3 providers accessible via `/models`:

1. `ollama-cloud` (primary, in `auth.json`) — minimax-m3 for build/plan
2. `hcnsec` (in `opencode.json:provider`) — 20 models, subagents + alternates
3. `google` (in `auth.json`) — Gemini 3.5-flash-lite for vision-tool MCP

TokenRouter (`https://api.tokenrouter.com/v1`) is an AI model routing proxy
that offers free-tier access to several models including Moonshot Kimi K3 and
NVIDIA Nemotron 3 Nano Omni. A 4th provider was desired to:

- Evaluate Kimi K3 (1M context window) without consuming hcnsec quota
- Access Nemotron 3 Nano Omni for experimental reasoning tasks
- Diversify the model pool for adversarial review scenarios

An API key (51 chars, `sk-2NW2...73er`) was obtained and set as the
`TOKENROUTER_API_KEY` User env var. The provider was added to
`opencode.json:provider` (NOT `auth.json`) because TokenRouter uses the
`@ai-sdk/openai-compatible` npm package, same as hcnsec — both are configured
in the `provider` block, not via opencode's built-in auth.json mechanism.

## Decision

Add TokenRouter as the 4th provider in `opencode.json:provider`, with 2
free-tier models. Do NOT add it to `auth.json` — it uses the same
`@ai-sdk/openai-compatible` pattern as hcnsec, configured in the `provider`
block.

### Tier classification

TokenRouter is classified **Tier-3 experimental**:

- Small routing proxy (not a direct model provider like hcnsec or
  ollama-cloud)
- Free-tier quota is unstated and may move without notice (per apidog.com
  Kimi K3 analysis: "Moonshot does not publish a fixed free-tier token
  quota, and that is the point: it can move")
- No production agent depends on it — all 17 agents use
  `hcnsec/Kimi-K2.6` or `ollama-cloud/minimax-m3`
- Access is opt-in via `/models` with `tokenrouter/<model-id>` format
- Fallback to hcnsec if TokenRouter is unavailable

### Changes in opencode.json

Added `provider.tokenrouter` block:

- `npm`: `@ai-sdk/openai-compatible`
- `name`: `TokenRouter`
- `options.baseURL`: `https://api.tokenrouter.com/v1`
- `options.apiKey`: `{env:TOKENROUTER_API_KEY}`
- `models`:
  - `moonshotai/kimi-k3-free`: name "Kimi K3 Free", limit.context 1048576,
    limit.output 131072
  - `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free`: name
    "Nemotron 3 Nano Omni 30B Free", limit.context 256000, limit.output 65536

### Untouched (intentionally)

- `auth.json` — TokenRouter is NOT in auth.json; it lives in
  `opencode.json:provider` alongside hcnsec. The key is in the
  `TOKENROUTER_API_KEY` env var.
- All 17 agent `model` fields — no agent points to `tokenrouter/*` models.
  All use `hcnsec/Kimi-K2.6` or `ollama-cloud/minimax-m3`.
- Child project configs — no child has a `tokenrouter` block. Children
  inherit the parent provider via `OPENCODE_CONFIG` env var (layer 3
  precedence). Zero child edits needed.
- `HCNSEC_API_KEY` and other env vars — no change.

## Alternatives Considered

1. **Add TokenRouter to auth.json instead of opencode.json:provider** —
   rejected: TokenRouter uses `@ai-sdk/openai-compatible`, same as hcnsec.
   Both are configured in the `provider` block, not via auth.json's built-in
   provider mechanism. Adding to auth.json would require a different config
   path and break the established pattern.
2. **Skip TokenRouter, use hcnsec for Kimi K3** — rejected: hcnsec does not
   offer Kimi K3 (only K2.6). TokenRouter is the only free-tier source for
   K3 in this workspace.
3. **Add TokenRouter as Tier-2 (trusted)** — rejected: the free-tier quota is
   unstated and the proxy is small. Classifying as Tier-2 would imply
   production agents can depend on it, which is not the case. Tier-3
   experimental is the honest classification.
4. **Add all TokenRouter free-tier models** — rejected: only 2 models (Kimi
   K3 Free, Nemotron 3 Nano Omni Free) are relevant to this workspace's use
   cases. Adding more would clutter the `/models` picker without benefit.

## Consequences

- **Positive:** 2 new models accessible via `/models` for evaluation: Kimi K3
  Free (1M context) and Nemotron 3 Nano Omni Free (256K context). No hcnsec
  quota consumed. Live API test returned HTTP 200 OK (9.8s, 91 prompt + 44
  completion tokens).
- **Negative:** TokenRouter free-tier quota may move or shrink without notice.
  No production agent depends on it (by design). If TokenRouter becomes
  unavailable, agents continue on hcnsec/ollama-cloud — no breakage.
- **Neutral:** Provider count increases to 4 (ollama-cloud, hcnsec, google,
  tokenrouter). The `/models` picker shows 22 models total (1 ollama-cloud +
  20 hcnsec + 2 tokenrouter; google is vision-only).

## Evidence

- `opencode debug config` exits 0 with tokenrouter block in resolved config
- Live API test: HTTP 200 OK with valid completion (9.8s, 91 prompt + 44
  completion tokens)
- Free-tier quota analysis: apidog.com confirms Kimi K3 free-tier quota is
  unstated and movable
- No agent config references `tokenrouter/` — confirmed by
  `Select-String -Path opencode.json -Pattern 'tokenrouter/'` returning 0
  hits in agent blocks

## Verification

```powershell
# 1. Confirm tokenrouter provider block exists
$oc = Get-Content opencode.json -Raw | ConvertFrom-Json
$oc.provider.tokenrouter.options.baseURL  # expect: https://api.tokenrouter.com/v1
$oc.provider.tokenrouter.models.PSObject.Properties.Count  # expect: 2

# 2. Confirm no agent points to tokenrouter
Select-String -Path opencode.json -Pattern '"model":\s*"tokenrouter/'  # expect: 0 hits

# 3. Confirm TOKENROUTER_API_KEY is set
[System.Environment]::GetEnvironmentVariable('TOKENROUTER_API_KEY', 'User').Length  # expect: 51

# 4. Config parses
opencode debug config
```

## References

- apidog.com — Kimi K3 free-tier quota analysis
- `AGENTS.md` — TokenRouter models table (added in docs sync)
- `ENTERPRISE_OPENCODE_SETUP.md` — provider table (TokenRouter row added in
  docs sync)
