#!/usr/bin/env python
"""Offline 416x416 mock of the watch composition using the baked layers.

Mirrors the Monkey C draw recipe 1:1 so every layout number proven here is
ported straight into JapaneseInkHeartrateScene.mc as the same fraction.
Writes art/kit_preview.png (circular-masked, on dark surround like the sim).

Planes, back to front (same order on the watch):
    paper -> sun/moon -> far_range -> mist_lite -> guest -> host -> mist
    -> fg_left -> fg_right -> paper grain -> (View) inscription + seal
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
OUT = os.path.join(FACE, "art", "kit_preview.png")

W = H = 416
PAPER = (242, 238, 230, 255)

# ---- mock HR history (same binning and landmark model as Monkey C) --------
MOCK = [72, 74, 76, 78, 82, 88, 95, 105, 112, 108, 100, 92, 85, 80, 77, 75,
        73, 72, 74, 78, 84, 92, 102, 115, 128, 135, 130, 120, 108, 95, 85, 78,
        74, 72, 70, 71, 73, 76, 79, 82, 85, 90, 96, 102, 108, 110, 105, 98]
HR_MIN, HR_MAX = 45.0, 160.0


def norm_hr(hr):
    return min(max((hr - HR_MIN) / (HR_MAX - HR_MIN), 0.0), 1.0)


def height_for_hr(hr):
    return 0.35 + norm_hr(hr) * 0.65


def peak_x(nx):
    return 0.20 + min(max(nx, 0.0), 1.0) * 0.60


def bucket_history(data, count=16):
    """Resample the full oldest-to-newest window into fixed time bins."""
    bins = []
    for i in range(count):
        lo = int(i * len(data) / count)
        hi = max(lo + 1, int((i + 1) * len(data) / count))
        bins.append(sum(data[lo:hi]) / len(data[lo:hi]))
    return bins


def landmark_peaks(history):
    """Strongest bucket (host) and strongest bucket at least an hour away (guest)."""
    host = max(range(len(history)), key=lambda i: history[i])
    guest, guest_hr = -1, -1.0
    for i, hr in enumerate(history):
        if abs(i - host) >= 4 and hr > guest_hr:
            guest, guest_hr = i, hr
    if guest < 0:
        guest = len(history) - 1 if host < len(history) / 2 else 0
    denom = len(history) - 1
    return [(host / denom, height_for_hr(history[host])),
            (guest / denom, height_for_hr(history[guest]))]


# ---- compose ----------------------------------------------------------------

def paste_scaled(base, img, x, y, w, h):
    """Scale and source-over like drawScaledBitmap. The layer is pasted WITHOUT
    a mask: pasting with the image as its own mask squares the alpha and made
    every earlier preview far paler than the device."""
    im = img.resize((max(1, int(round(w))), max(1, int(round(h)))), Image.LANCZOS)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(im, (int(round(x)), int(round(y))))
    return Image.alpha_composite(base, layer)


def load(name):
    return Image.open(os.path.join(DRAW, name)).convert("RGBA")


def compose(history, minute_of_day=14 * 60 + 42, hr_now=None):
    far = load("far_range.png")
    guest = load("guest_mountain.png")
    host = load("host_mountain.png")
    fg_l = load("fg_left.png")
    fg_r = load("fg_right.png")
    mist = load("mist_band.png")
    mist_lite = load("mist_band_lite.png")
    grain_p = os.path.join(DRAW, "paper_grain.png")
    grain = Image.open(grain_p).convert("RGBA") if os.path.exists(grain_p) else None

    (host_nx, h0), (guest_nx, h1) = landmark_peaks(history)
    hx = 0.36 + peak_x(host_nx) * 0.40          # host stays mid-right of center
    gx = peak_x(guest_nx)
    if abs(hx - gx) < 0.30:                      # guest must clear the host massif
        gx = hx + 0.34 if hx < 0.5 else hx - 0.34
    gx = min(max(gx, 0.16), 0.84)
    # Foreground masses carry the two ends of the window: oldest left, newest right.
    h_start = norm_hr(history[0])
    h_end = norm_hr(history[-1])

    base = Image.new("RGBA", (W, H), PAPER)

    # sun / moon on the day arc (sun 06:00-18:00 west to east)
    d = ImageDraw.Draw(base, "RGBA")
    night = minute_of_day < 360 or minute_of_day >= 1080
    t = ((minute_of_day - 1080) % 1440) / 720.0 if night else (minute_of_day - 360) / 720.0
    import math
    sx = int(W * 0.20 + W * 0.60 * t)
    sy = int(H * 0.14 - math.sin(t * math.pi) * H * 0.06)
    r_halo, r_core = int(W * 0.046), int(W * 0.034)
    if night:
        d.ellipse([sx - r_halo, sy - r_halo, sx + r_halo, sy + r_halo], fill=(240, 235, 220, 0x30))
        d.ellipse([sx - r_core, sy - r_core, sx + r_core, sy + r_core], fill=(248, 244, 232, 0xC0))
    else:
        d.ellipse([sx - r_halo, sy - r_halo, sx + r_halo, sy + r_halo], fill=(200, 70, 50, 0x40))
        d.ellipse([sx - r_core, sy - r_core, sx + r_core, sy + r_core], fill=(175, 38, 28, 0xCC))

    # 1. far plane (ghost + far ridges), the horizon haze
    base = paste_scaled(base, far, -0.02 * W, 0.33 * H, 1.04 * W, 0.29 * H)

    # 2. light mist between far and mid planes
    base = paste_scaled(base, mist_lite, -0.10 * W, 0.50 * H, 1.20 * W, 0.17 * H)

    # 3. guest: second landmark, recessed
    g_h = 0.50 * H * (0.55 + 0.45 * h1)
    g_w = g_h * (260.0 / 190.0)
    g_apex = 0.42
    base = paste_scaled(base, guest, gx * W - g_apex * g_w, 0.71 * H - g_h, g_w, g_h)

    # 4. host: strongest landmark, the hero
    m_h = 0.70 * H * (0.72 + 0.38 * h0)
    m_w = m_h * (340.0 / 260.0)
    m_apex = 0.47
    base = paste_scaled(base, host, hx * W - m_apex * m_w, 0.87 * H - m_h, m_w, m_h)

    # 5. full mist dissolving the mid-plane bases
    base = paste_scaled(base, mist, -0.03 * W, 0.69 * H, 1.06 * W, 0.20 * H)

    # 6. foreground masses: left = oldest hour, right = newest
    l_h = 0.58 * H * (0.80 + 0.20 * h_start)
    l_w = 0.74 * W
    base = paste_scaled(base, fg_l, -0.04 * W, H - l_h + 0.03 * H, l_w, l_h)
    r_h = 0.52 * H * (0.80 + 0.20 * h_end)
    r_w = 0.68 * W
    base = paste_scaled(base, fg_r, W - r_w + 0.04 * W, H - r_h + 0.03 * H, r_w, r_h)

    # 7. paper grain over everything
    if grain is not None:
        base = paste_scaled(base, grain, 0, 0, W, H)

    # 8. inscription time + seal (upper-left void), as the View draws them
    d = ImageDraw.Draw(base, "RGBA")
    try:
        f_big = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 58)
        f_small = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 16)
    except Exception:
        f_big = f_small = ImageFont.load_default()
    ink = (52, 42, 34, 255)
    hour = minute_of_day // 60
    hour12 = 12 if hour % 12 == 0 else hour % 12
    d.text((int(0.22 * W), int(0.21 * H)), str(hour12), font=f_big, fill=ink, anchor="mm")
    d.text((int(0.22 * W), int(0.33 * H)), "%02d" % (minute_of_day % 60), font=f_big, fill=ink, anchor="mm")
    seal = int(W * 0.067)
    sx0, sy0 = int(0.22 * W) - seal // 2, int(0.425 * H)
    d.rounded_rectangle([sx0, sy0, sx0 + seal, sy0 + seal], radius=seal // 7, fill=(176, 52, 38, 235))
    if hr_now is not None:
        d.text((int(0.22 * W), sy0 + seal // 2), str(int(round(hr_now))), font=f_small,
               fill=(244, 238, 226, 255), anchor="mm")
    d.text((int(0.22 * W), int(0.525 * H)), "4h", font=f_small, fill=(104, 98, 89, 190), anchor="mm")

    # circular mask + dark surround (sim look)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, W - 1, H - 1], fill=255)
    surround = Image.new("RGBA", (W, H), (24, 24, 24, 255))
    surround.paste(base, (0, 0), mask)
    return surround.convert("RGB")


def main(argv):
    out = argv[1] if len(argv) > 1 else OUT
    history = bucket_history(MOCK, 16)
    compose(history, hr_now=history[-1]).save(out)
    print("preview ->", os.path.abspath(out))


if __name__ == "__main__":
    main(sys.argv)
