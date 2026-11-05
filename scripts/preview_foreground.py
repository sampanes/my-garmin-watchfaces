"""Render whole-face foreground paintings on the real preview face.

Each foreground (a cut from scripts/cut_art_kit.py, art/cuts/fg-*/01_fg.png)
is laid 1:1 over compose_preview's painting in place of the baked foreground
(scripts/bake_foregrounds.py), under the paper halo, the time and the HR seal: one column
per foreground, day on top (14:42) and night below (22:15), on the mock HR
day.

Usage: py -3.11 scripts/preview_foreground.py OUT.png [FG_DIR ...]
       (default FG_DIRs: the picked foregrounds listed in PICKS)
"""
import os
import sys

from PIL import Image

import bake_foregrounds
import compose_preview as cp

HERE = os.path.dirname(os.path.abspath(__file__))
CUTS = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate", "art", "cuts")

# the foregrounds judged usable (art/sheets/PROMPTS.md, round 6 and 7): the
# ten bake_foregrounds.py bakes, ChatGPT's five then Gemini's five
PICKS = ["fg-%s-%s" % p for p in sorted(bake_foregrounds.PICKS, key=lambda p: p[1] != "b")]


def render(fg_dir, night):
    fg = Image.open(os.path.join(fg_dir, "01_fg%s.png" % ("_night" if night else "")))
    history = cp.bucket_history(cp.MOCK, 16)
    trace = [(i / (len(cp.MOCK) - 1.0), cp.norm_hr(v)) for i, v in enumerate(cp.MOCK)]
    minute = 22 * 60 + 15 if night else 14 * 60 + 42
    return cp.compose(history, minute_of_day=minute, hr_now=history[-1], night=night,
                      trace=trace, overlay=False, foreground=fg.convert("RGBA"))


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    dirs = argv[1:] or [os.path.join(CUTS, p) for p in PICKS]
    w = cp.W
    sheet = Image.new("RGB", (len(dirs) * (w + 10), 2 * (w + 10)), (24, 24, 24))
    for i, d in enumerate(dirs):
        for j, night in enumerate((False, True)):
            sheet.paste(render(d, night), (i * (w + 10), j * (w + 10)))
    sheet.save(argv[0])
    print("[OK] %s: %d foregrounds" % (argv[0], len(dirs)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
