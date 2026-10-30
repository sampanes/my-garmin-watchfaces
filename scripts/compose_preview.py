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

import csv
import datetime
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


# ---- real data (same binning as refreshHistory in the Scene) ----------------
HISTORY_SECONDS = 4 * 3600
HISTORY_BUCKETS = 16
ARIZONA = datetime.timezone(datetime.timedelta(hours=-7))


def fill_internal_gaps(history):
    """Interpolate empty buckets between buckets that hold data; leading and
    trailing emptiness stays empty (fillInternalGaps in the Scene)."""
    for i in range(1, len(history) - 1):
        if history[i] > 0.0:
            continue
        left, right = i - 1, i + 1
        while left >= 0 and history[left] <= 0.0:
            left -= 1
        while right < len(history) and history[right] <= 0.0:
            right += 1
        if left >= 0 and right < len(history):
            t = (i - left) / float(right - left)
            history[i] = history[left] + (history[right] - history[left]) * t


def edge_hr(history, edge):
    """Normalized HR of the oldest (edge < 0) or newest bucket that holds
    data; 0.5 when the window is empty (edgeHr in the Scene)."""
    order = range(len(history)) if edge < 0 else range(len(history) - 1, -1, -1)
    for i in order:
        if history[i] > 0.0:
            return norm_hr(history[i])
    return 0.5


