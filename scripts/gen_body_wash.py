"""Generate body_wash_soft.png — the mid-tone atmospheric body for the
japanese-ink-heartrate face.

See watch-faces/japanese-ink-heartrate/RENDERER_PLAN.md §6.

Run:
    python scripts/gen_body_wash.py

Output:
    watch-faces/japanese-ink-heartrate/resources/drawables/body_wash_soft.png

The asset substitutes for a Canvas linear-gradient + alpha compositing —
Garmin has neither, so the grayscale+alpha PNG carries the internal tonal
variation itself. Imported tuned in drawables.xml so the Garmin bitmap
pipeline preserves the soft alpha.

Design notes:
- 300x90 px. Will be drawScaledBitmap'd to roughly the sim's width x ~18% height.
- Grayscale ink ~#484542, slightly warm.
- Vertical alpha: feathered top, peaks around 45% of height, harder fall on the
  bottom so the form "dissolves" into whatever mist or paper is below.
- Horizontal alpha: gentle left-heavy tilt — gives us asymmetry for cheap.
- Low-amplitude noise so the surface doesn't read as plastic.
- PEAK_ALPHA is intentionally lower than intended final density; repeated
  placement + layered stamps darken the scene, per RENDERER_PLAN §9.
"""

from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/body_wash_soft.png"

W, H = 300, 90
PEAK_ALPHA = 110  # author lighter — overlap darkens
INK_R, INK_G, INK_B = 72, 69, 66  # warm sumi mid-tone


def build_alpha() -> np.ndarray:
    y = np.arange(H, dtype=float).reshape(-1, 1)
    x = np.arange(W, dtype=float).reshape(1, -1)
    y_norm = y / (H - 1)
    x_norm = x / (W - 1)

    # Feathered top (0 at top edge, full by 35% down)
    top_rise = np.clip(y_norm / 0.35, 0.0, 1.0)
    # Harder bottom fall (full above 55%, gone by bottom edge)
    bottom_fall = np.clip((1.0 - y_norm) / 0.45, 0.0, 1.0)
    vertical_profile = top_rise * bottom_fall  # peaks near y_norm ~0.45

    # Horizontal tilt: left-heavier than right, plus a soft center dip so
    # grouped placements read like two subtly separated phrases not one brick.
    tilt = 0.95 - 0.35 * x_norm
    center_dip = 1.0 - 0.15 * np.exp(-((x_norm - 0.55) ** 2) / (2 * 0.08 ** 2))
    horizontal_profile = tilt * center_dip

    rng = np.random.default_rng(seed=42)
    noise = rng.uniform(-4.0, 4.0, (H, W)) * (vertical_profile > 0.15)

    alpha = PEAK_ALPHA * vertical_profile * horizontal_profile + noise
    return np.clip(alpha, 0, 255).astype(np.uint8)


def build_rgb() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed=7)
    jitter = rng.integers(-4, 5, (H, W)).astype(np.int32)
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
    print(f"[gen_body_wash] wrote {OUT}  ({W}x{H}, peak alpha={PEAK_ALPHA})")


if __name__ == "__main__":
    main()
