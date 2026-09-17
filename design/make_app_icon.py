#!/usr/bin/env python3
"""
Generate the loqin app icon — "rinshen-app-icon.png".

Renders the Aura brand as a single luminous aperture on a near-black void:
  - near-black radial void (canvas #080E13 -> void #04090D) with a soft cerulean lift
  - a glowing orb core (#E5F2FF hot core) wrapped in a cerulean halo
  - a crisp luminous cerulean ring (the aperture / iris) + a faint outer ripple ring
  - a subtle film grain, matching the app's GrainOverlay

Composition uses an additive glow budget so the mark stays calm and cerulean (never
flat white), with a dark gap separating the orb from the aperture ring.

Output: 1024x1024 sRGB RGB PNG (no alpha), the single-size iOS app icon spec.
"""

import numpy as np
from PIL import Image

SIZE = 1024
CX = SIZE / 2.0
CY = SIZE / 2.0 - 8.0  # optical centre

# ---- colour tokens (0..1), from AuraTheme.swift / design-system.md ----
GLOW_CORE = np.array([0.898, 0.949, 1.000])   # #E5F2FF orb hot core
ACCENT    = np.array([0.447, 0.702, 0.867])   # #72B3DD calm cerulean
ACCENT_D  = np.array([0.298, 0.514, 0.753])   # #4C83C0 deep cerulean
RING      = np.array([0.580, 0.780, 0.940])   # luminous aperture line
BG_CENTRE = np.array([0.050, 0.095, 0.140])   # soft cerulean lift at centre
BG_EDGE   = np.array([0.014, 0.032, 0.050])   # deepest void at corners


def gauss(r, sigma):
    return np.exp(-(r ** 2) / (2.0 * sigma ** 2))


def ss(a, b, x):
    """Smoothstep: 0 at a, 1 at b."""
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def cut_mask(r, r0, r1):
    """1 for r <= r0, 0 for r >= r1, smooth between."""
    return 1.0 - ss(r0, r1, r)


def main():
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float64)
    r = np.sqrt((x - CX) ** 2 + (y - CY) ** 2)

    # 1) background: near-black radial void with a soft cerulean lift.
    t = np.clip(1.0 - r / (SIZE * 0.72), 0.0, 1.0) ** 1.9
    bg = BG_EDGE[None, None, :] + (BG_CENTRE - BG_EDGE)[None, None, :] * t[..., None]

    # gentle diagonal light for depth
    diag = (np.arange(SIZE)[None, :] + np.arange(SIZE)[:, None]) / (2.0 * (SIZE - 1))
    bg += ((diag - 0.5) * 0.028)[..., None]

    # 2) a whisper of wide cerulean lift (very dim, keeps the void from being flat)
    bg += (gauss(r, 360.0) * 0.07)[..., None] * ACCENT[None, None, :]

    # 3) glowing orb: cool-white core + cerulean halo (halo hard-cut before the ring)
    core = gauss(r, 58.0) * 0.72
    halo = (gauss(r, 100.0) - gauss(r, 48.0)) * cut_mask(r, 150.0, 190.0) * 0.60
    bg += (core[..., None] * GLOW_CORE[None, None, :]
           + halo[..., None] * ACCENT[None, None, :])

    # 4) the aperture ring + a faint outer ripple ring
    ring = gauss(r - 244.0, 4.0)
    bg += ring[..., None] * RING[None, None, :]

    outer = gauss(r - 326.0, 5.0) * 0.40
    bg += outer[..., None] * ACCENT[None, None, :]

    # 5) film grain (subtle), matching the app's GrainOverlay
    rng = np.random.default_rng(20240826)
    bg += rng.normal(0.0, 0.008, (SIZE, SIZE, 1))

    bg = np.clip(bg, 0.0, 1.0)
    img = (bg * 255.0).round().astype(np.uint8)
    Image.fromarray(img).save("rinshen-app-icon.png", format="PNG")

    # ---- numeric verification along the vertical axis through the mark ----
    def px(radius):
        yy = int(CY + radius)
        return tuple(int(v) for v in img[yy, int(CX)])

    print("vertical samples (radius -> RGB), centre at r=0:")
    for rr in (0, 60, 110, 170, 210, 244, 280, 326, 380):
        print(f"  r={rr:>3}: {px(rr)}")
    print("corner (0,0):", tuple(int(v) for v in img[0, 0]))
    print("max per channel:", img.reshape(-1, 3).max(axis=0))
    print("mean RGB:", img.reshape(-1, 3).mean(axis=0).round(1))


if __name__ == "__main__":
    main()
