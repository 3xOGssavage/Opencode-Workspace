---
description: Stage changes and write a conventional commit message.
agent: build
---

Stage the relevant changes and create a git commit following Conventional
Commits format:

```
type(scope): brief description

optional body explaining why
```

Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert.

Rules:
- Read `git diff --staged` first. If nothing is staged, stage only the files
  relevant to the current task (ask before staging everything).
- Keep the subject line under 72 characters. Imperative mood.
- Body wraps at 80 columns. Explain the *why*, not the *what*.
- Do NOT commit secrets, `.env` files, or `node_modules`.
- Do NOT push unless explicitly asked.

$ARGUMENTS
