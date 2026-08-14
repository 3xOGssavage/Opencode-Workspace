"""Mode A: browser-use 0.13.5 agent attached to a headed Patchright Chrome via CDP.

Vision comes from Gemini (GEMINI_API_KEY env var, already configured).
Runs asyncio since browser-use's Agent.run is async.
"""

import argparse
import asyncio
import os
import threading

os.environ.setdefault("GOOGLE_API_KEY", os.environ.get("GEMINI_API_KEY", ""))


def _start_patchright(profile_dir, port):
    from patchright.sync_api import sync_playwright

    p = sync_playwright().start()
    common = {
        "user_data_dir": profile_dir or "",
        "headless": False,
        "args": [f"--remote-debugging-port={port}", "--start-maximized"],
    }
    try:
        ctx = p.chromium.launch_persistent_context(channel="chrome", **common)
    except Exception:
        ctx = p.chromium.launch_persistent_context(**common)
    page = ctx.new_page()
    return p, ctx, page


async def _run(task, profile_dir, port, max_steps):
    from browser_use import Agent, Browser

    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key or api_key == "YOUR_API_KEY":
        raise SystemExit(
            "GEMINI_API_KEY missing or placeholder — set the real key before running Mode A"
        )

    try:
        from browser_use.llm.google import ChatGoogle

        llm = ChatGoogle(model="gemini-2.5-flash", api_key=api_key)
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

    p, ctx, page = _start_patchright(args.profile_dir, args.port)
    try:
        _run_agent_thread(args.task, args.profile_dir, args.port, args.max_steps)
        return 0
    except Exception as exc:
        print(f"agent error: {exc}")
        return 1
    finally:
        try:
            ctx.close()
            p.stop()
        except Exception:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
