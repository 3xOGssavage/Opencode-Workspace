---
description: Show what's in context and compact if needed.
agent: build
---

Show the current context state:

1. List the files currently in context (read this session).
2. Show approximate token usage if available.
3. If context is heavy (>70% of limit), suggest compacting.
4. If the user confirms, run compaction to free up context.

Also list any active todos and their status.

$ARGUMENTS
