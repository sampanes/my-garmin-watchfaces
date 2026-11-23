#!/usr/bin/env python
"""The shape library (2026-11-05): the 24 ChatGPT mountains, cut from the
sheets, as the whole painted mountains the face CHOOSES from to fit the
four hours.

John, 11-03, on a study that assembled mountains from brush primitives:
"200 primitives smashed into a bespoke shape is actually worse than 50
known shapes like our current mountains". And 11-05, after seeing the
image-generator sheets: no art drawn by the watch's code or by our scripts
any more (the decision at the top of ART_PIPELINE.md). So every shape here
is one whole mountain painted by ChatGPT (art/sheets/*_mountains-b.png and
*_mountains2-b.png, prompts in art/sheets/PROMPTS.md), cut by
scripts/cut_art_kit.py into art/cuts/<sheet>/, and baked here:

  * scaled by SCALE (sheet px to face px, one factor for all, so the sheet's
    relative sizes survive) and never scaled again on the watch, except in
    width: the fit stretches a shape's width to its run (compose_preview.
    fit_shape, 0.67x to 1.5x), which drawScaledBitmap does for free;
  * toned: TONE of the sheet's ink is kept, the rest pulled to paper, so the
    masses sit between the pale far range and the dark trees and foreground
    pieces (sumi-e depth: the farther, the paler); the sheets' solid black
    read too heavy on the face;
  * paper-backed, with a skirt: everything under the ridge line is body
    (ink over its own paper, black paper at night) that hides what stands
    behind, extended down to PLANE_H so a crest anywhere on the crest scale
    leaves the plane's foot under the mist, and fading out over the bottom
    BASE_FADE of the plane; over bare paper nothing changes;
  * soft-sided (2026-11-23): the paper body dissolves toward the plane's
    left and right edges (SIDE_FADE of the width, little at the summit's
    level, more toward the foot, as scripts/bake_planes.py feathers the near
    hills). The ink is left alone. Without it the body under a mountain was
    a paper slab with straight sides: over the far range or another
    mountain it showed as a white box that cut them off (John: "cut and
    paste with white space underneath");
  * packed as a 256-color palette PNG (the ink is one color over one
    paper: lossless to the eye, about a third of the bytes), the colors
    laid out on ink and paper amounts and the fades dithered so they stay
    smooth (pack).

Writes into watch-faces/japanese-ink-heartrate:
    resources/drawables/shape_<name>_cut.png, ..._cut_night.png
    resources/drawables/shapes.xml       their bitmap declarations
    source/JapaneseInkHeartrateShapes.mc the profile table and the loader
and scripts/shape_table.json, the same table for the mock.

    python scripts/gen_shape_library.py            cut (if needed), bake, measure, write tables
    python scripts/gen_shape_library.py --tables   rewrite the .xml and .mc from shape_table.json
    python scripts/gen_shape_library.py --check    exit 1 if a table or a PNG's size is stale (no scipy)

The profile of a shape is its ridge: the top of its OPAQUE body (alpha 250
or more) at K evenly spaced columns, in px from the bitmap's top (-1 where
the column has none), and its apex is the topmost opaque row, at the middle
of that row's opaque columns. It is measured during the bake on the body
BEFORE its sides are faded (profile), because a faded flank still carries
its ink ridge; so shape_table.json is the record, and the baked PNGs alone
no longer give it."""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
CUTS = os.path.join(FACE, "art", "cuts")
MC = os.path.join(FACE, "source", "JapaneseInkHeartrateShapes.mc")
XML = os.path.join(DRAW, "shapes.xml")
JSON = os.path.join(HERE, "shape_table.json")

SHEETS = ("mountains-b", "mountains2-b")   # the ChatGPT mountain sheets, in table order
SCALE = 1.20          # sheet px -> face px
TONE = 0.70           # share of the sheet's ink kept; the rest goes to paper
PLANE_H = 300         # px: every plane at least this tall, its skirt at the bottom edge
BASE_FADE = 0.30      # the body fades out over this bottom fraction of the plane
SIDE_FADE = (0.05, 0.30)   # the body dissolves toward each side over this share of the
                           # width: at the summit's level, and at the plane's foot
