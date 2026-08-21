# docs/ — Reference documentation

Organized reference material. Read on demand; AGENTS.md has the daily-use summaries.

## Folder layout

| Folder                 | Files                                | Purpose                                                                                                |
| ---------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `adrs/`                | 7 (ADR-001 through ADR-006, ADR-008) | Architecture Decision Records — _why_ past decisions were made                                         |
| `operational-history/` | 4                                    | Post-install notes + verification reports — _what was done and when_ (rollback recipes live here)      |
| `architecture/`        | 1                                    | VISION-TOOL-MCP-DOCUMENTATION.md — full vision-tool architecture, pipeline, cooldowns, troubleshooting |
| `research/`            | 3                                    | browser-use research — deep-dive findings, fix validation, smoke-test summary                          |

## When to read what

- **"Why is X configured this way?"** → `adrs/ADR-00X-<topic>.md`
- **"How do I roll back Y?"** → `operational-history/POST-INSTALL-NOTE-YYYY-MM-DD-*.md`
- **"Why isn't vision-tool working?"** → `architecture/VISION-TOOL-MCP-DOCUMENTATION.md`
