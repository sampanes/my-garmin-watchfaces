#!/usr/bin/env python
"""Offline 416x416 mock of the watch composition using the baked layers.

Mirrors the Monkey C draw recipe 1:1 so every layout number proven here is
ported straight into JapaneseInkHeartrateScene.mc as the same fraction.
Writes art/kit_preview.png (circular-masked, on dark surround like the sim).

Planes, back to front (same order on the watch):
    paper -> sun/moon -> horizon -> mist_lite -> masses (library shapes, the
    host last) -> near range -> mist -> foreground -> paper grain
    -> (View) paper halo -> inscription + seal

The relief (round 6, 2026-11-02): the window's floor is a level far horizon;
every run of buckets standing RUN_MIN over it is a mass with its crest on
the crest scale; a third layer, the near range, fills whichever third of
the screen the masses leave empty, under the half-way line, in front of
them, its feet in the mist. Every mass is a paper cutout, so the horizon
stays straight and hides behind it.

The shape library (2026-11-03; the 24 ChatGPT mountains since 2026-11-05):
each mass is one whole painted mountain CHOSEN from
scripts/gen_shape_library.py's library (fit_shape), drawn at its baked
height, its width stretched to the run (FIT_STRETCH), and sunk until its
crest sits on the run's peak. The library's profile table
(scripts/shape_table.json) is the same numbers the Scene compiles
(JapaneseInkHeartrateShapes.mc).

The foreground (2026-11-05): one whole-face painting from the art sheets,
baked by scripts/bake_foregrounds.py and chosen by the month, the day and
the watch's "foreground" setting (foreground_index), in place of the two
script-painted foreground masses.

The props (2026-11-05, evening): small pieces of the ChatGPT prop sheets
(scripts/bake_props.py), each shown by one rule (prop_rules) so a prop
always means something: the sun and the moon by its phase on the arc, geese
for the step goal, a village in an empty window, a hiker on a
workout's summit, a lantern for a low battery.

The fixed planes (2026-11-05, later): the far range (horizon.png), the two
mist bands and the near hills are pieces of the ChatGPT strip sheet, baked
by scripts/bake_planes.py (the near hills as paper cutouts, the mist
re-toned to paper), the last script-painted art gone but the grain. The
mock places them as before; their crests are measured from the PNGs here
and written into the Scene by the bake.

The inscription uses the baked BMFont pairs in resources/fonts (read from the
.fnt exactly as the resource compiler reads them), so the preview's digits
are the device's digits. --night composes the moonlit negative set (what the
night-mode hours show); the true-HR overlay is on unless --no-trace.
"""

import csv
import datetime
import json
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
FIT_STRETCH = (0.67, 1.5)   # a shape's width is stretched to its run's width, within this
NEAR_CREST_Y = 0.60      # the near range's crest, under the lowest horizon (0.58 H)
NEAR_H = 0.21            # its height (fraction of H): the foot under the mist and foreground ...
NEAR_HR_SPAN = 30.0      # ... up by almost half over this many bpm of its third over the floor
NEAR_EMPTY = 0.25        # a third of the screen with less mass cover than this is empty
NEAR_LEAN = (-0.05, 0.03, 0.05)   # the near hills lean outward from their third's center (W)
TREE_MAX = 3             # ridge trees per window, at most ...
TREE_NEED = 9.0          # ... each where the data stands this many px over the ridge ...
TREE_OVER = 3.0          # ... the tallest baked size within this many px over the data ...
TREE_GAP = 16.0          # ... this far from another tree (px) ...
TREE_SINK = 2            # ... its foot this many px into the ridge


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


# ---- the props (2026-11-05): one rule each, bake_props.py bakes the art ----

SYNODIC = 29.530588853     # days from new moon to new moon
NEW_MOON_EPOCH = 947182440 # a new moon: 2000-01-06 18:14 UTC
MOON_NEW = 1.85            # days either side of new moon with no moon drawn ...
MOON_FULL = 1.85           # ... and either side of full with the full moon
GEESE_Y = 0.21             # the geese's middle (H), on the side away from the sun/moon:
GEESE_X = (0.68, 0.45)     # here (W) when the sun/moon is on the left half, else here
VILLAGE_X = 0.50           # a quiet window's village, its middle (W; John, 11-06:
                           # 230 px wide, a click and a half left of 0.56) ...
