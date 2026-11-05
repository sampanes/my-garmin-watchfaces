#!/usr/bin/env python
"""Bake the inscription's fonts from the painters' numeral sheets (round 9).

The time and the seal's HR were drawn in glyphs our own script brushed
(gen_ink_font.py). Under the 11-05 art decision (no art drawn by our
scripts) they come from the painters' sheets instead, cut by
scripts/cut_art_kit.py:

    digits-<a|b>      minute digits 0-9        -> ink_digits
    kanji-<a|b>       hour kanji 〇一..九十廿    -> kanji_hours
    sealdigits-<a|b>  carved seal digits 0-9   -> seal_digits

Each set is cropped to its ink and scaled by ONE factor (so the painter's
relative sizes survive: 一 stays a single thin stroke), into the same line
metrics the old fonts had, so the View's layout is untouched. Digits sit on
a shared baseline; kanji are centered on the line, as a kanji box is. The
coverage is the cut's ink, normalized so the darkest stroke is full ink;
the View colors it (ink, pale ink at night, paper on the seal).

After a bake, run scripts/gen_halo.py: the paper halos are made from these
atlases.

    py -3.11 scripts/bake_glyphs.py [--digits b] [--kanji a] [--seal b] [--out DIR]

The defaults are John's picks (11-05): ChatGPT's digits and seal digits, Gemini's kanji.
"""
import argparse
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
CUTS = os.path.join(FACE, "art", "cuts")
FONT_DIR = os.path.join(FACE, "resources", "fonts")

DIGITS = "0123456789"
KANJI = "〇一二三四五六七八九十廿"
# name, cut set, cut names, chars, cap (px the set's median glyph stands),
# top margin, bearing, layout ("base": on a baseline, "mid": centered)
FONTS = [
    ("ink_digits", "digits", ["d%d" % i for i in range(10)], DIGITS, 40, 7, 3, "base"),
    ("kanji_hours", "kanji", ["k%d" % i for i in range(10)] + ["k10", "k20"], KANJI, 36, 6, 2, "mid"),
    ("seal_digits", "sealdigits", ["s%d" % i for i in range(10)], DIGITS, 15, 2, 1, "base"),
]
INK_FLOOR = 0.05   # coverage under this is not ink when cropping


def cut_alpha(sheet, name):
    d = os.path.join(CUTS, sheet)
    hits = [f for f in os.listdir(d) if f.endswith("_%s.png" % name)]
    if not hits:
        raise SystemExit("no cut %s/%s (run scripts/cut_art_kit.py --only %s)"
                         % (sheet, name, sheet))
    a = np.asarray(Image.open(os.path.join(d, hits[0])).convert("RGBA"), dtype=float)[..., 3] / 255.0
    ys, xs = np.nonzero(a >= INK_FLOOR)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def build(name, sheet, cuts, chars, cap, top, bearing, layout, out):
    line_h = cap + 2 * top
    src = [cut_alpha(sheet, c) for c in cuts]
    full = max(np.percentile(a[a >= INK_FLOOR], 99) for a in src)
    if layout == "base":
        scale = cap / float(np.median([a.shape[0] for a in src]))
    else:
        scale = cap / float(np.median([max(a.shape) for a in src]))
    glyphs = []
    for ch, a in zip(chars, src):
        w = max(1, int(round(a.shape[1] * scale)))
        h = max(1, int(round(a.shape[0] * scale)))
        im = Image.fromarray(np.round(np.clip(a / full, 0, 1) * 255).astype(np.uint8), "L")
        g = np.asarray(im.resize((w, h), Image.LANCZOS), dtype=np.uint8)
        yoff = top + cap - h if layout == "base" else (line_h - h) // 2
        if yoff < 0:                       # taller than the line: clip the top
            g, yoff = g[-yoff:], 0
        if yoff + g.shape[0] > line_h:     # or the bottom
            g = g[:line_h - yoff]
        glyphs.append({"ch": ch, "bmp": g, "xoff": bearing, "yoff": yoff,
                       "adv": g.shape[1] + 2 * bearing})
    atlas_w = sum(g["bmp"].shape[1] + 1 for g in glyphs) + 1
    atlas_h = max(g["bmp"].shape[0] for g in glyphs) + 2
    atlas = np.zeros((atlas_h, atlas_w), dtype=np.uint8)
    x = 1
    for g in glyphs:
        h, w = g["bmp"].shape
        atlas[1:1 + h, x:x + w] = g["bmp"]
        g["x"], g["y"] = x, 1
        x += w + 1
    os.makedirs(out, exist_ok=True)
    Image.fromarray(np.dstack([atlas] * 4), "RGBA").save(os.path.join(out, name + ".png"))
    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 '
        'smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0' % (name, cap),
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 '
        'alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4' % (line_h, top + cap, atlas_w, atlas_h),
        'page id=0 file="%s.png"' % name,
        'chars count=%d' % len(glyphs),
    ]
    for g in glyphs:
        h, w = g["bmp"].shape
        lines.append('char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d '
                     'xadvance=%d page=0 chnl=15'
                     % (ord(g["ch"]), g["x"], g["y"], w, h, g["xoff"], g["yoff"], g["adv"]))
    lines.append("kernings count=0")
    with open(os.path.join(out, name + ".fnt"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("baked %s from %s: line %d, advances %s" % (
        name, sheet, line_h, " ".join(str(g["adv"]) for g in glyphs)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--digits", default="b", help="painter of the minute digits: a (Gemini) or b (ChatGPT)")
    ap.add_argument("--kanji", default="a", help="painter of the hour kanji")
    ap.add_argument("--seal", default="b", help="painter of the seal digits")
    ap.add_argument("--out", default=FONT_DIR)
    args = ap.parse_args()
    pick = {"digits": args.digits, "kanji": args.kanji, "sealdigits": args.seal}
    for name, sheet, cuts, chars, cap, top, bearing, layout in FONTS:
        build(name, "%s-%s" % (sheet, pick[sheet]), cuts, chars, cap, top, bearing, layout, args.out)


if __name__ == "__main__":
    main()
