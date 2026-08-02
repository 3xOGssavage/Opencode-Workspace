@echo off
REM Memory MCP wrapper - relies on MEMORY_FILE_PATH being set in user env via setx
REM Default: F:\CD\Opencode\.opencode\memory.jsonl
if "%MEMORY_FILE_PATH%"=="" set MEMORY_FILE_PATH=F:\CD\Opencode\.opencode\memory.jsonl
npx -y @modelcontextprotocol/server-memory