BODY_FLOOR = 0.05     # ink over this is body (as cut_sprite_sheet.paper_back)
K = 32
OPAQUE = 250          # alpha at or over this is the cutout the fit measures
PALETTE = 256         # colors per baked PNG (0: keep RGBA)
LINE_STEPS = 64       # ... laid out by pack: ink levels of the solid body,
PAPER_STEPS = 48      # ... alphas of bare paper,
FADE_INK = 12         # ... and ink levels times
FADE_STEPS = 12       # ... paper levels for ink over a fading body
PAPER = (242, 238, 230)


def shapes():
    """[(name, sheet, cut path)] in table order: the sheets' cells in order.
    The names are the cells' names from the cut (NN_name.png)."""
    out = []
    for sheet in SHEETS:
        files = sorted(f for f in glob.glob(os.path.join(CUTS, sheet, "[0-9][0-9]_*.png"))
                       if not f.endswith("_night.png"))
        for f in files:
            out.append(("shape_" + os.path.basename(f)[3:-4], sheet, f))
    return out


def camel(name):
    return "".join(p.capitalize() for p in name.split("_"))


def ensure_cuts():
    """Cut a sheet whose cutouts are missing (needs scipy)."""
    for sheet in SHEETS:
        if glob.glob(os.path.join(CUTS, sheet, "[0-9][0-9]_*.png")):
            continue
        import cut_art_kit as kit
        path = glob.glob(os.path.join(kit.SHEETS, "20*_%s.*" % sheet))[0]
        print("cutting", os.path.basename(path), flush=True)
        kit.one(path, os.path.join(CUTS, sheet), *kit.RECIPE[sheet.rsplit("-", 1)[0]])


def plane_layers(path, night, scale=None, tone=None, sides=True):
    """One cut (ink over nothing, as cut_sprite_sheet writes it) scaled,
    toned, paper-backed, skirted and (sides) soft-sided, as its layers at
    the plane's size (PLANE_H or taller), all 0..1: (rgb, ink, body), the
    cut's color, the ink's alpha and the paper body's alpha."""
    scale = SCALE if scale is None else scale
    tone = TONE if tone is None else tone
    im = Image.open(path).convert("RGBA")
    w, h = max(1, int(round(im.width * scale))), max(1, int(round(im.height * scale)))
    im = im.resize((w, h), Image.LANCZOS)
    px = np.asarray(im, dtype=float) / 255.0
    plane_h = max(PLANE_H, h)
    rgb = np.zeros((plane_h, w, 3))
    a = np.zeros((plane_h, w))
    rgb[:h] = px[..., :3]
    a[:h] = px[..., 3]
    # the body: everything under the ridge line, down to the plane's foot
    solid = np.maximum.accumulate(a > BODY_FLOOR, axis=0)
    body = Image.fromarray((solid * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.0))
    body = np.asarray(body, dtype=float) / 255.0
    start = int(plane_h * (1.0 - BASE_FADE))
    ramp = np.ones(plane_h)
    ramp[start:] = np.linspace(1.0, 0.0, plane_h - start)
    body *= ramp[:, None]
    if sides and SIDE_FADE[1] > 0.0:
        # the body's sides: a smoothstep from its outermost columns inward,
        # narrow at the summit's row and widening to the foot, as mist
        # takes a flank; the ink keeps its own alpha
        cols = np.nonzero(solid.any(axis=0))[0]
        top = int(np.nonzero(solid.any(axis=1))[0][0])
        depth = np.clip((np.arange(plane_h) - top) / float(max(1, plane_h - 1 - top)), 0.0, 1.0)
        reach = np.maximum(1.0, (SIDE_FADE[0] + (SIDE_FADE[1] - SIDE_FADE[0]) * depth) * w)[:, None]
        x = np.arange(w, dtype=float)[None, :]
        t = np.clip(np.minimum(x - cols[0], cols[-1] - x) / reach, 0.0, 1.0)
        body *= t * t * (3.0 - 2.0 * t)
    return rgb, a * tone, body


