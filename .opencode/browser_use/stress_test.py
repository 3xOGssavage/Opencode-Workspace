"""S2 stress test — driverless CDP Chrome multi-tab handling.

Opens N tabs via browser-use Browser(cdp_url=...) (the validated driverless
path from agent_runner.py), records per-tab navigation latency + title
verification, and RSS at milestones. No second CDP client is ever attached.

Usage:
    python stress_test.py --variant A --out <jsonl>
    python stress_test.py --variant B --out <jsonl>
"""

import argparse
import asyncio
import json
import os
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psutil

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    os.path.join(
        os.environ.get("LOCALAPPDATA", ""), r"Google\Chrome\Application\chrome.exe"
    ),
]

FALLBACK_HTML = (
    b"<!doctype html><html><head><title>Fixture</title></head>"
    b"<body><h1>Fixture</h1></body></html>"
)

SITES = [
    "https://example.com/",
    "https://www.iana.org/help/example-domains",
    "https://httpbin.org/html",
    "https://www.wikipedia.org/",
    "https://news.ycombinator.com/",
]

MILESTONES = [1, 5, 10, 25, 50]
NAV_TIMEOUT_S = 30


def find_chrome():
    for p in CHROME_CANDIDATES:
        if p and os.path.exists(p):
            return p
    raise SystemExit("chrome.exe not found in common paths")


def chrome_version(chrome):
    try:
        out = subprocess.run(
            [chrome, "--version"], capture_output=True, text=True, timeout=30
        )
        return (out.stdout or out.stderr or "unknown").strip()
    except Exception as exc:
        return f"version-read-failed: {exc}"


def start_chrome(chrome, profile_dir, port):
    os.makedirs(profile_dir, exist_ok=True)
    args = [
        chrome,
        f"--remote-debugging-port={port}",
        f"--user-data-dir={profile_dir}",
        "--start-maximized",
        "--disable-gpu",
        "--disable-blink-features=AutomationControlled",
        "--no-first-run",
        "--no-default-browser-check",
    ]
    proc = subprocess.Popen(args)
    for _ in range(60):
        if proc.poll() is not None:
            raise RuntimeError(f"chrome exited early code {proc.returncode}")
        try:
            with urllib.request.urlopen(
                f"http://127.0.0.1:{port}/json/version", timeout=2
            ) as r:
                r.read()
            return proc
        except Exception:
            time.sleep(0.5)
    proc.kill()
    raise RuntimeError(f"chrome CDP endpoint not ready on port {port}")


def stop_chrome(proc):
    if proc.poll() is not None:
        return
    try:
        proc.terminate()
        proc.wait(timeout=5)
    except Exception:
        try:
            subprocess.run(
                ["taskkill", "/T", "/F", "/PID", str(proc.pid)],
                capture_output=True,
                timeout=10,
            )
        except Exception:
            pass


def cleanup_profile(profile_dir, proc):
    """Kill chrome (if alive), wait, then rmtree the profile dir."""
    stop_chrome(proc)
    time.sleep(2)
    if os.path.isdir(profile_dir):
        try:
            shutil.rmtree(profile_dir)
        except Exception as exc:
            print(f"warning: profile rmtree failed: {exc}", file=sys.stderr)


def rss_mb_of_tree(root_pid):
    """Sum WorkingSetSize of root chrome PID + all descendants (MB)."""
    try:
        root = psutil.Process(root_pid)
        total = root.memory_info().rss
        for child in root.children(recursive=True):
            try:
                total += child.memory_info().rss
            except Exception:
                pass
        return round(total / (1024 * 1024), 1)
    except Exception:
        return -1.0


class _FixtureHandler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(FALLBACK_HTML)))
        self.end_headers()
        self.wfile.write(FALLBACK_HTML)

    def log_message(self, *args):
        pass


def run_fixture_server():
    server = ThreadingHTTPServer(("127.0.0.1", 8765), _FixtureHandler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


def build_urls(variant):
    if variant == "A":
        return ["https://example.com/"] * 50
    return [SITES[i % len(SITES)] for i in range(25)]


def _norm(u):
    return (u or "").rstrip("/")


async def find_target(browser, url):
    """Find a target whose url matches exactly; return (found, title).
    Prefers a match with a populated title; falls back to match-only after ~3s.
    """
    want = _norm(url)
    fallback = (False, None)
    for _ in range(30):  # up to ~3s for the target to register
        for target in browser.get_page_targets():
            if _norm(target.url) == want:
                if target.title:
                    return True, target.title
                fallback = (True, None)
        await asyncio.sleep(0.1)
    return fallback


async def run_variant(variant, urls, out_path, chrome, profile_dir, port):
    profile_dir = os.path.join(
        profile_dir or os.environ.get("TEMP", r"C:\Users\user\AppData\Local\Temp"),
        f"opencode-browser-use-{port}",
    )
    proc = None
    records = []
    chrome_start = chrome_version(chrome)
    try:
        proc = start_chrome(chrome, profile_dir, port)
        from browser_use import Browser

        browser = Browser(cdp_url=f"http://127.0.0.1:{port}")
        await browser.start()
        for i, url in enumerate(urls):
            n = i + 1
            t0 = time.monotonic()
            ok, title, err = False, None, None
            try:
                await asyncio.wait_for(browser.new_page(url), timeout=NAV_TIMEOUT_S)
                found, title = await find_target(browser, url)
                ok = found
            except Exception as exc:
                err = str(exc)[:300]
            nav_ms = round((time.monotonic() - t0) * 1000, 1)
            rec = {
                "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
                "variant": variant,
                "n": n,
                "url": url,
                "nav_ms": nav_ms,
                "title": title,
                "ok": ok,
                "err": err,
            }
            if n in MILESTONES:
                rec["rss_mb"] = rss_mb_of_tree(proc.pid)
            records.append(rec)
            print(f"[{variant}] tab {n}/{len(urls)} ok={ok} nav={nav_ms}ms title={title!r} err={err}", flush=True)
        await browser.close() if hasattr(browser, "close") else None
    finally:
        if proc is not None:
            cleanup_profile(profile_dir, proc)
    chrome_end = chrome_version(chrome)
    summary = {
        "ts": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "variant": variant,
        "type": "summary",
        "total": len(urls),
        "failures": sum(1 for r in records if not r["ok"]),
        "chrome_start": chrome_start,
        "chrome_end": chrome_end,
    }
    records.append(summary)
    with open(out_path, "a", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec) + "\n")
    print(json.dumps(summary, indent=2), flush=True)
    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", choices=["A", "B"], required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--port", type=int, default=9222)
    ap.add_argument("--profile-dir")
    args = ap.parse_args()

    urls = build_urls(args.variant)
    chrome = find_chrome()
    print(f"chrome: {chrome_version(chrome)}", flush=True)
    summary = asyncio.run(
        run_variant(args.variant, urls, args.out, chrome, args.profile_dir, args.port)
    )

    # Fallback: variant A with >=1 failure that looks network-y -> local fixture.
    if args.variant == "A" and summary["failures"] > 0:
        print("variant A had failures — retrying against local fixture server", flush=True)
        server = run_fixture_server()
        try:
            summary2 = asyncio.run(
                run_variant(
                    "A", ["http://127.0.0.1:8765/"] * 50,
                    args.out, chrome, args.profile_dir, args.port,
                )
            )
        finally:
            server.shutdown()
        if summary2["failures"] == 0:
            print("fallback PASS — local fixture handled all 50 tabs", flush=True)
        else:
            print(f"fallback FAIL — {summary2['failures']} failures remain", flush=True)
    return 0 if summary["failures"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())