"""Generate ridge_cloud.png: a soft broken cloud eraser for peak mist."""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/ridge_cloud.png"

W, H = 168, 58
PAPER = (244, 240, 232)


def main() -> None:
    rng = np.random.default_rng(seed=42929)
    alpha = np.zeros((H, W), dtype=np.float32)

    # Overlapping soft lobes make a cloud instead of a single strip.
    lobes = [
        (0.18, 0.55, 0.18, 0.24, 92),
        (0.34, 0.45, 0.23, 0.26, 118),
        (0.53, 0.52, 0.28, 0.30, 100),
        (0.73, 0.46, 0.22, 0.24, 88),
        (0.88, 0.58, 0.16, 0.20, 62),
    ]

    for y in range(H):
        yn = y / (H - 1)
        for x in range(W):
            xn = x / (W - 1)
            a = 0.0
            for cx, cy, sx, sy, strength in lobes:
                dx = (xn - cx) / sx
                dy = (yn - cy) / sy
                a += strength * np.exp(-(dx * dx + dy * dy) * 0.5)

            fiber = 1.0 + 0.10 * np.sin(x * 0.22 + y * 0.43) + 0.07 * np.sin(x * 0.71)
            alpha[y, x] = a * fiber

    alpha *= rng.uniform(0.84, 1.10, (H, W))

    # Cut dry holes and ragged edges so it reads as paper/air, not fog UI.
    for _ in range(34):
        x0 = int(rng.integers(0, W))
        y0 = int(rng.integers(0, H))
        rx = int(rng.integers(7, 25))
        ry = int(rng.integers(2, 8))
        y_min = max(0, y0 - ry)
        y_max = min(H, y0 + ry + 1)
        x_min = max(0, x0 - rx)
        x_max = min(W, x0 + rx + 1)
        for yy in range(y_min, y_max):
            for xx in range(x_min, x_max):
                dx = (xx - x0) / max(1, rx)
                dy = (yy - y0) / max(1, ry)
                if dx * dx + dy * dy <= 1.0:
                    alpha[yy, xx] *= rng.uniform(0.34, 0.76)

    alpha = np.clip(alpha, 0, 150).astype(np.uint8)
    img = Image.new("RGBA", (W, H), (*PAPER, 0))
    img.putalpha(Image.fromarray(alpha, mode="L"))
    img = img.filter(ImageFilter.GaussianBlur(radius=1.15))

    # A few thin warm-gray fibers inside the cloud keep it from looking blank.
    draw = ImageDraw.Draw(img, "RGBA")
    for _ in range(10):
        x = int(rng.integers(0, W))
        y = int(rng.integers(10, H - 8))
        length = int(rng.integers(10, 42))
        draw.line(
            (x, y, min(W - 1, x + length), y + int(rng.integers(-1, 2))),
            fill=(168, 158, 142, int(rng.integers(7, 17))),
            width=1,
        )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"[gen_ridge_cloud] wrote {OUT} ({W}x{H})")


if __name__ == "__main__":
    main()
