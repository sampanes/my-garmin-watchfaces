#!/usr/bin/env python
"""The paper grain: the last thing on the ink face painted by a script.

This was the generator of every plane of the 2026-10-27 kit (a port of the
browser benchmark's brushwork, playgrounds/ink-sandbox/main.js, to
numpy/Pillow). Since the 2026-11-05 art decision (top of ART_PIPELINE.md)
every piece of art comes from the ChatGPT and Gemini sheets instead: the
masses from scripts/gen_shape_library.py, the foreground from
scripts/bake_foregrounds.py, the far range, mist bands and near hills from
scripts/bake_planes.py. What is left here:

    paper_grain.png      240x240  washi grain, upscaled on-device (day only)

and the noise helpers scripts/gen_ink_font.py borrows. The grain is texture,
not a picture; it stays until a sheet supplies one. Every random draw goes
through seeded numpy RNGs: regeneration is byte-identical.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..",
    "watch-faces", "japanese-ink-heartrate", "resources", "drawables")


# ------------------------------------------------------------------ noise

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vnoise(pos, seed, n=4096):
    """1-D value noise sampled at float positions (cell = 1), output [0,1]."""
    tab = np.random.default_rng(seed).random(n + 2)
    p = np.mod(np.asarray(pos, dtype=float), n)
    i0 = np.floor(p).astype(int)
    t = p - i0
    t = t * t * (3.0 - 2.0 * t)
    return tab[i0] * (1.0 - t) + tab[i0 + 1] * t


def fbm(pos, seed, octaves=4, lacunarity=2.0, gain=0.5):
    """Fractal value noise in about [-1, 1]."""
    out = np.zeros_like(np.asarray(pos, dtype=float))
    amp, freq, total = 1.0, 1.0, 0.0
    for i in range(octaves):
        out += amp * (2.0 * vnoise(pos * freq + i * 17.3, seed + i * 101) - 1.0)
        total += amp
        amp *= gain
        freq *= lacunarity
    return out / total


def turbulence(pos, seed, octaves=3):
    out = np.zeros_like(np.asarray(pos, dtype=float))
    amp, freq, total = 1.0, 1.0, 0.0
    for i in range(octaves):
        out += amp * np.abs(2.0 * vnoise(pos * freq + i * 7.1, seed + i * 37) - 1.0)
        total += amp
        amp *= 0.5
        freq *= 2.0
    return out / total


def domain_warp(pos, seed, strength=0.3):
    """Nested fbm, the benchmark's 'folded rock' edge quality (1-D form)."""
    q0 = fbm(pos, seed + 1)
    q1 = fbm(pos + 5.2, seed + 2)
    r0 = fbm(pos + strength * q0 + 1.7, seed + 3)
    r1 = fbm(pos + strength * q1 + 9.2, seed + 4)
    return fbm(pos + strength * (r0 + 0.5 * r1), seed + 5)


def vnoise2(h, w, cell_y, cell_x, seed, octaves=3, gain=0.55):
    """2-D value noise in [0,1], shape (h, w). Used for stroke modulation."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    cy, cx = float(cell_y), float(cell_x)
    for _ in range(octaves):
        ky = max(int(np.ceil(h / cy)) + 2, 2)
        kx = max(int(np.ceil(w / cx)) + 2, 2)
        grid = rng.random((ky, kx))
        ys = np.arange(h) / cy
        xs = np.arange(w) / cx
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        ty = (ys - y0)[:, None]
        tx = (xs - x0)[None, :]
        ty = ty * ty * (3 - 2 * ty)
        tx = tx * tx * (3 - 2 * tx)
        top = grid[np.ix_(y0, x0)] * (1 - tx) + grid[np.ix_(y0, x0 + 1)] * tx
        bot = grid[np.ix_(y0 + 1, x0)] * (1 - tx) + grid[np.ix_(y0 + 1, x0 + 1)] * tx
        out += amp * (top * (1 - ty) + bot * ty)
        total += amp
        amp *= gain
        cy = max(cy * 0.5, 1.5)
        cx = max(cx * 0.5, 1.5)
    return out / total


def over(a, s):
    """Source-over of a stroke alpha s onto canvas alpha a (same ink)."""
    return a + s * (1.0 - a)


# ---------------------------------------------------------------- paper

def make_paper_grain(size, seed):
    """Subtle washi fiber grain: low-freq mottle + sparse flecks + rim
    vignette. Max alpha kept tiny so it tones rather than speckles. Authored
    small and upscaled on-device. (Unchanged from the 2026-06 kit.)"""
    Wp = Hp = size
    mottle = vnoise2(Hp, Wp, 26, 34, seed, octaves=3)
    fibers = vnoise2(Hp, Wp, 1.6, 12, seed + 1, octaves=2)   # horizontal-ish
    rng = np.random.default_rng(seed + 2)
    flecks = (rng.random((Hp, Wp)) > 0.9985).astype(float)
    fleck_img = Image.fromarray((flecks * 255).astype(np.uint8), "L") \
        .filter(ImageFilter.GaussianBlur(0.7))
    flecks = np.asarray(fleck_img, dtype=float) / 255.0
    yy, xx = np.mgrid[0:Hp, 0:Wp].astype(float)
    r = np.sqrt((xx - Wp / 2) ** 2 + (yy - Hp / 2) ** 2) / (Wp / 2)
    vign = smoothstep(0.82, 1.02, r)
    dark = np.clip((mottle - 0.5) * 0.5 + (fibers - 0.5) * 0.25, 0, 1) * 0.055 \
        + flecks * 0.10 + vign * 0.05
    a = (np.clip(dark, 0, 0.16) * 255).astype(np.uint8)
    rgb = np.zeros((Hp, Wp, 3), dtype=np.uint8)
    rgb[..., 0], rgb[..., 1], rgb[..., 2] = (96, 84, 70)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    make_paper_grain(240, seed=99).save(os.path.join(OUT_DIR, "paper_grain.png"))
    print("paper grain written to", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
