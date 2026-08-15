"""Mode A: browser-use 0.13.5 agent attached to a headed Chrome via CDP.

Vision comes from Gemini (GEMINI_API_KEY env var, already configured).
Runs asyncio since browser-use's Agent.run is async.

Chrome is launched DIRECTLY (subprocess) — no patchright driver. Probe
evidence: raw-CDP-only chrome navigates cleanly (probe11), but a coexisting
patchright driver wedges the browser on the 2nd navigation regardless of
transport (pipe probe8 / connect_over_cdp probe18). browser_use connects via
its own raw cdp_use client, so the driver was only ever a launcher — and its
presence was the poison.
"""

import argparse
import asyncio
import os
import subprocess
import threading
import time
import urllib.request

os.environ.setdefault("GOOGLE_API_KEY", os.environ.get("GEMINI_API_KEY", ""))

CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"


def _start_chrome(profile_dir, port):
    """Launch Chrome directly (no patchright driver) and wait for CDP."""
    if not profile_dir:
        profile_dir = os.path.join(
            os.environ.get("TEMP", r"C:\Users\user\AppData\Local\Temp"),
            f"opencode-browser-use-{port}",
        )
    os.makedirs(profile_dir, exist_ok=True)
    args = [
        CHROME,
        f"--remote-debugging-port={port}",
        f"--user-data-dir={profile_dir}",
        "--start-maximized",
        # ponytail: --disable-gpu works around this box's renderer/compositor wedge
        # (OSM WebGL screenshot hang, Amazon CDP stalls) at the cost of software raster.
        "--disable-gpu",
        "--disable-blink-features=AutomationControlled",
        "--no-first-run",
        "--no-default-browser-check",
    ]
    proc = subprocess.Popen(args)
    for _ in range(60):
        if proc.poll() is not None:
            raise RuntimeError(f"chrome exited early with code {proc.returncode}")
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


def _stop_chrome(proc):
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


async def _run(task, profile_dir, port, max_steps):
    from browser_use import Agent, Browser

    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key or api_key == "YOUR_API_KEY":
        raise SystemExit(
            "GEMINI_API_KEY missing or placeholder — set the real key before running Mode A"
        )

    try:
        from browser_use.llm.google import ChatGoogle

        llm = ChatGoogle(model="gemini-3.5-flash-lite", api_key=api_key)
    except ImportError:
        try:
            from browser_use.llm import ChatGemini

            llm = ChatGemini()
        except ImportError:
            from browser_use import ChatGemini

            llm = ChatGemini()

    browser = Browser(cdp_url=f"http://127.0.0.1:{port}")
    agent = Agent(task=task, llm=llm, browser=browser, max_actions_per_step=1)
    await agent.run(max_steps=max_steps)


def _run_agent_thread(task, profile_dir, port, max_steps):
    err = {}

    def worker():
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        try:
            loop.run_until_complete(_run(task, profile_dir, port, max_steps))
        except Exception as exc:
            err["exc"] = exc
        finally:
            loop.close()

    t = threading.Thread(target=worker, daemon=True)
    t.start()
    t.join()
    if err:
        raise err["exc"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--profile-dir")
    ap.add_argument("--port", type=int, default=9222)
    ap.add_argument("--max-steps", type=int, default=20)
    args = ap.parse_args()

    proc = _start_chrome(args.profile_dir, args.port)
    try:
        _run_agent_thread(args.task, args.profile_dir, args.port, args.max_steps)
        return 0
    except Exception as exc:
        print(f"agent error: {exc}")
        return 1
    finally:
        _stop_chrome(proc)


if __name__ == "__main__":
    raise SystemExit(main())
