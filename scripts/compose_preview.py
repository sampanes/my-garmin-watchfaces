#!/usr/bin/env python
"""Offline 416x416 mock of the watch composition using the baked layers.

Mirrors the Monkey C draw recipe 1:1 so every layout number proven here is
ported straight into JapaneseInkHeartrateScene.mc as the same fraction.
Writes art/kit_preview.png (circular-masked, on dark surround like the sim).

Planes, back to front (same order on the watch):
    paper -> sun/moon -> horizon -> mist_lite -> masses (library shapes, the
    host last) -> near range -> mist -> fg_left -> fg_right -> paper grain
    -> (View) paper halo -> inscription + seal

The relief (round 6, 2026-11-02): the window's floor is a level far horizon;
every run of buckets standing RUN_MIN over it is a mass with its crest on
the crest scale; a third layer, the near range, fills whichever third of
the screen the masses leave empty, under the half-way line, in front of
them, its feet in the mist. Every mass is a paper cutout, so the horizon
stays straight and hides behind it.

The shape library (2026-11-03): each mass is one whole painted mountain
CHOSEN from scripts/gen_shape_library.py's library (fit_shape), drawn at
its baked size and sunk until its crest sits on the run's peak; it is never
stretched. The library's profile table (scripts/shape_table.json) is the
same numbers the Scene compiles (JapaneseInkHeartrateShapes.mc).

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
HALO_PAD = 27      # scripts/gen_halo.py; the View's HALO_PAD
MOON_INK_HALO = (24, 18, 14, 0x20)   # the moon on day paper (18:00 to night)
MOON_INK_CORE = (24, 18, 14, 0x50)

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


def axis_x(nx):
    """The landscape's time axis: four hours ago .. now -> the full width,
    0..1 of W (2026-11-02, John: the oldest hour may sit under the time and
    the seal, it matters least). Landmarks, the far ridge and the true-HR
    overlay all use it, so a departure of the art from the data is visible
    as such."""
    return min(max(nx, 0.0), 1.0)


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
    return window_from_rows(rows, end_epoch)


def window_from_rows(rows, end_epoch=None):
    """load_data's binning on in-memory (epoch, hr_avg, hr_max) rows."""
    rows = sorted(rows)
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


# ---- the relief: a horizon, masses, a near range (round 5, 2026-11-02) ----
# John on round 3: the far line should have stayed straight and hidden
# behind the mountain; a long effort wants a wide, fat mountain, not a
# zigzag horizon. On round 4: a 45-minute workout is ONE wide peak, not
# two; the little hills are trash; the heart rate wants a THIRD layer, a
# nearer one under the half-way line, drawn to fill empty space and
# balance the picture; the wide mountain's peak and flat part should line
# up with the data's.
FLOOR_RANK = 8           # the floor is the (n // FLOOR_RANK)-th lowest data bucket (3rd of 16)
RUN_MIN = 6.0            # bpm over the floor for a bucket to belong to a run
MASS_MIN = 15.0          # bpm a run's crest must stand over the floor to be a mass at all
GUEST_PROMINENCE = 8.0   # bpm a valley must drop under both summits to split a run in two
BASE_Y = 0.87            # the fidelity test's empty-column height (the 10-29 base)
WIDE_END_TOL = 5.0       # bpm: a run whose ends differ by less leans neither way
FIT_HIGH = 25.0          # px of rise over the floor that doubles a sample's weight
FIT_OVER_TOL = 3.0       # px a shape may stand over the data before it pays extra ...
FIT_OVER_K = 2.0         # ... this much per px: the art must not claim more effort
FOOT_Y = 0.80            # a placed shape's bottom edge must reach this far down (H), under the mist
FIT_SLIDE = (0.0, -12.0, 12.0, -24.0, 24.0)   # px: the apex tried this far from the run's summit
FIT_APEX_K = 1.0         # error per px between the shape's apex and the run's summit (its minute)
NEAR_CREST_Y = 0.60      # the near range's crest, under the lowest horizon (0.58 H)
NEAR_H = 0.21            # its height (fraction of H): the foot under the mist and foreground ...
NEAR_HR_SPAN = 30.0      # ... up by almost half over this many bpm of its third over the floor
NEAR_EMPTY = 0.25        # a third of the screen with less mass cover than this is empty
NEAR_LEAN = (-0.05, 0.03, 0.05)   # the near hills lean outward from their third's center (W)
KNOCKOUT = (0.02, 0.12)  # a mass's paper cutout is opaque where its ink is over 12%
                         # and gone under 2% (paper_backed): the washes are faint


