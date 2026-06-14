"""Generate ink_blot.png — small soft radial blot stamped along the
underside of peaks to simulate ink wicking down into paper fibers.

See iter9d in art/checkpoints/procedural/2026-04-27_iter9d-edge-bleed.md.

Run:
    python scripts/gen_ink_blot.py

Output:
    watch-faces/japanese-ink-heartrate/resources/drawables/ink_blot.png

Design:
- 18x18 px source. Stamped 25–35 times per scene at varied scales.
- RGBA. Warm sumi `rgb(20,14,10)` matching the peak-ink color.
- Radial alpha gradient from peak α=180 at center, falling to 0 at
  the outer edge via a smooth Gaussian falloff. The smooth falloff
  is what makes it feel like ink wicking — sharp-edged stamps would
  read as discrete shapes.
- Slight non-circular asymmetry — bleed in real ink isn't perfectly
  round; capillary action follows fiber direction. Implemented as
  small per-pixel noise on the alpha.
"""

from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/ink_blot.png"

W, H = 18, 18
PEAK_ALPHA = 180
INK_R, INK_G, INK_B = 20, 14, 10


def main() -> None:
    cx, cy = (W - 1) / 2.0, (H - 1) / 2.0
    sigma = W * 0.30  # tighter than W/2 so falloff is dramatic, not gradual

    y, x = np.mgrid[0:H, 0:W]
    dx = x - cx
    dy = y - cy
    r2 = dx * dx + dy * dy
    base = PEAK_ALPHA * np.exp(-r2 / (2 * sigma * sigma))

    # Slight per-pixel noise — capillary-action asymmetry.
    rng = np.random.default_rng(seed=181)
    noise = rng.uniform(-8, 8, (H, W)) * (base > 6)
    alpha = np.clip(base + noise, 0, 255).astype(np.uint8)

    r = np.full((H, W), INK_R, dtype=np.uint8)
    g = np.full((H, W), INK_G, dtype=np.uint8)
    b = np.full((H, W), INK_B, dtype=np.uint8)

    rgba = np.stack([r, g, b, alpha], axis=-1)
    img = Image.fromarray(rgba, mode="RGBA")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"[gen_ink_blot] wrote {OUT}  ({W}x{H}, peak alpha={PEAK_ALPHA})")


if __name__ == "__main__":
    main()
