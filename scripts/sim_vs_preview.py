#!/usr/bin/env python
"""Side-by-side of a simulator capture and the compose_preview.py render of
the same moment, plus their difference, judged inside the watch circle only
(the simulator paints the corners; the preview masks them).

    python scripts/sim_vs_preview.py sim.png preview.png out.png

Prints the mean absolute difference (0-255, greyscale of the per-channel
difference) and the share of pixels where that difference exceeds 32. The numbers are a smoke test, not a
verdict: the simulator feeds its own HR history, so the data never matches
exactly. Look at the sheet.
"""

import sys

from PIL import Image, ImageChops, ImageDraw

GAP = 20


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    sim = Image.open(argv[1]).convert("RGB")
    prev = Image.open(argv[2]).convert("RGB")
    if prev.size != sim.size:
        prev = prev.resize(sim.size, Image.LANCZOS)
    w, h = sim.size

    mask = Image.new("L", sim.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, w - 1, h - 1], fill=255)
    inside = sum(1 for v in mask.getdata() if v)

    diff = ImageChops.difference(sim, prev)
    grey = diff.convert("L")
    black = Image.new("L", sim.size, 0)
    grey = Image.composite(grey, black, mask)
    hist = grey.histogram()
    mean = sum(i * c for i, c in enumerate(hist)) / float(inside)
    over = 100.0 * sum(hist[33:]) / inside

    sheet = Image.new("RGB", (w * 3 + GAP * 2, h), (40, 40, 40))
    sheet.paste(sim, (0, 0))
    sheet.paste(prev, (w + GAP, 0))
    sheet.paste(grey.point(lambda v: min(255, v * 4)).convert("RGB"), (2 * (w + GAP), 0))
    sheet.save(argv[3])
    print("mean_abs_diff=%.1f over32_pct=%.1f" % (mean, over))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
