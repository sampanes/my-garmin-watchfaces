"""Generate crest_anchor.png — the dominant dark mark that sits above the
host descent and anchors the eye to "mountain peak."

See watch-faces/japanese-ink-heartrate/RENDERER_PLAN.md §6.

Run:
    python scripts/gen_crest_anchor.py

Output:
    watch-faces/japanese-ink-heartrate/resources/drawables/crest_anchor.png

Design:
- 60x28 px source — draws wider than tall so it reads as "ridge top" with
  horizontal extent, not a single floating dab.
- Sumi black `rgb(32,28,24)` — darker than the body wash (which uses 72/69/66).
  Peak alpha high (~210) because the crest is supposed to be the darkest mark
  in the scene and anchor the eye.
- One dominant calligraphic dab slightly left of center (~38% x), flanked
  by two smaller lighter drift fragments toward the right — matches the
  visual grammar of real sumi-e crest fragments where one brush contact
  produces a dominant mark plus trailing dry-brush particles.
- Internal texture via per-pixel noise; edges slightly ragged.
- Upper edge is softer than lower edge — the crest sits ON the descent
  (which is below), so its bottom meets the descent crisply while its top
  fades into paper/sky.
"""

from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/crest_anchor.png"

W, H = 60, 28
PEAK_ALPHA = 210  # darkest mark in the scene
INK_R, INK_G, INK_B = 32, 28, 24  # warm dense sumi


def _gaussian_blob(
    w: int,
    h: int,
    cx: float,
    cy: float,
    sx: float,
    sy: float,
    amp: float,
) -> np.ndarray:
    """Return a (h, w) float array of a 2D Gaussian blob normalized to `amp`."""
    x = np.arange(w, dtype=float).reshape(1, -1)
    y = np.arange(h, dtype=float).reshape(-1, 1)
    dx = (x - cx) / max(sx, 0.5)
    dy = (y - cy) / max(sy, 0.5)
    return amp * np.exp(-(dx * dx + dy * dy) * 0.5)


def build_alpha() -> np.ndarray:
    """Compose one dominant dab + two drift fragments + noise."""
    alpha = np.zeros((H, W), dtype=float)

    # Dominant dab: left of center, largest.
    alpha += _gaussian_blob(W, H, cx=W * 0.38, cy=H * 0.52, sx=6.5, sy=4.5, amp=PEAK_ALPHA)
    # Second dab: partially overlapping, smaller, to the right.
    alpha += _gaussian_blob(W, H, cx=W * 0.54, cy=H * 0.44, sx=5.0, sy=3.2, amp=PEAK_ALPHA * 0.75)
    # Drift fragment #1: right side.
    alpha += _gaussian_blob(W, H, cx=W * 0.72, cy=H * 0.55, sx=3.5, sy=2.2, amp=PEAK_ALPHA * 0.45)
    # Drift fragment #2: far right.
    alpha += _gaussian_blob(W, H, cx=W * 0.88, cy=H * 0.60, sx=2.5, sy=1.8, amp=PEAK_ALPHA * 0.28)
    # A very small highlight fragment to the left of the main dab.
    alpha += _gaussian_blob(W, H, cx=W * 0.22, cy=H * 0.58, sx=2.8, sy=2.0, amp=PEAK_ALPHA * 0.35)

    # Dry-brush speckle: subtract a bit of alpha at scattered points so the
    # mark isn't a plastic solid shape.
    rng = np.random.default_rng(seed=23)
    mask = rng.uniform(0, 1, (H, W)) < 0.12
    alpha[mask] -= 40
    # Soft noise everywhere for warmth.
    alpha += rng.uniform(-6, 6, (H, W))

    # Slight asymmetric vertical: top fades more than bottom so the crest
    # meets the descent below it more decisively.
    y = np.arange(H, dtype=float).reshape(-1, 1)
    y_norm = y / (H - 1)
    # Top softener: reduce alpha in the top 25% of rows.
    top_fade = np.where(y_norm < 0.25, y_norm / 0.25, 1.0)
    alpha *= top_fade

    return np.clip(alpha, 0, 255).astype(np.uint8)


def build_rgb() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed=29)
    jitter = rng.integers(-3, 4, (H, W)).astype(np.int32)
    r = np.clip(INK_R + jitter, 0, 255).astype(np.uint8)
    g = np.clip(INK_G + jitter, 0, 255).astype(np.uint8)
    b = np.clip(INK_B + jitter, 0, 255).astype(np.uint8)
    return r, g, b


def main() -> None:
    alpha = build_alpha()
    r, g, b = build_rgb()
    rgba = np.stack([r, g, b, alpha], axis=-1)
    img = Image.fromarray(rgba, mode="RGBA")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"[gen_crest_anchor] wrote {OUT}  ({W}x{H}, peak alpha={PEAK_ALPHA})")


if __name__ == "__main__":
    main()