def floor_level(history):
    """The window's floor: the third-lowest of sixteen data buckets, so one
    odd bucket cannot drag it (0.0 for an empty window)."""
    vals = sorted(h for h in history if h > 0.0)
    if not vals:
        return 0.0
    return vals[len(vals) // FLOOR_RANK]


def split_at_valleys(history, lo, hi):
    """[(lo, hi)] for a run of buckets: cut at the deepest interior valley
    that drops GUEST_PROMINENCE under the summits on both sides, again on
    each side. The valley bucket goes to both halves (it is both slopes)."""
    best = None
    for v in range(lo + 1, hi):
        drop = min(max(history[lo:v]), max(history[v + 1:hi + 1])) - history[v]
        if drop >= GUEST_PROMINENCE and (best is None or drop > best[0]):
            best = (drop, v)
    if best is None:
        return [(lo, hi)]
    v = best[1]
    return split_at_valleys(history, lo, v) + split_at_valleys(history, v, hi)


def split_runs(history, floor):
    """Maximal runs of data buckets RUN_MIN over the floor, each split at its
    valleys: [(lo, hi)] in time order."""
    runs, i, n = [], 0, len(history)
    while i < n:
        if history[i] > 0.0 and history[i] - floor >= RUN_MIN:
            j = i
            while j + 1 < n and history[j + 1] > 0.0 and history[j + 1] - floor >= RUN_MIN:
                j += 1
            runs.extend(split_at_valleys(history, i, j))
            i = j + 1
        else:
            i += 1
    return runs


def run_mass(history, floor, lo, hi, denom, trace=None):
    """A run as a mass: its crest heart rate (the highest thinned sample
    inside its buckets, so a five-minute flight of stairs paints its spike
    and not its fifteen-minute average; the highest bucket without a
    trace), its height over the floor, its place on the axis (the centroid
    of its height over the floor, so a plateau sits on its middle whichever
    noisy bucket is its highest) and which end stands higher."""
    peak_hr = max(history[lo:hi + 1])
    if trace:
        x0, x1 = (lo - 0.5) / denom, (hi + 0.5) / denom
        inside = [HR_MIN + norm * (HR_MAX - HR_MIN)
                  for nx, norm in thin_trace(trace) if x0 <= nx <= x1]
        if inside:
            peak_hr = max(peak_hr, max(inside))
    weights = [max(history[i] - floor, 0.0) for i in range(lo, hi + 1)]
    cx = sum(i * w for i, w in zip(range(lo, hi + 1), weights)) / max(sum(weights), 1e-9)
    start = sum(history[lo:lo + 2]) / len(history[lo:lo + 2])
    end = sum(history[max(lo, hi - 1):hi + 1]) / len(history[max(lo, hi - 1):hi + 1])
    return {"lo": lo, "hi": hi, "buckets": hi - lo + 1, "peak_hr": peak_hr,
            "elev": peak_hr - floor, "nx": cx / denom,
            "lean": "end" if end - start > WIDE_END_TOL else "start"}


def measure_apex(name):
    """The crest of a plane as (x frac, y frac) of its bitmap: the topmost
    row with ink, at the middle of its inked columns."""
    im = load(name)
    alpha = im.getchannel("A").load()
    w, h = im.size
    for y in range(h):
        xs = [x for x in range(w) if alpha[x, y] >= 40]
        if xs:
            return (0.5 * (xs[0] + xs[-1])) / w, y / float(h)
    return 0.5, 0.0


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


def paste_at(base, img, x, y):
    """drawBitmap(x, y): source-over at 1:1, clipped to the screen"""
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    layer.paste(img, (int(x), int(y)))
    return Image.alpha_composite(base, layer)


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
        return self.draw_left(img, text, cx - adv / 2.0, cy - self.line_h / 2.0, rgb)

    def draw_left(self, img, text, pen, top, rgb):
        """dc.drawText(pen, top, ..., LEFT): the line box's top-left at (pen, top)"""
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


CREST_LO_Y = 0.58        # the crest scale: 45 bpm sits here (fraction of H) ...
CREST_HI_Y = 0.26        # ... and 160 bpm here (round 3: 1.7x the 10-29 scale)

# The near range and the horizon by role. "apex" is the crest (x frac, y
# frac) inside the bitmap, measured from the PNG (measure_apex) the first
# time it is used. The masses come from the shape library (shape_table).
PLANES = {
    "near_hill": {"name": "near_hill", "aspect": 320.0 / 160.0, "apex": None},
    "near_hill2": {"name": "near_hill2", "aspect": 320.0 / 160.0, "apex": None},
    "horizon": {"name": "horizon", "aspect": 416.0 / 56.0, "apex": None},
}


def plane(role):
    p = PLANES[role]
    if p["apex"] is None:
        p["apex"] = measure_apex(p["name"] + ".png")
    return p


TRACE_COLS = 58          # fillPolygon takes at most 64 points (DC_PART1)
TRACE_FLOOR_PAD = 0.02   # the wash's floor sits this far under the lowest sample


def crest_y(h_norm):
    """The painting's one vertical scale, for a landmark height (0.35..1.0,
    height_for_norm): the far ridge, every crest and the overlay sit on
    it, so one height means one heart rate everywhere in the painting."""
    norm = (h_norm - 0.35) / 0.65
    return H * (CREST_LO_Y + (CREST_HI_Y - CREST_LO_Y) * norm)


def trace_y(norm):
    return crest_y(height_for_norm(norm))


def thin_trace(trace, cols=TRACE_COLS):
    """At most `cols` samples, each group reduced to its HIGHEST sample so a
    peak survives the thinning (storeTrace in the Scene)."""
    if len(trace) <= cols:
        return list(trace)
    stride = (len(trace) + cols - 1) // cols
    return [max(trace[i:i + stride], key=lambda t: t[1]) for i in range(0, len(trace), stride)]


_MASS_CACHE = {}


def paper_backed(img, night):
    """A mass as a cutout: its ink over its own paper (black paper at
    night), so whatever stands behind it, the horizon or a farther mass, is
    hidden the way a nearer mountain is painted over a gap left in the
    farther one. The cutout's alpha ramps from KNOCKOUT[0] to [1] of the
    ink's (a wash body is 20% ink and must still hide the line), and the
    color is chosen so that over bare paper every pixel is unchanged. The
    port bakes this into the plane PNGs (or draws a paper-colored
    silhouette polygon first)."""
    import numpy as np
    a = np.asarray(img.getchannel("A"), dtype=float) / 255.0
    rgb = np.asarray(img.convert("RGB"), dtype=float)
    paper = np.array((0.0, 0.0, 0.0) if night else PAPER[:3], dtype=float)
    k0, k1 = KNOCKOUT
    a2 = np.clip((a - k0) / (k1 - k0), 0.0, 1.0)
    share = np.clip(np.where(a2 > 0.0, a / np.maximum(a2, 1e-6), 0.0), 0.0, 1.0)[..., None]
    rgb2 = rgb * share + paper * (1.0 - share)
    out = np.dstack([rgb2, a2 * 255.0]).round().astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def mass_image(name, night, flip=False):
    """The cutout of a plane, mirrored when asked (the wide mountain with
    its summit on the right: drawBitmap2 with a flip, or a baked twin)."""
    key = (name, night, flip)
    if key not in _MASS_CACHE:
        img = paper_backed(load(name + ("_night" if night else "") + ".png"), night)
        if flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        _MASS_CACHE[key] = img
    return _MASS_CACHE[key]


def paint_horizon(base, layout, night):
    """The far range as a level line at the window's floor, full width, its
    crest row on the crest scale. Nothing on an empty window."""
    if layout["horizon_y"] is None:
        return base
    p = plane("horizon")
    img = load(p["name"] + ("_night" if night else "") + ".png")
    w, h = img.size
    return paste_scaled(base, img, 0, layout["horizon_y"] - p["apex"][1] * h, w, h)


def paint_masses(base, layout, night):
    """The masses in their depth order (mid_plane_layout), each its library
    shape's baked cutout at its own size. scripts/fidelity_test.py paints
    the scored skyline with paint_horizon and this."""
    for m in layout["masses"]:
        base = paste_scaled(base, shape_image(m["plane"], night), *m["rect"])
    return base


def paint_near(base, layout, night):
    """The near range, in front of the masses and under the horizon."""
    for n in layout["near"]:
        base = paste_scaled(base, mass_image(n["plane"], night), *n["rect"])
    return base


def draw_trace(base, trace, crests, night):
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
    for cx, cy in crests:
        d.ellipse([(cx - 4) * S, (cy - 4) * S, (cx + 4) * S, (cy + 4) * S], fill=edge)
    layer = layer.resize((W, H), Image.LANCZOS)
    return Image.alpha_composite(base, layer)


_SHAPES = {}


def shape_table():
    """The shape library's profile table (scripts/gen_shape_library.py)."""
    if "t" not in _SHAPES:
        import json
        with open(os.path.join(HERE, "shape_table.json")) as f:
            _SHAPES["t"] = json.load(f)
    return _SHAPES["t"]


def shape_image(name, night):
    key = ("img", name, night)
    if key not in _SHAPES:
        _SHAPES[key] = load(name + "_cut" + ("_night" if night else "") + ".png")
    return _SHAPES[key]


def fit_samples(history, trace):
    """The heart rate the fit scores against, as (x px, y px) on the crest
    scale: the thinned trace the Scene keeps, or the buckets without one."""
    if trace:
        return [(W * axis_x(nx), trace_y(n)) for nx, n in thin_trace(trace)]
    denom = float(len(history) - 1)
    return [(W * axis_x(i / denom), crest_y(height_for_hr(v)))
            for i, v in enumerate(history) if v > 0.0]


def fit_cost(py, y, floor_y):
    """What one sample costs when the top of the ink there is py: the
    distance to the data, weighted up on high ground, and more where the
    ink stands over the data."""
    rise = floor_y - y
    wgt = 1.0 + (rise / FIT_HIGH if rise > 0.0 else 0.0)
    diff = py - y
    c = abs(diff) * wgt
    if diff < -FIT_OVER_TOL:
        c += FIT_OVER_K * (-FIT_OVER_TOL - diff)
    return c


def fit_shape(samples, base, run_x0, run_x1, sx, cy, floor_y):
    """The library shape that best paints one run: (error, index, left).

    Every shape stands with its crest on the run's peak (cy) and is tried
    with its apex at the run's summit (sx) and FIT_SLIDE either side of it,
    and with its middle over the run's middle; FIT_APEX_K per px between
    apex and summit keeps the painted summit on its minute. Its error is
    what it changes: over every sample under it, the cost of the ink's top
    being the shape's profile instead of the far bank (fit_cost), so a long
    shoulder laid over rest pays for itself. A shape whose bottom edge would
    show above the mist (FOOT_Y) is not a candidate. Ties keep the earlier.
    samples run left to right; base[j] is fit_cost(floor_y, y_j, floor_y),
    the cost of the far bank alone there."""
    table = shape_table()
    k_cols = table["k"]
    best = None
    for i, sh in enumerate(table["shapes"]):
        top0 = cy - sh["ay"]
        if top0 + sh["h"] < FOOT_Y * H:
            continue
        lefts = [sx + dx - sh["ax"] for dx in FIT_SLIDE]
        lefts.append(0.5 * (run_x0 + run_x1) - 0.5 * sh["w"])
        for left in lefts:
            err = FIT_APEX_K * abs(left + sh["ax"] - sx)
            for j, (x, y) in enumerate(samples):
                d = x - left
                if d >= sh["w"]:
                    break
                if d >= 0.0:
                    t = sh["top"][int(d * k_cols / sh["w"])]
                    if t >= 0 and top0 + t < floor_y:
                        err += fit_cost(top0 + t, y, floor_y) - base[j]
            if best is None or err < best[0]:
                best = (err, i, left)
    return best


def mid_plane_layout(history, trace=None):
    """The relief for a window: {"floor": bpm, "horizon_y": px or None,
    "masses": [{"rect": (x, y, w, h), "crest": (x, y), "plane": name,
    "shape": index, "vis": (x0, x1), "host": bool, "run": (lo, hi)}] in
    draw order, "near": [{"plane": name, "rect": ...}]}, plus
    "host"/"host_crest"/"host_plane" and "guest"/... for the tallest and
    second-tallest mass (None without one). compose() and
    scripts/fidelity_test.py both use it, so the scored skyline is the
    painted one.

    Each run standing MASS_MIN over the floor gets the library shape that
    fits it best (fit_shape), crest on the run's peak, drawn at its baked
    size. "vis" is the stretch of the screen where the shape stands over
    the far bank (kept for the record; the near range's cover still counts
    the middle 70% of each mass's bitmap, as in round 6). Draw order: the other masses first (the taller farther),
    the host (the highest crest) last. The near range then takes any third
    of the screen the masses leave empty (both outer thirds when all three
    are), its foot under the mist."""
    floor = floor_level(history)
    out = {"floor": floor, "horizon_y": None, "masses": [], "near": [],
           "host": None, "host_crest": None, "host_plane": None,
           "guest": None, "guest_crest": None, "guest_plane": None}
    if floor <= 0.0:
        return out
    floor_y = crest_y(height_for_hr(floor))
    out["horizon_y"] = floor_y
    denom = len(history) - 1
    bucket_px = W / float(denom)
    runs = [run_mass(history, floor, lo, hi, denom, trace) for lo, hi in split_runs(history, floor)]
    runs = [r for r in runs if r["elev"] >= MASS_MIN]
    host = max(runs, key=lambda r: r["peak_hr"]) if runs else None
    samples = fit_samples(history, trace)
    base = [fit_cost(floor_y, y, floor_y) for _, y in samples]
    table = shape_table()
    k_cols = table["k"]
    masses = []
    for r in runs:
        run_x0, run_x1 = (r["lo"] - 0.5) * bucket_px, (r["hi"] + 0.5) * bucket_px
        cy = crest_y(height_for_hr(r["peak_hr"]))
        # the run's summit: its highest sample inside the run, else its centroid
        sx, best_y = axis_x(r["nx"]) * W, None
        for x, y in samples:
            if run_x0 <= x <= run_x1 and (best_y is None or y < best_y):
                sx, best_y = x, y
        fit = fit_shape(samples, base, run_x0, run_x1, sx, cy, floor_y)
        if fit is None:
            continue
        _, i, left = fit
        sh = table["shapes"][i]
        top0 = cy - sh["ay"]
        cols = [k for k in range(k_cols) if sh["top"][k] >= 0 and top0 + sh["top"][k] < floor_y]
        vis = ((left + cols[0] * sh["w"] / float(k_cols), left + (cols[-1] + 1) * sh["w"] / float(k_cols))
               if cols else (left + sh["ax"], left + sh["ax"]))
        masses.append({"rect": (left, top0, sh["w"], sh["h"]), "crest": (left + sh["ax"], cy),
                       "plane": sh["name"], "shape": i, "vis": vis, "flip": False,
                       "host": r is host, "run": (r["lo"], r["hi"])})
    # depth: the other masses first (the taller farther), the host last
    masses.sort(key=lambda m: (m["host"], m["crest"][1]))
    out["masses"] = masses

    # the near range: a third of the screen the masses leave empty gets a
    # near hill, its height nudged by that third's heart rate over the floor
    thirds = [(k * W / 3.0, (k + 1) * W / 3.0) for k in range(3)]
    cover = []
    for a, b in thirds:
        covered = 0.0
        for m in masses:
            x, _, w, _ = m["rect"]
            covered += max(0.0, min(b, x + 0.85 * w) - max(a, x + 0.15 * w))
        cover.append(min(covered / (b - a), 1.0))
    empty = [k for k in range(3) if cover[k] < NEAR_EMPTY]
    if len(empty) == 3:
        empty = [0, 2]
    for k in empty:
        a, b = thirds[k]
        lo_b, hi_b = int(round(a / bucket_px)), int(round(b / bucket_px))
        vals = [history[i] for i in range(max(0, lo_b), min(len(history), hi_b + 1))
                if history[i] > 0.0]
        over = max(0.0, sum(vals) / len(vals) - floor) if vals else 0.0
        p = plane("near_hill2" if k == 1 else "near_hill")
        h = NEAR_H * H * (0.85 + 0.45 * min(over / NEAR_HR_SPAN, 1.0))
        w = p["aspect"] * h
        cx = 0.5 * (a + b) + NEAR_LEAN[k] * W
        out["near"].append({"plane": p["name"],
                            "rect": (cx - p["apex"][0] * w, NEAR_CREST_Y * H - p["apex"][1] * h, w, h)})

    # the two tallest, for the fidelity test's peak timing and crest dots
    ranked = sorted(masses, key=lambda m: m["crest"][1])
    for key, m in zip(("host", "guest"), ranked):
        out[key] = m["rect"]
        out[key + "_crest"] = m["crest"]
        out[key + "_plane"] = m["plane"]
    return out


def compose(history, minute_of_day=14 * 60 + 42, hr_now=None, night=False, trace=None,
            hour24=False, overlay=True):
    """night: the moonlit negative set (pale ink on black paper, no grain).
    trace: [(nx, norm_hr)] raw samples (the relief is fitted to them, as the
    Scene fits its stored trace), or None. overlay: draw the true-HR overlay
    over the painting (the watch's "True HR line" setting)."""
    sfx = "_night" if night else ""
    fg_l = load("fg_left%s.png" % sfx)
    fg_r = load("fg_right%s.png" % sfx)
    mist = load("mist_band%s.png" % sfx)
    mist_lite = load("mist_band_lite%s.png" % sfx)
    grain_p = os.path.join(DRAW, "paper_grain.png")
    grain = Image.open(grain_p).convert("RGBA") if os.path.exists(grain_p) and not night else None

    layout = mid_plane_layout(history, trace)
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
    if moon and not night:
        # 18:00 until the night window: the moon on day paper, in pale ink
        # (the moonlit cream disk is invisible on cream paper)
        halo, core = MOON_INK_HALO, MOON_INK_CORE
    elif moon:
        halo, core = (240, 235, 220, 0x30), (248, 244, 232, 0xC0)
    else:
        halo, core = (200, 70, 50, 0x40), (175, 38, 28, 0xCC)
    base = blend_ellipse(base, sx, sy, r_halo, halo)
    base = blend_ellipse(base, sx, sy, r_core, core)

    # 1. the horizon: the far range as a level line at the window's floor
    #    (round 4, 11-02). Drawn first; every mass is a cutout over it.
    base = paint_horizon(base, layout, night)

    # 2. light mist between far and mid planes
    base = paste_scaled(base, mist_lite, -0.10 * W, 0.50 * H, 1.20 * W, 0.17 * H)

    # 3. the masses: the library shapes, the host last (none on a flat day)
    base = paint_masses(base, layout, night)

    # 4. the near range (round 5): a near hill in each third of the screen
    #    the masses leave empty, under the half-way line, to balance the
    #    picture; both outer thirds on a flat day
    base = paint_near(base, layout, night)

    # 5. full mist dissolving the mid-plane bodies and the near range's
    #    feet: raised in round 6 to begin just under the near crests, so the
    #    masses show their upper bodies and the depth order reads
    base = paste_scaled(base, mist, -0.03 * W, 0.66 * H, 1.06 * W, 0.22 * H)

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
    if trace is not None and overlay:
        base = draw_trace(base, trace, [m["crest"] for m in layout["masses"]], night)

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
    seal = int(W * 0.085)
    sx0, sy0 = int(0.22 * W) - seal // 2, int(0.465 * H)
    # Where each glyph lands, in the View's integer maths: [font, glyph, pen
    # x, line top], the ink drawn LEFT / TOP there, the minutes one glyph at
    # a time from a pen centred on the pair.
    cx = int(0.22 * W)
    placed = []
    for i, g in enumerate(glyphs):
        placed.append((kanji_font, g, cx - kanji_font.glyphs[g]["xadvance"] // 2,
                       bottom - (len(glyphs) - 1 - i) * pitch - kanji_font.line_h // 2))
    mins = "%02d" % (minute_of_day % 60)
    pen = cx - sum(ink_font.glyphs[c]["xadvance"] for c in mins) // 2
    for c in mins:
        placed.append((ink_font, c, pen, int(0.375 * H) - ink_font.line_h // 2))
        pen += ink_font.glyphs[c]["xadvance"]
    # the paper halo first (scripts/gen_halo.py): one bitmap per glyph, its
    # ink glyph's cell grown by HALO_PAD on every side, so the painting
    # fades back to bare paper around each glyph and the seal
    sfx = "_night" if night else ""
    for font, g, x, top in placed:
        name = ("halo_k%04x" % ord(g)) if font is kanji_font else ("halo_d" + g)
        base = paste_at(base, load(name + sfx + ".png"), x - HALO_PAD, top - HALO_PAD)
    base = paste_at(base, load("halo_seal" + sfx + ".png"), sx0 - HALO_PAD, sy0 - HALO_PAD)
    for font, g, x, top in placed:
        base = font.draw_left(base, g, x, top, ink)
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
    # the Scene's probe uses two library shapes since 11-03 (the round-6
    # planes left the watch)
    host = load("shape_peak_300_cut.png")
    guest = load("shape_spire_180_cut.png")
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

    # B: the 300 px peak, point sampling | bilinear
    bx, by, bw, bh = int(W * 0.08), int(H * 0.36), int(W * 0.40), int(H * 0.18)
    bx2 = bx + bw + int(W * 0.04)
    host_w = int(round(bh * 300.0 / 300.0))
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

    # D: two spires overlapping by half, source-over | multiply
    #    (multiply with an opaque destination: D * (S over white))
    dx, dy, dw, dh = int(W * 0.235), int(H * 0.78), int(W * 0.25), int(H * 0.12)
    dx2 = dx + dw + int(W * 0.03)
    gh = dh * 0.9
    gw = gh * 180.0 / 300.0
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
    if "--time" in opts:
        hh, mm = opts["--time"].split(":")
        minute = int(hh) * 60 + int(mm)
    compose(history, minute_of_day=minute, hr_now=hr_now, night=night, trace=trace,
            hour24="--24h" in argv, overlay="--no-trace" not in argv).save(out)
    print("preview ->", os.path.abspath(out))


if __name__ == "__main__":
    main(sys.argv)
