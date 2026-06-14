#!/usr/bin/env python
"""Offline 416x416 mock of the watch composition using the generated kit.

Mirrors the intended Monkey C draw recipe 1:1 so layout numbers proven here
can be ported straight into JapaneseInkHeartrateScene.mc. Writes
art/kit_preview.png (circular-masked, on dark surround like the sim).
"""

import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
OUT = os.path.join(FACE, "art", "kit_preview.png")

W = H = 416

# ---- mock HR -> peaks (same math as the Monkey C pipeline) ----------------
MOCK = [72, 74, 76, 78, 82, 88, 95, 105, 112, 108, 100, 92, 85, 80, 77, 75,
        73, 72, 74, 78, 84, 92, 102, 115, 128, 135, 130, 120, 108, 95, 85, 78,
        74, 72, 70, 71, 73, 76, 79, 82, 85, 90, 96, 102, 108, 110, 105, 98]


def smooth(data, win=7):
    out = []
    half = win // 2
    for i in range(len(data)):
        lo, hi = max(0, i - half), min(len(data) - 1, i + half)
        seg = data[lo:hi + 1]
        out.append(sum(seg) / len(seg))
    return out


def hr_to_peaks(data, count=3):
    peaks = []
    for i in range(count):
        t = (i + 0.5) / count
        idx = int(t * (len(data) - 1))
        raw = min(max(data[idx], 45.0), 160.0)
        hn = (raw - 45.0) / 115.0
        peaks.append((t, 0.35 + hn * 0.65))
    return sorted(peaks, key=lambda p: -p[1])


def peak_x(nx):
    return 0.20 + min(max(nx, 0.0), 1.0) * 0.60


# ---- compose ----------------------------------------------------------------

def paste_scaled(base, img, x, y, w, h, alpha=1.0):
    im = img.resize((max(1, int(w)), max(1, int(h))), Image.LANCZOS)
    if alpha < 1.0:
        a = im.getchannel("A").point(lambda v: int(v * alpha))
        im.putalpha(a)
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(im, (int(x), int(y)), im)
    return Image.alpha_composite(base, layer)


def main():
    host = Image.open(os.path.join(DRAW, "host_mountain.png")).convert("RGBA")
    guest = Image.open(os.path.join(DRAW, "guest_mountain.png")).convert("RGBA")
    far = Image.open(os.path.join(DRAW, "far_range.png")).convert("RGBA")
    mist = Image.open(os.path.join(DRAW, "mist_band.png")).convert("RGBA")
    shore = Image.open(os.path.join(DRAW, "shore_foreground.png")).convert("RGBA")
    grain_p = os.path.join(DRAW, "paper_grain.png")
    grain = Image.open(grain_p).convert("RGBA") if os.path.exists(grain_p) else None

    peaks = hr_to_peaks(smooth(MOCK), 3)
    (host_nx, h0), (guest_nx, h1) = peaks[0], peaks[1]
    hx = 0.36 + peak_x(host_nx) * 0.40       # host stays mid-right of center
    gx = peak_x(guest_nx)
    if abs(hx - gx) < 0.30:                  # guest must clear the host massif
        gx = hx + 0.34 if hx < 0.5 else hx - 0.34
    gx = min(max(gx, 0.16), 0.84)

    # paper
    base = Image.new("RGBA", (W, H), (242, 238, 230, 255))

    # 1. far range — sits high, pale atmosphere
    base = paste_scaled(base, far, -10, 128, 436, 112, alpha=1.0)

    # 2. guest mountain — recessed mid-ground hint beyond the mist, NOT a
    # competing tower. Small, pale, low.
    g_h = int(210 * (0.42 + 0.28 * h1))
    g_w = int(250 * g_h / 210)
    g_apex_frac = 100.0 / 250.0          # guest main spire x within bitmap
    g_x = int(gx * W - g_apex_frac * g_w)
    g_y = 300 - g_h
    base = paste_scaled(base, guest, g_x, g_y, g_w, g_h)

    # 3. mist pass 1 — separates guest from host plane (right fade on-screen)
    base = paste_scaled(base, mist, -90, 226, 444, 96, alpha=0.62)

    # 4. host mountain — the hero
    h_h = int(290 * (0.86 + 0.38 * h0))
    h_w = int(320 * h_h / 290)
    h_apex_frac = 158.0 / 320.0
    h_x = int(hx * W - h_apex_frac * h_w)
    h_y = 372 - h_h
    base = paste_scaled(base, host, h_x, h_y, h_w, h_h)

    # 5. mist pass 2 — dissolves all bases
    base = paste_scaled(base, mist, -12, 296, 446, 112, alpha=1.0)

    # 6. shore foreground bottom-left (after mist; high enough to stay
    # inside the circular screen)
    base = paste_scaled(base, shore, -8, 286, 332, 101)

    # 7. sun (afternoon position mock)
    d = ImageDraw.Draw(base, "RGBA")
    sx, sy = int(0.70 * W), 56
    d.ellipse([sx - 19, sy - 19, sx + 19, sy + 19], fill=(200, 70, 50, 0x40))
    d.ellipse([sx - 14, sy - 14, sx + 14, sy + 14], fill=(175, 38, 28, 0xCC))

    # 8. paper grain on top
    if grain is not None:
        base = paste_scaled(base, grain, 0, 0, W, H)

    # 9. inscription time + seal (upper-left void)
    d = ImageDraw.Draw(base, "RGBA")
    try:
        f_h = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 58)
        f_m = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 58)
        f_s = ImageFont.truetype("C:/Windows/Fonts/arialbd.ttf", 16)
    except Exception:
        f_h = f_m = f_s = ImageFont.load_default()
    ink = (52, 42, 34, 255)
    d.text((104, 96), "5", font=f_h, fill=ink, anchor="mm")
    d.text((104, 152), "42", font=f_m, fill=ink, anchor="mm")
    # red seal with current HR
    seal = (176, 52, 38, 235)
    d.rounded_rectangle([90, 186, 118, 214], radius=4, fill=seal)
    d.text((104, 200), "64", font=f_s, fill=(244, 238, 226, 255), anchor="mm")

    # circular mask + dark surround (sim look)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, W - 1, H - 1], fill=255)
    surround = Image.new("RGBA", (W, H), (24, 24, 24, 255))
    surround.paste(base, (0, 0), mask)
    surround.convert("RGB").save(OUT)
    print("preview ->", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
