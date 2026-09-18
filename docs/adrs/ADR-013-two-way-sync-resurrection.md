# ADR-013: 2-way sync watchdog resurrection (2026-09-19 window)

## Status

Accepted. Executed 2026-09-18 19:30 → 22:40 UTC by Soham (NeoDev) + agent, clients-off window, per-step verify.

## Context

Job `0610351d0281` (ClickUp inventory sync watchdog, every 2 min) OFF since Sep-04 (hand-fired runs correctly refused code 78, then wrongly left disabled). Re-arm exposed a chain of stale pins, each proven by the machine's own fail-closed refusals stepping forward exactly one gate per cycle.

## Chain (each proven live, each fixed, zero new-bug surface)

1. Wrapper pin stale (`2fb4e4…` Aug-09 vs live `7fc2c0…` Aug-19) → updated SLOT pin (7 slotupdate precedents), gateway restart #1. Digest gate passes.
2. Stale slot (next_run 2026-09-04) → re-anchored to grid. Slot gate passes.
3. Lease policy zero-manifest → minted candidate manifest (transparent content, user-approved) + activation lease mirroring GD-lane format; pinned manifest sha in policy. Lease gate passes.
4. Wrapper candidate/normalized zeros → ported to live values. Candidate gate passes.
5. Wrapper path duality (`/opt/data` vs `/srv/hermes/data`, same inode) + Windows-era pins → Linux port in batches: HERMES_HOME, venv site-packages, python exe+hash (`17b78e0a…`), parent exe+argv (`hermes gateway run --replace`), 5 artifact hashes, generation hash (replicated via AST+compile, `93847a30…`).
6. Two self-inflicted bugs found and fixed same night: dropped `, 16` radix (Job-1 file, caught via stderr log) and a forced trailing comma turning a hash str into a 1-tuple (caught via offline artifact replay).
7. Lease capacity discovery: `remaining_natural_ticks ≤ 2` always — each minted lease covers exactly 2 fires; no auto-replenish path exists. Continuous operation needs a minting practice (Trillex architecture decision).
8. Schedule truth: expr hours evaluate on BKK wall digits → natural grid is BKK 00:xx + 11:00–23:59 (matches Almog's activity window); BKK 01:00–10:59 sleeps. My hand re-anchors caused all off-grid fires; grid itself is correct, next_run 04:00 UTC proper.

## Proof

Fire at slot 22:10 UTC completed ok AND did real work: picked up a live ClickUp task_comment event (task 86eye6xr7), queued with receipt, dry_run false. Morning lease minted for 11:00/11:02 BKK (04:00/04:02 UTC).

## Consequences

- Steady state = Trillex decision: windowed leases (GD precedent) vs lane redesign (raise per-lease capacity) vs unprotected lane. Agent must NOT loosen lease bounds unilaterally.
- Image bakes stale wrapper pin: rebuilds must include current pins or regress silently.
- Transcription discipline (learned): never hand-copy hashes into edits; machine-derive + assert, or pattern-match existing bytes. All three slip-ups caught pre-write or same-cycle by gates.
- tmp scripts cleaned; backups kept (jobs rearm/repause/window/slot series, scheduler window baks, wrapper const/port baks, manifest/sig origin baks).
