"""Cut a generated sprite sheet (ink subjects on flat white) into RGBA cutouts.

The sheet is a COLS x ROWS grid of separate subjects on a white background,
as produced by the prompt in watch-faces/japanese-ink-heartrate/art/sheets/PROMPTS.md.
The grid is only a guide: every ink blob is found by connected components and
handed to the cell that holds its centre, so a subject that strays over a
cell line is still cut whole.

Transparency comes from un-compositing against the paper white: alpha is
"how much ink", so pale washes stay see-through and there is no white fringe.
Neutral ink is snapped to the face's ink colour; red stays red.

Per subject it writes NN_name.png (day: dark ink) and NN_name_night.png
(light ink for black paper). Subjects listed in --solid (the moon) are kept
as an opaque disc in their own colours instead, because a pale moon is not
"ink" and would turn inside out at night.

Usage:
  py -3.11 scripts/cut_sprite_sheet.py SHEET --out DIR [--grid 4x4]
         [--names a,b,...] [--solid a,b] [--preview PNG]
"""
import argparse
import os

import numpy as np
from PIL import Image
from scipy import ndimage

INK = np.array((12, 9, 7), dtype=float) / 255.0          # gen_ink_layers day ink
NIGHT_INK = np.array((168, 164, 152), dtype=float) / 255.0  # gen_ink_layers NIGHT_INK
NIGHT_SCALE = 0.80                                         # night alpha, as the planes use
PAPER = (242, 238, 230)

DEFAULT_NAMES = ("sun,sun_mist,moon_full,moon_crescent,"
                 "crane,geese,swallow,cloud_wisps,"
                 "pine,boat,pagoda,plum,"
                 "reeds,bridge,hiker,rain")

FLOOR = 0.05      # alpha below this is paper noise / JPEG ringing
MIN_AREA = 12     # px; smaller blobs are specks
PAD = 8           # px of clear margin around each cutout


def uncomposite(rgb):
    """rgb in 0..1 over white -> (colour, alpha)."""
    white = np.percentile(rgb.reshape(-1, 3), 99.5, axis=0)
    norm = np.clip(rgb / white, 0.0, 1.0)
    a = 1.0 - norm.min(axis=2)
    a = np.clip((a - FLOOR) / (1.0 - FLOOR), 0.0, 1.0)
    safe = np.maximum(a, 1e-3)[..., None]
    col = np.clip((norm - (1.0 - safe)) / safe, 0.0, 1.0)
    red = (norm[..., 0] - np.maximum(norm[..., 1], norm[..., 2])) > 0.10
    return norm, col, a, red


def find_subjects(a, cols, rows):
    h, w = a.shape
    lab, n = ndimage.label(a > 0.06, structure=np.ones((3, 3)))
    boxes = ndimage.find_objects(lab)
    areas = ndimage.sum(np.ones_like(a), lab, index=np.arange(1, n + 1))
    cells = {}
    split = []
    for i, sl in enumerate(boxes):
        if sl is None or areas[i] < MIN_AREA:
            continue
        # a blob that spans well over one cell (two strips painted touching)
        # is split by the grid lines instead of handed whole to one cell
        if (sl[0].stop - sl[0].start) > 1.3 * h / rows or (sl[1].stop - sl[1].start) > 1.3 * w / cols:
            split.append(i + 1)
            continue
        cy = (sl[0].start + sl[0].stop) / 2.0
        cx = (sl[1].start + sl[1].stop) / 2.0
        key = (min(int(cy * rows / h), rows - 1), min(int(cx * cols / w), cols - 1))
        cells.setdefault(key, []).append(i + 1)
    return lab, cells, split


PAPER_F = np.array(PAPER, dtype=float) / 255.0


def paper_back(rgb, a, paper, base_fade):
    """A mountain as a cutout that hides what stands behind it: everything
    below the ridge line is body (its ink over its own paper), and the body
    fades out over the bottom BASE_FADE of the cutout, into the mist. Over
    bare paper every pixel looks unchanged."""
    h = a.shape[0]
    body = np.maximum.accumulate(a > 0.05, axis=0).astype(float)
    body = ndimage.gaussian_filter(body, 1.0)
    start = int(h * (1.0 - base_fade))
    ramp = np.ones(h)
    ramp[start:] = np.linspace(1.0, 0.0, h - start)
    body *= ramp[:, None]
    alpha = np.maximum(a, body)
    share = np.where(alpha > 0, a / np.maximum(alpha, 1e-6), 0.0)[..., None]
    col = rgb * share + paper * (1.0 - share)
    return col, alpha


