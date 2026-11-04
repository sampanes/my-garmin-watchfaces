#!/usr/bin/env python
"""The shape library (2026-11-03): whole painted mountains the face CHOOSES
from to fit the four hours, instead of a few planes stretched to fit.

John, 11-03, on a study that assembled mountains from brush primitives:
"200 primitives smashed into a bespoke shape is actually worse than 50 known
shapes like our current mountains". So every shape here is one whole plane
from the same renderer as the rest of the painting (gen_ink_layers.
render_plane), baked at its final size, never stretched, cut or assembled
on the watch. A fit test over 93 windows (the study's fit_library.py) found
the accuracy comes from CHOOSING among enough profiles and SINKING the
chosen one until its crest sits on the data (its foot behind the bank and
the mist, as round 6's deep base already did), and that the miss stops
improving past about 100 shape choices.

Every plane is 300 px tall with its skirt at its bottom edge, so a crest
anywhere on the crest scale leaves the plane's foot under the mist. Width
and family give the profile: a narrow spire, a broad peak, a dome, a
plateau with bumps, a long low ridge for a walk, the wide mountain leaning
either way, a ramp for a slow climb, a range of three, twin summits.

Writes into watch-faces/japanese-ink-heartrate:
    resources/drawables/shape_<family>_<w>_cut.png, ..._cut_night.png
        paper-backed cutouts (compose_preview.paper_backed), day and night
    resources/drawables/shapes.xml       their bitmap declarations
    source/JapaneseInkHeartrateShapes.mc the profile table and the loader
and scripts/shape_table.json, the same table for the mock.

    python scripts/gen_shape_library.py            render, bake, write tables
    python scripts/gen_shape_library.py --tables   re-measure the baked PNGs only
    python scripts/gen_shape_library.py --check    exit 1 if a table is stale

The profile of a shape is the top of its OPAQUE cutout (alpha 255, which is
where the ink reaches 12%) at K evenly spaced columns, in px from the
bitmap's top (-1 where the column has none), and its apex is the topmost
opaque row, at the middle of that row's opaque columns."""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
MC = os.path.join(FACE, "source", "JapaneseInkHeartrateShapes.mc")
XML = os.path.join(DRAW, "shapes.xml")
JSON = os.path.join(HERE, "shape_table.json")

PLANE_H = 300
K = 32
INK = (12, 9, 7)

# family -> (peaks for render_plane in plane-normalized x, widths, roughness,
# mirrored-from). A mirrored family is the other one's painting flipped, so
# the pair is the same mountain leaning the other way.
FAMILIES = [
    ("spire", [(0.50, 1.0, 0.21), (0.31, 0.50, 0.12), (0.69, 0.56, 0.11)], (120, 180), 0.24, None),
    ("peak", [(0.50, 1.0, 0.23), (0.21, 0.40, 0.10), (0.80, 0.38, 0.10)], (200, 300), 0.24, None),
    ("dome", [(0.50, 1.0, 0.30), (0.30, 0.80, 0.16), (0.70, 0.82, 0.16)], (200, 300), 0.14, None),
    ("lean_l", [(0.34, 1.0, 0.17), (0.62, 0.78, 0.22), (0.12, 0.40, 0.08)], (240, 340), 0.20, None),
    ("lean_r", None, (240, 340), None, "lean_l"),
    ("plateau", [(0.50, 0.97, 0.28), (0.42, 1.0, 0.12), (0.15, 0.45, 0.08), (0.85, 0.45, 0.08)],
     (240, 340, 440), 0.08, None),
    ("ridge", [(0.50, 0.96, 0.34), (0.32, 1.0, 0.16), (0.70, 0.98, 0.16)], (300, 420, 540), 0.08, None),
    ("wide_l", [(0.25, 1.0, 0.11), (0.50, 0.86, 0.27), (0.78, 0.84, 0.16), (0.08, 0.45, 0.07)],
     (300, 420, 540), 0.13, None),
    ("wide_r", None, (300, 420, 540), None, "wide_l"),
    ("ramp_up", [(0.82, 1.0, 0.12), (0.60, 0.82, 0.14), (0.38, 0.64, 0.14), (0.16, 0.46, 0.12)],
     (360, 500), 0.16, None),
    ("ramp_down", None, (360, 500), None, "ramp_up"),
]


