# ADR-012: Deep-health transplant + cofounder-report seal rotation (2026-09-18)

## Status

Accepted. Executed 2026-09-18 ~09:45–11:35 UTC by Soham (NeoDev) + agent, build mode, per-step verify.

## Context

`hermes-stack-deep-health` failed every 15 min with `expected=[clickup,cofounder-report,cua-driver,graphify] configured=[clickup,cua-driver,graphify]`. Gateway reads shared `/srv/hermes/data/config.yaml` (3 tools); the 4th block lived only in `ayden`/`dev` profiles. After transplanting, the 4th server refused boot: its portable-certification bundle pinned 3 paused jobs to Aug-17 baselines (monthly ran 2→6 since, two pause-reasons changed). The Aug-17 RSA seal-maker is unrecoverable (not on VPS, no reachable PC).

## Decision

1. Transplant ayden `config.yaml` lines 714–758 after shared line 718 via pure text splice (never YAML re-serialize): diff +45/−0, tmp+fsync+atomic rename. Gateway reload deferred — the check spawns fresh each run, no restart needed.
2. Rotate the bundle seal (RSA-3072, root-only `600` at `/srv/hermes/secrets/cofounder-report-rot-sep18.key`, SPKI `3b86116a…2512c`): refresh 3 snapshot entries from live truth, re-emit manifest (3 baselines + auth + record_keys only), sign PKCS1v15-SHA256, replace `PUBLIC_MODULUS`/`EXPECTED_PUBLIC_KEY_SPKI_SHA256` (old kept as retired comments), keep all `.bak-origin-rot-sep18` files. Rollback = restore backups (~60s).
3. No forgery/bypass alternatives were acceptable (faking jobs backwards, weakening the probe, or silencing the guard all manufacture fake-green).

## Verification (all green before declaring done)

- R0: rebuilt old key from embedded modulus → SPKI recompute equals pinned `1986e726…` (scheme proven pre-generation).
- R1: openssl + independent Python lib agree on new SPKI; key `600` root.
- R3: full bundle verify + job-policy PASS using the system's own checker code, offline, pre-install.
- R5: live timer PASS 11:35 UTC — 4/4 servers connected, tools 37/26/43/12 exact, graph 5129/4971, 1 read-only call, 0 external.
- One self-inflicted bug found and fixed same session: dropped `, 16` radix in generated modulus block (caught via MCP stderr log, fixed, import-verified).

## Consequences

- Deep-health is the drift canary: any future shared-config/profile drift fails loudly in 15 min.
- Gateway _serving_ pickup of the 4th server needs a future reload/restart (maintenance window); the check itself is independent.
- Annual seal rotation recommended. Private key stays VPS-root-only, never in git/chat.
- Job-2 (2-way sync) separate track: wrapper pin stale (`2fb4e4…` vs `7fc2c0…`), fix = SLOT pin update + gateway restart in 12:15 window; image bakes stale pin — rebuilds must include the fix or it regresses (handover note).
