#!/usr/bin/env python
"""Offline 416x416 mock of the watch composition using the baked layers.

Mirrors the Monkey C draw recipe 1:1 so every layout number proven here is
ported straight into JapaneseInkHeartrateScene.mc as the same fraction.
Writes art/kit_preview.png (circular-masked, on dark surround like the sim).

Planes, back to front (same order on the watch):
    paper -> sun/moon -> far_range -> mist_lite -> guest -> host -> mist
    -> fg_left -> fg_right -> paper grain -> (View) inscription + seal

The inscription uses the baked BMFont pairs in resources/fonts (read from the
.fnt exactly as the resource compiler reads them), so the preview's digits
are the device's digits. --night composes the moonlit negative set (what the
night-mode hours show); the true-HR overlay is on unless --no-trace.
"""

import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
FONTS = os.path.join(FACE, "resources", "fonts")
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


def height_for_norm(norm):
    return 0.35 + norm * 0.65


def height_for_hr(hr):
    return height_for_norm(norm_hr(hr))


def peak_x(nx):
    return 0.20 + min(max(nx, 0.0), 1.0) * 0.60


def axis_x(nx):
    """The landscape's time axis: four hours ago .. now -> 0.36..0.80 of W,
    clear of the inscription column. Both landmarks and the true-HR overlay
    use it, so a departure of the art from the data is visible as such."""
    return 0.36 + (peak_x(nx) - 0.20) * 0.73


def host_height(h_norm):
    """Host plane height for a landmark height (height_for_hr output)."""
    return 0.70 * H * (0.50 + 0.60 * h_norm)


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


class BmFont:
    """Reads a baked .fnt/.png pair exactly as the resource compiler will, and
    draws a string the way dc.drawText(..., CENTER | VCENTER) places it: the
    advances summed and centered on x, the line height centered on y."""

    def __init__(self, name):
        self.glyphs = {}
        with open(os.path.join(FONTS, name + ".fnt")) as f:
            for line in f:
                kv = dict(tok.split("=", 1) for tok in line.split()[1:] if "=" in tok)
                if line.startswith("common "):
                    self.line_h = int(kv["lineHeight"])
                elif line.startswith("char "):
                    self.glyphs[chr(int(kv["id"]))] = {
                        k: int(kv[k]) for k in
                        ("x", "y", "width", "height", "xoffset", "yoffset", "xadvance")}
        self.atlas = Image.open(os.path.join(FONTS, name + ".png")).convert("RGBA").getchannel("A")

    def draw(self, img, text, cx, cy, rgb):
        adv = sum(self.glyphs[c]["xadvance"] for c in text)
        pen = cx - adv / 2.0
        top = cy - self.line_h / 2.0
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        for c in text:
            g = self.glyphs[c]
            a = self.atlas.crop((g["x"], g["y"], g["x"] + g["width"], g["y"] + g["height"]))
            tile = Image.new("RGBA", a.size, rgb + (255,))
            tile.putalpha(a)
            layer.paste(tile, (int(round(pen + g["xoffset"])), int(round(top + g["yoffset"]))))
            pen += g["xadvance"]
        return Image.alpha_composite(img, layer)


def kanji_hour(hour):
    """The hour as one or two numerals, as the View composes them: 0 = 〇,
    1-9, 10 = 十, 11-19 = 十X, 20 = 廿, 21-23 = 廿X. Never a third glyph,
    which would run the column into the bezel."""
    digits = "〇一二三四五六七八九"
    tens, ones = divmod(hour, 10)
    out = []
    if tens == 1:
        out.append("十")
    elif tens >= 2:
        out.append("廿")
    if ones != 0 or tens == 0:
        out.append(digits[ones])
    return out


# Where the painted crest sits inside each plane bitmap (alpha >= 40, measured
# 2026-10-29 on the day and night sets alike): the host apex is 31% down its
# bitmap, the guest 12%. The overlay is plotted on the HOST'S CREST SCALE, the
# y the host crest would have if the host were sized for that HR, so the data
# and the painting share a scale where the painting is honest (the hero
# crest) and the rest of the painting's license shows against it.
HOST_APEX_Y = 0.31
GUEST_APEX_Y = 0.12
TRACE_COLS = 58          # fillPolygon takes at most 64 points (DC_PART1)
TRACE_FLOOR_PAD = 0.02   # the wash's floor sits this far under the lowest sample


def trace_y(norm):
    """Crest scale: 45 bpm -> 0.527 H, 160 bpm -> 0.337 H."""
    return 0.87 * H - (1.0 - HOST_APEX_Y) * host_height(height_for_norm(norm))


