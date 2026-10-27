# LLM Wiki (with temporal memory)

A pattern for building personal or business knowledge bases using LLMs — extended so the wiki always knows which facts are current and which have been replaced.

This is an idea file, designed to be copy-pasted to your own LLM agent (Claude Code, Codex, OpenCode, or similar) so it builds out the specifics together with you. It adds one concrete mechanism to the original pattern: every fact that can change over time carries an explicit status and a timestamp, so a query never has to guess which of two conflicting pages is the real answer.

## The core idea

Most people's experience with LLMs and documents is RAG: upload files, retrieve relevant chunks at query time, generate an answer. Nothing accumulates — ask something that needs several documents synthesized together, and the model rebuilds that synthesis from scratch every time.

The alternative is having the LLM incrementally build and maintain an actual wiki that sits between you and the raw sources. When something new comes in, it doesn't just get filed away for later retrieval — it gets integrated: existing pages get updated, summaries get revised, and where the new material conflicts with something already written, that conflict gets resolved explicitly rather than left for whoever reads it next to notice on their own. The wiki compounds instead of restarting every session.

The gap in the original version of this idea: "note where new data contradicts old claims" is the right instinct, but noting isn't resolving. If the old claim and the new one both just sit in the wiki as separate pages, a future query has no way to know which one is true today — it might surface either one, or both, with nothing indicating which is current. The fix doesn't need to be complicated, but it does need to be explicit: any page stating a fact that can become outdated carries a status, and changing that fact is a tracked event, not a silent overwrite.

## Architecture

Three layers, same as the original pattern, with one addition to the middle one.

**Raw sources** — immutable. The LLM reads from these, never edits them.

**The wiki** — LLM-owned markdown pages: summaries, entity pages, concept pages, synthesis. The addition: any page describing something that can change — a role, a status, a location, a price — carries a status (active or superseded) and a timestamp for when that status last changed. A page is never silently overwritten with new information. It gets marked superseded, and a new page (or a clearly new section) becomes the active one. The old page isn't deleted — it's history now, not the answer to "what's true right now," but still there if anyone asks what used to be true.

**The schema** — CLAUDE.md / AGENTS.md — now also defines exactly what those status fields look like and whose job it is to set them, and when. This is what turns "note contradictions" from an aspiration into something that happens the same way every time, instead of depending on the LLM remembering to mention it.

## Operations

**Ingest.** Same flow as before — read the source, update the index, update the relevant pages, log it. The addition is what happens right before writing: search for an existing page on this subject first.
- No conflict → extend the existing page as usual.
- Conflict, and the existing page is already marked superseded → follow its pointer forward to whichever page is currently active for that subject, and update that one. Don't update the stale page you happened to find first — that's the single easiest way to end up with a broken trail where nothing is clearly marked current.
- Conflict, and the existing page is active → mark it superseded, timestamp it, point it at the new page, and the new page becomes active. The old page keeps exactly the same content — only its status changes.
- Conflict where it's genuinely unclear which is outdated (two people giving different answers, say) → don't pick a winner. Leave both active and flag it for the user. A silently resolved guess is worse than an open question.

**Query.** Same as before — search, synthesize, cite, and file good answers back into the wiki as new pages. The addition: default to active pages only. A question like "what's the current status" should never surface a superseded page alongside an active one without clearly marking which is which. Superseded pages only come into an answer on purpose — when someone asks about history, asks when something changed, or wants a timeline.

**Lint.** Same periodic health-check, with sharper things to look for now: pages that should have been marked superseded and weren't; superseded pages whose pointer is missing or points to something that no longer exists; two pages both marked active for what's actually one subject. This is the safety net for whatever ingest should have caught and didn't.

## Currency and history

This needs almost no new infrastructure — three small fields on any page that states a fact which can change:

```
status: active        # or: superseded
since: 2026-06-18      # when this status last became true
superseded_by: —       # set only once status becomes superseded
```

Whatever a page asserts is treated as true as of `since`, until something marks it superseded. A subject's full history is just every page ever written about it, sorted by `since` — nothing needs to be deleted for that to work, which is the same principle the rest of the wiki already runs on: sources are immutable, history is additive, only the *current* pointer moves.

