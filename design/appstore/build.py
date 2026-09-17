#!/usr/bin/env python3
"""Compose App Store screenshots for du vide.

Takes the raw 1320x2868 simulator captures in `shots/` and lays a headline into each frame's
own empty space, in the app's own serif (New York), so the marketing type reads as part of the
world rather than an overlay. Renders with headless Chrome at 1:1, then verifies dimensions.

    python3 build.py

Output: out/1..5.png (App Store 6.9" display, 1320x2868) plus out/contact-sheet.png
"""

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SHOTS = ROOT / "shots"
OUT = ROOT / "out"
# App Store Connect accepts 1284x2778 (6.7") and 1242x2688 (6.5"); it rejects 1320x2868.
# Captured natively on an iPhone 14 Plus simulator (428x926pt @3x), so nothing is ever rescaled.
W, H = 1284, 2778

# Frame positions below are authored in this reference space and scaled to W x H, so the same
# numbers keep working if the required submission size changes again.
REF_W, REF_H = 1284, 2778


def sx(v: float) -> int:
    """Scale a horizontal reference value (and type sizes) to the output width."""
    return round(v * W / REF_W)


def sy(v: float) -> int:
    """Scale a vertical reference value to the output height."""
    return round(v * H / REF_H)

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
TMP_PROFILE = tempfile.mkdtemp(prefix="duvide-shots-chrome-")

# Frames in App Store display order. The palette runs light -> blue -> navy -> near-black so the
# carousel reads as one gradient as you swipe.
FRAMES = [
    {
        "src": "01-gym-home.png",
        "name": "1",
        "lines": ["one gesture", "locks you in."],
        "top": 420,
        "color": "#1F2227",
    },
    {
        # The app's own "leave the noise." is the headline here; anything added would double up.
        "src": "02-study-home.png",
        "name": "2",
        "lines": [],
    },
    {
        "src": "03-session.png",
        "name": "3",
        "lines": ["no streaks. no badges.", "just time."],
        "top": 400,
        "color": "#FFFFFF",
    },
    {
        "src": "05-insights.png",
        "name": "4",
        "lines": ["every session,", "quietly kept."],
        "top": 2400,
        "size": 90,
        "color": "#FFFFFF",
        # The list runs to the bottom edge. Fade it into the frame's own base colour, starting in
        # the gap *below* the last full row so no row is left half-faded or clipped mid-glyph.
        "fade": {"from": 2245, "to": 2360, "color": "9, 15, 33"},
    },
    {
        "src": "04-wheel.png",
        "name": "5",
        "lines": ["a world for every", "place you go."],
        "top": 2200,
        "color": "#FFFFFF",
    },
]

PAGE = """<!doctype html>
<meta charset="utf-8">
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{ width: {W}px; height: {H}px; overflow: hidden; }}
  .frame {{ position: relative; width: {W}px; height: {H}px; }}
  .shot {{ position: absolute; inset: 0; width: {W}px; height: {H}px; display: block; }}
  .fade {{ position: absolute; left: 0; right: 0; }}
  .headline {{
    position: absolute;
    left: 96px;
    right: 96px;
    font-family: "New York", ui-serif, Georgia, serif;
    font-weight: 600;
    font-size: 100px;
    line-height: 1.12;
    letter-spacing: -0.021em;
    text-rendering: geometricPrecision;
    -webkit-font-smoothing: antialiased;
  }}
</style>
<div class="frame">
  <img class="shot" src="{src}">
  {fade}
  {headline}
</div>
"""


def render(frame: int) -> Path:
    spec = FRAMES[frame]
    src = (SHOTS / spec["src"]).as_uri()

    fade = ""
    if f := spec.get("fade"):
        fade = (
            '<div class="fade" style="top:{f}px;height:{h}px;background:linear-gradient('
            "to bottom, rgba({c},0) 0%, rgba({c},0.72) 46%, rgba({c},1) 100%);\"></div>"
            '<div class="fade" style="top:{t}px;bottom:0;background:rgb({c});"></div>'
        ).format(
            f=sy(f["from"]),
            h=sy(f["to"]) - sy(f["from"]),
            t=sy(f["to"]),
            c=f["color"],
        )

    headline = ""
    if spec["lines"]:
        body = "<br>".join(spec["lines"])
        headline = (
            '<div class="headline" style="top:{t}px;left:{m}px;right:{m}px;'
            'color:{c};font-size:{s}px;">{b}</div>'
        ).format(
            t=sy(spec["top"]),
            m=sx(93),
            c=spec["color"],
            b=body,
            s=sx(spec.get("size", 97)),
        )

    html = PAGE.format(W=W, H=H, src=src, fade=fade, headline=headline)
    page = OUT / f"_frame-{spec['name']}.html"
    page.write_text(html)

    dest = OUT / f"{spec['name']}.png"
    if dest.exists():
        dest.unlink()

    cmd = [
        CHROME,
        "--headless",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        # Isolated profile: the default one is locked whenever the user's Chrome is open.
        f"--user-data-dir={TMP_PROFILE}",
        "--force-device-scale-factor=1",
        f"--window-size={W},{H}",
        f"--screenshot={dest}",
        page.as_uri(),
    ]
    # Chrome writes the screenshot and then frequently fails to exit, so bound it and judge by
    # the file it produced rather than by its exit status.
    try:
        subprocess.run(cmd, timeout=45, capture_output=True)
    except subprocess.TimeoutExpired:
        pass
    if not dest.exists():
        raise RuntimeError(f"chrome produced no screenshot for frame {spec['name']}")

    # App Store Connect rejects PNGs carrying an alpha channel, which Chrome always writes.
    from PIL import Image

    with Image.open(dest) as im:
        flat = im.convert("RGB")
    flat.save(dest, "PNG", optimize=True)
    return dest


def main() -> int:
    OUT.mkdir(exist_ok=True)
    missing = [f["src"] for f in FRAMES if not (SHOTS / f["src"]).exists()]
    if missing:
        print("missing source captures:", ", ".join(missing), file=sys.stderr)
        return 1

    from PIL import Image

    rendered = []
    for i in range(len(FRAMES)):
        dest = render(i)
        im = Image.open(dest)
        ok = im.size == (W, H)
        kb = dest.stat().st_size / 1024
        print(f"  {dest.name:<12} {im.size[0]}x{im.size[1]}  {kb:7.0f} KB  {'ok' if ok else 'WRONG SIZE'}")
        if not ok:
            return 1
        rendered.append(dest)

    # Contact sheet, for judging the set side by side.
    scale = 6
    tw, th = W // scale, H // scale
    sheet = Image.new("RGB", (tw * len(rendered) + 20 * (len(rendered) + 1), th + 40), "#111315")
    for i, p in enumerate(rendered):
        sheet.paste(Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS), (20 + i * (tw + 20), 20))
    sheet.save(OUT / "contact-sheet.png")
    print(f"  contact-sheet.png {sheet.size[0]}x{sheet.size[1]}")

    for p in OUT.glob("_frame-*.html"):
        p.unlink()
    return 0


if __name__ == "__main__":
    sys.exit(main())
