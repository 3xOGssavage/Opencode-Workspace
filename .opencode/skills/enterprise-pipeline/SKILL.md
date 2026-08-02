---
name: enterprise-pipeline
description: >-
  Mandatory gated workflow for all build, create, implement, fix, or add tasks.
  Enforces plan → architect → branch → implement (TDD) → verify → review →
  security → commit → PR → Vercel preview → plain-English report.
  Use proactively when the user asks to build, create, implement, fix, add,
  ship, deploy, or make anything. Even when the user says "just do it" or
  "quick fix" — the pipeline runs, with reduced gates for trivial tasks.
  Examples:
    - user: "build a login page" → full 11-step pipeline
    - user: "add a dark mode toggle" → full pipeline (2+ files)
    - user: "fix the typo in README" → escape hatch (1-file, skip review/security)
    - user: "create a new API endpoint" → full pipeline
---

# Enterprise Pipeline

You MUST follow this pipeline for every build task. Do not skip steps unless the
escape hatch criteria are met. Each step has a gate — if the gate fails, you stop
and fix before proceeding.

## Step 1 — PLAN

Create an implementation plan before writing any code.

- Use the `plan` agent or `planning-and-task-breakdown` skill.
- Output: a concise list of files to create/edit and what changes in each.
- Gate: plan exists and is specific (file names, not vague intent).

## Step 2 — ARCHITECT (skip for 1-file changes)

Dispatch the `architect` subagent for tasks touching 2+ files or when structure
is ambiguous.

- The architect reviews the plan, proposes the smallest set of changes, and
  calls out tradeoffs.
- Gate: architect has no blocking concerns, or concerns are acknowledged.

## Step 3 — BRANCH

Never work on `main` or `master`. Create a new branch:

```
git checkout -b feat/<short-kebab-description>
```

- `feat/` for features, `fix/` for bugs, `refactor/` for refactoring.
- Gate: `git branch --show-current` does not return `main` or `master`.

## Step 4 — IMPLEMENT (TDD)

Build with test-driven development when tests are feasible:

1. Write a test that demonstrates the desired behavior (must fail).
2. Run the test — confirm it fails for the right reason.
3. Write the minimum code to make the test pass.
4. Run the test — confirm it passes.
5. Refactor if needed, re-run the test.

For UI-only or config changes where TDD is impractical, implement directly but
still run verification in Step 5.

- Gate: code is written and (if applicable) tests pass.

## Step 5 — VERIFY

Run the project's verification commands in order:

```
lint → typecheck → test
```

- Detect the toolchain from `package.json`, `pyproject.toml`, `Cargo.toml`,
  `go.mod`, etc.
- Use the project's own commands (e.g., `npm run lint`, `npm run typecheck`,
  `npm test`). Do not assume defaults.
- If a step is absent, skip it and note that.
- Gate: all steps pass. If any fails, auto-trigger `debugging-and-error-recovery`
  skill, fix the root cause, and re-verify. Max 3 retry attempts before stopping.

## Step 6 — REVIEW (skip for 1-file changes or "quick fix")

Dispatch the `reviewer` subagent to review the diff.

- The reviewer checks conventions, correctness, scope, and completeness.
- Gate: no blocking issues. If blocking issues exist, fix them and re-review.
- Non-blocking nits are noted but optional.

## Step 7 — SECURITY (skip for 1-file changes or "quick fix")

Run the `security-and-hardening` skill checklist mentally against the changes:

- Is user input validated at system boundaries?
- Are secrets kept out of code, logs, and version control?
- Are queries parameterized? Is output encoded?
- Any new dependencies with known vulnerabilities?

- Gate: no CRITICAL or HIGH severity findings. If found, STOP and ask the user.
- MEDIUM/LOW findings are noted but do not block.

## Step 8 — COMMIT

Stage and commit the changes with a conventional commit message:

```
git add -A
git commit -m "feat: <short description>"
```

- `feat:` for features, `fix:` for bugs, `refactor:` for refactoring.
- Gate: commit succeeds, working tree is clean.

## Step 9 — PR

Create a GitHub pull request using the `github` MCP `create_pull_request` tool.

PR body must include:

- **What was built** (plain English, 2-3 sentences)
- **Test results** (X/Y pass)
- **Files changed** (count + names)
- **Breaking changes** (if any)
- **Preview URL** (added after Step 10)

- Gate: PR created, URL returned.

## Step 10 — PREVIEW

Deploy to Vercel preview using the `deploy-to-vercel` skill or `vercel` MCP.

- If the project has no Vercel config, skip this step and note it.
- Gate: preview URL returned (or step skipped with reason).

## Step 11 — REPORT

Report to the user in plain English:

```
I built <what was built>.

PR: <clickable URL>
Preview: <clickable URL, if deployed>
Tests: X/Y passed
Security: no issues / <issues found and fixed>
Review: approved / <issues fixed>

You can review the preview, then merge the PR when you're happy.
```

- Use plain English, no jargon.
- Provide URLs as clickable links.
- Say "X tests passed, Y failed" not "test suite status: PASS".
- Gate: report delivered.

## Escape Hatch (Simple Tasks)

For trivial tasks, skip steps 2, 6, 7 (architect, review, security):

- **1-file change** (e.g., typo fix, single config value): skip 2, 6, 7
- **User says "quick fix"**: skip 2, 6, 7, 9, 10 (just commit, no PR/preview)
- **User says "just test it"**: skip 9, 10 (run pipeline but don't ship)

Never skip Step 5 (VERIFY) — verification is always mandatory.

## Failure Handling

- Step 5 fails 3 times → stop, report failure to user, ask for guidance
- Step 6 has blocking issues → fix, re-review (max 3 rounds)
- Step 7 has CRITICAL/HIGH → stop, report to user
- Step 9 PR creation fails → report failure, provide manual instructions
- Step 10 deploy fails → report PR URL without preview, note deploy failure

Never claim success without evidence. Every gate must pass (or be explicitly
skipped via the escape hatch) before reporting "done."
