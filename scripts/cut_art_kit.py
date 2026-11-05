"""Rebuild every cutout of the ink art kit from the committed sheets.

The sheets in watch-faces/japanese-ink-heartrate/art/sheets/ are the source;
the cutouts are build output, written to art/cuts/ (git-ignored) and never
edited by hand. This file is the recipe: which grid, names and cutter flags
each sheet was cut with. "a" sheets are Gemini, "b" sheets ChatGPT (see
art/sheets/PROMPTS.md).

    art/cuts/<sheet>/NN_name.png, NN_name_night.png   one cutout, day / night
    art/cuts/<sheet>-contact.png                       contact sheet, day | night

The Gemini foreground redo (fg-redo-a) is three circle paintings on one
sheet. It is first split into three square paintings (one per circle: the
square is the circle's ink width, sat on its ink bottom), which are then cut
whole like the other foregrounds, into fg-autumn-c, fg-winter-c, fg-pass-c.

Usage: py -3.11 scripts/cut_art_kit.py [--only fg-] [--out DIR]
"""
import argparse
import glob
import os

import numpy as np
from PIL import Image

import cut_sprite_sheet as cutter

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate", "art")
SHEETS = os.path.join(ART, "sheets")

PROPS2 = ("torii,lantern,hut,heron,deer,waterfall,sailboat,village,"
          "maple,petals,snow,snow_pine,seal_square,seal_oval,enso,mist_band")
MOUNTAINS = "peak,dome,plateau,ridge3,ramp_up,ramp_down,spire,twin,lean_l,lean_r,broad,teeth"
MOUNTAINS2 = ("cliff_l,cliff_r,two_tier,spires3,twin_domes,cone_shoulder,"
              "notch,crag,wedge,headland_l,headland_r,tall_peak")
STRIPS = "far_pale,far_hills,mist_dense,mist_wisps,near_ridge,near_pines"
WATER = "lake,shore_reeds,reflections,ground_fog,foreshore,treeline"
CORNERS = "grass_l,grass_r,boulder_l,boulder_r,pine_l,pine_r,maple_l,maple_r"
ARCS = "arc_grass,arc_reeds,arc_snow,arc_maple"
TREES = ("pine_narrow,pine_wide,pine_lean_l,pine_lean_r,pines2,pines3,fir,broadleaf,"
         "row5,row5_uneven,bare,snow_pine,umbrella,umbrellas2,cypress,cypresses2")

# sheet stem (after the date) -> grid, names, solid, backed, full
RECIPE = {
    "props": ("4x4", cutter.DEFAULT_NAMES, "moon_full,moon_crescent", "", False),
    "props2": ("4x4", PROPS2, "", "", False),
    "mountains": ("3x4", MOUNTAINS, "", "", False),
    "mountains2": ("3x4", MOUNTAINS2, "", "", False),
    "strips": ("1x6", STRIPS, "", "near_ridge,near_pines", False),
    "water": ("1x6", WATER, "", "", False),
    "corners": ("2x4", CORNERS, "", "", False),
    "arcs": ("1x4", ARCS, "", "", False),
    "arcs2": ("1x4", ARCS, "", "", False),
    "trees": ("4x4", TREES, "", "", False),
}
for season in ("spring", "summer", "autumn", "winter", "pass"):
    RECIPE["fg-" + season] = ("1x1", "fg", "", "", True)

REDO = ("fg-redo", ("autumn", "winter", "pass"))


def split_circles(sheet, names, out_dir):
    """N circle paintings side by side -> N square paintings on white."""
    im = Image.open(sheet).convert("RGB")
    a = 1.0 - np.asarray(im, dtype=float).min(axis=2) / 255.0
    w = a.shape[1]
    ink = a > 0.12
    paths = []
    for i, name in enumerate(names):
        x0, x1 = i * w // len(names), (i + 1) * w // len(names)
        cols = np.nonzero(ink[:, x0:x1].sum(axis=0) > 2)[0] + x0
        rows = np.nonzero(ink[:, x0:x1].sum(axis=1) > 2)[0]
        l, r, t, b = cols.min(), cols.max(), rows.min(), rows.max()
        d = max(r - l, b - t)
        cx = (l + r) / 2.0
        pad = int(0.02 * d)
        box = (int(cx - d / 2) - pad, int(b - d) - pad, int(cx + d / 2) + pad, int(b) + pad)
        sq = Image.new("RGB", (box[2] - box[0], box[3] - box[1]), (255, 255, 255))
        sq.paste(im.crop(box), (0, 0))
        p = os.path.join(out_dir, "split-%s.png" % name)
        sq.save(p)
        paths.append(p)
    return paths


def one(sheet, out, grid, names, solid, backed, full):
    cols, rows = (int(v) for v in grid.split("x"))
    names = [n.strip() for n in names.split(",")]
    solid = set(n for n in solid.split(",") if n)
    backed = set(n for n in backed.split(",") if n)
    written = cutter.cut(sheet, out, cols, rows, names, solid, backed, 0.3, full)
    cutter.contact(written, out + "-contact.png")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="cut only sheets whose name starts with this")
    ap.add_argument("--out", default=os.path.join(ART, "cuts"))
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    for path in sorted(glob.glob(os.path.join(SHEETS, "20*_*-[ab].*"))):
        stem = os.path.splitext(os.path.basename(path))[0].split("_", 1)[1]   # e.g. fg-spring-a
        kind = stem.rsplit("-", 1)[0]
        if kind == REDO[0]:
            targets = ["fg-%s-c" % n for n in REDO[1]]
            if not any(t.startswith(args.only) for t in targets + [stem]):
                continue
            for name, t, p in zip(REDO[1], targets, split_circles(path, REDO[1], args.out)):
                print("== %s (from %s)" % (t, stem))
                one(p, os.path.join(args.out, t), *RECIPE["fg-" + name])
            continue
        if not stem.startswith(args.only):
            continue
        if kind not in RECIPE:
            print("[!] %s: no recipe, skipped" % stem)
            continue
        print("== " + stem)
        one(path, os.path.join(args.out, stem), *RECIPE[kind])


if __name__ == "__main__":
    main()
