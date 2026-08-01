# ADR-004: Remove addy- Prefix from Specialist Agent Names

- **Status:** Accepted
- **Date:** 2026-07-31
- **Deciders:** Workspace owner
- **Commit:** 98718d2 (refactor), merged at b0b9682

## Context

Four specialist subagents were named with an `addy-` prefix in
`opencode.json:agent`:

- `addy-code-reviewer`
- `addy-security-auditor`
- `addy-test-engineer`
- `addy-web-perf-auditor`

The `addy-` prefix was a namespace convention inherited from the
`addyosmani/agent-skills` skill pack (installed at
`~/.opencode/agent-skills/skills`). However, no other agent in the workspace
used a vendor prefix — the 7 custom agents (`architect`, `reviewer`,
`tester`, etc.) and the 8 OMO-Slim agents (`orchestrator`, `oracle`, etc.)
all used bare names. The `addy-` prefix created an inconsistency: the TUI
agent picker showed `addy-code-reviewer` alongside `reviewer` and
`architect`, making the 4 specialists look like second-class citizens.

Additionally, `addyosmani/agent-skills` is a skill pack, not an agent pack —
the `addy-` prefix implied a dependency that did not exist. The 4 agents
were defined locally in `opencode.json:agent` and `.opencode/agents/*.md`,
not imported from the skill pack.

## Decision

Rename the 4 agents by dropping the `addy-` prefix:

- `addy-code-reviewer` -> `code-reviewer`
- `addy-security-auditor` -> `security-auditor`
- `addy-test-engineer` -> `test-engineer`
- `addy-web-perf-auditor` -> `web-perf-auditor`

This aligns all 17 agents on the bare-name convention. The
`addyosmani/agent-skills` skill pack remains installed (it provides 24
skills), but the agent names no longer reflect a non-existent agent-pack
dependency.

### Changes in opencode.json

- `agent.addy-code-reviewer` key removed, `agent.code-reviewer` key added
  (same model: `hcnsec/Kimi-K2.6`, same description)
- `agent.addy-security-auditor` key removed, `agent.security-auditor` key
  added
- `agent.addy-test-engineer` key removed, `agent.test-engineer` key added
- `agent.addy-web-perf-auditor` key removed, `agent.web-perf-auditor` key
  added
- Total agent count remains 17 (2 primary + 15 subagents)

### Changes in .opencode/agents/

- New files created: `code-reviewer.md`, `security-auditor.md`,
  `test-engineer.md`, `web-perf-auditor.md`

### Changes in other files

- `AGENTS.md` — agent roster updated (addy- references replaced with bare
  names)
- `ENTERPRISE_OPENCODE_SETUP.md` — addy- references replaced with bare names
  in 7+ locations (agent roster, decision framework, section headings, file
  mapping table, permissions table)
- `opencode.json` (neodev-portal child) — same 4 key renames

### Untouched (intentionally)

- `ADR-001` — frozen historical record, still references `agent.addy-*` in
  its "Changes in opencode.json" section. This is correct — ADR-001
  documents the state as of 2026-07-27; the addy- removal happened
  2026-07-31. ADRs are immutable once accepted (supersede, don't edit, per
  Martin Fowler ADR best practice).
- `POST-INSTALL-NOTE-2026-07-27-subagents.md` — frozen post-install record.
  Line 96 will be updated separately (it's an expected-output string, not a
  historical narrative).
- `.opencode/agent-skills/` — the addyosmani skill pack is unchanged; it
  provides skills, not agents.
- `session-newai5.md` — raw transcript, not a reference doc.

## Alternatives Considered

1. **Keep the addy- prefix** — rejected: inconsistent with the 15 other
   bare-named agents; the prefix implied a non-existent skill-pack dependency.
2. **Rename to addyosmani-code-reviewer (full vendor name)** — rejected: even
   longer, worse UX in the TUI picker.
3. **Remove the 4 agents entirely** — rejected: the 4 specialists provide
   distinct review capabilities (multi-axis code review, security audit, test
   strategy, web perf). They were migrated to hcnsec/Kimi-K2.6 in ADR-001 and
   are actively used.
4. **Merge into the existing `reviewer` agent** — rejected: `reviewer` is a
   strict convention review; `code-reviewer` is a 5-axis staff-engineer review
   with different rubric. Different purposes.

## Consequences

- **Positive:** All 17 agents use bare names; TUI picker is consistent; no false
  vendor dependency signal.
- **Negative:** Any external automation or script referencing
  `addy-code-reviewer` etc. must update to bare names. Mitigated: this is a
  local-only workspace with no external automation.
- **Neutral:** Agent count stays 17; all agent models remain
  `hcnsec/Kimi-K2.6`; the `addyosmani/agent-skills` skill pack is unaffected.

## Evidence

- `opencode debug config` exits 0, sees 4 new keys (code-reviewer,
  security-auditor, test-engineer, web-perf-auditor)
- `verify-inheritance.ps1` 11/11 PASS after rename
- `rg 'addy-'` in parent opencode.json: 0 hits; neodev opencode.json: 0 hits;
  AGENTS.md: 0 hits
- 4 new .md files exist in `.opencode/agents/`; 0 old addy-.md files remain

## Verification

```powershell
# 1. Confirm 4 new agent keys present in opencode.json
$oc = Get-Content opencode.json -Raw | ConvertFrom-Json
$oc.agent.PSObject.Properties.Name -contains 'code-reviewer'      # True
$oc.agent.PSObject.Properties.Name -contains 'security-auditor'  # True
$oc.agent.PSObject.Properties.Name -contains 'test-engineer'     # True
$oc.agent.PSObject.Properties.Name -contains 'web-perf-auditor'   # True

# 2. Confirm 4 old keys absent
$oc.agent.PSObject.Properties.Name -contains 'addy-code-reviewer' # False

# 3. Agent count is 17
$oc.agent.PSObject.Properties.Count  # 17

# 4. Config parses
opencode debug config
```

## References

- `AGENTS.md` — agent roster section
- `ENTERPRISE_OPENCODE_SETUP.md` — agent roster, decision framework,
  permissions table
- ADR-001 (frozen, still references addy-\* as historical state — correct per
  immutability principle)