def load_data(path, end_epoch=None):
    """A real window from an `epoch,hr_avg[,hr_max]` CSV (one row per live
    bucket; scripts/read-friend.ps1 rows or any HR export). The window is
    the four hours ending at `end_epoch` (default: the newest row). Rows
    bin by TIME exactly as refreshHistory does: averages feed the sixteen
    buckets, maxima feed the overlay (the watch thins its raw samples by
    group maximum, so the per-bucket maximum is what the wrist shows).
    Returns (history, trace, hr_now, end_epoch, n_rows)."""
    rows = []
    with open(path, newline="") as fh:
        for d in csv.DictReader(fh):
            avg = float(d["hr_avg"])
            if avg <= 0:
                continue
            rows.append((int(d["epoch"]), avg, float(d.get("hr_max") or avg)))
    rows.sort()
    if end_epoch is None:
        end_epoch = rows[-1][0]
    start = end_epoch - HISTORY_SECONDS
    rows = [r for r in rows if start <= r[0] <= end_epoch]
    sums, counts, trace = [0.0] * HISTORY_BUCKETS, [0] * HISTORY_BUCKETS, []
    for t, avg, mx in rows:
        elapsed = t - start
        b = min(max(elapsed * HISTORY_BUCKETS // HISTORY_SECONDS, 0), HISTORY_BUCKETS - 1)
        sums[b] += avg
        counts[b] += 1
        trace.append((elapsed / float(HISTORY_SECONDS), norm_hr(mx)))
    history = [sums[i] / counts[i] if counts[i] else 0.0 for i in range(HISTORY_BUCKETS)]
    fill_internal_gaps(history)
    hr_now = rows[-1][1] if rows else None
    return history, trace, hr_now, end_epoch, len(rows)


def landmark_peaks(history):
    """Strongest bucket (host) and the strongest bucket WITH DATA at least an
    hour away (guest). An empty bucket is not a landmark; with none in
    reach the list has one peak and the painting has no guest."""
    host = max(range(len(history)), key=lambda i: history[i])
    guest, guest_hr = -1, 0.0
    for i, hr in enumerate(history):
        if abs(i - host) >= 4 and hr > guest_hr:
            guest, guest_hr = i, hr
    denom = len(history) - 1
    peaks = [(host / denom, height_for_hr(history[host]))]
    if guest >= 0:
        peaks.append((guest / denom, height_for_hr(history[guest])))
    return peaks


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


def blend_ellipse(base, cx, cy, r, rgba):
    """A translucent disk source-over the paper, like fillCircle after
    setFill(createColor(a, r, g, b)). ImageDraw on an RGBA image REPLACES
    pixels, alpha included, and the final circle mask then shows that color
    opaque: the sun's 0x40 halo came out as a solid red disk until the
    2026-10-30 simulator sheet caught it."""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([cx - r, cy - r, cx + r, cy + r], fill=rgba)
    return Image.alpha_composite(base, layer)


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
GUEST_RECESS = 0.03      # the guest crest sits this far below the crest scale
TRACE_COLS = 58          # fillPolygon takes at most 64 points (DC_PART1)
TRACE_FLOOR_PAD = 0.02   # the wash's floor sits this far under the lowest sample


def crest_y(h_norm):
    """The host's crest scale for a landmark height: 45 bpm -> 0.527 H,
    160 bpm -> 0.337 H. The guest crest and the overlay sit on it too, so
    one height means one heart rate everywhere in the painting."""
    return 0.87 * H - (1.0 - HOST_APEX_Y) * host_height(h_norm)


def trace_y(norm):
    return crest_y(height_for_norm(norm))


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
    # (guest_crest is None when the painting has no guest this window)
    edge = (236, 110, 84, 0xF0) if night else (166, 44, 30, 0xF0)
    pts = [(W * axis_x(nx) * S, trace_y(norm) * S) for nx, norm in thin_trace(trace)]
    # The floor hugs the window's lowest sample, so the wash is the data's
    # own relief rather than a box: no flat band, short sides.
    floor = max(y for _, y in pts) + TRACE_FLOOR_PAD * H * S
    d.polygon(pts + [(pts[-1][0], floor), (pts[0][0], floor)], fill=wash)
    d.line(pts, fill=edge, width=2 * S, joint="curve")
    for crest in (host_crest, guest_crest):
        if crest is None:
            continue
        cx, cy = crest
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
    # it cannot do both on its own side of the host it crosses over. No
    # second landmark means no guest plane.
    peaks = landmark_peaks(history)
    host_nx, h0 = peaks[0]
    hx = axis_x(host_nx)
    gx, h1 = None, None
    if len(peaks) > 1:
        guest_nx, h1 = peaks[1]
        gx = max(axis_x(guest_nx), 0.34)
        if abs(hx - gx) < 0.30:
            gx = hx + 0.34 if hx < 0.55 else hx - 0.34
            gx = min(max(gx, 0.34), 0.84)
    # Foreground masses carry the two ends of the window: the oldest and the
    # newest bucket WITH DATA (a window missing its first hours after a
    # reboot keeps those buckets at zero, and zero is not a heart rate).
    h_start = edge_hr(history, -1)
    h_end = edge_hr(history, 1)

    base = Image.new("RGBA", (W, H), (0, 0, 0, 255) if night else PAPER)

    # sun / moon on the day arc (sun 06:00-18:00 west to east)
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
        halo, core = (240, 235, 220, 0x30), (248, 244, 232, 0xC0)
    else:
        halo, core = (200, 70, 50, 0x40), (175, 38, 28, 0xCC)
    base = blend_ellipse(base, sx, sy, r_halo, halo)
    base = blend_ellipse(base, sx, sy, r_core, core)

    # 1. far plane (ghost + far ridges), the horizon haze
    base = paste_scaled(base, far, -0.02 * W, 0.33 * H, 1.04 * W, 0.29 * H)

    # 2. light mist between far and mid planes
    base = paste_scaled(base, mist_lite, -0.10 * W, 0.50 * H, 1.20 * W, 0.17 * H)

    # 3. guest: second landmark, its crest on the host's crest scale and
    #    GUEST_RECESS lower, so a lower heart rate is a lower peak
    guest_crest = None
    if gx is not None:
        g_h = 0.50 * H * (0.40 + 0.70 * h1)
        g_w = g_h * (260.0 / 190.0)
        g_apex = 0.46      # measured crest column (was 0.42, 8 px off the axis)
        g_y = crest_y(h1) + GUEST_RECESS * H - GUEST_APEX_Y * g_h
        base = paste_scaled(base, guest, gx * W - g_apex * g_w, g_y, g_w, g_h)
        guest_crest = (gx * W, g_y + GUEST_APEX_Y * g_h)

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
                          (hx * W, 0.87 * H - m_h + HOST_APEX_Y * m_h), guest_crest, night)

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
    seal_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(seal_layer).rounded_rectangle(
        [sx0, sy0, sx0 + seal, sy0 + seal], radius=seal // 7,
        fill=(150, 44, 32, 235) if night else (176, 52, 38, 235))
    base = Image.alpha_composite(base, seal_layer)
    if hr_now is not None:
        base = seal_font.draw(base, str(int(round(hr_now))), int(0.22 * W), sy0 + seal / 2.0,
                              (244, 238, 226))

    return round_off(base)


def round_off(base):
    """Circular mask + dark surround (the sim look)."""
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, W - 1, H - 1], fill=255)
    surround = Image.new("RGBA", (W, H), (24, 24, 24, 255))
    surround.paste(base, (0, 0), mask)
    return surround.convert("RGB")


