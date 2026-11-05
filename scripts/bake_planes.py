#!/usr/bin/env python
"""The fixed planes (2026-11-05): the far range, the two mist bands and the
near hills from the ChatGPT strip sheet, in place of the last script-painted
planes (gen_ink_layers' horizon, mist_band, mist_band_lite, near_hill and
near_hill2, retired here; the generator keeps only the paper grain).

The art is art/sheets/2026-11-05_strips-b.png (the prompt is PROMPTS.md
4.2): six full-width strips, cut by scripts/cut_art_kit.py into
art/cuts/strips-b/. Five of the six are baked here, day and night:

  * the far range (horizon.png) is FAR at the face's width, unbacked (nothing
    stands behind it but the sky) and at the painter's own dilution, the
    palest plane (the sheet's palest strip, far_pale, all but vanished at
    the face's size); its crest row is what the Scene puts on the window's
    floor;
  * the two mist bands are the two mist strips re-toned to paper: the
    sheet's grey wash is read as mist density (its alpha, gained by the
    strip's MIST gain) and colored paper, black at night, so the mist only
    ever erases ink, as the script mist did. Each is baked at the size the
    Scene draws it (its rect in MIST, fractions of the face);
  * the near hills (NEAR) are NEAR_ASPECT:1 windows cut from the two near
    strips, the pines for the outer thirds and the bare ridge for the middle,
    baked at NEAR_SIZE as paper cutouts: everything under the ridge line is
    body (ink over its own paper, black paper at night) that hides what
    stands behind, fading out over the bottom NEAR_FADE as the library's
    skirts do, and the window's cut sides dissolve over NEAR_FEATHER of the
    width (a smoothstep, the lower body sooner than the ridge, as mist takes
    a flank) so no edge shows;
  * night: the same alpha (scaled per plane by NIGHT_SCALE) in NIGHT_INK;
  * kept as RGBA PNGs: a 256-color palette bands the soft feathers, and
    the ten planes are small.

Writes into watch-faces/japanese-ink-heartrate:
    resources/drawables/horizon.png, mist_band.png, mist_band_lite.png,
        near_hill.png, near_hill2.png, each with its _night twin
    resources/drawables/planes.xml          their bitmap declarations
    source/JapaneseInkHeartratePlanes.mc    sizes, crests and the loaders
and scripts/plane_table.json, the same numbers for the record. The crests
are measured from the written PNGs exactly as the mock measures them
(compose_preview.measure_apex), so the mock and the Scene agree.

    py -3.11 scripts/bake_planes.py           cut (if needed), bake, write tables
    py -3.11 scripts/bake_planes.py --check   exit 1 if a table is stale (no scipy)
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import compose_preview as cp  # noqa: E402

FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
CUTS = os.path.join(FACE, "art", "cuts")
MC = os.path.join(FACE, "source", "JapaneseInkHeartratePlanes.mc")
XML = os.path.join(DRAW, "planes.xml")
JSON = os.path.join(HERE, "plane_table.json")

SHEET = "strips-b"       # the ChatGPT strips, as the library is ChatGPT's
W = 416                  # the face the planes are baked for
FAR = "far_hills"        # the far range: soft rounded hills (far_pale vanished on the face)
FAR_TONE = 1.0           # share of its ink kept (the painter's dilution as it is)
# the mist bands: strip, the Scene's rect (w, h as fractions of the face: the
# bake's size), and the gain on the strip's wash read as mist density
MIST = {"mist_band": ("mist_dense", (1.06, 0.22), 1.6),
        "mist_band_lite": ("mist_wisps", (1.20, 0.17), 0.8)}
# the near hills: plane, strip, and the window's left edge as a fraction of
# the strip's width (the window is NEAR_ASPECT times the strip's height wide)
NEAR = [("near_hill", "near_pines", 0.424),     # the tall pine on the center hump
        ("near_hill2", "near_ridge", 0.352)]    # the center hump
NEAR_ASPECT = 2.0
NEAR_SIZE = (320, 160)
NEAR_TONE = 0.90         # the nearest plane but the foreground: nearly the sheet's ink
NEAR_FADE = 0.40         # the body fades out over this bottom fraction
NEAR_FEATHER = 0.30      # each cut side dissolves over this fraction of the width
BODY_FLOOR = 0.05        # ink over this is body (as gen_shape_library)
NIGHT_INK = (168, 164, 152)
NIGHT_SCALE = {"far": 0.90, "near": 0.85}   # the mist is black at the same alpha
PAPER = (242, 238, 230)
PALETTE = 0              # full RGBA: the soft feathers band in a palette, and the planes are small


def camel(name):
    return "".join(p.capitalize() for p in name.split("_"))


def cut_path(strip):
    hits = [f for f in glob.glob(os.path.join(CUTS, SHEET, "[0-9][0-9]_%s.png" % strip))
            if not f.endswith("_night.png")]
    if not hits:
        raise SystemExit("no cut for %s in %s (run scripts/cut_art_kit.py --only %s)"
                         % (strip, SHEET, SHEET))
    return hits[0]


def ensure_cuts():
    """Cut the strip sheet when its cutouts are missing (needs scipy)."""
    if glob.glob(os.path.join(CUTS, SHEET, "[0-9][0-9]_*.png")):
        return
    import cut_art_kit as kit
    path = glob.glob(os.path.join(kit.SHEETS, "20*_%s.*" % SHEET))[0]
    print("cutting", os.path.basename(path), flush=True)
    kit.one(path, os.path.join(CUTS, SHEET), *kit.RECIPE[SHEET.rsplit("-", 1)[0]])


def load_cut(strip):
    """The strip's cut as float arrays (rgb, alpha) in 0..1."""
    px = np.asarray(Image.open(cut_path(strip)).convert("RGBA"), dtype=float) / 255.0
    return px[..., :3], px[..., 3]


