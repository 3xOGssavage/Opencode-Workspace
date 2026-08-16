"""Mode B: headless Camoufox harvester with human-like pacing.

Exit codes: 0 = ok, 1 = error, 2 = blocked after retries (escalate to Mode A).
"""

import argparse
import os
import random
import shutil
import time

from camoufox.sync_api import Camoufox

from human_input import human_scroll

BLOCK_MARKERS = [
    "just a moment",
    "attention required",
    "cf-challenge",
    "challenge-platform",
    "verify you are human",
    "access denied",
    "turnstile",
    "puzzle",
    "unusual traffic",
    "automated access",
    "checking your browser",
]
RETRIES = 3
COOLDOWN = [30, 90, 240]


def is_blocked(page):
    try:
        body = page.locator("body").inner_text(timeout=4000) or ""
    except Exception:
        return True
    text = (page.title() + " " + body[:1000]).lower()
    return any(m in text for m in BLOCK_MARKERS)


def _launch(profile_dir):
    kwargs = {
        "headless": True,
        "humanize": True,
        "os": "windows",
    }
    if profile_dir:
        kwargs["persistent_context"] = True
        kwargs["user_data_dir"] = profile_dir
    return Camoufox(**kwargs)


def harvest(url, profile_dir, output, max_scrolls):
    with _launch(profile_dir) as browser:
        page = browser.new_page()
        page.set_default_timeout(45000)
        page.goto(url, wait_until="domcontentloaded", timeout=60000)
        time.sleep(random.uniform(1.5, 3.5))
        if is_blocked(page):
            return "blocked"
        for _ in range(max_scrolls):
            human_scroll(page, random.randint(400, 900))
            time.sleep(random.uniform(1.2, 3.0))
        if is_blocked(page):
            return "blocked"
        if output:
            text = page.locator("body").inner_text(timeout=10000)
            with open(output, "w", encoding="utf-8") as f:
                f.write(f"# {url}\n\n" + text[:200000])
        return "ok"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--profile-dir")
    ap.add_argument("--output")
    ap.add_argument("--max-scrolls", type=int, default=8)
    args = ap.parse_args()

    for attempt in range(RETRIES):
        profile = None
        if args.profile_dir:
            profile = (
                args.profile_dir if attempt == 0 else f"{args.profile_dir}-r{attempt}"
            )
        try:
            result = harvest(args.url, profile, args.output, args.max_scrolls)
        except Exception as exc:
            print(f"harvest error (attempt {attempt + 1}): {exc}")
            result = "error"
        if result == "ok":
            for i in range(1, RETRIES):
                stale = f"{args.profile_dir}-r{i}"
                if args.profile_dir and os.path.isdir(stale):
                    shutil.rmtree(stale, ignore_errors=True)
            print(f"OK {args.name} {args.url}")
            return 0
        if attempt < RETRIES - 1:
            wait = COOLDOWN[attempt] + random.randint(0, 30)
            print(
                f"{result} (attempt {attempt + 1}), retry in {wait}s with fresh identity"
            )
            time.sleep(wait)
    print(f"BLOCKED {args.name} {args.url} after {RETRIES} attempts")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
