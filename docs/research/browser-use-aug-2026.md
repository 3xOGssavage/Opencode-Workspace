# Browser-Use Integration: Human-Like Vision + Keyboard/Mouse Browsing for opencode (August 2026)

**Status:** Research-grade, web-verified 2026-08-14. All facts below were re-verified against primary sources (browser-use README, techinz/browsers-benchmark, camoufox docs, patchright npm, SeleniumBase repo, ScrapeOps/Scrapfly guides) during the planning cycle.
**Verdict:** Integration viable with a **dual-mode stealth architecture** (Camoufox headless for scheduled runs, Patchright-headed Chrome for interactive/edge cases) + a 4-tier free captcha ladder. Honest limits: no $0 stack silently bypasses every site 100% of the time; the strictest sites may occasionally need a manual click in chat.

> **Corrections to the previous draft of this file (2026-08-10):** the earlier version claimed browser-use v1.1.8 with built-in `cf_clearance`/`ddddocr`, "94.5% confidence, 18 planning cycles", CloakBrowser 8.3, and a browser-use-webui integration. Web verification (2026-08-14) proved: current browser-use is **0.13.5**; `cf_clearance`/Cloudflare solving is a **paid cloud** feature, not built-in; CloakBrowser's free wrapper is **0.4.8** (Chromium 146); browser-use-webui is **dropped (YAGNI)** — the override UI is opencode chat itself. This file is the corrected source of truth.

---

## 1. Objective

Give opencode the ability to browse the web **like a human**: an AI agent with **vision** (Gemini, already configured) that plans steps, plus a browser that simulates **human-like keyboard/mouse interaction**, so e-commerce, social, job-board, listing, and directory sites (lead sources) don't flag it as a bot. Scope: whole workspace (`F:\CD\Opencode`), Windows 11 host, **$0 budget**, heavy scheduled use.

## 2. Executive Summary (TL;DR)

