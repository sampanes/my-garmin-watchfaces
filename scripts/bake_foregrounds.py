#!/usr/bin/env python
"""The foregrounds (2026-11-05): ten whole-face paintings from the sheets,
one on the face per day, in place of the two script-painted foreground
masses (gen_ink_layers' fg_left / fg_right, retired here).

The art is the round-6 and round-7 sheets (art/sheets/*_fg-<season>-a/b.png
and fg-redo-a.jpg; prompts and verdicts in art/sheets/PROMPTS.md), each one
foreground composed inside the circle: tall up both sides, low and sparse in
the middle, the inscription's column kept clear. PICKS are the ten John
judged usable on the preview face: ChatGPT's five seasons (b) and Gemini's
five (a, or c from the redo), one place through the seasons. Each is cut
whole by scripts/cut_art_kit.py (art/cuts/fg-<season>-<letter>/01_fg.png) and
baked here at the face's size, day and night:

  * day: the cut as it is (ink over nothing; red stays red);
  * night: the same alpha at full strength (the cutter's 0.80 is right for
    the far planes and too faint for this, the nearest layer: round 4's
    lesson), pale ink, and the red dimmed to NIGHT_RED (full red at night
    was loud: round 6);
  * packed as a 256-color palette PNG, like the shape library.

The snow scenes (SNOW_GROUND, winter): the cut makes paper transparent,
and the painted snow is paper, so the snow banks became holes (the masses
showed through by day, black paper at night). There the white closed in by
ink and the frame's bottom and lower sides (snow_mask; the sky reaches the
top, so it stays open) is kept as ground: opaque paper by day; at night the
painting stays positive inside it, pale snow and dark ink dimmed to
SNOW_NIGHT, moonlit snow beside the pale-ink negative around it. Baked
once, like every other cut: the watch only draws the result.

Which one shows (compose_preview.foreground_index, the Scene's
foregroundIndex): the season from the month (Dec-Feb winter, Mar-May
spring, Jun-Aug summer, Sep-Nov autumn) unless the watch setting
"foreground" names a scene (1..5: spring, summer, autumn, winter, pass),
and the painter alternating with the day of the month (even: ChatGPT, odd:
Gemini), so a scene has two faces.

Writes into watch-faces/japanese-ink-heartrate:
    resources/drawables/fg_<season>_<letter>.png, ..._night.png
    resources/drawables/foregrounds.xml         their bitmap declarations
    source/JapaneseInkHeartrateForegrounds.mc   the table and the loader
and scripts/foreground_table.json, the same table for the mock.

    py -3.11 scripts/bake_foregrounds.py           cut (if needed), bake, write tables
    py -3.11 scripts/bake_foregrounds.py --check   exit 1 if a table is stale (no scipy)
"""
import glob
import json
import os
import sys

import numpy as np
from PIL import Image

import hand_masks

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
CUTS = os.path.join(FACE, "art", "cuts")
MC = os.path.join(FACE, "source", "JapaneseInkHeartrateForegrounds.mc")
XML = os.path.join(DRAW, "foregrounds.xml")
JSON = os.path.join(HERE, "foreground_table.json")

SEASONS = ("spring", "summer", "autumn", "winter", "pass")
# per season, the painters' cuts in painter order: ChatGPT (b), then Gemini
PICKS = [("spring", "b"), ("spring", "a"),
         ("summer", "b"), ("summer", "a"),
         ("autumn", "b"), ("autumn", "c"),
         ("winter", "b"), ("winter", "c"),
         ("pass", "b"), ("pass", "c")]
PAINTERS = 2
FACE_PX = 416
NIGHT_INK = (168, 164, 152)   # cut_sprite_sheet.NIGHT_INK
NIGHT_RED = 0.60              # the red's brightness at night
PALETTE = 256


# John's hand masks (scripts/hand_masks.py, painted in mask_painter.py)
# win over the cutter wherever he painted: art/edits/fg_<season>_<letter>_mask.png.
SNOW_GROUND = {"winter"}
SNOW_NIGHT = 0.60      # the moonlit snow's brightness, a share of day paper
SNOW_INK = 0.15        # alpha over which a pixel is ink for the snow mask
SNOW_SIDES = 0.45      # the frame's sides close the snow below this share of H
PAPER_RGB = (242, 238, 230)


def name_of(season, letter):
    return "fg_%s_%s" % (season, letter)


def camel(name):
    return "".join(p.capitalize() for p in name.split("_"))


def cut_dir(season, letter):
    return os.path.join(CUTS, "fg-%s-%s" % (season, letter))


def ensure_cuts():
    """Cut the foreground sheets whose cutouts are missing (needs scipy)."""
    missing = [p for p in PICKS if not os.path.exists(os.path.join(cut_dir(*p), "01_fg.png"))]
    if not missing:
        return
    import subprocess
    print("cutting the foreground sheets:", " ".join("fg-%s-%s" % p for p in missing), flush=True)
    subprocess.check_call([sys.executable, os.path.join(HERE, "cut_art_kit.py"), "--only", "fg-"])