def paper_color(night):
    return np.zeros(3) if night else np.array(PAPER, dtype=float) / 255.0


def plane_from_cut(path, night, scale=None, tone=None, sides=True):
    """plane_layers as one RGBA image: the ink over its own paper."""
    rgb, ink, body = plane_layers(path, night, scale, tone, sides)
    alpha = np.maximum(ink, body)
    share = np.where(alpha > 0, ink / np.maximum(alpha, 1e-6), 0.0)[..., None]
    col = rgb * share + paper_color(night) * (1.0 - share)
    out = np.dstack([col, alpha]) * 255.0
    return Image.fromarray(np.round(np.clip(out, 0, 255)).astype(np.uint8), "RGBA")


def pack_octree(img):
    """The pack until 2026-11-23: FASTOCTREE's own 256 colors. It gives the
    bare paper about eight alpha steps, which band a fade; kept because the
    profile is measured on it (profile)."""
    return img.quantize(colors=PALETTE, method=Image.Quantize.FASTOCTREE)


def pack(layers, night=False):
    """plane_layers as it is saved: a palette PNG with alpha (the RGBA
    image when PALETTE is 0).

    A cut's ink is ONE color, so a pixel is two amounts: ink, and paper
    showing under it (the body's alpha less the ink's). The colors are
    laid out on those two instead of left to an octree:
      * LINE_STEPS for the solid body (paper = all that the ink leaves),
        even steps of ink up to the plane's darkest;
      * PAPER_STEPS for bare paper at even alphas, the fades at the foot
        and the sides where nothing is painted;
      * FADE_INK ink levels (closer together toward none) times FADE_STEPS
        paper levels for ink over a fading body, the misty feet.
    A pixel takes the nearest ink level. Under ink in a fading body the
    paper level is rounded by chance in proportion (a fixed-seed dither:
    twelve levels alone would step), which shows only where something
    darker stands behind. The octree's eight paper alphas, and
    nearest-color rounding after it, drew terraces at every foot once the
    sides faded too."""
    if not PALETTE:
        return plane_from_layers(layers, night)
    rgb, ink, body = layers
    paper = paper_color(night)
    color = rgb[np.unravel_index(int(np.argmax(ink)), ink.shape)]
    top = max(float(ink.max()), 1e-3)
    i = np.clip(ink, 0.0, top)
    alpha = np.clip(np.maximum(i, body), 0.0, 1.0)
    # the palette as (ink, paper) amounts: the solid line first
    line = top * np.arange(LINE_STEPS) / float(LINE_STEPS - 1)
    fade = np.concatenate([[0.0], top * (np.arange(1, FADE_INK + 1) / float(FADE_INK)) ** 2.0])
    counts = np.array([PAPER_STEPS] + [FADE_STEPS] * FADE_INK)
    starts = LINE_STEPS + np.concatenate([[0], np.cumsum(counts)[:-1]])
    amounts = [(v, 1.0 - v) for v in line]
    for k, n in enumerate(counts):
        amounts += [(fade[k], (1.0 - fade[k]) * j / float(n)) for j in range(n)]
    assert len(amounts) <= 256, len(amounts)
    # every pixel: its nearest ink level among the fade's, then its paper
    # level as a share of what that much ink leaves (bare paper: the
    # nearest of its many; under ink: by chance)
    rng = np.random.default_rng(20261123)
    hi = np.clip(np.searchsorted(fade, i, side="right"), 1, FADE_INK)
    lo = hi - 1
    k = np.where(i - fade[lo] > fade[hi] - i, hi, lo)
    share = np.clip((alpha - i) / np.maximum(1.0 - i, 1e-6), 0.0, 1.0)
    j = np.floor(share * counts[k] + np.where(k == 0, 0.5, rng.random(i.shape))).astype(int)
    index = starts[k] + np.minimum(j, counts[k] - 1)
    solid = (alpha >= 1.0 - 0.5 / 255.0) | (j >= counts[k])
    index[solid] = np.round(i[solid] / top * (LINE_STEPS - 1)).astype(int)
    pal = np.zeros((256, 4))
    for n, (v, q) in enumerate(amounts):
        if v + q > 0.0:
            pal[n, :3] = (v * color + q * paper) / (v + q)
        pal[n, 3] = v + q
    out = Image.fromarray(index.astype(np.uint8), "P")
    out.putpalette(np.round(pal * 255.0).astype(np.uint8).tobytes(), "RGBA")
    return out


