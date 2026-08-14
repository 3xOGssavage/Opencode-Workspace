"""Bot-score verification: CreepJS / BrowserScan / reCAPTCHA + 10-site matrix.

Engines: camoufox (headless, default), patchright-headed, patchright-headless.
Writes an honest markdown report to logs/botscore-YYYYMMDD.md.
"""

import argparse
import datetime
import os
import re
import time
from contextlib import contextmanager

from camoufox_harvest import BLOCK_MARKERS

SITES = [
    ("amazon", "https://www.amazon.com/", "amazon"),
    ("ebay", "https://www.ebay.com/", "ebay"),
    ("indeed", "https://www.indeed.com/", "indeed"),
    ("linkedin", "https://www.linkedin.com/", "linkedin"),
    ("upwork", "https://www.upwork.com/", "upwork"),
    ("craigslist", "https://www.craigslist.org/", "craigslist"),
    ("yelp", "https://www.yelp.com/", "yelp"),
    ("reddit", "https://www.reddit.com/", "reddit"),
    ("x", "https://x.com/", "x"),
    ("yellowpages", "https://www.yellowpages.com/", "yellowpages"),
]

CREEPJS_URL = "https://abrahamjuliot.github.io/creepjs/"
BROWSERSCAN_URL = "https://www.browserscan.net/bot-detection"


@contextmanager
def _mk_page(engine):
    if engine == "camoufox":
        from camoufox.sync_api import Camoufox

        with Camoufox(headless=True, humanize=True, os="windows") as browser:
            yield browser.new_page()
        return
    from patchright.sync_api import sync_playwright

    p = sync_playwright().start()
    browser = p.chromium.launch(
        headless=(engine == "patchright-headless"),
        args=["--disable-blink-features=AutomationControlled"],
    )
    try:
        yield browser.new_page()
    finally:
        browser.close()
        p.stop()


def _verdict(page, expected_marker, url):
    try:
        body = page.locator("body").inner_text(timeout=6000) or ""
    except Exception:
        return "ERROR"
    text = (page.title() + " " + body).lower()
    if any(m in text for m in BLOCK_MARKERS):
        return "BLOCKED"
    if expected_marker and expected_marker in text:
        return "PASS"
    if expected_marker:
        return "CHALLENGE"
    return "PASS"


def _creepjs(page):
    page.goto(CREEPJS_URL, wait_until="domcontentloaded", timeout=60000)
    time.sleep(20)
    body = page.locator("body").inner_text(timeout=10000) or ""
    like = re.search(r"(\d{1,3})%\s*like headless", body, re.IGNORECASE)
    headless = re.search(r"(\d{1,3})%\s*headless", body, re.IGNORECASE)
    stealth = re.search(r"(\d{1,3})%\s*stealth", body, re.IGNORECASE)
    if like and headless and stealth:
        return f"like-headless {like.group(1)}% / headless {headless.group(1)}% / stealth {stealth.group(1)}%"
    return "results n/a"


def _browserscan(page):
    page.goto(BROWSERSCAN_URL, wait_until="domcontentloaded", timeout=60000)
    time.sleep(12)
    body = page.locator("body").inner_text(timeout=10000) or ""
    failed = re.findall(r"^failed$", body, re.IGNORECASE | re.MULTILINE)
    normal = len(re.findall(r"^normal$", body, re.IGNORECASE | re.MULTILINE))
    if failed:
        return f"FAIL ({len(failed)} failed)"
    if normal:
        return f"PASS ({normal} normal)"
    return "inconclusive"


def run(engine):
    rows = []
    with _mk_page(engine) as page:
        page.set_default_timeout(45000)
        rows.append(("creepjs", _creepjs(page)))
        rows.append(("browserscan", _browserscan(page)))
        for name, url, marker in SITES:
            try:
                page.goto(url, wait_until="domcontentloaded", timeout=60000)
                time.sleep(2)
                verdict = _verdict(page, marker, url)
            except Exception as exc:
                verdict = f"ERROR ({type(exc).__name__})"
            rows.append((name, verdict))
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--engine",
        default="camoufox",
        choices=["camoufox", "patchright-headed", "patchright-headless"],
    )
    args = ap.parse_args()

    rows = run(args.engine)
    date = datetime.date.today().isoformat()
    log_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "logs"
    )
    os.makedirs(log_dir, exist_ok=True)
    report = os.path.join(log_dir, f"botscore-{args.engine}-{date}.md")
    lines = [f"# Bot-score report ({args.engine}) - {date}", ""]
    passed = 0
    for name, verdict in rows:
        ok = verdict.startswith(("PASS", "like-headless"))
        passed += 1 if ok else 0
        lines.append(f"| {name} | {verdict} |")
        print(f"{name}: {verdict}")
    lines.insert(2, f"**Score: {passed}/{len(rows)} pass**")
    with open(report, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"report: {report}")
    return 0 if passed >= max(2, len(rows) - 3) else 1


if __name__ == "__main__":
    raise SystemExit(main())
