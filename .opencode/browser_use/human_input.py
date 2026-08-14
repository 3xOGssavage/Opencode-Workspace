"""Human-like input layer: Bezier mouse, jittered typing, eased scrolling.

All helpers drive Playwright's page.mouse/keyboard, which works both headed
and headless (Camoufox Mode B + botscore). OS-level PyAutoGUI clicks for
captchas are handled by SeleniumBase UC, not here.
"""

import math
import random
import time


def bezier(p0, p1, p2, p3, steps):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        mt = 1 - t
        x = (
            mt**3 * p0[0]
            + 3 * mt * mt * t * p1[0]
            + 3 * mt * t * t * p2[0]
            + t**3 * p3[0]
        )
        y = (
            mt**3 * p0[1]
            + 3 * mt * mt * t * p1[1]
            + 3 * mt * t * t * p2[1]
            + t**3 * p3[1]
        )
        pts.append((x, y))
    return pts


def fitts_ms(distance, target_px=8):
    base = 300 + 320 * math.log2(max(distance, 2) / max(target_px, 2) + 1)
    return max(120, min(1400, base * random.uniform(0.85, 1.25)))


_pos = None


def _get_pos(page):
    global _pos
    if _pos is None:
        vs = page.viewport_size or {"width": 1280, "height": 720}
        _pos = (
            vs["width"] * random.uniform(0.3, 0.7),
            vs["height"] * random.uniform(0.4, 0.7),
        )
    return _pos


def human_move(page, x, y):
    """Move the mouse to (x, y) along a randomized Bezier path with tremor and optional overshoot."""
    global _pos
    sx, sy = _get_pos(page)
    dist = math.hypot(x - sx, y - sy)
    if dist < 4:
        page.mouse.move(x, y)
        _pos = (x, y)
        return
    dur = fitts_ms(dist)
    n = max(10, min(40, int(dur / 30)))
    c1 = (
        sx + (x - sx) * random.uniform(0.2, 0.5),
        sy + (y - sy) * random.uniform(0.2, 0.5),
    )
    c2 = (
        sx + (x - sx) * random.uniform(0.5, 0.8),
        sy + (y - sy) * random.uniform(0.5, 0.8),
    )
    pts = bezier((sx, sy), c1, c2, (x, y), n)
    step = dur / n
    for px, py in pts:
        page.mouse.move(px + random.uniform(-1.2, 1.2), py + random.uniform(-1.2, 1.2))
        time.sleep(step / 1000 + random.uniform(0, 0.015))
    page.mouse.move(x, y)
    _pos = (x, y)


def human_click(page, x, y):
    human_move(page, x, y)
    time.sleep(random.uniform(0.06, 0.26))
    page.mouse.down()
    time.sleep(random.uniform(0.05, 0.12))
    page.mouse.up()
    time.sleep(random.uniform(0.1, 0.4))


def human_type(page, locator, text):
    locator.scroll_into_view_if_needed(timeout=10000)
    box = locator.bounding_box()
    if not box:
        raise RuntimeError("element has no bounding box")
    human_click(page, box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
    for ch in text:
        page.keyboard.type(ch)
        time.sleep(random.uniform(0.06, 0.22))
        if random.random() < 0.03:
            time.sleep(random.uniform(0.3, 0.9))


def human_scroll(page, delta):
    remaining = delta
    while remaining != 0:
        chunk = max(-500, min(500, remaining))
        page.mouse.wheel(0, chunk + random.randint(-3, 3))
        remaining -= chunk
        time.sleep(random.uniform(0.12, 0.4))