def plane_from_layers(layers, night):
    rgb, ink, body = layers
    alpha = np.maximum(ink, body)
    share = np.where(alpha > 0, ink / np.maximum(alpha, 1e-6), 0.0)[..., None]
    out = np.dstack([rgb * share + paper_color(night) * (1.0 - share), alpha]) * 255.0
    return Image.fromarray(np.round(np.clip(out, 0, 255)).astype(np.uint8), "RGBA")


def measure_alpha(a):
    """The profile table entry of a cutout's alpha (uint8 array)."""
    h, w = a.shape
    top = []
    for k in range(K):
        x = int((k + 0.5) * w / K)
        rows = np.nonzero(a[:, x] >= OPAQUE)[0]
        top.append(int(rows[0]) if len(rows) else -1)
    ys, xs = np.nonzero(a >= OPAQUE)
    ay = int(ys.min())
    row = np.nonzero(a[ay] >= OPAQUE)[0]
    ax = int(round(0.5 * (row[0] + row[-1])))
    return {"w": int(w), "h": int(h), "ax": ax, "ay": ay, "top": top}


def profile(path, scale=None, tone=None):
    """A shape's profile table entry: its day plane with its sides still
    solid, measured as the tables always were (on the FASTOCTREE pack, whose
    alphas the 11-05 table was read from, so that table stands)."""
    ref = pack_octree(plane_from_cut(path, False, scale, tone, sides=False)).convert("RGBA")
    return measure_alpha(np.asarray(ref.getchannel("A")))


def build(scale=None, tone=None):
    """Every shape in memory, as saved: [(name, sheet, day, night)] with
    the images already packed. The mock-only experiments use this."""
    out = []
    for name, sheet, path in shapes():
        day = pack(plane_layers(path, False, scale, tone), False)
        night = pack(plane_layers(path[:-4] + "_night.png", True, scale, tone), True)
        out.append((name, sheet, day, night))
    return out


def render_all():
    ensure_cuts()
    names = {n for n, _, _ in shapes()}
    for path in glob.glob(os.path.join(DRAW, "shape_*_cut*.png")):
        base = os.path.basename(path).replace("_cut_night.png", "").replace("_cut.png", "")
        if base not in names:
            os.remove(path)
            print("removed", os.path.basename(path))
    total = 0
    for name, sheet, day, night in build():
        for img, suffix in ((day, "_cut.png"), (night, "_cut_night.png")):
            path = os.path.join(DRAW, name + suffix)
            img.save(path, optimize=True)
            total += os.path.getsize(path)
        print("baked", name, day.width, "x", day.height, flush=True)
    print("library: %d shapes, %.2f MB of PNG" % (len(names), total / 1e6))
    return {"k": K, "scale": SCALE, "tone": TONE,
            "shapes": [dict(profile(path), name=name, sheet=sheet)
                       for name, sheet, path in shapes()]}


def stored_table():
    """shape_table.json: the profiles as the last bake measured them."""
    with open(JSON) as f:
        return json.load(f)


def stale_pngs(table):
    """The baked PNGs that are missing or not the table's size."""
    out = []
    for s in table["shapes"]:
        for suffix in ("_cut.png", "_cut_night.png"):
            path = os.path.join(DRAW, s["name"] + suffix)
            if not os.path.exists(path) or Image.open(path).size != (s["w"], s["h"]):
                out.append(os.path.basename(path))
    return out


