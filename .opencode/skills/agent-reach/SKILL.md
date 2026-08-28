---
name: agent-reach
description: Read platforms that block normal fetching - YouTube video info and subtitles, RSS/Atom feeds, V2EX, Bilibili search, and any web page via Jina Reader. Use when the user asks to read, summarize, or research content from YouTube, RSS feeds, V2EX, Bilibili, or when a normal fetch fails on a platform page. Zero-config channels only; login-required platforms (Twitter, Reddit, Instagram, Xiaohongshu) are intentionally not installed.
---

# Agent Reach - Platform Readers

agent-reach v1.5.0 is installed in an isolated venv. Doctor/check:

```powershell
& "$env:USERPROFILE\.agent-reach-venv\Scripts\agent-reach.exe" doctor
```

## Working channels (5/15 enabled by design)

| Channel                | How to use                                                                                                                                          |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| Any web page           | `curl.exe -s "https://r.jina.ai/<full-url>"` - returns clean markdown of the page                                                                   |
| YouTube info/subtitles | `yt-dlp --skip-download --print title "<url>"` (also `--print description`, or write subtitles: `--write-auto-subs --sub-langs en --skip-download`) |
| RSS/Atom               | `python -c "import feedparser; d=feedparser.parse('<feed-url>'); print(d.entries[0].title)"`                                                        |
| V2EX                   | Public API, e.g. `curl.exe -s "https://www.v2ex.com/api/topics/hot.json"`                                                                           |
| Bilibili search        | Search API via curl (basic); full features need bili-cli (not installed)                                                                            |

## Notes

- yt-dlp config at `~\.config\yt-dlp\config` has `--js-runtimes node` (set 2026-08-29). Titles, descriptions, and subtitles work; full stream extraction may warn about signature solving - irrelevant for reading content.
- The web-reader channel via Jina usually succeeds where the fetch MCP gets blocked (JS-heavy or anti-bot pages). Prefer the fetch MCP first; fall back here.
- Login channels (Twitter, Reddit, Facebook, Instagram, Xiaohongshu, LinkedIn, Xueqiu, Xiaoyuzhou) are deliberately NOT installed. Do not install them without the user explicitly asking.
- `gh` CLI and Exa/mcporter are deliberately NOT installed - the github MCP and tavily MCP cover those jobs.