# ---- the RENDERER_PLAN §13 probe card ---------------------------------------
# What the Scene draws with PROBE = true, geometry 1:1 (fractions of the
# screen, integer truncation as on the watch). The RIGHT tile of each pair is
# rendered the way the API promises (Pillow's bilinear resample, half the
# mist's alpha, the documented multiply), so the wrist photo has something to
# be judged against: a tile that matches this is a row that survives, one
# that matches its LEFT neighbor is a no-op, and the word ERR or n/a is the
# firmware refusing the call. The labels use Pillow's default face; the
# watch uses FONT_XTINY, so their width differs, and the title's API level
# and buffer note ("full" = ALPHA_BLENDING_FULL accepted) are the watch's.
MIST_W, MIST_H = 416, 110
PROBE_GROUND = (0x5A, 0x55, 0x50, 255)
PROBE_INK = (24, 18, 14, 255)


def compose_probe():
    from PIL import ImageChops, ImageFont
    host = load("host_mountain.png")
    guest = load("guest_mountain.png")
    mist = load("mist_band.png")
    mist_lite = load("mist_band_lite.png")
    base = Image.new("RGBA", (W, H), PAPER)
    d = ImageDraw.Draw(base, "RGBA")
    try:
        font = ImageFont.load_default(size=15)
    except TypeError:     # Pillow < 10.1
        font = ImageFont.load_default()

    def frame(x, y, w, h):
        d.rectangle([x - 1, y - 1, x + w, y + h], outline=PROBE_INK, width=1)

    def ground(x, y, w, h):
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=PROBE_GROUND)

    def label(cy, text):
        d.text((W // 2, int(cy)), text, fill=PROBE_INK, font=font, anchor="mm")

    def mist_middle(img, w, h):
        ox, oy = (MIST_W - w) // 2, (MIST_H - h) // 2
        return img.crop((ox, oy, ox + w, oy + h))

    label(0.075 * H, "PROBE 5.2.1 full")

    # A: the mist's middle over gray into FULL | PARTIAL | the screen; all
    #    three the same when every surface blends 8-bit alpha
    ax, ay, aw, ah, gap = int(W * 0.17), int(H * 0.14), int(W * 0.20), int(H * 0.15), int(W * 0.03)
    for i in range(3):
        x = ax + i * (aw + gap)
        frame(x, ay, aw, ah)
        ground(x, ay, aw, ah)
        base.alpha_composite(mist_middle(mist, aw, ah), dest=(x, ay))
    label(0.325 * H, "A: full | partial | screen")

    # B: the host plane, point sampling | bilinear
    bx, by, bw, bh = int(W * 0.08), int(H * 0.36), int(W * 0.40), int(H * 0.18)
    bx2 = bx + bw + int(W * 0.04)
    host_w = int(round(bh * 340.0 / 260.0))
    inset = int((bw - host_w) / 2.0)
    frame(bx, by, bw, bh)
    frame(bx2, by, bw, bh)
    base.alpha_composite(host.resize((host_w, bh), Image.NEAREST), dest=(bx + inset, by))
    base.alpha_composite(host.resize((host_w, bh), Image.BILINEAR), dest=(bx2 + inset, by))
    label(0.575 * H, "B: point | bilinear")

    # C: mist_band_lite as baked | mist_band at half alpha (the tint)
    cy, ch = int(H * 0.60), int(H * 0.11)
    for x in (bx, bx2):
        frame(x, cy, bw, ch)
        ground(x, cy, bw, ch)
    base.alpha_composite(mist_middle(mist_lite, bw, ch), dest=(bx, cy))
    tinted = mist_middle(mist, bw, ch)
    tinted.putalpha(tinted.getchannel("A").point(lambda v: v * 0x80 // 255))
    base.alpha_composite(tinted, dest=(bx2, cy))
    label(0.745 * H, "C: baked 62% | tint 50%")

    # D: two guests overlapping by half, source-over | multiply
    #    (multiply with an opaque destination: D * (S over white))
    dx, dy, dw, dh = int(W * 0.235), int(H * 0.78), int(W * 0.25), int(H * 0.12)
    dx2 = dx + dw + int(W * 0.03)
    gh = dh * 0.9
    gw = gh * 260.0 / 190.0
    gy = int(round(dy + (dh - gh) / 2.0))
    g = guest.resize((int(round(gw)), int(round(gh))), Image.LANCZOS)
    g_over_white = Image.alpha_composite(Image.new("RGBA", g.size, (255, 255, 255, 255)), g)
    for x in (dx, dx2):
        frame(x, dy, dw, dh)
    for off in (3.0, dw - 3.0 - gw):
        base.alpha_composite(g, dest=(int(round(dx + off)), gy))
        x = int(round(dx2 + off))
        region = base.crop((x, gy, x + g.width, gy + g.height))
        base.paste(ImageChops.multiply(region, g_over_white), (x, gy))
    label(0.93 * H, "D: over | multiply")
    return round_off(base)


def main(argv):
    """compose_preview.py [out.png] [--night] [--no-trace] [--24h] [--time HH:MM]
                          [--data hr.csv [--end YYYY-MM-DDTHH:MM]] [--probe]

    Defaults: 14:42 by day, 22:15 by night, 12-hour clock, the mock window.
    --data composes a real window (see load_data); its clock is the window's
    end in Arizona time unless --time is given, and --end (Arizona local)
    picks which four hours of the file to show. --probe writes the expected
    RENDERER_PLAN §13 probe card instead of the painting."""
    valued = ("--time", "--data", "--end")
    args, opts = [], {}
    it = iter(argv[1:])
    for a in it:
        if a in valued:
            opts[a] = next(it)
        elif not a.startswith("--"):
            args.append(a)
    night = "--night" in argv
    out = args[0] if args else OUT
    if "--probe" in argv:
        compose_probe().save(out)
        print("probe card ->", os.path.abspath(out))
        return
    minute = 22 * 60 + 15 if night else 14 * 60 + 42
    if "--data" in opts:
        end_epoch = None
        if "--end" in opts:
            local = datetime.datetime.strptime(opts["--end"], "%Y-%m-%dT%H:%M")
            end_epoch = int(local.replace(tzinfo=ARIZONA).timestamp())
        history, trace, hr_now, end_epoch, n = load_data(opts["--data"], end_epoch)
        end_local = datetime.datetime.fromtimestamp(end_epoch, ARIZONA)
        minute = end_local.hour * 60 + end_local.minute
        # (The wrist needs 8 raw history samples or it shows the mock; its
        # samples are denser than 5-minute rows, so judge the shape here,
        # not the row count.)
        print("window ends %s Arizona, %d rows, buckets with data %d/16"
              % (end_local.strftime("%Y-%m-%d %H:%M"), n, sum(1 for h in history if h > 0)))
    else:
        history = bucket_history(MOCK, 16)
        trace = [(i / (len(MOCK) - 1.0), norm_hr(v)) for i, v in enumerate(MOCK)]
        hr_now = history[-1]
    if "--no-trace" in argv:
        trace = None
    if "--time" in opts:
        hh, mm = opts["--time"].split(":")
        minute = int(hh) * 60 + int(mm)
    compose(history, minute_of_day=minute, hr_now=hr_now, night=night, trace=trace,
            hour24="--24h" in argv).save(out)
    print("preview ->", os.path.abspath(out))


if __name__ == "__main__":
    main(sys.argv)
