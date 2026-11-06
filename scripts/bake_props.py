#!/usr/bin/env python
"""The props (2026-11-05): small pieces from the ChatGPT prop sheets, each
shown by one rule, so a prop always means something (John, 11-05).

    sun            daytime (sunrise to sunset), on the day arc: replaces the disc
                   the code used to draw
    moon_*         sunset to sunrise, on the night arc, by the real moon
                   phase: full, a waxing or waning crescent, none at new moon
    geese          today's step goal is met: across the sky, on the side
                   away from the sun or moon
    village / hut  a quiet window (a horizon and no mountain): in the valley
                   under the far range, the village on even days, the hut on
                   odd ones
    hiker          a recorded workout overlaps the window (11-06; the heart
                   rate alone said workout on a lazy day): on the highest summit
    swallow        unread notifications: at its spot (bake_spots.py), 24 px
    clouds         a cloudy sky (or a chance of rain or snow): the cloud bank
                   in place of the sun or moon, upper right (11-06)
    cloud_wisp     a few clouds, mist, haze or smoke: a wisp across the sun
                   or moon
    lantern        the battery is under 30%: on the foreground's ground
    seal_oval /    the artist's seal under the time, carrying the live HR:
    seal_rect      the oval while the HR is near the resting baseline, the
                   rectangle once it is SEAL_WORK bpm over it (John, 11-05).
                   The View draws it, not the Scene. The oval is turned on
                   its side and the square seal widened to a rectangle, so
                   three digits fit inside either.
    seal_square    the seal carrying the date instead (the "Red seal = HR"
                   setting off): month over day, stacked as a four-character
                   seal is laid out (John, 11-05).

The rules live in compose_preview (prop_rules) and the Scene; this script
only bakes the art. The cuts (scripts/cut_art_kit.py, art/cuts/props-b and
props2-b) are cropped to their ink and baked at the size they are drawn on
the 416 px face (drawn 1:1, never scaled on the watch), day and night:

  * day: the cut's ink, toned by depth (the far village paler);
  * night: NIGHT_INK at the day alpha times the prop's night share, red kept
    and dimmed to NIGHT_RED (as the foregrounds); the moon keeps its own pale
    color, so its texture survives on black;
  * the waning crescent is the waxing one mirrored (a baked twin: the watch
    has no flip in drawBitmap);
  * RGBA PNGs (they are small).

Writes into watch-faces/japanese-ink-heartrate:
    resources/drawables/prop_<name>.png, prop_<name>_night.png
    resources/drawables/props.xml           their bitmap declarations
    source/JapaneseInkHeartrateProps.mc     sizes and the loader
and scripts/prop_table.json, the same table for the mock.

    py -3.11 scripts/bake_props.py           bake, write tables
    py -3.11 scripts/bake_props.py --check   exit 1 if a table is stale
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
CUTS = os.path.join(FACE, "art", "cuts")
MC = os.path.join(FACE, "source", "JapaneseInkHeartrateProps.mc")
XML = os.path.join(DRAW, "props.xml")
JSON = os.path.join(HERE, "prop_table.json")

# name, cut (sheet/file), size ("w" or "h", px on the 416 face), tone,
# night share, mirrored, own color at night (the moon is pale already: it
# keeps its texture on black instead of going flat NIGHT_INK)
PROPS = [
    ("sun", "props-b/01_sun", ("h", 34), 1.0, 1.0, False, False),
    ("moon_full", "props-b/03_moon_full", ("h", 34), 1.0, 1.0, False, True),
    ("moon_waxing", "props-b/04_moon_crescent", ("h", 34), 1.0, 1.0, False, True),
    ("moon_waning", "props-b/04_moon_crescent", ("h", 34), 1.0, 1.0, True, True),
    ("geese", "props-b/06_geese", ("w", 78), 0.80, 0.85, False, False),
    ("village", "props2-b/08_village", ("w", 96), 0.55, 0.75, False, False),
    ("hut", "props2-b/03_hut", ("w", 84), 0.55, 0.75, False, False),
    ("hiker", "props-b/15_hiker", ("h", 34), 1.0, 1.0, False, False),
    ("lantern", "props2-b/02_lantern", ("h", 50), 1.0, 1.0, False, False),
    ("seal_oval", "props2-b/14_seal_oval", ("h", 32), 0.92, 1.0, False, True),
    ("seal_rect", "props2-b/13_seal_square", ("wh", (52, 34)), 0.92, 1.0, False, True),
    ("seal_square", "props2-b/13_seal_square", ("wh", (42, 42)), 0.92, 1.0, False, True),
    ("swallow", "props-b/07_swallow", ("w", 24), 1.0, 1.0, False, False),
    ("clouds", "clouds-b/01_clouds_gathering", ("w", 150), 0.70, 0.85, False, False),
    ("cloud_wisp", "weather-b/06_overcast", ("w", 76), 0.90, 0.90, False, False),
]
# Turned before sizing (degrees counter-clockwise): the sheet's oval stands
# upright, too narrow for three digits.
ROTATE = {"seal_oval": 90}
# Ink erased from a cut before cropping, as boxes in fractions of the cut's
# ink box (x0, y0, x1, y1), feathered over TRIM_FEATHER px: the hiker's
# grass and the level ground he walks on, which stuck out sideways from a
# sloped summit (John, 11-05). A patch stays under his feet.
TRIM = {"hiker": [(0.0, 0.66, 0.40, 1.0), (0.64, 0.80, 1.0, 1.0)]}
TRIM_FEATHER = 6
# Solid inside its outline: the cut makes paper clear, so the lantern's
# paper panels let the foreground through and it looked like a ghost
# (John, 11-05). Inside the ink closed by OPAQUE_CLOSE px it is paper by
# day and black paper at night.
OPAQUE = {"lantern"}
OPAQUE_CLOSE = 5
PAPER_RGB = (242, 238, 230)
# A hand-edited cut wins over the sheet's: art/edits/<name>.png, a full
# RGBA cut erased by hand (John, 11-05: more ground off the hiker).
# `bake_props.py --export-edit <name>` writes the current one to start from.
EDITS = os.path.join(FACE, "art", "edits")
NIGHT_INK = (168, 164, 152)   # cut_sprite_sheet.NIGHT_INK
NIGHT_RED = 0.60              # the red's brightness at night (bake_foregrounds)
INK_FLOOR = 12                # alpha under this is not ink when cropping


def camel(name):
    return "".join(p.capitalize() for p in name.split("_"))


def cut_path(cut):
    p = os.path.join(CUTS, cut + ".png")
    if not os.path.exists(p):
        raise SystemExit("no cut %s (run scripts/cut_art_kit.py --only %s)" % (cut, cut.split("/")[0]))
    return p


def trim(im, boxes):
    """Erase the boxes (fractions of the ink box) with a soft edge."""
    p = np.asarray(im, dtype=float).copy()
    ys, xs = np.nonzero(p[..., 3] >= INK_FLOOR)
    x0, y0 = xs.min(), ys.min()
    bw, bh = xs.max() - x0 + 1, ys.max() - y0 + 1
    yy, xx = np.mgrid[0:p.shape[0], 0:p.shape[1]]
    keep = np.ones(p.shape[:2])
    for fx0, fy0, fx1, fy1 in boxes:
        ax0, ay0 = x0 + fx0 * bw, y0 + fy0 * bh
        ax1, ay1 = x0 + fx1 * bw, y0 + fy1 * bh
        # distance inside the box, 0 at its edge; the image border is no edge
        d = np.minimum.reduce([xx - ax0 if fx0 > 0 else np.full_like(xx, 1e9, dtype=float),
                               ax1 - xx if fx1 < 1 else np.full_like(xx, 1e9, dtype=float),
                               yy - ay0 if fy0 > 0 else np.full_like(yy, 1e9, dtype=float),
                               ay1 - yy if fy1 < 1 else np.full_like(yy, 1e9, dtype=float)])
        keep = np.minimum(keep, 1.0 - np.clip(d / TRIM_FEATHER, 0.0, 1.0))
    p[..., 3] *= keep
    return Image.fromarray(np.round(p).astype(np.uint8), "RGBA")


def source(name, cut):
    """The cut a prop starts from: the hand edit if there is one, else the
    sheet's cut with its TRIM boxes erased."""
    edit = os.path.join(EDITS, name + ".png")
    if os.path.exists(edit):
        return Image.open(edit).convert("RGBA")
    im = Image.open(cut_path(cut)).convert("RGBA")
    if name in TRIM:
        im = trim(im, TRIM[name])
    return im


