# ADR-006: Simplify TokenRouter Model Display Names

- **Status:** Accepted
- **Date:** 2026-08-01
- **Deciders:** Workspace owner
- **Commit:** 9b11b9d (feat), merged directly to main (fast-forward)

## Context

When the TokenRouter provider was added (ADR-005, 2026-07-31), the two
free-tier models were registered with their raw model IDs as the `name`
field:

- `moonshotai/kimi-k3-free` had `name: "moonshotai/kimi-k3-free"`
- `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` had
  `name: "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free"`

The `/models` TUI picker showed these raw identifiers — the second one was
64 characters long with slashes, hyphens, and colons, making the picker
unreadable. This reversed a prior user decision recorded in
`session-newai5.md` (lines 694-715) where raw IDs were initially chosen.
The decision was reversed deliberately: clean labels are better for the TUI
picker, and the model ID (JSON key) remains the API routing key.

This mirrors the same pattern applied to hcnsec models in ADR-003
(2026-07-31): `name` field is display-only, JSON key is the routing key.

## Decision

Set `name` fields to clean Title Case labels with spaces, no vendor prefixes,
bare `Free` suffix (no parentheses):

- `moonshotai/kimi-k3-free` -> `name: "Kimi K3 Free"`
- `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` -> `name:
"Nemotron 3 Nano Omni 30B Free"`

Matches the naming convention from ADR-003: bare `Free` suffix (no parens),
no vendor prefixes, Title Case with spaces.

### Changes in opencode.json

- `provider.tokenrouter.models."moonshotai/kimi-k3-free".name` ->
  "Kimi K3 Free"
- `provider.tokenrouter.models."nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free".name`
  -> "Nemotron 3 Nano Omni 30B Free"

### Untouched (intentionally)

- Model ID JSON keys (`moonshotai/kimi-k3-free`,
  `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free`) — these are the API
  routing keys sent to TokenRouter; changing them would break model resolution
- `limit.context` and `limit.output` values — unchanged (1048576/131072 for
  Kimi K3, 256000/65536 for Nemotron)
- `provider.tokenrouter.options` — no change to baseURL or apiKey
- `TOKENROUTER_API_KEY` env var — unchanged

## Alternatives Considered

1. **Keep raw IDs as names** — rejected: the Nemotron ID is 64 characters;
   the TUI picker truncated it and was unreadable. This was the original
   choice (per session-newai5.md lines 694-715) and was reversed for good UX
   reasons.
2. **Use vendor-prefixed names (e.g., "Moonshot Kimi K3 Free")** — rejected:
   matches ADR-003 convention of no vendor prefixes; the provider name
   "TokenRouter" is already shown in the picker context.
3. **Use parentheses for Free suffix (e.g., "Kimi K3 (Free)")** — rejected:
   matches ADR-003 convention of bare `Free` suffix without parentheses.
   Consistency across providers matters more than personal preference on one
   model.

## Consequences

- **Positive:** TUI `/models` picker shows clean labels; matches hcnsec naming
  convention from ADR-003.
- **Negative:** Cosmetic divergence between JSON keys (vendor-prefixed, long)
  and display names (clean, short). This is expected and documented — keys
  are for routing, names are for humans.
- **Neutral:** No behavioral impact; opencode resolves models by the JSON
  key, not the name field.

## Evidence

- `opencode debug config` exits 0 with valid JSON after the rename
- 6-point verification passed: 2 name fields match expected values, 2 JSON
  keys unchanged, 2 limit blocks unchanged
- Backup at `.opencode/backups/pre-tokenrouter-name-simplify-2026-08-01`
  (SHA256 verified)

## Verification

```powershell
# 1. Confirm the 2 new display names
$oc = Get-Content opencode.json -Raw | ConvertFrom-Json
$oc.provider.tokenrouter.models.'moonshotai/kimi-k3-free'.name  # expect: Kimi K3 Free
$oc.provider.tokenrouter.models.'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free'.name
# expect: Nemotron 3 Nano Omni 30B Free

# 2. Confirm JSON keys unchanged
$oc.provider.tokenrouter.models.PSObject.Properties.Name -contains 'moonshotai/kimi-k3-free'
# expect: True

# 3. Config still parses
opencode debug config
```

## References

- `AGENTS.md` — TokenRouter models table
- ADR-003 — same naming convention applied to hcnsec models (precedent)
- ADR-005 — TokenRouter provider addition (this ADR refines the name field
  only)
