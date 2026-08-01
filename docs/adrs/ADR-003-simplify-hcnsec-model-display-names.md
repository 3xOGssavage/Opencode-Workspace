# ADR-003: Simplify hcnsec Model Display Names

- **Status:** Accepted
- **Date:** 2026-07-31
- **Deciders:** Workspace owner
- **Commit:** 5c67a1d (feat), merged at 1c5835a

## Context

The hcnsec provider (`https://api.hcnsec.cn/v1`) was added to
`opencode.json:provider` with 20 models. Initially, each model's `name` field
was set to the raw model ID (the JSON key), e.g., `"Kimi-K2.6"` had
`name: "Kimi-K2.6"`, `"MiniMax-M3"` had `name: "MiniMax-M3"`. This meant the
TUI model picker (`/models`) showed raw API identifiers rather than
human-readable labels. For 5 models with complex or vendor-prefixed IDs, the
raw form was especially unhelpful for the user:

| Model ID (JSON key) | Old name (was raw ID) | New name (display label) |
| ------------------- | --------------------- | ------------------------ |
| `auto`              | `auto`                | Auto (smart routing)     |
| `MiniMax-M3`        | `MiniMax-M3`          | MiniMax M3               |
| `MiniMax-M2.7`      | `MiniMax-M2.7`        | MiniMax M2.7             |
| `Kimi-K2.6`         | `Kimi-K2.6`           | Kimi K2.6                |
| `DeepSeek-V4-Pro`   | `DeepSeek-V4-Pro`     | DeepSeek V4 Pro          |

The `name` field in opencode's provider config is display-only — it controls
the TUI picker label. The model ID (the JSON key under `models`) is the API
routing key and must not change. This was confirmed by opencode documentation
and three independent blog sources.

## Decision

Set `name` fields to clean Title Case labels with spaces, no vendor prefixes,
no hyphens. Match the hcnsec naming convention already established in
AGENTS.md's model table (which used "GLM 4.7", "Kimi K2.6" etc. in prose).
The pattern: `Free` suffix is bare (no parentheses), annotations in
parentheses where needed, no vendor name prefixes.

### Changes in opencode.json

- `provider.hcnsec.models.auto.name` -> "Auto (smart routing)"
- `provider.hcnsec.models.MiniMax-M3.name` -> "MiniMax M3"
- `provider.hcnsec.models.MiniMax-M2.7.name` -> "MiniMax M2.7"
- `provider.hcnsec.models.Kimi-K2.6.name` -> "Kimi K2.6"
- `provider.hcnsec.models.DeepSeek-V4-Pro.name` -> "DeepSeek V4 Pro"

### Untouched (intentionally)

- Model ID JSON keys (e.g., `Kimi-K2.6`, `MiniMax-M3`) — these are the API
  routing keys sent to hcnsec; changing them would break model resolution
- Other 15 hcnsec model names that were already acceptable (e.g., `glm-4.7`
  had `name: "GLM 4.7"` which was already clean)
- `provider.hcnsec.options` — no change to baseURL or apiKey
- `auth.json` — hcnsec key stored in `HCNSEC_API_KEY` env var, not in auth.json

## Alternatives Considered

1. **Keep raw IDs as names** — rejected: poor UX, the TUI picker is the primary
   model selection interface; raw IDs with hyphens and dots are hard to scan.
2. **Use vendor-prefixed names (e.g., "Moonshot Kimi K2.6")** — rejected: adds
   noise without adding signal; the provider name "hcnsec" is already shown in
   the picker context. Matches AGENTS.md convention of no vendor prefixes in
   the table.
3. **Rename the JSON keys too (e.g., `Kimi-K2.6` -> `kimi-k2.6`)** — rejected:
   dangerous, the keys are the API routing identifiers; changing them would
   break every `hcnsec/<model-id>` reference in agent configs and AGENTS.md.

## Consequences

- **Positive:** TUI `/models` picker shows clean human-readable labels; matches
  AGENTS.md prose convention.
- **Negative:** Cosmetic divergence between JSON keys (hyphenated, vendor-style)
  and display names (spaced, clean). This is expected and documented — keys
  are for routing, names are for humans.
- **Neutral:** No behavioral impact; opencode resolves models by the JSON key,
  not the name field.

## Evidence

- `opencode debug config` exits 0 with valid JSON after the rename
- 14/14 assertions passed in the verification suite (5 name fields match
  expected values, 5 JSON keys unchanged, 4 other fields unchanged)
- Confirmed via opencode docs: `name` field is display-only; model ID (JSON
  key) is the routing key

## Verification

```powershell
# 1. Confirm the 5 new display names
$oc = Get-Content opencode.json -Raw | ConvertFrom-Json
$oc.provider.hcnsec.models.auto.name              # expect: Auto (smart routing)
$oc.provider.hcnsec.models.'MiniMax-M3'.name      # expect: MiniMax M3
$oc.provider.hcnsec.models.'MiniMax-M2.7'.name    # expect: MiniMax M2.7
$oc.provider.hcnsec.models.'Kimi-K2.6'.name        # expect: Kimi K2.6
$oc.provider.hcnsec.models.'DeepSeek-V4-Pro'.name  # expect: DeepSeek V4 Pro

# 2. Confirm JSON keys unchanged
$oc.provider.hcnsec.models.PSObject.Properties.Name -contains 'Kimi-K2.6'  # True

# 3. Config still parses
opencode debug config
```

## References

- `AGENTS.md` — hcnsec model table (lines ~26-56)
- opencode documentation — provider config `name` field is display-only