def solid_inside(alpha):
    """0..1: the area closed in by the ink (holes filled), softened a px."""
    from PIL import ImageFilter
    from scipy import ndimage
    ink = alpha > 0.15
    k = np.ones((OPAQUE_CLOSE, OPAQUE_CLOSE))
    filled = ndimage.binary_fill_holes(ndimage.binary_closing(ink, structure=k))
    soft = Image.fromarray((filled * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    return np.asarray(soft, float) / 255.0


def bake_one(name, cut, size, tone, night_share, mirror, own):
    im = source(name, cut)
    if name in ROTATE:
        im = im.rotate(ROTATE[name], expand=True, resample=Image.BICUBIC)
    a = np.asarray(im)[..., 3]
    ys, xs = np.nonzero(a >= INK_FLOOR)
    im = im.crop((int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1))
    if mirror:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    axis, px = size
    if axis == "wh":
        w, h = px
    elif axis == "h":
        w, h = max(1, int(round(im.width * px / float(im.height)))), px
    else:
        w, h = px, max(1, int(round(im.height * px / float(im.width))))
    im = im.resize((w, h), Image.LANCZOS)
    p = np.asarray(im, dtype=float) / 255.0
    rgb, alpha = p[..., :3], p[..., 3]
    red = (rgb[..., 0] - np.maximum(rgb[..., 1], rgb[..., 2])) > 0.10
    night = np.empty_like(rgb)
    night[:] = np.array(NIGHT_INK, dtype=float) / 255.0
    night[red] = rgb[red] * NIGHT_RED
    if own:
        night = rgb

    def img(c, al):
        out = np.dstack([c, al]) * 255.0
        return Image.fromarray(np.round(np.clip(out, 0, 255)).astype(np.uint8), "RGBA")

    if name in OPAQUE:
        m = solid_inside(alpha)
        paper = np.array(PAPER_RGB, float) / 255.0
        a = alpha[..., None]
        day_rgb = rgb * a + paper * (1 - a)
        night_rgb = night * a
        out_a = np.maximum(alpha, m)
        keep = (out_a > 0)[..., None]
        day_rgb = np.where(keep, (day_rgb * m[..., None] + rgb * a * (1 - m[..., None]))
                           / np.maximum(out_a, 1e-6)[..., None], rgb)
        night_rgb = np.where(keep, (night_rgb * m[..., None] + night * a * (1 - m[..., None]))
                             / np.maximum(out_a, 1e-6)[..., None], night)
        return img(day_rgb, out_a), img(night_rgb, out_a)
    return img(rgb, alpha * tone), img(night, alpha * tone * night_share)


def bake_all():
    total = 0
    for name, cut, size, tone, share, mirror, own in PROPS:
        day, night = bake_one(name, cut, size, tone, share, mirror, own)
        for im, sfx in ((day, ""), (night, "_night")):
            path = os.path.join(DRAW, "prop_%s%s.png" % (name, sfx))
            im.save(path, optimize=True)
            total += os.path.getsize(path)
        print("baked prop_%s %dx%d" % (name, day.width, day.height), flush=True)
    print("props: %d, %.3f MB of PNG" % (len(PROPS), total / 1e6))


def tables():
    sizes = [Image.open(os.path.join(DRAW, "prop_%s.png" % p[0])).size for p in PROPS]
    table = {"face": 416, "props": [{"name": p[0], "cut": p[1], "w": s[0], "h": s[1]}
                                    for p, s in zip(PROPS, sizes)]}
    js = json.dumps(table, indent=1) + "\n"

    xml = ['<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">',
           "    <!-- Generated by scripts/bake_props.py; do not edit. -->"]
    for p in PROPS:
        for sfx in ("", "_night"):
            n = "prop_%s%s" % (p[0], sfx)
            xml.append('    <bitmap id="%s" filename="%s.png" dithering="none" '
                       'automaticPalette="false" packingFormat="png" compress="false" />' % (camel(n), n))
    xml.append("</drawables>")
    xml = "\n".join(xml) + "\n"

    mc = ["using Toybox.Graphics;", "using Toybox.Lang;", "using Toybox.WatchUi;", "",
          "// Generated by scripts/bake_props.py; do not edit.",
          "// The props: small pieces of the ChatGPT prop sheets, each shown by one",
          "// rule (the Scene's props; compose_preview.prop_rules). Baked at the size",
          "// they are drawn on a 416 px face, drawn 1:1.", "",
          "const PROP_COUNT = %d;" % len(PROPS)]
    for i, p in enumerate(PROPS):
        mc.append("const PROP_%s = %d;" % (p[0].upper(), i))
    mc += ["",
           "function propW() as Lang.Array<Lang.Number> {",
           "    return [%s] as Lang.Array<Lang.Number>;" % ", ".join(str(s[0]) for s in sizes), "}", "",
           "function propH() as Lang.Array<Lang.Number> {",
           "    return [%s] as Lang.Array<Lang.Number>;" % ", ".join(str(s[1]) for s in sizes), "}", "",
           "// Prop i, day or night; the caller catches a refusal.",
           "function loadPropBitmap(i as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {"]
    for i, p in enumerate(PROPS):
        n = "prop_" + p[0]
        mc.append("    if (i == %d) { return WatchUi.loadResource(night ? Rez.Drawables.%s : Rez.Drawables.%s) as Graphics.BitmapType; }"
                  % (i, camel(n + "_night"), camel(n)))
    mc += ["    return null;", "}", ""]
    return {JSON: js, XML: xml, MC: "\n".join(mc)}


def export_edit(name):
    """Write prop name's current source cut to art/edits/<name>.png to erase by hand."""
    row = [p for p in PROPS if p[0] == name]
    if not row:
        raise SystemExit("no prop %s" % name)
    os.makedirs(EDITS, exist_ok=True)
    out = os.path.join(EDITS, name + ".png")
    if os.path.exists(out):
        raise SystemExit("%s exists; delete it first to start over" % out)
    source(name, row[0][1]).save(out)
    print("wrote", out)


def main(argv):
    if "--export-edit" in argv:
        export_edit(argv[argv.index("--export-edit") + 1])
        return 0
    if "--check" not in argv:
        bake_all()
    stale = 0
    for path, text in tables().items():
        if "--check" in argv:
            cur = open(path).read() if os.path.exists(path) else None
            if cur != text:
                print("stale:", os.path.relpath(path, os.path.join(HERE, "..")))
                stale += 1
        else:
            with open(path, "w", newline="\n") as f:
                f.write(text)
            print("wrote", os.path.relpath(path, os.path.join(HERE, "..")))
    if "--check" in argv:
        print("props:", "current" if not stale else "%d stale" % stale)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