def cut(sheet, out, cols, rows, names, solid, backed=False, base_fade=0.3, full=False):
    rgb = np.asarray(Image.open(sheet).convert("RGB"), dtype=float) / 255.0
    norm, col, a, red = uncomposite(rgb)
    lab, cells, split = find_subjects(a, cols, rows)
    H, W = a.shape
    yy, xx = np.mgrid[0:H, 0:W]
    in_split = np.isin(lab, split) if split else np.zeros_like(a, dtype=bool)
    os.makedirs(out, exist_ok=True)
    written = []
    for r in range(rows):
        for c in range(cols):
            k = r * cols + c
            name = names[k] if k < len(names) else "cell%02d" % k
            ids = cells.get((r, c), [])
            in_cell = ((yy * rows // H) == r) & ((xx * cols // W) == c)
            mine = np.isin(lab, ids) | (in_split & in_cell)
            if not mine.any():
                print("[!] cell %d %s: no ink found" % (k + 1, name))
                continue
            if full:
                # a painting composed for the whole face: keep its frame
                y0, y1, x0, x1 = 0, a.shape[0], 0, a.shape[1]
                near = np.ones(a.shape, dtype=bool)
            else:
                ys, xs = np.nonzero(mine)
                y0, y1 = max(ys.min() - PAD, 0), min(ys.max() + PAD + 1, a.shape[0])
                x0, x1 = max(xs.min() - PAD, 0), min(xs.max() + PAD + 1, a.shape[1])
                # keep faint wash around my blobs, but nothing from other cells
                near = ndimage.binary_dilation(mine[y0:y1, x0:x1], iterations=PAD)
            aa = a[y0:y1, x0:x1] * near
            rr = red[y0:y1, x0:x1]
            day = np.empty(aa.shape + (3,))
            day[:] = INK
            day[rr] = col[y0:y1, x0:x1][rr]
            night = np.empty_like(day)
            night[:] = NIGHT_INK
            night[rr] = day[rr]
            an = np.where(rr, aa, aa * NIGHT_SCALE)
            if name in solid:
                # a pale moon's bright edge leaks to the paper; close the gaps
                # with a disk, then fill. A crescent's inner arc is far wider
                # than the disk, so it survives.
                rad = max(6, int(0.08 * min(aa.shape)))
                yy, xx = np.mgrid[-rad:rad + 1, -rad:rad + 1]
                disk = xx * xx + yy * yy <= rad * rad
                body = np.pad(aa > 0.02, rad)
                body = ndimage.binary_closing(body, structure=disk)[rad:-rad, rad:-rad]
                disc = ndimage.binary_fill_holes(body)
                disc = ndimage.gaussian_filter(disc.astype(float), 1.2)
                day = norm[y0:y1, x0:x1]
                night = day * 0.92
                aa = an = np.clip(disc, 0.0, 1.0)
            elif backed and ("*" in backed or name in backed):
                day, aa = paper_back(day, aa, PAPER_F, base_fade)
                night, an = paper_back(night, an, np.zeros(3), base_fade)
            base = os.path.join(out, "%02d_%s" % (k + 1, name))
            for path, rgbx, alpha in ((base + ".png", day, aa), (base + "_night.png", night, an)):
                px = np.dstack([rgbx, alpha]) * 255.0
                Image.fromarray(np.round(px).astype(np.uint8), "RGBA").save(path)
            written.append((name, base + ".png", base + "_night.png", (x1 - x0, y1 - y0)))
            print("[OK] %02d %-14s %4dx%-4d blobs=%d" % (k + 1, name, x1 - x0, y1 - y0, len(ids)))
    return written


def contact(written, path, tile=220):
    cols = 4
    rows = (len(written) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tile * 2, rows * tile), (40, 40, 40))
    for i, (name, dayp, nightp, _) in enumerate(written):
        for j, (p, bg) in enumerate(((dayp, PAPER), (nightp, (0, 0, 0)))):
            im = Image.open(p)
            im.thumbnail((tile - 16, tile - 16), Image.LANCZOS)
            t = Image.new("RGB", (tile - 4, tile - 4), bg)
            t.paste(im, ((t.width - im.width) // 2, (t.height - im.height) // 2), im)
            sheet.paste(t, (((i % cols) * 2 + j) * tile + 2, (i // cols) * tile + 2))
    sheet.save(path)
    print("[OK] contact sheet", path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--out", required=True)
    ap.add_argument("--grid", default="4x4")
    ap.add_argument("--names", default=DEFAULT_NAMES)
    ap.add_argument("--solid", default="moon_full,moon_crescent")
    ap.add_argument("--preview")
    ap.add_argument("--backed", nargs="?", const="*", default="",
                    help="mountains: opaque paper-backed body below the ridge; "
                         "alone for every subject, or a comma list of names")
    ap.add_argument("--full", action="store_true",
                    help="1x1 painting composed for the whole face: keep the full frame")
    ap.add_argument("--base-fade", type=float, default=0.3,
                    help="with --backed: fraction of height the body fades over")
    args = ap.parse_args()
    cols, rows = (int(v) for v in args.grid.lower().split("x"))
    names = [n.strip() for n in args.names.split(",")]
    solid = set(n.strip() for n in args.solid.split(",") if n.strip())
    backed = set(n.strip() for n in args.backed.split(",") if n.strip())
    written = cut(args.sheet, args.out, cols, rows, names, solid,
                  backed, args.base_fade, args.full)
    if args.preview:
        contact(written, args.preview)


if __name__ == "__main__":
    main()