VILLAGE_FOOT = 0.92        # ... its foot here (H), in the ground layer
CLOUDS_XY = (0.64, 0.145)  # a cloudy sky's cloud bank, its middle (W, H), clear of the time column
# the cloud over the sun by level (1-3): its painting and its middle's
# offset (W, H) from the sun's middle (round 11, 11-06)
CLOUD_OVER = {1: ("cloud_wisp", 0.024, 0.043), 2: ("cloud_band", 0.014, 0.029),
              3: ("cloud_bands2", 0.010, 0.010)}
CLOUD_SPILL = 0.40         # a cloud over the sun may fade this share of its width past the rim ...
                           # ... and never reaches into the time column (INSCRIPTION_BOX's x)
MOON_MIST_DROP = 0.015     # the moon behind cloud: its painting's middle this far (H) under the arc
INSCRIPTION_BOX = (0.36, 0.60)   # the time column and seal with their halos: x and y
                                 # under these (W, H); no prop lands there
HIKER_SINK = 7             # px the hiker sinks under the summit: he stands just below it, his ground hidden
# the low-battery lantern stands where John placed it on each foreground
# (spot_table.json, scripts/bake_spots.py), just behind the foreground
BATTERY_LOW = 30.0         # percent under which the lantern shows
SEAL_WORK = 30.0           # bpm over the resting baseline that turns the seal rectangular ...
# The seal digits' nudge per position (x, y px), on top of their baked
# crookedness, counted across both lines of the date (the View's
# SEAL_NUDGE_X/Y); and where the date's two lines center, from the seal's
# center (month over day).
SEAL_NUDGE = [(0, -1), (0, 1), (-1, 0), (0, 2)]
SEAL_DATE_DY = (-8, 9)
# The weather (scripts/bake_weather.py): one whole-face painting behind the
# grasses. Precipitation replaces the sun or moon; wind does not.
WX_PRECIP = ("rain_light", "rain", "storm", "snow")
WIND_LEAVES = 8.0          # m/s over which the leaves blow without a "windy" forecast
# Toybox.Weather condition numbers, by the Scene's weatherForCondition sets
WX_CONDITIONS = {
    "storm": (6, 12, 32, 41, 42),                     # thunderstorms, scattered, tornado, hurricane, tropical storm
    "snow": (4, 7, 16, 17, 18, 19, 21, 34, 48, 50, 51),   # snow, wintry mix, light/heavy, rain-snow, ice, flurries, sleet, ice-snow
    "rain": (3, 10, 15, 26, 49),                      # rain, hail, heavy rain, heavy showers, freezing rain
    "rain_light": (11, 13, 14, 24, 25, 31),           # scattered showers, unknown precip, light rain, light showers, showers, drizzle
    "wind": (5, 36),                                  # windy, squall
}


# the sky's cloud level by Toybox.Weather condition, the Scene's
# cloudLevel: 4 cloudy (or a chance of rain or snow), 3 mostly cloudy, 2
# partly cloudy, 1 thin clouds, partly clear, mist, haze or smoke; else 0
CLOUD_LEVELS = {
    4: (20, 27, 28, 43, 44, 45, 46, 47),   # cloudy, chance of / cloudy chance of
    3: (2,),                               # mostly cloudy
    2: (1,),                               # partly cloudy
    1: (22, 52, 8, 9, 29, 39, 33, 30, 35, 37, 38),   # partly clear, thin clouds, fog, hazy, mist, haze, smoke, dust, sand, sandstorm, ash
}


def cloud_level(condition):
    """The sky's cloud level, 0..4, for a Toybox.Weather condition."""
    for level, conds in CLOUD_LEVELS.items():
        if condition in conds:
            return level
    return 0


