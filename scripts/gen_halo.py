#!/usr/bin/env python
"""Bake the paper halo that sits between the painting and the inscription.

A painter leaves bare paper where the inscription goes. The face's
foregrounds are full paintings, so a branch can run behind the time; the
halo fades the painting back to paper just around each glyph and around the
seal, following the letter shapes, so the time reads on any scene.

The Dc has no blur, so each halo is baked: the glyph's coverage from the
inscription font atlas, dilated and blurred, as a bitmap in paper colour
(black for the night set). The View draws the halo bitmaps first, then the
ink on top.

Why bitmaps and not a second font: a Connect IQ font keeps only a few alpha
levels (a soft edge turns into contour rings) and clips each glyph to its
line box. A bitmap keeps its full alpha and lands on an exact pixel.

Each halo bitmap is its ink glyph's whole cell (advance x line height) grown
by PAD on every side, so it is drawn at (pen - PAD, line top - PAD), where
pen and line top are where the ink glyph is drawn (LEFT / TOP justified).

    resources/drawables/halo_d<0-9>[_night].png    minute digits (ink_digits)
    resources/drawables/halo_k<hex>[_night].png    hour kanji (kanji_hours),
                                                    by code point
    resources/drawables/halo_seal[_night].png      the seal square
    resources/drawables/halo.xml                   their resource ids

Usage: python scripts/gen_halo.py [--grow 9] [--blur 7] [--gain 1.6]
"""

import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate", "resources")
FONT_DIR = os.path.join(FACE, "fonts")
DRAW_DIR = os.path.join(FACE, "drawables")
W = 416            # fr265; the View sizes the seal as width * 85 / 1000
SEAL = (W * 85) // 1000
FLOOR = 3          # halo alpha below this (0..255) is dropped
PAPER = (242, 238, 230)
ATTRS = 'dithering="none" automaticPalette="false" packingFormat="png" compress="false"'


def read_fnt(path):
    line_h, chars = None, []
    for line in open(path):
        kv = dict(t.split("=", 1) for t in line.split()[1:] if "=" in t)
        if line.startswith("common "):
            line_h = int(kv["lineHeight"])
        elif line.startswith("char "):
            chars.append({k: int(v) for k, v in kv.items()})
    return line_h, chars


def pad_for(grow, blur):
    # the blurred edge has faded under FLOOR by 2.5 radii past the dilation
    return grow + int(math.ceil(2.5 * blur))


def halo(cell, grow, blur, gain):
    """ink coverage on its padded cell canvas -> halo coverage"""
    big = cell.filter(ImageFilter.MaxFilter(2 * grow + 1))
    big = big.filter(ImageFilter.GaussianBlur(blur))
    return big.point(lambda v: 0 if v * gain < FLOOR else int(min(255, v * gain)))


def save(name, alpha, xml):
    for sfx, rgb in (("", PAPER), ("_night", (0, 0, 0))):
        im = Image.new("RGBA", alpha.size, rgb + (0,))
        im.putalpha(alpha)
        fn = "%s%s.png" % (name, sfx)
        im.save(os.path.join(DRAW_DIR, fn), optimize=True)
        rid = "".join(p[:1].upper() + p[1:] for p in (name + sfx).split("_"))
        xml.append('    <bitmap id="%s" filename="%s" %s />' % (rid, fn, ATTRS))


def font_halos(src, prefix, key, grow, blur, gain, xml):
    line_h, chars = read_fnt(os.path.join(FONT_DIR, src + ".fnt"))
    cover = Image.open(os.path.join(FONT_DIR, src + ".png")).getchannel("A")
    pad = pad_for(grow, blur)
    chars = [c for c in chars if key(c["id"]) is not None]
    for c in chars:
        a = cover.crop((c["x"], c["y"], c["x"] + c["width"], c["y"] + c["height"]))
        cell = Image.new("L", (c["xadvance"] + 2 * pad, line_h + 2 * pad), 0)
        cell.paste(a, (pad + c["xoffset"], pad + c["yoffset"]))
        save(prefix + key(c["id"]), halo(cell, grow, blur, gain), xml)
    print("[OK] %s: %d halos, pad %d, line %d" % (src, len(chars), pad, line_h))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grow", type=int, default=9, help="px the glyph is widened by")
    ap.add_argument("--blur", type=float, default=7, help="gaussian radius, px")
    ap.add_argument("--gain", type=float, default=1.6, help="halo coverage multiplier")
    args = ap.parse_args()
    g = (args.grow, args.blur, args.gain)
    xml = []
    # the colon is in the font but never drawn
    font_halos("ink_digits", "halo_d", lambda cid: chr(cid) if chr(cid).isdigit() else None,
               *g, xml=xml)
    font_halos("kanji_hours", "halo_k", lambda cid: "%04x" % cid, *g, xml=xml)
    pad = pad_for(args.grow, args.blur)
    cell = Image.new("L", (SEAL + 2 * pad, SEAL + 2 * pad), 0)
    ImageDraw.Draw(cell).rounded_rectangle([pad, pad, pad + SEAL - 1, pad + SEAL - 1],
                                           radius=SEAL // 7, fill=255)
    save("halo_seal", halo(cell, *g), xml)
    with open(os.path.join(DRAW_DIR, "halo.xml"), "w", newline="\n") as f:
        f.write('<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
                'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/'
                'connect-iq/resources.xsd">\n')
        f.write("    <!-- Generated by scripts/gen_halo.py; do not edit. The paper halo\n"
                "         behind the inscription: one per glyph, day and night. -->\n")
        f.write("\n".join(xml) + "\n</drawables>\n")
    print("[OK] halo.xml: %d bitmaps, PAD = %d (the View's HALO_PAD)" % (len(xml), pad))


if __name__ == "__main__":
    main()
