"""Generate mist_strip.png — feathered asymmetric warm-white strip used as
erasure across the lower joins of the mountain range.

See watch-faces/japanese-ink-heartrate/RENDERER_PLAN.md §6.

Run:
    python scripts/gen_mist_strip.py

Output:
    watch-faces/japanese-ink-heartrate/resources/drawables/mist_strip.png

Design:
- 320x60 px source — wider than tall, drawn nearly the full screen width so
  it spans both peaks' lower portions.
- Warm off-white `rgb(246,242,234)` matches the sandbox's mist color and
  sits between the washi paper tone and pure white. Keeps the atmosphere
  coherent.
- Peak alpha 80 — mist **erases** and **dissolves**; it must not overwrite.
  Low alpha ensures it reveals the underlying forms rather than painting
  a cloud over them.
- Asymmetric: denser on the left-center, thinning toward the right. This
  maps to "wind from one direction" in sumi-e — gives the scene a single
  coherent atmospheric read rather than a symmetric stripe.
- Uneven top AND bottom edges — critical for breaking the rectangle feel.
  The alpha profile uses a sinusoidal top edge plus Gaussian "puff" blobs
  for internal wisp structure.
- Internal variation — a few overlapping Gaussian puffs so the strip has
  thicker and thinner regions, not uniform density.
"""

from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/mist_strip.png"

W, H = 320, 60
PEAK_ALPHA = 80  # low — mist erases, never overwrites
MIST_R, MIST_G, MIST_B = 246, 242, 234  # warm off-white (sandbox-derived)


def _gaussian_blob(w, h, cx, cy, sx, sy, amp) -> np.ndarray:
    x = np.arange(w, dtype=float).reshape(1, -1)
    y = np.arange(h, dtype=float).reshape(-1, 1)
    dx = (x - cx) / max(sx, 0.5)
    dy = (y - cy) / max(sy, 0.5)
    return amp * np.exp(-(dx * dx + dy * dy) * 0.5)


def build_alpha() -> np.ndarray:
    y = np.arange(H, dtype=float).reshape(-1, 1)
    x = np.arange(W, dtype=float).reshape(1, -1)
    y_norm = y / (H - 1)
    x_norm = x / (W - 1)

    # Horizontal density profile: left-center-biased. Peaks around x_norm=0.35.
    # Gentle but visible tilt — sandbox mist has a clear "mist drifting from
    # one side" character.
    h_profile = np.exp(-((x_norm - 0.35) ** 2) / (2 * 0.26 ** 2))

    # Vertical profile: feather top and bottom, peak near middle. Non-symmetric
    # so the mist feels more like drift than a stripe — bottom slightly taller
    # fade than top so the base of the mountains feels dissolved.
    top_rise = np.clip((y_norm - 0.05) / 0.30, 0.0, 1.0)
    bottom_fall = np.clip((1.0 - y_norm) / 0.45, 0.0, 1.0)
    v_profile = top_rise * bottom_fall

    # Add sinusoidal perturbation to the top and bottom edges so neither reads
    # as a clean line. Phase-shifted between them for organic asymmetry.
    top_wave = 0.14 * np.sin(x_norm * 2 * np.pi * 2.7 + 0.3)
    bot_wave = 0.11 * np.sin(x_norm * 2 * np.pi * 3.5 + 1.8)
    y_centered = y_norm - 0.5
    edge_mask = 1.0 - np.clip(np.abs(y_centered) * 2.2 + top_wave + bot_wave, 0, 1) ** 2

    alpha = PEAK_ALPHA * h_profile * v_profile * np.clip(edge_mask + 0.35, 0, 1.2)

    # Internal wisp puffs — two or three overlapping to create thicker spots
    # and thinner gaps. Centers chosen so they cluster in the denser region.
    alpha += _gaussian_blob(W, H, cx=W * 0.22, cy=H * 0.45, sx=40, sy=12, amp=PEAK_ALPHA * 0.45)
    alpha += _gaussian_blob(W, H, cx=W * 0.42, cy=H * 0.52, sx=55, sy=14, amp=PEAK_ALPHA * 0.55)
    alpha += _gaussian_blob(W, H, cx=W * 0.65, cy=H * 0.48, sx=45, sy=11, amp=PEAK_ALPHA * 0.28)
    alpha += _gaussian_blob(W, H, cx=W * 0.86, cy=H * 0.55, sx=30, sy=9, amp=PEAK_ALPHA * 0.15)

    # Low-amplitude per-pixel noise so the surface isn't plastic.
    rng = np.random.default_rng(seed=57)
    alpha += rng.uniform(-3, 3, (H, W)) * (alpha > 4)

    # Clip out the weakest values so the outermost edges go fully transparent
    # (prevents the "faint rectangle outline" artifact at low alphas).
    alpha = np.where(alpha < 5, 0, alpha)

    return np.clip(alpha, 0, 255).astype(np.uint8)


def build_rgb() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    rng = np.random.default_rng(seed=61)
    jitter = rng.integers(-2, 3, (H, W)).astype(np.int32)
    r = np.clip(MIST_R + jitter, 0, 255).astype(np.uint8)
    g = np.clip(MIST_G + jitter, 0, 255).astype(np.uint8)
    b = np.clip(MIST_B + jitter, 0, 255).astype(np.uint8)
    return r, g, b


def main() -> None:
    alpha = build_alpha()
    r, g, b = build_rgb()
    rgba = np.stack([r, g, b, alpha], axis=-1)
    img = Image.fromarray(rgba, mode="RGBA")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"[gen_mist_strip] wrote {OUT}  ({W}x{H}, peak alpha={PEAK_ALPHA})")


if __name__ == "__main__":
    main()
