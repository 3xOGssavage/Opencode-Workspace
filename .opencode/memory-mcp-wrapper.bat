@echo off
REM Memory MCP wrapper - relies on MEMORY_FILE_PATH being set in user env via setx
REM Default (if MEMORY_FILE_PATH unset): memory.jsonl in this .opencode/ dir
REM (relative to the script; not hardcoded to any workspace path)
if "%MEMORY_FILE_PATH%"=="" set MEMORY_FILE_PATH=%~dp0memory.jsonl
npx -y @modelcontextprotocol/server-memory