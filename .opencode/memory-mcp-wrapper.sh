#!/bin/sh
# memory-mcp-wrapper.sh - POSIX sh twin of memory-mcp-wrapper.bat (Linux/macOS).
# Relies on MEMORY_FILE_PATH being set in the environment (installer writes it
# to the shell rc file). Default (if unset): memory.jsonl next to this script.
if [ -z "$MEMORY_FILE_PATH" ]; then
  MEMORY_FILE_PATH="$(dirname "$0")/memory.jsonl"
  export MEMORY_FILE_PATH
fi
exec npx -y @modelcontextprotocol/server-memory
