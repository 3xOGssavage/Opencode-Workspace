# Security Policy

## Supported Versions

The opencode workspace at the repository root is actively maintained. Sub-projects under `Projects/` follow their own security policies.

| Component                     | Supported           |
| ----------------------------- | ------------------- |
| Configuration (root)          | Active              |
| Scripts (`scripts/*.ps1`)     | Active              |
| Skills (`.opencode/skills/*`) | Active              |
| Documentation (`docs/*`)      | Active              |
| Sub-projects                  | See their own repos |

## Reporting a Vulnerability

**Please use GitHub Security Advisories** to report security issues privately:

1. Go to https://github.com/3xOGssavage/Opencode-Workspace/security/advisories/new
2. Fill in the title and description
3. Submit the advisory

This creates a private channel where we can discuss the issue before any public disclosure.

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### What to expect

- **Acknowledgement**: within 7 days
- **Initial assessment**: within 14 days
- **Fix or mitigation**: depends on severity
  - Critical: within 7 days of assessment
  - High: within 30 days
  - Medium: within 90 days
  - Low: next regular release

### What NOT to report via this channel

- Publicly known issues (already in GitHub Issues)
- Feature requests (use GitHub Discussions)
- General questions (use GitHub Discussions)

## Security Tooling Already in Place

- **Secret scanning**: gitleaks runs on every push and PR via `.github/workflows/secret-scan.yml`. Local pre-commit hook at `.githooks/pre-commit`.
- **Branch protection**: classic protection on `main` (no force push, no deletion, gitleaks check required).
- **Auth storage**: `auth.json` is ACL-locked to current user + SYSTEM + Administrators.
- **Dependabot**: weekly Sunday 16:00 UTC scan for vulnerable dependencies (`.github/dependabot.yml`).
- **PII redaction**: scripts/agents redact API keys and PII from logged output before persistence.

## Scope

This security policy applies to the **root workspace configuration and shared tooling only**. Each sub-project under `Projects/` has its own repository and security policy — see those repos for details.