def shapes():
    """[(name, family, width, mirror_of_name or None)] in table order."""
    out = []
    for fam, _, widths, _, mirror in FAMILIES:
        for w in widths:
            out.append(("shape_%s_%d" % (fam, w), fam, w,
                        ("shape_%s_%d" % (mirror, w)) if mirror else None))
    return out


def camel(name):
    return "".join(p.capitalize() for p in name.split("_"))


def wash_texture(cut, night, seed):
    """Vary the ink within a cutout without changing its measured outline.

    Low-frequency pooling and finer dry paper are baked into the color only;
    alpha (including the opaque skyline used by the fitter) stays unchanged.
    """
    import gen_ink_layers as gl
    pixels = np.array(cut, dtype=np.uint8)
    h, w = pixels.shape[:2]
    pooling = gl.vnoise2(h, w, 42, 29, seed, octaves=3) - 0.5
    fiber = gl.vnoise2(h, w, 7, 3, seed + 1, octaves=2) - 0.5
    strength = np.clip(1.0 + 1.10 * pooling + 0.28 * fiber, 0.65, 1.35)
    paper = np.array((0, 0, 0) if night else gl.PAPER, dtype=float)
    color = pixels[..., :3].astype(float)
    pixels[..., :3] = np.clip(paper + (color - paper) * strength[..., None], 0, 255).round().astype(np.uint8)
    return Image.fromarray(pixels, "RGBA")


def render_all():
    import glob
    import compose_preview as cp
    import gen_ink_layers as gl
    names = {n for n, _, _, _ in shapes()}
    for path in glob.glob(os.path.join(DRAW, "shape_*_cut*.png")):
        base = os.path.basename(path).replace("_cut_night.png", "").replace("_cut.png", "")
        if base not in names:
            os.remove(path)
            print("removed", os.path.basename(path))
    alphas = {}
    for i, (name, fam, w, mirror) in enumerate(shapes()):
        if mirror:
            a = alphas[mirror][:, ::-1]
        else:
            peaks, _, rough = [(f[1], f[2], f[3]) for f in FAMILIES if f[0] == fam][0][0:3]
            a = gl.render_plane(w, PLANE_H, peaks, amp_frac=0.80, rough=rough, ink=0.62, fade=0.0,
                                seed=4000 + 37 * i, blur_1x=0.9, cun_count=int(0.5 * w) + 20,
                                tree_prob=0.018, bleed=0.14, edge_left=0.09, edge_right=0.09,
                                base_fade=(0.82, 0.99), tree_size=(5.0, 12.0), crown=0.30)
        alphas[name] = a
        for night in (False, True):
            rgb = gl.NIGHT_INK if night else INK
            scale = 0.80 if night else 1.0
            arr = np.zeros(a.shape + (4,), np.uint8)
            arr[..., 0], arr[..., 1], arr[..., 2] = rgb
            arr[..., 3] = (np.clip(a * scale, 0, 1) * 255).astype(np.uint8)
            cut = cp.paper_backed(Image.fromarray(arr, "RGBA"), night)
            cut = wash_texture(cut, night, 8200 + 37 * i)
            path = os.path.join(DRAW, name + "_cut" + ("_night" if night else "") + ".png")
            cut.save(path, optimize=True)
        print("painted", name, w, "x", PLANE_H, flush=True)


def measure(name):
    im = Image.open(os.path.join(DRAW, name + "_cut.png")).convert("RGBA")
    a = np.asarray(im.getchannel("A"))
    h, w = a.shape
    top = []
    for k in range(K):
        x = int((k + 0.5) * w / K)
        rows = np.nonzero(a[:, x] >= 255)[0]
        top.append(int(rows[0]) if len(rows) else -1)
    ys, xs = np.nonzero(a >= 255)
    ay = int(ys.min())
    row = np.nonzero(a[ay] >= 255)[0]
    ax = int(round(0.5 * (row[0] + row[-1])))
    return {"name": name, "w": int(w), "h": int(h), "ax": ax, "ay": ay, "top": top}


def tables():
    table = {"k": K, "shapes": [dict(measure(n), family=f) for n, f, _, _ in shapes()]}
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
          "// The shape library: %d whole painted mountains, each %d px tall with its" % (n, PLANE_H),
          "// skirt at its bottom edge. shapeTop() holds each shape's profile, the",
          "// top of its opaque cutout at SHAPE_K evenly spaced columns in px from",
          "// the bitmap's top (-1: none), shape after shape.", "",
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
        render_all()
    out = tables()
    stale = 0
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
