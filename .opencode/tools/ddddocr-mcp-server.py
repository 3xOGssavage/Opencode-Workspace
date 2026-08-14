"""ddddocr MCP server: offline OCR for legacy image/slider captchas.

Honest limits: solves legacy text + slider captchas only. It does NOT solve
Cloudflare Turnstile / reCAPTCHA / hCaptcha / DataDome — those go to the
SeleniumBase UC tier of the captcha ladder.
"""

import os

import ddddocr
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("ddddocr")

_ocr = ddddocr.DdddOcr(show_ad=False)
_slide = ddddocr.DdddOcr(det=False, show_ad=False)

_WS_ROOT = os.path.abspath(os.environ.get("DDDDOCR_ROOT", r"F:\CD"))


def _safe_read(path):
    p = os.path.abspath(path)
    if not p.lower().startswith(_WS_ROOT.lower() + os.sep):
        raise ValueError(f"path outside allowed root: {p}")
    return p


@mcp.tool()
def solve_text_captcha(image_path: str) -> str:
    """Recognize text/number characters in a legacy captcha image (PNG/JPG). Returns the recognized text."""
    with open(_safe_read(image_path), "rb") as f:
        return _ocr.classification(f.read())


@mcp.tool()
def solve_slider_captcha(background_path: str, target_path: str) -> int:
    """Find the horizontal offset (px) of the puzzle piece in a legacy slider captcha."""
    with (
        open(_safe_read(background_path), "rb") as bf,
        open(_safe_read(target_path), "rb") as tf,
    ):
        res = _slide.slide_match(bf.read(), tf.read())
    return int(res["target"][0])


if __name__ == "__main__":
    mcp.run()