def resized(strip, size):
    im = Image.open(cut_path(strip)).convert("RGBA").resize(size, Image.LANCZOS)
    px = np.asarray(im, dtype=float) / 255.0
    return px[..., :3], px[..., 3]


def to_image(rgb, a):
    out = np.dstack([rgb, a]) * 255.0
    return Image.fromarray(np.round(np.clip(out, 0, 255)).astype(np.uint8), "RGBA")


def ink_pair(rgb, a, tone, night_scale):
    """(day, night) of an unbacked plane: the ink toned by day, NIGHT_INK at
    the same alpha scaled by night."""
    night = np.empty_like(rgb)
    night[:] = np.array(NIGHT_INK, dtype=float) / 255.0
    return to_image(rgb, a * tone), to_image(night, a * tone * night_scale)


def bake_far():
    """The far range across the whole width: the strip cropped to its inked
    columns first (its ends taper to nothing), tighter until every column
    of the face has ink at the crest threshold (alpha 40, as measure_apex
    and the fidelity test read it), so no column is left without a horizon."""
    src = Image.open(cut_path(FAR)).convert("RGBA")
    a0 = np.asarray(src)[..., 3]
    for floor in range(40, 256, 10):
        cols = np.nonzero((a0 >= floor).any(axis=0))[0]
        im = src.crop((int(cols[0]), 0, int(cols[-1]) + 1, src.height))
        h = max(1, int(round(im.height * W / float(im.width))))
        px = np.asarray(im.resize((W, h), Image.LANCZOS), dtype=float) / 255.0
        if (px[..., 3] * 255.0 >= 40).any(axis=0).all():
            break
    return ink_pair(px[..., :3], px[..., 3], FAR_TONE, NIGHT_SCALE["far"])


def bake_mist(strip, rect, gain):
    size = (int(round(rect[0] * W)), int(round(rect[1] * W)))
    _, a = resized(strip, size)
    a = np.clip(a * gain, 0.0, 1.0)
    paper = np.empty(a.shape + (3,))
    paper[:] = np.array(PAPER, dtype=float) / 255.0
    return to_image(paper, a), to_image(np.zeros_like(paper), a)