def bake_one(season, letter, masked=True):
    """(day, night) RGBA images at the face's size, with John's hand mask
    (hand_masks: solid trunks, rocks and snow, see-through gaps) unless
    masked is False (the mask painter's starting point)."""
    im = Image.open(os.path.join(cut_dir(season, letter), "01_fg.png")).convert("RGBA")
    im = im.resize((FACE_PX, FACE_PX), Image.LANCZOS)
    px = np.asarray(im, dtype=float) / 255.0
    rgb, a = px[..., :3], px[..., 3]
    red = (rgb[..., 0] - np.maximum(rgb[..., 1], rgb[..., 2])) > 0.10
    night = np.empty_like(rgb)
    night[:] = np.array(NIGHT_INK, dtype=float) / 255.0
    night[red] = rgb[red] * NIGHT_RED
    night = np.dstack([night, a]) * 255.0
    night = Image.fromarray(np.round(np.clip(night, 0, 255)).astype(np.uint8), "RGBA")
    day, night_out = snow_ground(im, night) if season in SNOW_GROUND else (im, night)
    mask = hand_masks.load(name_of(season, letter), (FACE_PX, FACE_PX)) if masked else None
    if mask is not None:
        # solid is the painting on its paper by day; at night a snow
        # scene's moonlit snow, else black paper with its pale ink
        solid_day = hand_masks.on_paper(im)
        solid_night = solid_day * SNOW_NIGHT if season in SNOW_GROUND else hand_masks.on_black(night)
        day = hand_masks.apply(day, solid_day, mask)
        night_out = hand_masks.apply(night_out, solid_night, mask)
    return day, night_out


def snow_mask(a):
    """0..1: the white closed in by ink and the frame's bottom and lower
    sides (the painted snow), softened a px."""
    from PIL import ImageFilter
    from scipy import ndimage
    ink = ndimage.binary_closing(a > SNOW_INK, structure=np.ones((5, 5)))
    h, w = ink.shape
    pad = np.zeros((h + 2, w + 2), bool)
    pad[1:-1, 1:-1] = ink
    pad[-1, :] = True
    pad[int(SNOW_SIDES * h):, 0] = True
    pad[int(SNOW_SIDES * h):, -1] = True
    filled = ndimage.binary_fill_holes(pad)[1:-1, 1:-1]
    soft = Image.fromarray((filled * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    return np.asarray(soft, float) / 255.0


def snow_ground(day, night):
    """(day, night) with the painted snow kept as ground (the docstring)."""
    d = np.asarray(day, float) / 255.0
    n = np.asarray(night, float) / 255.0
    m = snow_mask(d[..., 3])[..., None]
    paper = np.array(PAPER_RGB, float) / 255.0
    pos = d[..., :3] * d[..., 3:] + paper * (1 - d[..., 3:])      # the ink on its snow
    out = []
    for px, inside in ((d, pos), (n, pos * SNOW_NIGHT)):
        rgb, a = px[..., :3], px[..., 3:]
        new_a = a + (1 - a) * m
        new_rgb = (inside * m + rgb * a * (1 - m)) / np.maximum(new_a, 1e-6)
        out.append(Image.fromarray(np.round(np.clip(np.dstack([new_rgb, new_a]), 0, 1) * 255)
                                   .astype(np.uint8), "RGBA"))
    return tuple(out)


def pack(img):
    if not PALETTE:
        return img
    return img.quantize(colors=PALETTE, method=Image.Quantize.FASTOCTREE)


def bake_all():
    ensure_cuts()
    keep = {name_of(*p) for p in PICKS}
    for path in glob.glob(os.path.join(DRAW, "fg_*.png")):
        base = os.path.basename(path).replace("_night.png", "").replace(".png", "")
        if base not in keep:
            os.remove(path)
            print("removed", os.path.basename(path))
    total = 0
    for season, letter in PICKS:
        day, night = bake_one(season, letter)
        for img, suffix in ((day, ".png"), (night, "_night.png")):
            path = os.path.join(DRAW, name_of(season, letter) + suffix)
            pack(img).save(path, optimize=True)
            total += os.path.getsize(path)
        print("baked", name_of(season, letter), flush=True)
    print("foregrounds: %d paintings, %.2f MB of PNG" % (len(PICKS), total / 1e6))


def tables():
    table = {"face": FACE_PX, "seasons": list(SEASONS), "painters": PAINTERS,
             "foregrounds": [{"name": name_of(s, l), "season": s, "painter": l} for s, l in PICKS]}
    js = json.dumps(table, indent=1) + "\n"

    xml = ['<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/connect-iq/resources.xsd">',
           "    <!-- Generated by scripts/bake_foregrounds.py; do not edit. -->"]
    for s, l in PICKS:
        for night in (False, True):
            n = name_of(s, l) + ("_night" if night else "")
            xml.append('    <bitmap id="%s" filename="%s.png" dithering="none" '
                       'automaticPalette="false" packingFormat="png" compress="false" />' % (camel(n), n))
    xml.append("</drawables>")
    xml = "\n".join(xml) + "\n"

    mc = ["using Toybox.Graphics;", "using Toybox.Lang;", "using Toybox.WatchUi;", "",
          "// Generated by scripts/bake_foregrounds.py; do not edit.",
          "// The foregrounds: %d whole-face paintings, %d px square, drawn over" % (len(PICKS), FACE_PX),
          "// the whole face. Index = season * FG_PAINTERS + painter, seasons in order",
          "// %s;" % ", ".join(SEASONS),
          "// painter 0 is ChatGPT's, 1 Gemini's.", "",
          "const FG_COUNT = %d;" % len(PICKS), "const FG_SEASONS = %d;" % len(SEASONS),
          "const FG_PAINTERS = %d;" % PAINTERS, "",
          "// Foreground i, day or night; the caller catches a refusal.",
          "function loadForegroundBitmap(i as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {"]
    for night in (False, True):
        mc.append("    if (%snight) {" % ("" if night else "!"))
        for i, (s, l) in enumerate(PICKS):
            mc.append("        if (i == %d) { return WatchUi.loadResource(Rez.Drawables.%s) as Graphics.BitmapType; }"
                      % (i, camel(name_of(s, l) + ("_night" if night else ""))))
        mc.append("    }")
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
        print("foregrounds:", "current" if not stale else "%d stale" % stale)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