def cloud_x(cx, cy, w):
    """A cloud's middle x, moved off the time column and in from the rim
    (the Scene's cloudX)."""
    import math
    r = W / 2.0
    lo = INSCRIPTION_BOX[0] * W + w / 2.0
    hi = r + math.sqrt(max(0.0, r * r - (cy - r) ** 2)) - CLOUD_SPILL * w
    if lo > hi:
        return (lo + hi) / 2.0
    return min(max(cx, lo), hi)


def arc_t(minute, sunrise=360, sunset=1080):
    """(night, t): whether it is night (sunset to sunrise) and where the
    sun or moon is on its arc, 0..1 west to east (the Scene's arcT)."""
    if sunrise <= minute < sunset:
        return False, (minute - sunrise) / float(sunset - sunrise)
    into = minute - sunset if minute >= sunset else minute + 1440 - sunset
    return True, into / float(1440 - (sunset - sunrise))


def weather_veil(condition, wind_ms=None):
    """Which weather painting shows for a Toybox.Weather condition and wind
    speed (m/s), or None: the Scene's weatherForCondition plus its wind
    rule. Order matters: a storm over snow over rain over light rain."""
    for name in ("storm", "snow", "rain", "rain_light", "wind"):
        if condition in WX_CONDITIONS[name]:
            return name
    if wind_ms is not None and wind_ms >= WIND_LEAVES:
        return "wind"
    return None


SEAL_HYST = 8.0            # ... and back to the oval this far under that (the watch only)


def seal_shape(hr_now, baseline):
    """The seal under the time: "seal_rect" once the HR stands SEAL_WORK
    over the baseline (working), else "seal_oval" (resting). baseline is the
    profile's resting HR, or the window's floor without one. The Scene's
    sealWork, which also holds the rectangle until SEAL_HYST under the line."""
    if hr_now is not None and baseline and hr_now >= baseline + SEAL_WORK:
        return "seal_rect"
    return "seal_oval"


def moon_age(epoch):
    """The days since the last new moon (mean lunation; within about half a day)."""
    return ((epoch - NEW_MOON_EPOCH) / 86400.0) % SYNODIC


def moon_prop(epoch):
    """The moon's prop for a moment: None near new moon, "moon_full" near
    full, else the waxing or waning crescent. The Scene's moonProp."""
    age = moon_age(epoch)
    half = SYNODIC / 2.0
    if age < MOON_NEW or age > SYNODIC - MOON_NEW:
        return None
    if abs(age - half) <= MOON_FULL:
        return "moon_full"
    return "moon_waxing" if age < half else "moon_waning"


_PROPS = {}


def prop_table():
    if not _PROPS:
        with open(os.path.join(HERE, "prop_table.json")) as f:
            _PROPS.update(json.load(f))
    return _PROPS


def prop_image(name, night):
    return load("prop_%s%s.png" % (name, "_night" if night else ""))


def spot_table():
    """scripts/spot_table.json (bake_spots.py): each piece's spot per foreground."""
    if "spots" not in _SHAPES:
        with open(os.path.join(HERE, "spot_table.json")) as f:
            _SHAPES["spots"] = json.load(f)
    return _SHAPES["spots"]