- **Agent brain:** [browser-use](https://github.com/browser-use/browser-use) 0.13.5 (MIT, ~106k stars, Python ≥3.11, `pip install browser-use`). CDP-native since 2025 (dropped Playwright relay). Gemini vision works via `GOOGLE_API_KEY`/`GEMINI_API_KEY` — zero new cost (workspace already has the key).
- **Engine (dual-mode):**
  - **Mode B — scheduled harvests (default, ~90%):** Camoufox (anti-detect Firefox fork; **0% headless detection**; human-like cursor at C++ level; ~1.2GB RAM) driven via its Playwright-compatible API with a Bezier human-input layer.
  - **Mode A — interactive + edge cases (~10%, auto-escalated):** Patchright (patched Playwright/Chromium; **100% bypass in benchmark but only in headed mode**; headless drops to ~40-67% detected) + browser-use `Agent(task=..., llm=ChatGemini, browser=Browser(cdp_url=...))` in a visible window.
- **Captcha ladder (all free):** avoid (stealth + human pacing) → `ddddocr` (legacy image/slider captchas; Rust port Jan 2026, still maintained; does NOT solve Turnstile/reCAPTCHA) → SeleniumBase UC Mode (`uc_gui_click_captcha()`; auto-clicks Cloudflare Turnstile / reCAPTCHA / hCaptcha / DataDome via OS-level PyAutoGUI; actively maintained, May 2026) → wait + backoff + retry with fresh identity (up to 3 tries) → **ask user in chat** (they click once).
- **Heavy-use policy (the "$0 + heavy" tension):** per-site volume caps, **identity persistence** (one profile per site = one consistent "person"), auto-backoff + cooldown on block detection, randomized human-like scheduling via Windows Task Scheduler (no always-on service needed).
- **Accounts:** public sites need none; for gated sites the user creates throwaway accounts **once manually** (never automated signup), agent persists cookies.
- **Verification:** bot-score test (CreepJS / BrowserScan / reCAPTCHA challenge) + 10-site real-world matrix, results recorded honestly in `logs/`.
- **Cost:** 0 new paid dependencies. Files: 3 PowerShell wrappers + 3 Python modules + 1 MCP server + research doc + ADR-008 + config updates.

## 3. Scope

### 3.1 In scope

- browser-use 0.13.5 + Gemini vision agent (Mode A), Camoufox headless harvester (Mode B), Patchright headed fallback, `human_input.py` Bezier layer, `ddddocr` MCP server, SeleniumBase UC captcha ladder glue, setup/run/bot-score scripts, `opencode.json` MCP + permission entries, `AGENTS.md` section, ADR-008, bot-score verification.

### 3.2 Out of scope

- Paid captcha/proxy services (budget $0), browser-use-webui, CloakBrowser (superseded by Patchright/Camoufox), nodriver (AGPL license), playwright-extra/stealth (unmaintained ~18mo), always-on NSSM service (Task Scheduler instead), mobile native, anything in AGENTS.md "What's NOT configured".

## 4. Methodology (what was verified, when, where)

Verified 2026-08-14 via primary sources + current user forums/blogs:

| Claim                           | Verified fact                                                                                                                                                                                                                                             | Source                                                                                                                                                                                |
| ------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| browser-use version             | **0.13.5** (PyPI), Python ≥3.11, MIT                                                                                                                                                                                                                      | pypi.org/project/browser-use, browser-use README                                                                                                                                      |
| browser-use agent performance   | 87.4% avg Odysseys leaderboard (#1, ahead of OpenAI/Anthropic/Google/Microsoft agents); 89.1% WebVoyager with GPT-4o                                                                                                                                      | browser-use README                                                                                                                                                                    |
| browser-use transport           | Raw CDP since 2025 (Playwright relay removed); `Browser(cdp_url=...)` connects to external browser                                                                                                                                                        | browser-use.com/posts/playwright-to-cdp; hermes-agent docs                                                                                                                            |
| Engine benchmark (Aug 10, 2026) | patchright 100% bypass / 40% headless; cloakbrowser 90%; camoufox-headless 90%; **vanilla Playwright FAILS 40-60%**                                                                                                                                       | techinz/browsers-benchmark                                                                                                                                                            |
| Patchright headless gap         | CreepJS headless detection 100% → 67% with Patchright; headed + real Chrome ≈ undetectable                                                                                                                                                                | roundproxies.com/blog/patchright; npm/patchright ("passes CreepJS, Cloudflare, Kasada, Akamai, Datadome, Fingerprint.com, Sannysoft, Browserscan")                                    |
| Camoufox                        | Custom Firefox, C++ fingerprint spoofing, 0% headless detection, human-like cursor; heavier (~1181-1318MB RAM)                                                                                                                                            | roundproxies "best Patchright alternatives"; camoufox docs; kahtaf.com browser comparison (Camoufox 15/15 sites)                                                                      |
| ddddocr status                  | Alive; **Rust port Jan 2026**; offline OCR for text/slider captchas only; NOT Turnstile/reCAPTCHA                                                                                                                                                         | github.com/mzdk100/ddddocr-rs                                                                                                                                                         |
| SeleniumBase UC captchas        | 4.50.x actively maintained; `uc_gui_click_captcha()`/`uc_gui_handle_captcha()` auto-click Turnstile, reCAPTCHA, hCaptcha, DataDome slider via PyAutoGUI (OS-level, undetectable as synthetic); works headed on Windows; also scrapes Upwork jobs in demos | github.com/seleniumbase/SeleniumBase (issues #2865, #4333); scrapfly.io "how-to-bypass-cloudflare-turnstile"                                                                          |
| Human-like input                | Bezier mouse + Fitts's law timing + jittered typing = the behavioral differentiator; DataDome scores 35+ behavioral signals; OS-level events (PyAutoGUI) are the gold standard for CAPTCHA clicking                                                       | arxiv 2509.00625 (PyAutoGUI + Bezier); roundproxies DataDome guide; proxies.sx DataDome/Camoufox guide; Pydoll docs (humanize=True: Bezier, minimum-jerk velocity, tremor, overshoot) |
| Site behavior                   | LinkedIn/Reddit-class sites block headless Chromium **even with cookies**; Camoufox passes; headed Chrome + persistent identity needed for job/social sites                                                                                               | kahtaf.com/browser-automation-compared (Reddit blocks headless Chromium with valid cookies)                                                                                           |
| Cloudflare reality              | Modern captchas = 200+ invisible checks (TLS, canvas, WebGL, mouse dynamics, session history); "solver services fail on Turnstile" — stealth-first is the strategy                                                                                        | LinkedIn/BrowserAct post; capsolver/scrapfly 2026 guides                                                                                                                              |

## 5. Architecture (7 layers, dual-mode)

```
 1 BRAIN      browser-use Agent (0.13.5) — vision via Gemini (GEMINI_API_KEY, existing)   [Mode A only]
 2 ENGINE     Mode B: Camoufox headless (0% detection, Firefox) ─── default 90%
              Mode A: Patchright headed (real Chrome, 100% bypass, visible window) ────── edge/on-demand
 3 HUMANIZE   human_input.py: Bezier mouse paths, Fitts's-law timing, jittered typing,
              human scroll; Camoufox C++ human cursor underneath; OS-level PyAutoGUI for
              CAPTCHA clicks (SeleniumBase UC)
 4 CAPTCHA    avoid → ddddocr (legacy) → SeleniumBase UC click (Turnstile/reCAPTCHA/hCaptcha/
              DataDome) → wait+backoff+retry fresh identity (≤3) → ask user in chat
 5 IP LAYER   own home IP only (budget $0). Rate caps + identity persistence keep it clean.
              (Proxy = future optional upgrade, documented in ADR-008.)
 6 INTEGRATE  scripts/setup-browser-use.ps1 · browser-use-run.ps1 (A) · camoufox-harvest.ps1 (B)
              .opencode/tools/ddddocr-mcp-server.py (real MCP, stdio, local)
 7 GUARDRAILS allowlist of domains, localhost-only binding, no secrets in code,
              rate limits + cooldowns, block-detection kill switch, honest logging
```

**Escalation:** Mode B hits a block marker → auto-retry with fresh identity (≤3) → wrapper escalates to Mode A (headed Patchright + AI agent) for that URL → if Mode A also fails captcha ladder → ask user in chat. Overnight runs degrade to "skip + log" instead of blocking forever.

## 6. Engine decision (rationale)

| Engine             | Headless        | Headed        | RAM        | Notes                                                                       |
| ------------------ | --------------- | ------------- | ---------- | --------------------------------------------------------------------------- |
| **Camoufox**       | 0% detection    | n/a (Firefox) | 1.2-1.3GB  | Primary for scheduled headless harvests; human cursor at engine level       |
| **Patchright**     | 40-67% detected | ~100% bypass  | ~600-900MB | Primary for interactive AI agent (browser-use cdp_url); real Chrome channel |
| vanilla Playwright | fails 40-60%    | fails         | low        | Rejected (benchmark)                                                        |
| nodriver           | 67%             | good          | mid        | Rejected (AGPL license)                                                     |
| CloakBrowser       | 90%             | good          | mid        | Rejected (superseded; fewer vectors patched than Camoufox)                  |

## 7. Human-like input (the actual differentiator)

- **Bezier mouse paths** with randomized control points, minimum-jerk velocity, tremor, overshoot+correct (70% prob), micro-pauses; duration from Fitts's law. Implemented in `human_input.py` on top of Playwright `page.mouse` (works headless for Camoufox) and available for Mode A.
- **Typing:** per-keystroke delays 60-220ms, small jitter, occasional typo-correction behavior at configurable rate.
- **Scrolling:** Bezier-eased, jitter ±3px, large distances split into flicks.
- **Captcha clicks:** OS-level via PyAutoGUI (SeleniumBase UC) — indistinguishable from real input at the OS event level.
- Reference implementations studied: Pydoll `humanize=True` params, SeleniumBase `uc_gui_click_captcha`, proxies.sx Camoufox DataDome guide, arxiv 2509.00625.

## 8. Captcha ladder (free, in order)

1. **Avoid** — stealth engine + human pacing + volume caps (most sites never challenge).
2. **ddddocr** — legacy text/image/slider captchas, offline OCR (`.opencode/tools/ddddocr-mcp-server.py` exposes via MCP).
3. **SeleniumBase UC Mode** — `uc_gui_click_captcha()` auto-detects + OS-level clicks Turnstile / reCAPTCHA / hCaptcha / DataDome slider. Free, maintained.
4. **Wait + backoff + retry** — fresh identity profile, exponential backoff, up to 3 attempts.
5. **Ask user in chat** — agent posts a message; user clicks once; agent resumes. (User-chosen policy.)

## 9. Heavy-use policy ($0 + home IP)

- **Volume caps:** ≤20-30 actions/min/site, ≤5 sessions/site/day, then cooldown (24h for blocked sites).
- **Identity persistence:** one browser profile per site (consistent fingerprint = one "person"); never rotate mid-task.
- **Block detection:** 403/"Just a moment"/Turnstile frame/CF-challenge markers → kill switch, log, backoff, escalate per ladder.
- **Scheduling:** Windows Task Scheduler runs at randomized human-like times (e.g., 9-11am / 2-4pm local), not 2am "bot o'clock"; RAM freed between runs (no always-on service).
- **ToS/ethics:** respect robots.txt and site ToS; low volume; user takes responsibility for targets (job/lead sites).

## 10. Accounts (throwaway, manual setup)

- User creates throwaway accounts **once** per site (signup pages are the most bot-protected; never automate signup).
- Checklist provided in ADR-008 appendix: fresh email, human-like signup pacing, 2FA off, unique password manager entry.
- Agent persists cookies per profile; behaves like a normal logged-in user. Public sites need no account.

## 11. Security & guardrails

- All CDP/browser traffic binds `127.0.0.1` only. No credentials in code; keys come from existing User env vars (`GEMINI_API_KEY`). No secrets logged.
- `ddddocr` MCP server: stdio local, tool schemas minimal, no network calls.
- Domains allowlist in wrapper (configurable `site-profiles.json`), default deny.
- Kill switch: any detected block → immediate stop + log + escalate/skip.
- Rate limits enforced in-process (per-site token bucket).

## 12. Verification plan (bot-score)

- `scripts/browser-use-botscore.ps1` runs `botscore.py`:
  - CreepJS trust-score page + BrowserScan bot-detection page (headed + headless variants where possible).
  - reCAPTCHA challenge page load test.
  - 10-site real-world matrix (ecom ×3, social ×2, jobs ×2, listings/directories ×3): record PASS / CHALLENGE / BLOCKED + page size + load time.
  - Outputs `logs/botscore-YYYYMMDD.md` with honest results. **No pass rate claimed until measured.**
- Acceptance: Mode B (Camoufox headless) passes ≥8/10 sites; Mode A (Patchright headed) passes ≥9/10.

## 13. Files changed / integration points

| File                                        | Purpose                                                  |
| ------------------------------------------- | -------------------------------------------------------- |
| `docs/research/browser-use-aug-2026.md`     | This doc (corrected)                                     |
| `docs/adrs/ADR-008-browser-use-aug-2026.md` | Decision record                                          |
| `scripts/setup-browser-use.ps1`             | One-time: venv + pinned deps + browser download          |
| `scripts/browser-use-run.ps1`               | Mode A wrapper (headed Patchright + browser-use agent)   |
| `scripts/camoufox-harvest.ps1`              | Mode B wrapper (headless Camoufox harvester)             |
| `scripts/browser-use-botscore.ps1`          | Verification wrapper                                     |
| `.opencode/browser_use/agent_runner.py`     | Mode A agent core (CDP attach, Gemini, ladder hooks)     |
| `.opencode/browser_use/camoufox_harvest.py` | Mode B core (profiles, pacing, block detection, backoff) |
| `.opencode/browser_use/human_input.py`      | Bezier mouse / jittered typing / human scroll            |
| `.opencode/browser_use/botscore.py`         | CreepJS/BrowserScan + 10-site matrix                     |
| `.opencode/tools/ddddocr-mcp-server.py`     | Real ddddocr captcha MCP (stdio, local)                  |
| `opencode.json`                             | MCP entry + permission rules                             |
| `AGENTS.md`                                 | Browser-use section + guardrails                         |

## 14. Rollback

- `Remove-Item .opencode\browser_use -Recurse -Force; Remove-Item .opencode\tools\ddddocr-mcp-server.py`; revert `opencode.json` + `AGENTS.md` via git; delete Task Scheduler entries; uninstall nothing else (venv self-contained). No system services installed. Branch `feat/browser-use-aug-2026` can be dropped; production untouched (no prod deploy for this feature).

## 15. References

- browser-use: https://github.com/browser-use/browser-use · pypi.org/project/browser-use · docs.browser-use.com · browser-use.com/posts/playwright-to-cdp
- Benchmark: https://github.com/techinz/browsers-benchmark (2026-08-10)
- Camoufox: https://github.com/daijro/camoufox · roundproxies.com/blog/patchright + /best-patchright-alternatives
- SeleniumBase: https://github.com/seleniumbase/SeleniumBase (issues #2865, #4333; UC/CDP examples)
- ddddocr Rust port: https://github.com/mzdk100/ddddocr-rs
- Human input: arxiv.org/abs/2509.00625 · pydoll.tech/docs/deep-dive/fingerprinting/evasion-techniques
- Site behavior: https://kahtaf.com/blog/browser-automation-compared
- Captcha landscape 2026: capsolver.com blog, scrapfly.io blog, scrapeops.io web-scraping-playbook

## 16. Appendix A — prior-claims corrections

| Prior claim (2026-08-10 draft)                         | Corrected fact (2026-08-14)                                                                                 |
| ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------- |
| browser-use v1.1.8 with built-in cf_clearance/dddddocr | v0.13.5; Cloudflare solving is paid cloud-only; cf_clearance is a 30-60min cookie, only when a site demands |
| "94.5% confidence, 18 planning cycles"                 | Fabricated confidence — dropped; verification is empirical (bot-score)                                      |
| CloakBrowser 8.3 primary                               | Wrapper 0.4.8; superseded by Camoufox/Patchright                                                            |
| browser-use-webui manual override                      | Dropped (YAGNI); chat is the override UI                                                                    |
| NSSM always-on service                                 | Windows Task Scheduler (RAM freed between runs)                                                             |
| Playwright backend for browser-use                     | CDP-native since 2025; external browser via `Browser(cdp_url=...)`                                          |
| 2 fake MCP servers (cloak + ddddocr)                   | One real ddddocr MCP server                                                                                 |
| H-1..H-10 regression + "94.5%"                         | Bot-score test (CreepJS/BrowserScan + 10-site matrix), honest numbers                                       |