def thin_trace(trace, cols=TRACE_COLS):
    """At most `cols` samples, each group reduced to its HIGHEST sample so a
    peak survives the thinning (storeTrace in the Scene)."""
    if len(trace) <= cols:
        return list(trace)
    stride = (len(trace) + cols - 1) // cols
    return [max(trace[i:i + stride], key=lambda t: t[1]) for i in range(0, len(trace), stride)]


def draw_trace(base, trace, host_crest, guest_crest, night):
    """The true-HR overlay as the Scene draws it: the data as a SILHOUETTE in
    the painting's own grammar, a translucent vermilion wash under the data's
    skyline on the host crest scale, with a crisp brush edge, and a dot on
    each painted crest. Where the wash rises above the ink the painting
    under-states; where ink stands above the edge it over-states. Drawn at
    2x for antialiasing."""
    S = 2
    layer = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    wash = (200, 70, 50, 0x50) if night else (176, 52, 38, 0x3C)
    edge = (236, 110, 84, 0xF0) if night else (166, 44, 30, 0xF0)
    pts = [(W * axis_x(nx) * S, trace_y(norm) * S) for nx, norm in thin_trace(trace)]
    # The floor hugs the window's lowest sample, so the wash is the data's
    # own relief rather than a box: no flat band, short sides.
    floor = max(y for _, y in pts) + TRACE_FLOOR_PAD * H * S
    d.polygon(pts + [(pts[-1][0], floor), (pts[0][0], floor)], fill=wash)
    d.line(pts, fill=edge, width=2 * S, joint="curve")
    for cx, cy in (host_crest, guest_crest):
        d.ellipse([(cx - 4) * S, (cy - 4) * S, (cx + 4) * S, (cy + 4) * S], fill=edge)
    layer = layer.resize((W, H), Image.LANCZOS)
    return Image.alpha_composite(base, layer)


