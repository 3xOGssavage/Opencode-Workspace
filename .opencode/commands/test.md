---
description: Run the project's test suite. Dispatches the tester subagent.
agent: build
---

Run the test suite for the current project. Dispatch the `tester` subagent to:

1. Detect the toolchain from manifests (`package.json`, `pyproject.toml`,
   `Cargo.toml`, `go.mod`, etc.).
2. Find and run the project's exact test command.
3. Report pass/fail with trimmed failing output.

If the user provides a specific test name or file, pass it to the tester so it
runs only that test. Otherwise run the full suite.

$ARGUMENTS
