"""Hand masks (2026-11-06): John's own strokes over a cut, saying where it is
solid and where it is see-through, painted in the mask painter
(scripts/mask_painter.py) and applied by the bakes (bake_foregrounds,
bake_props). The cutter makes paper clear, which is right between branches
and wrong in a trunk, a rock or a snow bank (John, 11-06: "the snow and
trunk and rocks NOT see through, but spots between branches see through").

A mask is art/edits/<name>_mask.png, an RGBA image over the cut (any size;
resized to the baked one):
    alpha 0                   untouched: the cut as the cutter left it
    white, opaque             solid: the painting itself, its paper included
    black, opaque             see-through: nothing
    anything between          the blend (a soft brush edge)

Solid means the painted pixel: the cut laid over its paper by day. At night
the caller says what solid shows (a foreground's black paper with its pale
ink, or a snow scene's moonlit snow).
"""
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
EDITS = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate", "art", "edits")
PAPER_RGB = (242, 238, 230)


def path_of(name):
    return os.path.join(EDITS, name + "_mask.png")


def load(name, size):
    """(solid, clear), each 0..1 at size (w, h), or None without a mask."""
    p = path_of(name)
    if not os.path.exists(p):
        return None
    m = Image.open(p).convert("RGBA").resize(size, Image.LANCZOS)
    m = np.asarray(m, float) / 255.0
    a, white = m[..., 3], m[..., 0]
    return a * white, a * (1.0 - white)


def on_paper(img):
    """0..1 RGB: an RGBA image laid over the paper (the painting as painted)."""
    p = np.asarray(img.convert("RGBA"), float) / 255.0
    paper = np.array(PAPER_RGB, float) / 255.0
    return p[..., :3] * p[..., 3:] + paper * (1.0 - p[..., 3:])


def on_black(img):
    """0..1 RGB: an RGBA image laid over black paper (the night negative)."""
    p = np.asarray(img.convert("RGBA"), float) / 255.0
    return p[..., :3] * p[..., 3:]


def apply(img, solid_rgb, mask):
    """img (RGBA) with the mask: solid shows solid_rgb (0..1), see-through
    shows nothing, untouched keeps img."""
    s, c = mask
    p = np.asarray(img.convert("RGBA"), float) / 255.0
    rgb, a = p[..., :3], p[..., 3]
    keep = np.clip(1.0 - s - c, 0.0, 1.0)
    new_a = a * keep + s
    pre = rgb * (a * keep)[..., None] + solid_rgb * s[..., None]
    new_rgb = pre / np.maximum(new_a, 1e-6)[..., None]
    out = np.dstack([new_rgb, new_a])
    return Image.fromarray(np.round(np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")