def prop_rules(layout, minute_of_day, epoch, day, steps_met, battery, hide=(), fg=0,
               sunrise=360, sunset=1080, cloud=0, workout=True, notified=False):
    """Which props show, and where: {layer: [(name, x, y)]} with (x, y) the
    bitmap's top-left on the 416 face. Layers: "sky" with the sun or moon,
    "valley" after the far range, "summit" and "air" after the masses (the
    hiker on the highest workout summit clear of INSCRIPTION_BOX),
    "ground" after the foreground. hide: the pieces turned off on the
    watch ("lantern", "geese", "hiker", "village"). sunrise, sunset (minutes) set the arcs; cloud: the sky's cloud
    level (cloud_level): by day the sun under one painting per level 1-3,
    the bank alone at 4; by night the moon veiled (1-2) or hidden (3) in
    its own painting, the bank alone at 4 (one painting per level, never
    a cloud copied: John, 11-06); workout: a
    recorded workout overlaps the window (the hiker); notified: unread
    notifications (the swallow). The Scene's placeProps is the same."""
    import math
    out = {"sky": [], "valley": [], "summit": [], "air": [], "ground": []}
    size = {p["name"]: (p["w"], p["h"]) for p in prop_table()["props"]}
    moon, t = arc_t(minute_of_day, sunrise, sunset)
    sx = int(W * 0.20 + W * 0.60 * t)
    sy = int(H * 0.14 - math.sin(t * math.pi) * H * 0.06)
    cel = moon_prop(epoch) if moon else "sun"
    cloud = cloud or 0
    if cloud >= 4:
        w, h = size["cloud_bank"]
        out["sky"].append(("cloud_bank", int(CLOUDS_XY[0] * W - w / 2.0), int(CLOUDS_XY[1] * H - h / 2.0)))
    elif moon and cel is not None and cloud > 0:
        cel = "%s_%s" % (cel, "hidden" if cloud >= 3 else "veil")
        w, h = size[cel]
        out["sky"].append((cel, sx - w // 2, int(sy + MOON_MIST_DROP * H - h / 2.0)))
    elif cel is not None:
        w, h = size[cel]
        out["sky"].append((cel, sx - w // 2, sy - h // 2))
        if not moon and cloud > 0:
            name, dx, dy = CLOUD_OVER[cloud]
            w, h = size[name]
            cy = sy + dy * H
            cx = cloud_x(sx + dx * W, cy, w)
            out["sky"].append((name, int(cx - w / 2.0), int(cy - h / 2.0)))
    if steps_met and "geese" not in hide:
        w, h = size["geese"]
        gx = GEESE_X[0] if sx < W / 2 else GEESE_X[1]
        out["air"].append(("geese", int(gx * W - w / 2), int(GEESE_Y * H - h / 2)))
    if layout["horizon_y"] is not None and not layout["masses"] and "village" not in hide:
        w, h = size["village"]
        out["ground"].append(("village", int(VILLAGE_X * W - w / 2), int(VILLAGE_FOOT * H - h)))
    if notified and "swallow" not in hide:
        w, h = size["swallow"]
        x, foot = spot_table()["swallow"]
        out["air"].append(("swallow", int(x - w / 2.0), int(foot - h)))
    # the hiker: while a recorded workout overlaps the window, on the
    # highest summit clear of the time column
    w, h = size["hiker"]
    for m in ([] if "hiker" in hide or not workout else sorted(layout["masses"], key=lambda m: m["crest"][1])):
        cx, cy = m["crest"]
        x, y = int(cx - w / 2), int(cy - h + HIKER_SINK)
        if x < INSCRIPTION_BOX[0] * W and y < INSCRIPTION_BOX[1] * H:
            continue
        out["summit"].append(("hiker", x, y))
        break
    if battery < BATTERY_LOW and "lantern" not in hide:
        w, h = size["lantern"]
        x, foot = spot_table()["spots"][fg]["lantern"]
        out["ground"].append(("lantern", int(x - w / 2.0), int(foot - h)))
    return out


def paint_props(base, placed, night):
    for name, x, y in placed:
        base = paste_at(base, prop_image(name, night), x, y)
    return base


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

    def draw_nudged(self, img, text, cx, cy, rgb, first=0):
        """The seal's text as the View draws it: centered on (cx, cy) in
        integer maths, one glyph at a time, each moved by SEAL_NUDGE for its
        position (counted from first)."""
        pen = int(cx) - sum(self.glyphs[c]["xadvance"] for c in text) // 2
        top = int(cy) - self.line_h // 2
        for i, c in enumerate(text):
            dx, dy = SEAL_NUDGE[(first + i) % len(SEAL_NUDGE)]
            img = self.draw_left(img, c, pen + dx, top + dy, rgb)
            pen += self.glyphs[c]["xadvance"]
        return img

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

# The near range and the horizon by role (scripts/bake_planes.py bakes
# them). "apex" is the crest (x frac, y frac) inside the bitmap, measured
# from the PNG (measure_apex) the first time it is used; the bake writes the
# same numbers into the Scene. The masses come from the shape library
# (shape_table).
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
    """The near range, in front of the masses and under the horizon: the
    baked cutouts (scripts/bake_planes.py) at their own size."""
    for n in layout["near"]:
        base = paste_scaled(base, load(n["plane"] + ("_night" if night else "") + ".png"), *n["rect"])
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


def foreground_table():
    """scripts/foreground_table.json, as bake_foregrounds.py wrote it."""
    if "fg" not in _SHAPES:
        with open(os.path.join(HERE, "foreground_table.json")) as f:
            _SHAPES["fg"] = json.load(f)
    return _SHAPES["fg"]


def foreground_index(month=None, day=None, scene=0):
    """Which baked foreground shows: the season from the month (Dec-Feb
    winter, Mar-May spring, Jun-Aug summer, Sep-Nov autumn) unless scene
    names one (1..5: spring, summer, autumn, winter, pass), and the painter
    alternating with the day of the month (even: ChatGPT, odd: Gemini). The
    Scene's foregroundIndex is the same arithmetic. Today's month and day
    by default."""
    today = datetime.date.today()
    month = today.month if month is None else month
    day = today.day if day is None else day
    t = foreground_table()
    season = scene - 1 if 1 <= scene <= len(t["seasons"]) else ((month % 12) // 3 + 3) % 4
    return season * t["painters"] + day % t["painters"]


def wind_painting(weather, fg):
    """The wind's painting for foreground fg's season (John, 11-06): dry
    leaves in winter, cherry petals in spring, the maples otherwise; any
    other weather unchanged. The Scene's seasonalWeather."""
    if weather != "wind":
        return weather
    season = fg // foreground_table()["painters"]
    return {0: "wind_spring", 3: "wind_winter"}.get(season, "wind")


def foreground_image(i, night):
    """The baked foreground i (resources/drawables/fg_*.png)."""
    key = ("fg", i, night)
    if key not in _SHAPES:
        name = foreground_table()["foregrounds"][i]["name"]
        _SHAPES[key] = load(name + ("_night" if night else "") + ".png")
    return _SHAPES[key]


def tree_table():
    """The ridge trees' size table (scripts/bake_trees.py)."""
    if "trees" not in _SHAPES:
        import json
        with open(os.path.join(HERE, "tree_table.json")) as f:
            _SHAPES["trees"] = json.load(f)
    return _SHAPES["trees"]


def tree_image(i, k, night):
    t = tree_table()
    return load("tree_%s_%d%s.png" % (t["trees"][i]["name"], t["sizes"][k], "_night" if night else ""))


def place_trees(masses, samples, floor_y):
    """Up to TREE_MAX ridge trees: [{"tree": i, "size": k, "pos": (x, y)}].

    Where a sample of the data stands TREE_NEED or more over the painted
    ridge (the topmost mass profile there, from the shape table, as the
    watch knows it), a tree stands on the ridge: the biggest, the most
    over first, TREE_GAP apart; its baked height is the tallest that stays
    within TREE_OVER of the data. Which tree is (sample index * 3 + pick)
    mod the tree count, so a window always grows the same trees."""
    table, trees_t = shape_table(), tree_table()
    k_cols, sizes = table["k"], trees_t["sizes"]
    need = []
    for x, y in samples:
        ridge = None
        for m in masses:
            left, top, w, h = m["rect"]
            sh = table["shapes"][m["shape"]]
            d = x - left
            if d < 0.0 or d >= w:
                continue
            t = sh["top"][int(d * k_cols / w)]
            if t < 0:
                continue
            py = top + t * h / sh["h"]
            if py < floor_y and (ridge is None or py < ridge):
                ridge = py
        need.append((ridge - y, ridge) if ridge is not None else (-1.0, 0.0))
    out, xs = [], []
    for pick in range(TREE_MAX):
        best = None
        for j, (x, _) in enumerate(samples):
            if need[j][0] < TREE_NEED or any(abs(x - tx) < TREE_GAP for tx in xs):
                continue
            if best is None or need[j][0] > need[best][0]:
                best = j
        if best is None:
            break
        n, ridge = need[best]
        k = max(q for q in range(len(sizes)) if sizes[q] <= n + TREE_OVER)
        i = (best * 3 + pick) % len(trees_t["trees"])
        x = samples[best][0]
        xs.append(x)
        out.append({"tree": i, "size": k,
                    "pos": (int(x + 0.5) - trees_t["trees"][i]["foot"][k],
                            int(ridge + 0.5) - sizes[k] + TREE_SINK)})
    return out


def paint_trees(base, layout, night):
    """The ridge trees, 1:1 (drawBitmap). scripts/fidelity_test.py paints
    them into the scored skyline too."""
    for t in layout.get("trees", []):
        base = paste_at(base, tree_image(t["tree"], t["size"], night), *t["pos"])
    return base


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
    """The library shape that best paints one run: (error, index, left,
    stretch).

    Every shape stands with its crest on the run's peak (cy), its width
    stretched so that the part of it over the far bank is as wide as the
    run (within FIT_STRETCH; the watch's drawScaledBitmap does that for
    free), and is tried with its apex at the run's summit (sx) and
    FIT_SLIDE either side of it, and with its middle over the run's
    middle; FIT_APEX_K per px between apex and summit keeps the painted
    summit on its minute. Its error is
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
        vis = sum(1 for t in sh["top"] if t >= 0 and top0 + t < floor_y)
        st = (run_x1 - run_x0) * k_cols / (max(vis, 1) * sh["w"])
        st = min(max(st, FIT_STRETCH[0]), FIT_STRETCH[1])
        w, ax = sh["w"] * st, sh["ax"] * st
        lefts = [sx + dx - ax for dx in FIT_SLIDE]
        lefts.append(0.5 * (run_x0 + run_x1) - 0.5 * w)
        for left in lefts:
            err = FIT_APEX_K * abs(left + ax - sx)
            for j, (x, y) in enumerate(samples):
                d = x - left
                if d >= w:
                    break
                if d >= 0.0:
                    t = sh["top"][int(d * k_cols / w)]
                    if t >= 0 and top0 + t < floor_y:
                        err += fit_cost(top0 + t, y, floor_y) - base[j]
            if best is None or err < best[0]:
                best = (err, i, left, st)
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
    height and "stretch" times its baked width. "vis" is the stretch of the screen where the shape stands over
    the far bank (kept for the record; the near range's cover still counts
    the middle 70% of each mass's bitmap, as in round 6). Draw order: the other masses first (the taller farther),
    the host (the highest crest) last. The near range then takes any third
    of the screen the masses leave empty (both outer thirds when all three
    are), its foot under the mist."""
    floor = floor_level(history)
    out = {"floor": floor, "horizon_y": None, "masses": [], "near": [], "trees": [],
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
        _, i, left, st = fit
        sh = table["shapes"][i]
        top0 = cy - sh["ay"]
        w, ax = sh["w"] * st, sh["ax"] * st
        cols = [k for k in range(k_cols) if sh["top"][k] >= 0 and top0 + sh["top"][k] < floor_y]
        vis = ((left + cols[0] * w / float(k_cols), left + (cols[-1] + 1) * w / float(k_cols))
               if cols else (left + ax, left + ax))
        masses.append({"rect": (left, top0, w, sh["h"]), "crest": (left + ax, cy),
                       "plane": sh["name"], "shape": i, "stretch": st, "vis": vis, "flip": False,
                       "host": r is host, "run": (r["lo"], r["hi"]), "elev": r["elev"]})
    # depth: the other masses first (the taller farther), the host last
    masses.sort(key=lambda m: (m["host"], m["crest"][1]))
    out["masses"] = masses
    out["trees"] = place_trees(masses, samples, floor_y)

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
            hour24=False, overlay=True, foreground=None, month=None, day=None, scene=0,
            epoch=None, steps_met=False, battery=100.0, resting=None, seal_hr=True,
            weather=None, hide=(), kanji=True, cloud=0, sunrise=360, sunset=1080,
            workout=True, notified=False):
    """night: the moonlit negative set (pale ink on black paper, no grain).
    trace: [(nx, norm_hr)] raw samples (the relief is fitted to them, as the
    Scene fits its stored trace), or None. overlay: draw the true-HR overlay
    over the painting (the watch's "True HR line" setting). foreground: an
    RGBA painting composed for the whole face (a cut from art/cuts/fg-*) to
    lay instead of the baked one; month, day (today's by default) and scene
    (the watch's "foreground" setting, 0 = by season) choose the baked one
    (foreground_index). epoch (now by default) sets the moon's phase,
    steps_met (today's step goal met) the geese, battery (percent) the
    lantern (prop_rules), resting (the profile's resting HR; the window's
    floor without it) the seal's shape (seal_shape). hide: the pieces
    turned off (prop_rules); kanji False: the hour in the brush digits
    ("Hour in kanji" off). cloud, sunrise, sunset, workout, notified:
    prop_rules (night stays the caller's: the watch sets it from sunset to
    sunrise, arc_t)."""
    import time
    epoch = time.time() if epoch is None else epoch
    day_of_month = datetime.date.today().day if day is None else day
    sfx = "_night" if night else ""
    mist = load("mist_band%s.png" % sfx)
    mist_lite = load("mist_band_lite%s.png" % sfx)
    grain_p = os.path.join(DRAW, "paper_grain.png")
    grain = Image.open(grain_p).convert("RGBA") if os.path.exists(grain_p) and not night else None

    layout = mid_plane_layout(history, trace)
    base = Image.new("RGBA", (W, H), (0, 0, 0, 255) if night else PAPER)

    # the sun (sunrise to sunset) or the moon by its phase on the arc, west
    # to east, under its cloud or behind it, or a cloudy sky's bank in its place: props from the
    # sheets (prop_rules); the night cut in night mode.
    props = prop_rules(layout, minute_of_day, epoch, day_of_month, steps_met, battery, hide,
                       foreground_index(month, day, scene), sunrise, sunset,
                       0 if weather in WX_PRECIP else cloud, workout, notified)
    if weather in WX_PRECIP:
        props["sky"] = []     # the rain or snow replaces the sun or moon
    base = paint_props(base, props["sky"], night)

    # 1. the horizon: the far range as a level line at the window's floor
    #    (round 4, 11-02). Drawn first; every mass is a cutout over it.
    base = paint_horizon(base, layout, night)

    # 1b. the valley pieces under the far range (none drawn yet; the
    #     village moved to the ground layer, 11-06)
    base = paint_props(base, props["valley"], night)

    # 2. light mist between far and mid planes
    base = paste_scaled(base, mist_lite, -0.10 * W, 0.50 * H, 1.20 * W, 0.17 * H)

    # 3. the masses: the library shapes, the host last (none on a flat day)
    base = paint_masses(base, layout, night)
    base = paint_trees(base, layout, night)

    # 3c. the hiker on a workout's summit; the geese for the step goal
    base = paint_props(base, props["summit"], night)
    base = paint_props(base, props["air"], night)
    # 3d. the weather (weather_veil's pick), behind the grasses
    if weather:
        wx = wind_painting(weather, foreground_index(month, day, scene))
        base = paste_at(base, load("wx_%s%s.png" % (wx, sfx)), 0, 0)

    # 4. the near range (round 5): a near hill in each third of the screen
    #    the masses leave empty, under the half-way line, to balance the
    #    picture; both outer thirds on a flat day
    base = paint_near(base, layout, night)

    # 5. full mist dissolving the mid-plane bodies and the near range's
    #    feet: raised in round 6 to begin just under the near crests, so the
    #    masses show their upper bodies and the depth order reads
    base = paste_scaled(base, mist, -0.03 * W, 0.66 * H, 1.06 * W, 0.22 * H)

    # 5b. a quiet window's village, then the low-battery lantern where John
    #     placed it on this foreground, just behind it, so the painting's
    #     grass blends them in
    base = paint_props(base, props["ground"], night)

    # 6. the foreground: one whole-face painting for the season and the day
    #    (foreground_index), over everything but the grain
    if foreground is None:
        foreground = foreground_image(foreground_index(month, day, scene), night)
    base = paste_scaled(base, foreground, 0, 0, W, H)

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
    if kanji:
        for i, g in enumerate(glyphs):
            placed.append((kanji_font, g, cx - kanji_font.glyphs[g]["xadvance"] // 2,
                           bottom - (len(glyphs) - 1 - i) * pitch - kanji_font.line_h // 2))
    else:
        # the hour in the brush digits, one line at the column's bottom line
        hrs = "%d" % hour
        hpen = cx - sum(ink_font.glyphs[c]["xadvance"] for c in hrs) // 2
        for c in hrs:
            placed.append((ink_font, c, hpen, bottom - ink_font.line_h // 2))
            hpen += ink_font.glyphs[c]["xadvance"]
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
    # the seal's halo follows the seal drawn (its shape decided here, as the View does)
    if seal_hr:
        shape = seal_shape(hr_now, resting if resting else layout["floor"])
    else:
        shape = "seal_square"
    sw, sh = {p["name"]: (p["w"], p["h"]) for p in prop_table()["props"]}[shape]
    scy = sy0 + seal // 2
    base = paste_at(base, load("halo_%s%s.png" % (shape, sfx)),
                    cx - sw // 2 - HALO_PAD, scy - sh // 2 - HALO_PAD)
    for font, g, x, top in placed:
        base = font.draw_left(base, g, x, top, ink)
    # the seal from the sheet, centered where the drawn square was: the oval
    # at rest, the rectangle at work (seal_shape)
    # (seal_hr False: the square, carrying the date, month over day)
    base = paste_at(base, prop_image(shape, night), cx - sw // 2, scy - sh // 2)
    paper = (244, 238, 226)
    if not seal_hr:
        mo, dd = "%02d" % (month or datetime.date.today().month), "%02d" % day_of_month
        base = seal_font.draw_nudged(base, mo, cx, scy + SEAL_DATE_DY[0], paper)
        base = seal_font.draw_nudged(base, dd, cx, scy + SEAL_DATE_DY[1], paper, first=len(mo))
    elif hr_now is not None:
        base = seal_font.draw_nudged(base, str(int(round(hr_now))), cx, scy, paper)

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
PROBE_GROUND = (0x5A, 0x55, 0x50, 255)
PROBE_INK = (24, 18, 14, 255)


def compose_probe():
    from PIL import ImageChops, ImageFont
    # the Scene's probe uses two library shapes since 11-03 (the round-6
    # planes left the watch)
    host = load("shape_peak_cut.png")
    guest = load("shape_spire_cut.png")
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
        ox, oy = (img.width - w) // 2, (img.height - h) // 2
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
    host_w = int(round(bh * host.width / float(host.height)))
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
    gw = gh * guest.width / float(guest.height)
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
                          [--month M] [--day D] [--scene N]
                          [--data hr.csv [--end YYYY-MM-DDTHH:MM]] [--probe]

    Defaults: 14:42 by day, 22:15 by night, 12-hour clock, the mock window,
    today's foreground (--month, --day and --scene pick another; see
    foreground_index).
    --data composes a real window (see load_data); its clock is the window's
    end in Arizona time unless --time is given, and --end (Arizona local)
    picks which four hours of the file to show. --probe writes the expected
    RENDERER_PLAN §13 probe card instead of the painting."""
    valued = ("--time", "--data", "--end", "--month", "--day", "--scene")
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
            hour24="--24h" in argv, overlay="--no-trace" not in argv,
            month=int(opts["--month"]) if "--month" in opts else None,
            day=int(opts["--day"]) if "--day" in opts else None,
            scene=int(opts.get("--scene", 0))).save(out)
    print("preview ->", os.path.abspath(out))


if __name__ == "__main__":
    main(sys.argv)
