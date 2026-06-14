"""Generate paper_grain.png — subtle fiber/noise texture overlay that
makes the canvas read as paper rather than as a glass screen.

See watch-faces/japanese-ink-heartrate/RENDERER_PLAN.md §6.

Run:
    python scripts/gen_paper_grain.py

Output:
    watch-faces/japanese-ink-heartrate/resources/drawables/paper_grain.png

Design:
- 250x250 px source — drawScaledBitmap'd to canvas size at draw time.
- RGBA. Warm taupe-brown grain `rgb(96,82,68)` so dark spots integrate
  with the warm washi paper instead of looking like a cold gray haze.
- Two scales of texture overlaid:
  * Tiny dark specks (0.5–1.5 px) — paper "tooth"
  * Short horizontal fiber strokes (3–10 px) — washi has visible fiber
- Peak alpha 28 — barely-there. Texture should register as tactile
  rather than as a graphic element. Higher would compete with the
  mountains.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/paper_grain.png"

W, H = 250, 250
PEAK_ALPHA = 28
GRAIN_R, GRAIN_G, GRAIN_B = 96, 82, 68


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed=131)

    # Specks — tiny darker dots scattered across the field.
    speck_count = 1400
    for _ in range(speck_count):
        x = rng.integers(0, W)
        y = rng.integers(0, H)
        r = rng.uniform(0.2, 1.4)
        alpha = int(rng.integers(8, PEAK_ALPHA))
        draw.ellipse([x - r, y - r, x + r, y + r],
                     fill=(GRAIN_R, GRAIN_G, GRAIN_B, alpha))

    # Fibers — short horizontal-ish strokes simulating washi fiber.
    fiber_count = 220
    for _ in range(fiber_count):
        x0 = rng.integers(0, W)
        y0 = rng.integers(0, H)
        length = rng.uniform(3, 10)
        angle = rng.uniform(-0.18, 0.18)  # near-horizontal
        x1 = x0 + length * np.cos(angle)
        y1 = y0 + length * np.sin(angle)
        alpha = int(rng.integers(6, 18))
        # Slight color jitter per fiber so they don't all match.
        cr = max(0, min(255, GRAIN_R + int(rng.integers(-12, 13))))
        cg = max(0, min(255, GRAIN_G + int(rng.integers(-10, 11))))
        cb = max(0, min(255, GRAIN_B + int(rng.integers(-10, 11))))
        draw.line([(x0, y0), (x1, y1)], fill=(cr, cg, cb, alpha), width=1)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"[gen_paper_grain] wrote {OUT}  ({W}x{H}, peak alpha={PEAK_ALPHA})")


if __name__ == "__main__":
    main()
