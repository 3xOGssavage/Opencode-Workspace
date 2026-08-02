---
description: Ship the current work — verify, review, commit, PR, deploy preview, and report
agent: build
---

Run the full enterprise pipeline on the current work to ship it.

Execute these steps in order:

1. **VERIFY** — Run lint, typecheck, and test for the current project.
   - Detect the toolchain from manifests (package.json, pyproject.toml, etc.)
   - Run: lint → typecheck → test
   - If any step fails, stop and report the failure. Do not proceed.

2. **REVIEW** — Dispatch the `reviewer` subagent to review the diff.
   - Fix all blocking issues before proceeding.
   - Non-blocking nits are optional.

3. **SECURITY** — Run the `security-and-hardening` skill checklist.
   - If CRITICAL or HIGH issues found, stop and report to user.
   - MEDIUM/LOW are noted but do not block.

4. **COMMIT** — Stage and commit all changes:

   ```
   git add -A
   git commit -m "feat: <short description of what was built>"
   ```
   - Use `feat:` for features, `fix:` for bug fixes, `refactor:` for refactoring.

5. **PUSH** — Push the current branch to remote:

   ```
   git push -u origin HEAD
   ```

6. **PR** — Create a GitHub pull request using the `github` MCP `create_pull_request` tool.
   - Title: `<type>: <short description>`
   - Body must include:
     - What was built (plain English, 2-3 sentences)
     - Test results (X/Y pass)
     - Files changed (count + names)
     - Breaking changes (if any)

7. **PREVIEW** — Deploy to Vercel preview using the `deploy-to-vercel` skill or `vercel` MCP.
   - If no Vercel config exists, skip and note it.

8. **REPORT** — Report to the user in plain English:
   - What was shipped (3-5 sentences, no jargon)
   - PR URL (clickable)
   - Preview URL (clickable, if deployed)
   - Test results (X passed, Y failed)
   - Security status (no issues / issues found and fixed)
   - Review status (approved / issues fixed)
   - Tell user: "You can review the preview, then merge the PR when you're happy."

Never skip verification. Never auto-merge. Never auto-deploy to production.