def compose(history, minute_of_day=14 * 60 + 42, hr_now=None, night=False, trace=None,
            hour24=False):
    """night: the moonlit negative set (pale ink on black paper, no grain).
    trace: [(nx, norm_hr)] raw samples for the true-HR overlay, or None."""
    sfx = "_night" if night else ""
    far = load("far_range%s.png" % sfx)
    guest = load("guest_mountain%s.png" % sfx)
    host = load("host_mountain%s.png" % sfx)
    fg_l = load("fg_left%s.png" % sfx)
    fg_r = load("fg_right%s.png" % sfx)
    mist = load("mist_band%s.png" % sfx)
    mist_lite = load("mist_band_lite%s.png" % sfx)
    grain_p = os.path.join(DRAW, "paper_grain.png")
    grain = Image.open(grain_p).convert("RGBA") if os.path.exists(grain_p) and not night else None

    # Both landmarks on the one time axis. The guest apex also stays right of
    # the inscription column (x >= 0.34) and clear of the host massif; when
    # it cannot do both on its own side of the host it crosses over.
    (host_nx, h0), (guest_nx, h1) = landmark_peaks(history)
    hx = axis_x(host_nx)
    gx = max(axis_x(guest_nx), 0.34)
    if abs(hx - gx) < 0.30:
        gx = hx + 0.34 if hx < 0.55 else hx - 0.34
        gx = min(max(gx, 0.34), 0.84)
    # Foreground masses carry the two ends of the window: oldest left, newest right.
    h_start = norm_hr(history[0])
    h_end = norm_hr(history[-1])

    base = Image.new("RGBA", (W, H), (0, 0, 0, 255) if night else PAPER)

    # sun / moon on the day arc (sun 06:00-18:00 west to east)
    d = ImageDraw.Draw(base, "RGBA")
    # (moon, not night: night mode is the settings window passed in, and it
    # must not be shadowed here or the ink goes pale on day paper after
    # 18:00, which the watch never does)
    moon = minute_of_day < 360 or minute_of_day >= 1080
    t = ((minute_of_day - 1080) % 1440) / 720.0 if moon else (minute_of_day - 360) / 720.0
    import math
    sx = int(W * 0.20 + W * 0.60 * t)
    sy = int(H * 0.14 - math.sin(t * math.pi) * H * 0.06)
    r_halo, r_core = int(W * 0.046), int(W * 0.034)
    if moon:
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
    g_h = 0.50 * H * (0.40 + 0.70 * h1)
    g_w = g_h * (260.0 / 190.0)
    g_apex = 0.46          # measured crest column (was 0.42, 8 px off the axis)
    base = paste_scaled(base, guest, gx * W - g_apex * g_w, 0.71 * H - g_h, g_w, g_h)

    # 4. host: strongest landmark, the hero
    m_h = host_height(h0)
    m_w = m_h * (340.0 / 260.0)
    m_apex = 0.47
    base = paste_scaled(base, host, hx * W - m_apex * m_w, 0.87 * H - m_h, m_w, m_h)

    # 5. full mist dissolving the mid-plane bases
    base = paste_scaled(base, mist, -0.03 * W, 0.69 * H, 1.06 * W, 0.20 * H)

    # 6. foreground masses: left = oldest hour, right = newest
    l_h = 0.58 * H * (0.65 + 0.45 * h_start)
    l_w = 0.74 * W
    base = paste_scaled(base, fg_l, -0.04 * W, H - l_h + 0.03 * H, l_w, l_h)
    r_h = 0.52 * H * (0.65 + 0.45 * h_end)
    r_w = 0.68 * W
    base = paste_scaled(base, fg_r, W - r_w + 0.04 * W, H - r_h + 0.03 * H, r_w, r_h)

    # 7. paper grain over everything (day only: black paper stays black)
    if grain is not None:
        base = paste_scaled(base, grain, 0, 0, W, H)

    # 8. the data itself, for judging the painting against it: dots on the
    #    painted crests (the apex pixel inside each plane, not its rect top)
    if trace is not None:
        base = draw_trace(base, trace,
                          (hx * W, 0.87 * H - m_h + HOST_APEX_Y * m_h),
                          (gx * W, 0.71 * H - g_h + GUEST_APEX_Y * g_h), night)

    # 9. inscription column + seal (upper-left void), as the View draws them:
    #    the hour as brush kanji stacked on a 0.10 H pitch, bottom glyph at
    #    0.265 H so one- and two-glyph hours share a baseline, the minutes in
    #    the brush digits at 0.375 H, the carved seal digits for HR.
    ink_font = BmFont("ink_digits")
    kanji_font = BmFont("kanji_hours")
    seal_font = BmFont("seal_digits")
    ink = (216, 210, 198) if night else (24, 18, 14)
    hour = minute_of_day // 60
    if not hour24:
        hour = 12 if hour % 12 == 0 else hour % 12
    glyphs = kanji_hour(hour)
    pitch, bottom = int(0.10 * H), int(0.265 * H)
    for i, g in enumerate(glyphs):
        base = kanji_font.draw(base, g, int(0.22 * W), bottom - (len(glyphs) - 1 - i) * pitch, ink)
    base = ink_font.draw(base, "%02d" % (minute_of_day % 60), int(0.22 * W), int(0.375 * H), ink)
    seal = int(W * 0.085)
    sx0, sy0 = int(0.22 * W) - seal // 2, int(0.465 * H)
    ImageDraw.Draw(base, "RGBA").rounded_rectangle(
        [sx0, sy0, sx0 + seal, sy0 + seal], radius=seal // 7,
        fill=(150, 44, 32, 235) if night else (176, 52, 38, 235))
    if hr_now is not None:
        base = seal_font.draw(base, str(int(round(hr_now))), int(0.22 * W), sy0 + seal / 2.0,
                              (244, 238, 226))

    # circular mask + dark surround (sim look)
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, W - 1, H - 1], fill=255)
    surround = Image.new("RGBA", (W, H), (24, 24, 24, 255))
    surround.paste(base, (0, 0), mask)
    return surround.convert("RGB")


def main(argv):
    """compose_preview.py [out.png] [--night] [--no-trace] [--24h] [--time HH:MM]

    Defaults: 14:42 by day, 22:15 by night, 12-hour clock."""
    args = []
    skip = False
    for i, a in enumerate(argv[1:], 1):
        if skip:
            skip = False
        elif a == "--time":
            skip = True
        elif not a.startswith("--"):
            args.append(a)
    night = "--night" in argv
    out = args[0] if args else OUT
    history = bucket_history(MOCK, 16)
    trace = None if "--no-trace" in argv else \
        [(i / (len(MOCK) - 1.0), norm_hr(v)) for i, v in enumerate(MOCK)]
    minute = 22 * 60 + 15 if night else 14 * 60 + 42
    if "--time" in argv:
        hh, mm = argv[argv.index("--time") + 1].split(":")
        minute = int(hh) * 60 + int(mm)
    compose(history, minute_of_day=minute, hr_now=history[-1], night=night, trace=trace,
            hour24="--24h" in argv).save(out)
    print("preview ->", os.path.abspath(out))


if __name__ == "__main__":
    main(sys.argv)