def window(strip, left):
    """The NEAR_ASPECT:1 window of the strip at NEAR_SIZE, as (rgb, alpha)."""
    im = Image.open(cut_path(strip)).convert("RGBA")
    ww = int(round(NEAR_ASPECT * im.height))
    x0 = min(int(round(left * im.width)), im.width - ww)
    im = im.crop((x0, 0, x0 + ww, im.height)).resize(NEAR_SIZE, Image.LANCZOS)
    px = np.asarray(im, dtype=float) / 255.0
    return px[..., :3], px[..., 3]


def cutout(rgb, a, night):
    """A near hill as a paper cutout, its foot fading, its sides feathered."""
    h, w = a.shape
    body = np.maximum.accumulate(a > BODY_FLOOR, axis=0)
    body = Image.fromarray((body * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(1.0))
    body = np.asarray(body, dtype=float) / 255.0
    start = int(h * (1.0 - NEAR_FADE))
    ramp = np.ones(h)
    ramp[start:] = np.linspace(1.0, 0.0, h - start)
    body *= ramp[:, None]
    ink = a * NEAR_TONE * (NIGHT_SCALE["near"] if night else 1.0)
    alpha = np.maximum(ink, body)
    share = np.where(alpha > 0, ink / np.maximum(alpha, 1e-6), 0.0)[..., None]
    paper = np.zeros(3) if night else np.array(PAPER, dtype=float) / 255.0
    col = rgb if not night else np.broadcast_to(np.array(NIGHT_INK, dtype=float) / 255.0, rgb.shape)
    col = col * share + paper * (1.0 - share)
    # distance from the nearer cut side, in feathers (0 at the edge, 1 inside)
    x = np.arange(w, dtype=float)
    d = np.clip(np.minimum(x, w - 1 - x) / max(1.0, w * NEAR_FEATHER), 0.0, 1.0)
    # the lower body dissolves sooner: the feather is narrower at the ridge
    depth = np.linspace(0.0, 1.0, h)[:, None]
    t = np.clip(d[None, :] * (1.6 - 0.9 * depth), 0.0, 1.0)
    side = t * t * (3.0 - 2.0 * t)
    return to_image(col, alpha * side)


def bake_near(strip, left):
    rgb, a = window(strip, left)
    return cutout(rgb, a, False), cutout(rgb, a, True)


def pack(img):
    if not PALETTE:
        return img
    return img.quantize(colors=PALETTE, method=Image.Quantize.FASTOCTREE)


def planes():
    """[(name, (day, night))] in planes.xml order."""
    out = [("horizon", bake_far())]
    for name, (strip, rect, gain) in MIST.items():
        out.append((name, bake_mist(strip, rect, gain)))
    for name, strip, left in NEAR:
        out.append((name, bake_near(strip, left)))
    return out


def bake_all():
    ensure_cuts()
    total = 0
    for name, (day, night) in planes():
        for img, suffix in ((day, ".png"), (night, "_night.png")):
            path = os.path.join(DRAW, name + suffix)
            pack(img).save(path, optimize=True)
            total += os.path.getsize(path)
        print("baked %s %dx%d" % (name, day.width, day.height), flush=True)
    print("planes: %d, %.2f MB of PNG" % (2 * (1 + len(MIST) + len(NEAR)), total / 1e6))


def size_of(name):
    return Image.open(os.path.join(DRAW, name + ".png")).size


def tables():
    hw, hh = size_of("horizon")
    _, apex_y = cp.measure_apex("horizon.png")
    near = []
    for name, strip, left in NEAR:
        w, h = size_of(name)
        ax, ay = cp.measure_apex(name + ".png")
        near.append({"name": name, "strip": strip, "left": left, "w": w, "h": h,
                     "aspect": round(w / float(h), 4), "apex_x": round(ax, 4), "apex_y": round(ay, 4)})
    mist = {name: {"strip": MIST[name][0], "w": size_of(name)[0], "h": size_of(name)[1],
                   "gain": MIST[name][2]} for name in MIST}
    table = {"sheet": SHEET, "face": W,
             "horizon": {"strip": FAR, "w": hw, "h": hh, "apex_y": round(apex_y, 4)},
             "mist": mist, "near": near}
    js = json.dumps(table, indent=1) + "\n"

    names = ["horizon"] + list(MIST) + [n for n, _, _ in NEAR]
    xml = ['<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">',
           "    <!-- Generated by scripts/bake_planes.py; do not edit. -->"]
    for n in names:
        for night in (False, True):
            f = n + ("_night" if night else "")
            xml.append('    <bitmap id="%s" filename="%s.png" dithering="none" '
                       'automaticPalette="false" packingFormat="png" compress="false" />' % (camel(f), f))
    xml.append("</drawables>")
    xml = "\n".join(xml) + "\n"

    def flist(key):
        return "[%s] as Lang.Array<Lang.Float>" % ", ".join("%.4f" % n[key] for n in near)

    def res(n, night):
        return "WatchUi.loadResource(Rez.Drawables.%s) as Graphics.BitmapType" % camel(n + ("_night" if night else ""))

    mc = ["using Toybox.Graphics;", "using Toybox.Lang;", "using Toybox.WatchUi;", "",
          "// Generated by scripts/bake_planes.py; do not edit.",
          "// The fixed planes from the ChatGPT strip sheet: the far range (the",
          "// horizon), the two mist bands and the near hills. Sizes are the PNGs'",
          "// on a %d px face; a crest is the topmost row with ink (alpha >= 40)," % W,
          "// at the middle of that row's inked columns, as compose_preview.measure_apex",
          "// reads it.", "",
          "const HORIZON_W = %.1f;    // horizon.png, drawn full width at native height" % hw,
          "const HORIZON_H = %.1f;" % hh,
          "const HORIZON_APEX_Y = %.4f;" % apex_y,
          "const MIST_W = %d;         // mist_band.png, as drawn on the face (the probe draws it 1:1)" % mist["mist_band"]["w"],
          "const MIST_H = %d;" % mist["mist_band"]["h"],
          "const MIST_LITE_W = %d;    // mist_band_lite.png" % mist["mist_band_lite"]["w"],
          "const MIST_LITE_H = %d;" % mist["mist_band_lite"]["h"],
          "const NEAR_PLANES = %d;" % len(near), "",
          "// The near hills by index (the Scene's P_NEAR, P_NEAR2): the PNG's width",
          "// over its height, and the crest inside it (fractions of the bitmap).",
          "function planeAspect() as Lang.Array<Lang.Float> {", "    return %s;" % flist("aspect"), "}", "",
          "function planeApexX() as Lang.Array<Lang.Float> {", "    return %s;" % flist("apex_x"), "}", "",
          "function planeApexY() as Lang.Array<Lang.Float> {", "    return %s;" % flist("apex_y"), "}", "",
          "// Each plane, day or night; the caller catches a refusal.",
          "function loadHorizonBitmap(night as Lang.Boolean) as Graphics.BitmapType? {",
          "    if (night) { return %s; }" % res("horizon", True),
          "    return %s;" % res("horizon", False), "}", "",
          "function loadMistBitmap(lite as Lang.Boolean, night as Lang.Boolean) as Graphics.BitmapType? {",
          "    if (lite && night) { return %s; }" % res("mist_band_lite", True),
          "    if (lite) { return %s; }" % res("mist_band_lite", False),
          "    if (night) { return %s; }" % res("mist_band", True),
          "    return %s;" % res("mist_band", False), "}", "",
          "function loadNearBitmap(p as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {"]
    for i, n in enumerate(near):
        mc.append("    if (p == %d) { return night ? %s : %s; }" % (i, res(n["name"], True), res(n["name"], False)))
    mc += ["    return null;", "}", ""]
    return {JSON: js, XML: xml, MC: "\n".join(mc)}


def main(argv):
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
        print("planes:", "current" if not stale else "%d stale" % stale)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
