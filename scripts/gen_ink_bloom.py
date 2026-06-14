"""Generate ink_bloom.png: a broad vertical wash plume for the Garmin face.

The renderer uses this as a Garmin-safe substitute for Canvas blur/gradient:
stamp the plume under HR peaks, then draw the dark ridge over it.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "watch-faces/japanese-ink-heartrate/resources/drawables/ink_bloom.png"

W, H = 96, 190
INK_R, INK_G, INK_B = 36, 30, 24


def main() -> None:
    rng = np.random.default_rng(seed=918)
    alpha = np.zeros((H, W), dtype=np.float32)

    for y in range(H):
        yn = y / (H - 1)
        top_rise = np.clip(yn / 0.13, 0.0, 1.0) ** 0.85
        bottom_fall = np.clip((1.0 - yn) / 0.86, 0.0, 1.0) ** 0.82
        vertical = np.exp(-((yn - 0.22) ** 2) / (2 * 0.20 * 0.20))
        vertical *= top_rise * bottom_fall
        vertical += 0.10 * np.exp(-((yn - 0.50) ** 2) / (2 * 0.25 * 0.25)) * bottom_fall

        for x in range(W):
            xn = (x - (W - 1) * 0.5) / ((W - 1) * 0.5)
            width = 0.28 + yn * 0.28
            body = np.exp(-(xn * xn) / (2 * width * width))
            side_fall = np.clip(1.0 - abs(xn) ** 2.6, 0.0, 1.0)
            fiber = 1.0 + 0.14 * np.sin(x * 0.31 + y * 0.055) + 0.08 * np.sin(x * 0.83)
            alpha[y, x] = 90 * vertical * body * side_fall * fiber

    noise = rng.uniform(-8.0, 8.0, (H, W)) * (alpha > 4)
    alpha = np.clip(alpha + noise, 0, 135)

    # Dry-brush fiber voids: subtract alpha rather than drawing black marks.
    for _ in range(34):
        x = int(rng.integers(4, W - 4))
        y0 = int(rng.integers(0, int(H * 0.72)))
        y1 = y0 + int(rng.integers(28, 95))
        x1 = x + int(rng.integers(-4, 5))
        steps = max(1, abs(y1 - y0))
        for i in range(steps):
            t = i / steps
            yy = min(H - 1, max(0, y0 + i))
            xx = min(W - 1, max(0, int(x + (x1 - x) * t)))
            alpha[yy, xx] *= rng.uniform(0.35, 0.68)
            if xx + 1 < W:
                alpha[yy, xx + 1] *= rng.uniform(0.55, 0.82)

    alpha = np.clip(alpha, 0, 135).astype(np.uint8)

    img = Image.new("RGBA", (W, H), (INK_R, INK_G, INK_B, 0))
    img.putalpha(Image.fromarray(alpha, mode="L"))

    # Feather once so the asset carries the softness Garmin cannot synthesize.
    img = img.filter(ImageFilter.GaussianBlur(radius=1.35))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, format="PNG")
    print(f"[gen_ink_bloom] wrote {OUT} ({W}x{H})")


if __name__ == "__main__":
    main()
