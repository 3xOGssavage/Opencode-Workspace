# docs/ — Reference documentation

Organized reference material. Read on demand; AGENTS.md has the daily-use summaries.

## Folder layout

| Folder                 | Files                       | Purpose                                                                                                |
| ---------------------- | --------------------------- | ------------------------------------------------------------------------------------------------------ |
| `adrs/`                | 6 (ADR-001 through ADR-006) | Architecture Decision Records — _why_ past decisions were made                                         |
| `operational-history/` | 4                           | Post-install notes + verification reports — _what was done and when_ (rollback recipes live here)      |
| `architecture/`        | 1                           | VISION-TOOL-MCP-DOCUMENTATION.md — full vision-tool architecture, pipeline, cooldowns, troubleshooting |

## When to read what

- **"Why is X configured this way?"** → `adrs/ADR-00X-<topic>.md`
- **"How do I roll back Y?"** → `operational-history/POST-INSTALL-NOTE-YYYY-MM-DD-*.md`
- **"Why isn't vision-tool working?"** → `architecture/VISION-TOOL-MCP-DOCUMENTATION.md`
