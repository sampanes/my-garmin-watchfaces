"""Generate mountain_texture.png — cun-stroke / dry-brush texture that
sits inside the mountain silhouette area, converting the silhouette
from a filled shape into a brushed-on ink wash.

See watch-faces/japanese-ink-heartrate/RENDERER_PLAN.md §6.

Run:
    python scripts/gen_mountain_texture.py

Output:
    watch-faces/japanese-ink-heartrate/resources/drawables/mountain_texture.png

Design:
- 320x140 px source — wide-and-short matches the mountain band's
  aspect ratio when scaled to the silhouette area.
- RGBA. Warm dark sumi `rgb(40,32,24)` strokes — same family as the
  peak-ink color, just slightly lighter so internal texture reads as
  brush pressure variation, not as additional dark forms.
- Composed of three primitives, all with alpha variation:
  * Short dashes (5–12 px) at small angles — primary cun strokes
  * Tiny dots — micro dry-brush dots where bristles caught
  * A few longer strokes (15–28 px) — brush lifts and sweeps
- Density is highest in the vertical middle, fading toward top and
  bottom. The mountain area is centered vertically when stamped, so
  this puts the most texture mid-mountain and lets the dark crown
  + light base read cleanly without clutter.
- Peak alpha 110 — visible as texture, but doesn't dominate the
  underlying silhouette tonal gradient.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/mountain_texture.png"

W, H = 320, 140
PEAK_ALPHA = 110
INK_R, INK_G, INK_B = 40, 32, 24


def vertical_density(y: float) -> float:
    """Triangular falloff: 0 at top/bottom edges, 1 at middle."""
    t = y / (H - 1)
    return 1.0 - abs(t - 0.5) * 2.0


def main() -> None:
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rng = np.random.default_rng(seed=149)

    # Short cun-strokes — the primary texture element.
    dash_count = 380
    for _ in range(dash_count):
        x0 = rng.integers(0, W)
        y0 = rng.integers(0, H)
        if rng.uniform(0, 1) > vertical_density(y0):
            continue  # drop strokes near top/bottom edges
        length = rng.uniform(4, 12)
        angle = rng.uniform(-0.35, 0.35)
        x1 = x0 + length * np.cos(angle)
        y1 = y0 + length * np.sin(angle)
        alpha = int(rng.integers(35, PEAK_ALPHA))
        # Stroke width varies — bristle-like
        thick = int(rng.integers(1, 3))
        draw.line([(x0, y0), (x1, y1)],
                  fill=(INK_R, INK_G, INK_B, alpha),
                  width=thick)

    # Micro dots — bristle catches.
    dot_count = 600
    for _ in range(dot_count):
        x = rng.integers(0, W)
        y = rng.integers(0, H)
        if rng.uniform(0, 1) > vertical_density(y):
            continue
        r = rng.uniform(0.3, 1.4)
        alpha = int(rng.integers(20, 70))
        draw.ellipse([x - r, y - r, x + r, y + r],
                     fill=(INK_R, INK_G, INK_B, alpha))

    # Longer sweeps — fewer, bigger brush-lifts.
    sweep_count = 32
    for _ in range(sweep_count):
        x0 = rng.integers(0, W)
        y0 = rng.integers(int(H * 0.25), int(H * 0.75))
        length = rng.uniform(15, 28)
        angle = rng.uniform(-0.12, 0.12)
        x1 = x0 + length * np.cos(angle)
        y1 = y0 + length * np.sin(angle)
        alpha = int(rng.integers(40, 90))
        draw.line([(x0, y0), (x1, y1)],
                  fill=(INK_R, INK_G, INK_B, alpha),
                  width=1)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"[gen_mountain_texture] wrote {OUT}  ({W}x{H}, peak alpha={PEAK_ALPHA})")


if __name__ == "__main__":
    main()