def tables(table):
    js = json.dumps(table, indent=1) + "\n"

    xml = ['<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">',
           "    <!-- Generated by scripts/gen_shape_library.py; do not edit. -->"]
    for s in table["shapes"]:
        for night in (False, True):
            xml.append('    <bitmap id="%s%s" filename="%s_cut%s.png" dithering="none" '
                       'automaticPalette="false" packingFormat="png" compress="false" />'
                       % (camel(s["name"]), "Night" if night else "", s["name"], "_night" if night else ""))
    xml.append("</drawables>")
    xml = "\n".join(xml) + "\n"

    n = len(table["shapes"])
    def arr(vals):
        return "[" + ", ".join(str(v) for v in vals) + "] as Lang.Array<Lang.Number>"
    mc = ["using Toybox.Graphics;", "using Toybox.Lang;", "using Toybox.WatchUi;", "",
          "// Generated by scripts/gen_shape_library.py; do not edit.",
          "// The shape library: %d whole painted mountains from the ChatGPT sheets," % n,
          "// each at least %d px tall with its skirt at its bottom edge. shapeTop()" % PLANE_H,
          "// holds each shape's profile, the top of its opaque cutout at SHAPE_K",
          "// evenly spaced columns in px from the bitmap's top (-1: none), shape",
          "// after shape.", "",
          "const SHAPE_COUNT = %d;" % n, "const SHAPE_K = %d;" % K, ""]
    mc += ["const %s = %d;" % (s["name"].upper(), i) for i, s in enumerate(table["shapes"])]
    mc += ["",
          "function shapeW() as Lang.Array<Lang.Number> {",
          "    return %s;" % arr(s["w"] for s in table["shapes"]), "}", "",
          "function shapeH() as Lang.Array<Lang.Number> {",
          "    return %s;" % arr(s["h"] for s in table["shapes"]), "}", "",
          "function shapeApexX() as Lang.Array<Lang.Number> {",
          "    return %s;" % arr(s["ax"] for s in table["shapes"]), "}", "",
          "function shapeApexY() as Lang.Array<Lang.Number> {",
          "    return %s;" % arr(s["ay"] for s in table["shapes"]), "}", "",
          "function shapeTop() as Lang.Array<Lang.Number> {",
          "    return %s;" % arr(v for s in table["shapes"] for v in s["top"]), "}", "",
          "// One shape's cutout, day or night; the caller catches a refusal.",
          "function loadShapeBitmap(i as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {"]
    for night in (False, True):
        mc.append("    if (%snight) {" % ("" if night else "!"))
        for i, s in enumerate(table["shapes"]):
            mc.append("        if (i == %d) { return WatchUi.loadResource(Rez.Drawables.%s%s) as Graphics.BitmapType; }"
                      % (i, camel(s["name"]), "Night" if night else ""))
        mc.append("    }")
    mc += ["    return null;", "}", ""]
    mc = "\n".join(mc)
    return {JSON: js, XML: xml, MC: mc}


def main(argv):
    if "--tables" not in argv and "--check" not in argv:
        table = render_all()
    else:
        table = stored_table()
    out = tables(table)
    stale = 0
    if "--check" in argv:
        for name in stale_pngs(table):
            print("stale:", name)
            stale += 1
    for path, text in out.items():
        if "--check" in argv:
            # Universal newlines: a Windows checkout (autocrlf) is not stale.
            cur = open(path).read() if os.path.exists(path) else None
            if cur != text:
                print("stale:", os.path.relpath(path, os.path.join(HERE, "..")))
                stale += 1
        else:
            with open(path, "w", newline="\n") as f:
                f.write(text)
            print("wrote", os.path.relpath(path, os.path.join(HERE, "..")))
    if "--check" in argv:
        print("shape library:", "current" if not stale else "%d stale" % stale)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
