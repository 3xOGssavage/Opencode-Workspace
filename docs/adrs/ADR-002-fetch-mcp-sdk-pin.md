# ADR-002: Pin fetch MCP to mcp SDK <2

- **Status:** Accepted
- **Date:** 2026-07-29
- **Deciders:** Workspace owner
- **Commit:** d5fa6dc (fix), merged at 4604b49; related cleanup 9e74ce5 (remove broken headroom MCP)

## Context

The `fetch` MCP server (`mcp-server-fetch`) broke when the `mcp` Python SDK
released v2.0.0 on 2026-07-29. The v2.0.0 release renamed `McpError` to
`MCPError` across the codebase, but `mcp-server-fetch` had not yet been
updated to use the new class name. When opencode launched the fetch MCP, the
server crashed with `McpError` import failure, producing `-32000 Connection
closed` errors. The fetch MCP became unusable for all web content retrieval.

Upstream bug: https://github.com/modelcontextprotocol/servers/issues/4560

Additionally, the `headroom` MCP server was present in the config but was
Anthropic-only and could not function on this workspace's hcnsec/ollama-cloud
model stack. It was removed in the same maintenance window (commit 9e74ce5).

## Decision

Pin the fetch MCP's `command` array to use
`uvx --with "mcp<2" mcp-server-fetch`, forcing the mcp Python SDK to resolve
to a v1.x release where `McpError` still exists. This is the canonical
workaround cited in upstream issue #4560.

Remove the headroom MCP server block entirely from `opencode.json:mcp` since
it is unusable on this workspace's model stack.

### Changes in opencode.json

- `mcp.fetch.command` changed from `["uvx", "mcp-server-fetch"]` to
  `["uvx", "--with", "mcp<2", "mcp-server-fetch"]`
- `mcp.headroom` block removed entirely (was Anthropic-only, unusable on
  hcnsec/ollama-cloud stack)

### Untouched (intentionally)

- All other MCP servers (15 remaining) — no change to their command arrays
- `mcp-server-fetch` itself — the pin is on the SDK version, not the server
  version
- Child project configs — the fetch pin propagates via `OPENCODE_CONFIG` env
  var inheritance (parent opencode.json is loaded as layer 3; child
  opencode.json overrides at layer 4). Children that define their own fetch
  MCP must add the pin locally.

## Alternatives Considered

1. **Wait for upstream fix** — rejected: the fetch MCP is critical for web
   content retrieval in this workspace; waiting days/weeks for the PyPI publish
   was unacceptable.
2. **Fork mcp-server-fetch and patch the import** — rejected: high maintenance
   burden, diverges from upstream, unnecessary when the `--with` pin is a
   one-token fix.
3. **Remove fetch MCP entirely** — rejected: fetch is one of the most-used MCPs
   for documentation retrieval; removing it would degrade workspace capability.
4. **Pin to a specific mcp version (e.g., mcp==1.9.4)** — rejected: too
   restrictive; `mcp<2` allows all v1.x patch releases which may include
   security fixes.

## Consequences

- **Positive:** fetch MCP works immediately, no crash on session start.
- **Negative:** The pin must be manually removed when upstream #4560 ships a
  fix to PyPI. Removal trigger: when `uvx mcp-server-fetch --version` reports
  a version published after 2026.7.10, remove `--with "mcp<2"` from BOTH parent
  and child `fetch.command` arrays. This trigger is documented in AGENTS.md
  gotchas section.
- **Neutral:** The headroom MCP removal reduces the active MCP count from 16
  to 15 (this workspace now has 15 MCP servers).

## Evidence

- `opencode debug config` exits 0 with valid JSON after the pin
- fetch MCP returns content from test URLs without `-32000` errors
- Upstream issue #4560 confirms the `McpError` -> `MCPError` rename as root
  cause and the `mcp<2` pin as the canonical workaround

## Verification

```powershell
# 1. Confirm the pin is in the fetch command
Select-String -Path opencode.json -Pattern 'mcp<2'

# 2. Confirm headroom is gone
Select-String -Path opencode.json -Pattern 'headroom'

# 3. Config still parses
opencode debug config
```

## References

- Upstream bug: https://github.com/modelcontextprotocol/servers/issues/4560
- `AGENTS.md` — MCP table (fetch row) and gotchas section (removal trigger)
- `ENTERPRISE_OPENCODE_SETUP.md` — fetch MCP template (line ~677)
