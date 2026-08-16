# ADR-008: Human-like Vision + Keyboard/Mouse Browser Browsing for opencode

- **Date:** 2026-08-14
- **Status:** Accepted
- **Decision makers:** opencode build agent + user (requirements: $0 budget, heavy scheduled use, ecom/social/job/lead sites, public + throwaway accounts)

## Context

opencode needs to browse the web like a human (vision + human-like keyboard/mouse interaction) without being blocked by anti-bot systems (Cloudflare Turnstile, reCAPTCHA, DataDome, FingerprintJS, behavioral analysis). Constraints: **$0 budget** (no paid captcha/proxy services), **heavy scheduled use** from a single home IP, targets include job/social/listing sites with medium-hard protection, whole-workspace scope.

Previous plan draft (2026-08-10) contained fabricated claims (v1.1.8 with built-in cf_clearance, "94.5% confidence", CloakBrowser 8.3, fake MCP servers). Web verification on 2026-08-14 corrected all facts (see `docs/research/browser-use-aug-2026.md` §16).

## Decision

Adopt a **dual-mode stealth browsing stack**, all free:

1. **Brain:** [browser-use](https://github.com/browser-use/browser-use) **0.13.5** (MIT, CDP-native) with **Gemini vision** via existing `GEMINI_API_KEY`. Used in Mode A only (deterministic Mode B harvests need no AI).
2. **Engine — Mode B (default ~90%, scheduled):** **Camoufox headless** (0% headless detection in Aug-2026 benchmark; Firefox; C++ human cursor). Driven via its Playwright-compatible API + `human_input.py` Bezier layer.
3. **Engine — Mode A (edge/on-demand, auto-escalated):** **Patchright** (patched Playwright, real Chrome channel, **headed** — headless is only 40-67% stealth) exposing CDP; browser-use attaches via `Browser(cdp_url="ws://127.0.0.1:<port>")`.
4. **Humanization:** `human_input.py` — Bezier mouse paths (Fitts's-law timing, tremor, overshoot), jittered typing (60-220ms), eased scroll; OS-level PyAutoGUI clicks for captchas via SeleniumBase UC.
5. **Captcha ladder (free):** avoid → `ddddocr` (legacy image/slider; Rust port alive Jan 2026) → SeleniumBase UC `uc_gui_click_captcha()` (Turnstile/reCAPTCHA/hCaptcha/DataDome) → wait + backoff + fresh identity (≤3 tries) → **ask user in chat**.
6. **Heavy-use policy:** per-site volume caps (≤20-30 actions/min, ≤5 sessions/day), identity persistence (one profile per site), block-detection kill switch, auto-backoff/cooldown, Windows Task Scheduler at human-like times (no always-on service).
7. **Accounts:** user manually creates throwaway accounts once; agent persists cookies; no automated signup.
8. **Verification:** bot-score test (CreepJS / BrowserScan / reCAPTCHA) + 10-site matrix; results logged honestly; acceptance = Mode B ≥8/10, Mode A ≥9/10.

## Consequences

**Positive:** zero new paid dependencies; reuses existing Gemini key; highest free-tier bypass documented in Aug-2026 benchmarks; full accountability via logging; clean rollback (self-contained venv, no services).

**Negative / risks:** hardest sites (LinkedIn/Cloudflare-Enterprise-class) may occasionally need a manual click; home IP may degrade over time under heavy load (mitigated by caps; proxy = future optional upgrade); stealth tools need version-following (patchright/camoufox updates).

**Ethics/ToS:** targets respected via robots.txt-aware volume limits; user responsible for chosen targets.

## Rollback

Remove `.opencode/browser_use/`, `ddddocr-mcp-server.py`, revert `opencode.json`/`AGENTS.md`, delete Task Scheduler entries. No production impact.

## References

- Research doc: `docs/research/browser-use-aug-2026.md` (verified 2026-08-14, sources in §15)
- Prior ADRs: ADR-001..007 for workspace conventions
