# Member-Ready Opencode Setup — Import Plan for Neodev Coders

- **Version:** v1.3 DRAFT — owner's "few changes" still awaited; build started on locked items
- **Date:** 2026-09-11
- **Status:** Stage 1 BUILT (installer/checker/guide, verified green). Remap + rollout pending Sunday data.
- **Scope:** This workspace (`F:\CD\Opencode`) ONLY. NeoDev Portal app, portal repo, database, hosting — strictly out (return ~2 months).

---

## 1. Goal

This week: 4 Neodev Studio coders (2 Windows, 2 Linux) run the owner's opencode setup
on their own machines — fetched from the owner's GitHub, auto-cleaned on install with
no "which system?" questions, own logins, studio-paid main-AI keys, read-only start.
One weekday pilot first, then rollout. Owner merges every change, as today.

## 2. Two-version doctrine (owner's rule)

- **V1 (owner):** setup, settings, memory, projects — preserved byte-identical.
  Backup before any work; owner-mode checker stays green.
- **V2 (teammates):** same repo, installer adapts on install: their paths, their keys,
  blank fresh memory (owner notes replaced, never shipped). Their future projects are
  theirs alone.
- One repo + member-mode installer. No second copy, no drift.

## 3. Identity

Installer asks once — _"Is this the owner's machine? (yes/no)"_, default NO.
No passwords, no locks (a password would guard notes holding no secrets, at the cost
of lose-key-lose-notes). Auto-detection rejected: a fresh/reset machine carries no
identity. Lying gains nothing: keys and backups live outside the repo by possession,
never by installer answers. Includes an "owner moves machines" restore page
(fetch → yes → own keys → memory from own backup).

## 4. Credential map (binding-verified, 29 items)

- **Studio-provided (2 labeled keys per coder):** 4 OpenCode-Go keys (one per
  coder, weekly pools; multi-key per account asserted by owner from console —
  30-sec verify still open) + 4 OpenRouter keys (free-models-only, weekly caps;
  account holds 10+ credits for the 1,000/day allowance). Handover: owner's
  method, never in chat. Leaver rule: freeze their 2 keys + remove collaborator
  - ask to delete local copy. Personal machines can't be wiped — safe because
    members never held shared secrets.
- **Member-owned (each own free account, $0):**
  GitHub login + token — FIRST step (private repo; config binds it at code-tools block);
  own FREE hcnsec account (= own free quota; studio tops up only if someone runs dry);
  Google key (vision binding); search key (Tavily; launcher reads machine settings);
  nvidia login (inside opencode); error-tracker browser login (optional day one);
  Sentry token — NO binding found anywhere, skip freely.
  (ollama login dropped after remap — no agent uses it; opencode-go login only
  if a member holds their own sub, studio keys cover duty.)
- **Owner-only (20):** backup-AI key; database token; database tool blocks
  (stripped for members); hosting login; 16 Portal app keys; all personal
  logins / notes / backups.
