# Post-Install Note — 2026-08-02

## Event: opencode v1.18.11 upgrade + parallel subagent verification

**Date:** 2026-08-02
**Scope:** Binary upgrade + env var restoration + documentation sync across 3 files + memory entity
**Risk profile:** Low — single npm package upgrade on a bugfix release; env var restoration to a previously-working value; documentation-only changes to AGENTS.md and ENTERPRISE_OPENCODE_SETUP.md.

---

## What was done

### 1. Upgraded opencode from v1.18.10 to v1.18.11

**Command:**

```
npm install -g opencode-ai@1.18.11 --force
```

**Why v1.18.11:** v1.18.10 had a bug where subagent calls returned zero output tokens (`finish_reason: "unknown"`, `t_out=0`) due to interleaved reasoning field handling in provider configs. v1.18.11 fixes this class of bug. This was the upstream cause of the zero-output issue observed with `hcnsec/Kimi-K2.6` subagent dispatches.

**Verification:**

- `opencode --version` → `1.18.11`
- `npm list -g opencode-ai` → `opencode-ai@1.18.11`
- `package.json` in npm global → `"version": "1.18.11"`
- User restarted all opencode instances after install

### 2. Restored `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`

**Command:**

```powershell
setx OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS "true"
```

**Why:** This User env var gates the `background` parameter on the `task` tool, enabling parallel subagent dispatch via the orchestrator. It was previously set during the 2026-07-27 subagent migration but had been removed as a mitigation for the v1.18.10 zero-output bug. With v1.18.11 fixing the bug, the env var is restored.

**Verification:**

- `[System.Environment]::GetEnvironmentVariable("OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS", "User")` → `"true"`
- Process scope also `true` after opencode restart

### 3. 2-task parallel subagent test PASSED

**Test:** Dispatched 2 `explorer` background subagents in parallel via the `task` tool:

- Task 1: "Read AGENTS.md and report its section count" → returned 427 lines, 19 sections, first section = "Role"
- Task 2: "List all .md files in .opencode/agents/" → returned 7 files

**Result:** Both subagents returned non-zero output with real data. The v1.18.10 zero-output bug is confirmed FIXED on v1.18.11 + `hcnsec/Kimi-K2.6`.

### 4. Removed v1.18.10 regression table from AGENTS.md

**What:** Deleted the version table, failure modes, and WARNING block from `AGENTS.md` → "Parallel background subagent workflow" → "Known issues and mitigations" (previously ~40 lines). The dynamic enum note now flows directly into the parallel workflow section.

**Why:** The regression table was a mitigation reference for v1.18.10's broken state. With v1.18.11 fixing the bug, the table is obsolete.

### 5. Updated AGENTS.md prerequisites

**What:** Changed "v1.18.9 (NOT v1.18.10)" to "v1.18.11+" with a description of the v1.18.10→v1.18.11 fix.

### 6. Added v1.18.11 changelog note to AGENTS.md

**What:** Added a note after the known-issues table explaining what v1.18.11 fixes and that the bug is "likely fixed but UNVERIFIED on hcnsec/Kimi-K2.6 — run a 2-task parallel test after restart before relying on it."

### 7. Clarified `oh-my-openagent#2954`

**What:** Changed `#2954` to `oh-my-openagent#2954` in the AGENTS.md known-issues table to disambiguate from `anomalyco/opencode` issues.

### 8. Synced documentation across 3 files

#### AGENTS.md (2 edits)

- L434: `v1.18.9 binary` → `v1.18.11 binary` (lossless compression section)
- L364: Appended v1.18.11 upgrade + parallel subagent verification to the stale-reference list in the ENTERPRISE_OPENCODE_SETUP.md reference entry + added ADR-007 forward reference

#### ENTERPRISE_OPENCODE_SETUP.md (6 edits)

- L1710: `v1.18.9 binary` → `v1.18.11 binary` (compaction V2 note)
- L645: Template orchestrator `mode: "subagent"` → `mode: "primary"` (re-deployment fix — a fresh machine would have had broken parallel subagent dispatch)
- After L1207: Added 3 new rows to env var table (`OPENCODE_CONFIG`, `OPENCODE_CONFIG_DIR`, `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS`)
- After L1267: Added Section 12 step 10: "Run a 2-task parallel subagent test" with detailed instructions
- After L1810: Added Post-snapshot item 12 with ADR-007 reference and full change summary
- L1275: Verification checklist `>= 1.0.0` → `>= 1.18.11` with note about v1.18.10 zero-output bug