This is intentionally minimal. If a domain genuinely needs to separate "when we learned this" from "when it actually became true" — back-dated information, audit trails, that kind of precision — that's a real, distinct problem (sometimes called bi-temporal tracking) and worth building deliberately if a specific case demands it. Most personal and small-business use doesn't need that extra layer; knowing what's current versus what's history is usually enough.

## Indexing and logging

index.md and log.md still serve their original purpose: index.md as a content-oriented catalog the LLM checks before drilling into specific pages, log.md as the append-only chronological record of everything that's happened. One addition — when index.md lists a page about something that can change, include its status there too, so a glance at the index already shows what's current without opening anything.

## Optional: CLI tools

At some point you may want to build small tools that help the LLM operate on the wiki more efficiently. A search engine over the wiki pages is the most obvious one — at small scale the index file is enough, but as the wiki grows you want proper search. [qmd](https://github.com/tobi/qmd) is a good option: it's a local search engine for markdown files with hybrid BM25/vector search and LLM re-ranking, all on-device. It has both a CLI (so the LLM can shell out to it) and an MCP server (so the LLM can use it as a native tool). You could also build something simpler yourself — the LLM can help you vibe-code a naive search script as the need arises.

With status tracking in place, it's also worth considering a small script that queries all pages by `status` and `since` — a one-liner that answers "what changed this week" or "show me everything currently active about this subject" without needing the LLM at all. The LLM can help you write this as the need comes up, the same way as any other small tool.

## Tips and tricks

- **Obsidian Web Clipper** is a browser extension that converts web articles to markdown. Very useful for quickly getting sources into your raw collection.
- **Download images locally.** In Obsidian Settings → Files and links, set "Attachment folder path" to a fixed directory (e.g. `raw/assets/`). Then in Settings → Hotkeys, search for "Download" to find "Download attachments for current file" and bind it to a hotkey (e.g. Ctrl+Shift+D). After clipping an article, hit the hotkey and all images get downloaded to local disk. This lets the LLM view and reference images directly instead of relying on URLs that may break. Note that LLMs can't natively read markdown with inline images in one pass — the workaround is to have the LLM read the text first, then view the referenced images separately. It's a bit clunky but works well enough.
- **Obsidian's graph view** is the best way to see the shape of your wiki — what's connected to what, which pages are hubs, which are orphans. With status fields on every changeable page, you can also color nodes by status in the graph view to immediately see what's current versus historical at a glance.
- **Marp** is a markdown-based slide deck format. Obsidian has a plugin for it. Useful for generating presentations directly from wiki content.
- **Dataview** is an Obsidian plugin that runs queries over page frontmatter. With status tracking in place this becomes especially useful: `TABLE since FROM "wiki" WHERE status = "active"` gives a live table of everything currently true; `TABLE since, superseded_by FROM "wiki" WHERE status = "superseded" SORT since DESC` gives a full change history sorted newest-first — both without involving the LLM at all.
- The wiki is just a git repo of markdown files. You get version history, branching, and collaboration for free — and with explicit status changes happening as discrete commits, every time something gets marked superseded is a real, dated event in the git log. That's a complete audit trail of what was believed true at any point in the past, for free.

## Why this works

The tedious part of a knowledge base was never the reading — it's the bookkeeping, specifically the part where someone has to remember an old fact is now wrong and go fix every place it appears. Humans let that slide; pages quietly go stale and nobody notices until something built on top of them breaks. An explicit status field doesn't make the LLM smarter about spotting contradictions — it gives "this is now wrong" a real, checkable place to live, instead of staying an implicit thing the LLM is supposed to remember to mention.

## Note

This stays intentionally minimal beyond the status mechanism itself. The exact field names, how granular a "page" is, whether a whole entity gets one status or each fact about it gets its own — that's still for you and your agent to work out for your own domain, the same way the rest of this pattern always has been. The point isn't this specific schema. It's that "currently true" and "history" need to be two different, checkable things — not one thing you're hoping the LLM remembers correctly every time.