- Clone proven clean (verified 2026-09-10): no secret files tracked, `Projects/`
  guard holds (portal keys can't travel), notes snapshot scanned clean of key shapes.
- OPEN: owner must check the 34-char DB authorization value in shared config via
  Supabase dashboard (look only, never paste). Rotate if live.

## 5. Access model

Full collaborators (personal repos have NO read-only role — GitHub docs; "reader
first" impossible). Guarded by: written no-direct-push rule + owner merges everything

- visible history + secret scanning + hook-active check. Technical branch lock
  impossible on free private repos (GitHub docs) — $4/mo owner-Pro path documented
  and DECLINED (you-merge rule, $0). Invites in small groups (GitHub invite
  rate-limits); 4 collaborators fit on free plan (2020 rule change).

## 6. Linux readiness (evidence-found fixes)

- Memory launcher `.sh` twin BUILT; installer picks per OS automatically, no questions.
- Portable home / skill / temp / settings paths BUILT (incl. `$USERPROFILE`
  - log-path backslash fixes); installer asks one identity question (default: member).
- Per-distro PowerShell lines (Ubuntu/Debian, Fedora, Arch — Microsoft docs).
- Pinned opencode 1.18.30 (installed + verified 2026-09-11) + `member-ready` tag for installs.
- Key fragments scrubbed from installer + checker member output (lengths only).
- Tarball pack (github-mcp-server) manual step for now.
- `--headless` switch documented; browser auto-download confirmed (Playwright docs).
- Python check already handles `python3`; missing Python = warning only
  (image-reader + one fetcher affected; one guide line).

## 7. Checker member-mode (BUILT 2026-09-11 — 19 OK / 0 fail in member mode)

Must-pass: settings point at own copy; main-AI key works; Google key works;
GitHub works; test command runs; hooks active; OS-correct launcher.
Skipped-by-design: backup-AI, database, hosting. Green = done, no false alarms.
Version stamp updated to 1.18.30. Output prints lengths only, never key fragments.

## 8. Rollout

- **Stage 0 (owner, ~30 min, before pilot day):** message 4 coders individually
  (no group chat) → invites in small groups → key accounts (coders register own
  FREE hcnsec accounts; studio issues 4 Go + 4 OpenRouter labeled keys) → name
  pilot → DB authorization dashboard check.
- **Stage 1 (BUILT 2026-09-11 on feat/member-ready-setup):** §6 + §7 + member guide (simple English; fixed order:
  invite → GitHub login → fetch → per-distro PowerShell → install → keys →
  logins WITH database + hosting skipped → verify; done-checklist; rollback;
  leaver rule) → verified (syntax + dry-run + member-mode green).
- **Stage 2 (this week):** weekday pilot (~1–2 hrs their screen) → fix everything →
  second pilot (other system) → final two → each ends checker-green + one tiny
  merged change.
- Sunday automation stays owner-only; pilot and Sunday watch don't move each other.
- Pilot needs: 1–2 hrs OK'd; coders terminal-comfortable (lean guide);
  all have GitHub accounts; English guide; good internet (no offline bundle).

## 9. Agent remap (EXECUTED 2026-09-11 on fix/gemini-vercel-deny — awaiting merge + Sunday watch)

| Seats                                 | Model                                                               | Door                                                  | Proof                                                         |
| ------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------- |
| build, plan (mains)                   | Nemotron 3 Ultra free                                               | Zen (`opencode/nemotron-3-ultra-free`)                | Live full-tools OK twice ($0); fallback-run OK on live config |
| architect, oracle, council (thinkers) | kimi-k3                                                             | Nvidia (`moonshotai/kimi-k3`)                         | 3/3 grades (awake, reasoning, tool-call)                      |
| 11 doers + orchestrator               | gemini-3.8-flash (Google free)                                      | `google/gemini-3.8-flash` + `vercel_*` deny per agent | Live OK with 16 MCPs; deny proven to strip vercel tools       |
| Fallbacks                             | 3.7-flash (doers) / hcnsec-k3 (thinkers) / paid Ultra + cap (mains) | —                                                     | Sunday verdicts                                               |

Vercel/Gemini rule (proven by bisection Sep 11): ONE vercel MCP tool carries
oneOf boolean-enum params that direct-Google Gemini rejects (3 crashes in logs:
Aug 24, Sep 3, Sep 10; sole offender proven — all-minus-vercel passes). Every
Gemini-running agent carries `"vercel_*": "deny"` (proven to remove tools from
the request). Non-Gemini agents unaffected. Helpers never need vercel tools.
Ollama removal completes with the remap (build/plan leave ollama-cloud; vault
login stays dormant for later re-setup). V1+V2 inherit identically (doctrine).
Sunday trigger: storm confirmed → switch; cleared → hcnsec seats stay (case closed).

## 10. Non-goals & standing decisions

No second repo; no installer passwords; skills-lock stays parity with owner's level
(accepted shared risk, documented); no offline bundle; no beginner hand-holding;
English guide; Sunday model loop untouched; Portal / hosting / database / wider
access out (2-month return); password tool = owner call; leaver PCs acknowledged
unverifiable (safe by design, §4); single-offender rule (no second bad tool —
all-minus-vercel passes, Sep 11).

## 11. Open items (owner only)

Sharing execution • password tool • pilot name • owner's unsaid "one more thing" •
dashboard check (§4, §8) • Portal test-admin password rotation (Portal-side) •
Go multi-key console glance (30-sec) • Sunday storm verdict (automatic).

## 12. History of this document

- v1.0 (chat): initial design, Approach A approved.
- v1.1 (chat): + Linux triple-fix, + member-mode checker, + 4 research passes.
- v1.2 (this file): + 5-point self-audit fixes (sharing-method correction,
  login skips, auto-adjust promise, skills-lock verdict, Sunday coexistence)
  - provider-move program + two-version doctrine + identity design.
- v1.3 (this file, 2026-09-11): Stage 1 built+verified (installer/checker/guide);
  proven remap spec (Ultra/k3/3.8 + vercel rule); free-tier key map; 1.18.30 pin.
  Owner's "few changes" STILL AWAITING OWNER WORDS → v1.4.
