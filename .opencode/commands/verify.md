---
description: Run lint, typecheck, and test for the current project. Hands off to the tester subagent.
agent: build
---

Run the `/verify` step for the current project. Dispatch the `tester` subagent
to detect the toolchain from manifests and run the project's exact lint →
typecheck → test commands in that order. Report a concise pass/fail per step.

$ARGUMENTS