#### memory.jsonl (1 append)

- Added `opencode-v1.18.11-upgrade-2026-08-02` config-state entity with session observations + D11 known-issue note (L20 counting ambiguity, pre-existing, out of scope this session)

### 9. Temp file cleanup

**What:** Deleted 3 temp files created during verification:

- `Projects/sqlite-query/` (test directory)
- `opencode-readonly-copy.db-shm` (SQLite shared-memory file)
- `opencode-readonly-copy.db-wal` (SQLite write-ahead log)

### 10. No config file modifications

The following files were NOT modified (zero blast radius):

- `opencode.json`
- `oh-my-opencode-slim.json`
- `opencode.jsonc` (global)
- `auth.json`
- Any agent definition files in `.opencode/agents/`
- Any command files in `.opencode/commands/`
- Any skill files

---

## Files changed

| File                                                              | Change                                                                         | Lines affected                          |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------ | --------------------------------------- |
| `F:\CD\Opencode\AGENTS.md`                                        | v1.18.9→v1.18.11 + stale-ref append                                            | L364, L434                              |
| `F:\CD\Opencode\ENTERPRISE_OPENCODE_SETUP.md`                     | v1.18.9→v1.18.11 + template fix + env var rows + step 10 + item 12 + checklist | L645, L1207, L1267, L1275, L1710, L1810 |
| `F:\CD\Opencode\.opencode\memory.jsonl`                           | Append new entity                                                              | +1 line                                 |
| `F:\CD\Opencode\POST-INSTALL-NOTE-2026-08-02-v1.18.11-upgrade.md` | New file (this file)                                                           | New                                     |

---

## Verification results (13-point check)

| #   | Check                                                              | Result |
| --- | ------------------------------------------------------------------ | ------ |
| 1   | `opencode --version` returns 1.18.11                               | PASS   |
| 2   | `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` User env var = "true" | PASS   |
| 3   | No `v1.18.10` regression markers in AGENTS.md                      | PASS   |
| 4   | `v1.18.11+` in AGENTS.md prerequisites                             | PASS   |
| 5   | v1.18.11 changelog note present in AGENTS.md                       | PASS   |
| 6   | `oh-my-openagent#2954` clarified in AGENTS.md                      | PASS   |
| 7   | `opencode.json` valid JSON                                         | PASS   |
| 8   | `oh-my-opencode-slim.json` valid JSON                              | PASS   |
| 9   | `AGENTS.md` L434 = `v1.18.11`                                      | PASS   |
| 10  | `ENTERPRISE_OPENCODE_SETUP.md` L1710 = `v1.18.11`                  | PASS   |
| 11  | `ENTERPRISE_OPENCODE_SETUP.md` L645 = `mode: "primary"`            | PASS   |
| 12  | 2-task parallel subagent test returned real data                   | PASS   |
| 13  | Temp files cleaned (sqlite-query, db-shm, db-wal)                  | PASS   |

---

## Rollback procedure

If v1.18.11 causes issues:

1. **Downgrade binary:**

   ```powershell
   npm install -g opencode-ai@1.18.9 --force
   ```

2. **Disable background subagents:**

   ```powershell
   setx OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS ""
   ```

3. **Restart opencode.**

4. **Restore regression table** from `AGENTS.md.bak.parallel` (contains the v1.18.10-era regression table and WARNING block).

5. **Revert ENTERPRISE_OPENCODE_SETUP.md** template orchestrator mode back to `"subagent"` if downgrading (the bug will re-emerge on v1.18.9 or v1.18.10 with background subagents enabled).

---

## Known issues (not introduced this session)

- **AGENTS.md L20 counting ambiguity:** Says "15 custom + 8 OMO-Slim" subagents — double-counts because orchestrator is OMO-Slim but `mode:primary`. Real count: 7 custom subagents + 7 OMO-Slim subagents (excluding orchestrator) = 14 subagents + 3 primary = 17 total. Pre-existing, not introduced this session. Documented in memory entity for future cleanup.

---

## References

- **ADR-007:** Virtual reference (no ADR file on disk) — points to this post-snapshot item 12. Follows the ADR-002, ADR-005, ADR-006 pattern.
- **Related:** `POST-INSTALL-NOTE-2026-07-27-subagents.md` (initial subagent migration to hcnsec/Kimi-K2.6)
- **GitHub issues referenced:** #31789 (completed background tasks re-dispatch loop), #27898 (no streaming for background tasks), oh-my-openagent#2954 (background subagents stay idle on Windows)
