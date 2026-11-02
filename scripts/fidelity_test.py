#!/usr/bin/env python
"""How faithfully does the ink face's landscape show the heart-rate graph?

Feeds many four-hour HR windows through compose_preview.py (the 1:1 offline
mock of the watch recipe), reads the PAINTED skyline of the two landmark
relief (horizon + masses) column by column along the face's time axis, and
scores it against the true curve:

    r          Pearson correlation of painted height and true HR per column
               (1 = the skyline rises and falls with the data, 0 = unrelated)
    peak_min   minutes between the true highest moment and the host crest
    peaks      prominent true peaks vs painted crests (1 host + 0/1 guest)
    gap_px     mean vertical distance between the red overlay's edge and the
               painted skyline (0 = the overlay sits exactly on the ink)
    relief     true HR range (bpm) vs painted skyline relief (px)

Writes a contact sheet (true graph | the face | skyline vs data) and a
Markdown report. Python 3 + Pillow only, so a machine without the Garmin SDK
can run it and compare a recipe change before anything is built.

    py -3.11 scripts/fidelity_test.py                  synthetic cases -> common/fidelity/
    py -3.11 scripts/fidelity_test.py --real hr.csv    adds real windows -> bin/fidelity/

--real takes any CSV with an `epoch` column and `hr_avg` or `hr` (Friend's
live.csv, a Connect export): it is sliced into consecutive four-hour
windows, labeled real-1, real-2 ... with no timestamps. Real runs default to
the ignored bin/fidelity/ so nothing personal is committed by accident;
pass --out to choose.
"""

import csv
import datetime
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose_preview as cp  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ALPHA_INK = 40            # the crest measurement threshold compose_preview uses
BASE_Y = 0.87 * cp.H      # the planes' foot; an empty column has height 0
EPOCH0 = 1800000000       # synthetic windows start here (no real date)
WINDOW_MIN = cp.HISTORY_SECONDS // 60
TILE = 260                # contact sheet tile size


# ---- synthetic cases ---------------------------------------------------------
# Each is a function minute -> bpm (None = no sample) over a 240-minute window,
# oldest first, sampled once a minute with a little deterministic noise.

def bump(t, center, width, height):
    """A smooth hump: `height` bpm at `center`, about `width` minutes wide."""
    return height * math.exp(-0.5 * ((t - center) / (width / 2.355)) ** 2)


def plateau(t, start, end, height, ramp=4.0):
    """`height` bpm between start and end with short ramps (a workout)."""
    up = 1.0 / (1.0 + math.exp(-(t - start) / (ramp / 4.0)))
    down = 1.0 / (1.0 + math.exp((t - end) / (ramp / 4.0)))
    return height * up * down


CASES = [
    ("flat_rest", "resting all window, 62 bpm",
     lambda t: 62.0),
    ("workout_middle", "40 min at 140 in the middle",
     lambda t: 66.0 + plateau(t, 100, 140, 74.0)),
    ("workout_recent", "the last 45 min at 135",
     lambda t: 66.0 + plateau(t, 195, 260, 69.0)),
    ("workout_oldest", "the first 45 min at 135",
     lambda t: 66.0 + plateau(t, -20, 45, 69.0)),
    ("two_workouts", "30 min at 130 early, 30 min at 145 late",
     lambda t: 65.0 + plateau(t, 20, 50, 65.0) + plateau(t, 180, 210, 80.0)),
    ("intervals", "four 5-min efforts at 150 inside an hour",
     lambda t: 70.0 + sum(plateau(t, 90 + 15 * k, 95 + 15 * k, 80.0, 2.0) for k in range(4))),
    ("steady_climb", "a slow rise from 60 to 110",
     lambda t: 60.0 + 50.0 * t / 240.0),
    ("nap_dip", "75 awake, an hour asleep at 52",
     lambda t: 75.0 - plateau(t, 90, 150, 23.0, 8.0)),
    ("stress_plateau", "70, then a tense two hours at 90",
     lambda t: 70.0 + plateau(t, 110, 260, 20.0, 15.0)),
    ("short_spike", "stairs: 5 min at 125 once",
     lambda t: 68.0 + plateau(t, 150, 155, 57.0, 2.0)),
    ("long_walk", "90 min walking at 98",
     lambda t: 68.0 + plateau(t, 60, 150, 30.0, 6.0)),
    ("reboot_gap", "no data for 90 min, then a workout",
     lambda t: None if t < 90 else 67.0 + plateau(t, 160, 200, 68.0)),
    ("three_humps", "three moderate efforts, 100 / 115 / 105",
     lambda t: 68.0 + bump(t, 40, 30, 32.0) + bump(t, 120, 30, 47.0) + bump(t, 200, 30, 37.0)),
]


def synthetic_rows(fn, seed):
    rng = random.Random(seed)
    rows = []
    for m in range(WINDOW_MIN + 1):
        v = fn(float(m))
        if v is None:
            continue
        v = v + rng.gauss(0.0, 1.5)
        rows.append((EPOCH0 + m * 60, round(v, 1), round(v + abs(rng.gauss(0.0, 1.0)), 1)))
    return rows


# ---- real windows ------------------------------------------------------------

def real_windows(path, minimum_rows=60):
    """Consecutive non-overlapping four-hour windows from a CSV, newest last."""
    rows = []
    with open(path, newline="") as fh:
        for d in csv.DictReader(fh):
            raw = d.get("hr_avg") or d.get("hr") or ""
            try:
                hr = float(raw)
                epoch = int(float(d["epoch"]))
            except (KeyError, ValueError):
                continue
            if hr > 0:
                rows.append((epoch, hr, float(d.get("hr_max") or hr)))
    rows.sort()
    out = []
    if not rows:
        return out
    end = rows[-1][0]
    while end - cp.HISTORY_SECONDS >= rows[0][0] - cp.HISTORY_SECONDS:
        start = end - cp.HISTORY_SECONDS
        window = [(t - start + EPOCH0, a, m) for t, a, m in rows if start <= t <= end]
        if len(window) >= minimum_rows:
            out.append(window)
        end -= cp.HISTORY_SECONDS
    out.reverse()
    return out


# ---- measurement -------------------------------------------------------------

def axis_columns():
    lo = int(round(cp.W * cp.axis_x(0.0)))
    hi = min(int(round(cp.W * cp.axis_x(1.0))), cp.W - 1)   # a full-width axis ends on the last column
    return list(range(lo, hi + 1))


def column_minute(x):
    """Minutes since the window's start for a screen column on the axis."""
    lo, hi = cp.W * cp.axis_x(0.0), cp.W * cp.axis_x(1.0)
    nx = (x - lo) / (hi - lo)
    return min(max(nx, 0.0), 1.0) * WINDOW_MIN


def true_series(rows, columns):
    """Mean HR of the samples nearest each column (None where no data)."""
    per_min = {}
    for t, avg, _ in rows:
        per_min.setdefault(int(round((t - EPOCH0) / 60.0)), []).append(avg)
    span = WINDOW_MIN / float(len(columns) - 1) / 2.0 + 0.5
    out = []
    for x in columns:
        m = column_minute(x)
        vals = [v for k in range(int(m - span), int(m + span) + 1)
                for v in per_min.get(k, []) if abs(k - m) <= span]
        out.append(sum(vals) / len(vals) if vals else None)
    return out


def smooth(series, radius):
    out = []
    for i in range(len(series)):
        vals = [v for v in series[max(0, i - radius):i + radius + 1] if v is not None]
        out.append(sum(vals) / len(vals) if vals else None)
    return out


def skyline(history, trace):
    """Top inked row of the horizon + masses per screen column, as painted
    (the same painters compose() uses; the near range sits under the
    horizon and is not relief)."""
    layout = cp.mid_plane_layout(history, trace)
    canvas = Image.new("RGBA", (cp.W, cp.H), (0, 0, 0, 0))
    canvas = cp.paint_horizon(canvas, layout, False)
    canvas = cp.paint_masses(canvas, layout, False)
    alpha = canvas.getchannel("A").load()
    tops = []
    for x in range(cp.W):
        top = None
        for y in range(cp.H):
            if alpha[x, y] >= ALPHA_INK:
                top = y
                break
        tops.append(top)
    return tops, layout


def pearson(xs, ys):
    pairs = [(a, b) for a, b in zip(xs, ys) if a is not None and b is not None]
    if len(pairs) < 3:
        return 0.0
    n = float(len(pairs))
    mx = sum(a for a, _ in pairs) / n
    my = sum(b for _, b in pairs) / n
    sx = math.sqrt(sum((a - mx) ** 2 for a, _ in pairs))
    sy = math.sqrt(sum((b - my) ** 2 for _, b in pairs))
    if sx < 1e-9 or sy < 1e-9:
        return 0.0
    return sum((a - mx) * (b - my) for a, b in pairs) / (sx * sy)


def prominent_peaks(series, minutes_per_col, prominence=12.0, separation_min=20.0):
    """Peaks with topographic prominence of at least `prominence` bpm: walk
    each way until a higher point (or the window's edge) and take the lowest
    valley on the way; the peak stands above the higher of those two valleys.
    A side that is empty (the peak is at the edge) does not count. At least
    `separation_min` apart."""
    idx = [i for i, v in enumerate(series) if v is not None]
    if not idx:
        return []
    vals = [series[i] for i in idx]
    top = max(range(len(vals)), key=lambda k: vals[k])
    # The highest point has no higher ground; its prominence is over the
    # window's lowest value (so a workout still running at "now" counts).
    peaks = [top] if vals[top] - min(vals) >= prominence else []
    for k in range(len(vals)):
        if k == top:
            continue
        if (k > 0 and vals[k] < vals[k - 1]) or (k < len(vals) - 1 and vals[k] < vals[k + 1]):
            continue
        valleys = []
        for step in (-1, 1):
            j, low, moved = k + step, vals[k], False
            while 0 <= j < len(vals) and vals[j] <= vals[k]:
                low = min(low, vals[j])
                moved = True
                j += step
            if moved:
                valleys.append(low)
        if valleys and vals[k] - max(valleys) >= prominence:
            peaks.append(k)
    kept = []
    for k in sorted(peaks, key=lambda k: -vals[k]):
        if all(abs(idx[k] - idx[j]) * minutes_per_col >= separation_min for j in kept):
            kept.append(k)
    return sorted(idx[k] for k in kept)


def score(rows):
    history, trace, hr_now, _, _ = cp.window_from_rows(rows, EPOCH0 + cp.HISTORY_SECONDS)
    columns = axis_columns()
    truth = true_series(rows, columns)
    tops, layout = skyline(history, trace)
    heights = [BASE_Y - tops[x] if tops[x] is not None else 0.0 for x in columns]
    minutes_per_col = WINDOW_MIN / float(len(columns) - 1)
    smoothed = smooth(truth, int(round(2.5 / minutes_per_col)))

    r = pearson(heights, truth)
    have = [(i, v) for i, v in enumerate(smoothed) if v is not None]
    true_peak_min = column_minute(columns[max(have, key=lambda p: p[1])[0]]) if have else None
    painted_peak_min = (column_minute(layout["host_crest"][0])
                        if layout["host_crest"] is not None else None)
    peak_err = (abs(true_peak_min - painted_peak_min)
                if true_peak_min is not None and painted_peak_min is not None else None)
    true_peaks = len(prominent_peaks(smoothed, minutes_per_col))
    painted_peaks = len(layout["masses"])
    gaps = [abs(cp.trace_y(cp.norm_hr(v)) - (tops[x] if tops[x] is not None else BASE_Y))
            for x, v in zip(columns, truth) if v is not None]
    gap_px = sum(gaps) / len(gaps) if gaps else None
    tv = [v for v in smoothed if v is not None]
    true_range = (max(tv) - min(tv)) if tv else 0.0
    relief = max(heights) - min(heights)
    return {
        "history": history, "trace": trace, "hr_now": hr_now, "rows": rows,
        "columns": columns, "truth": truth, "tops": tops, "layout": layout,
        "r": r, "peak_err": peak_err, "true_peaks": true_peaks,
        "painted_peaks": painted_peaks, "gap_px": gap_px,
        "true_range": true_range, "relief": relief,
    }


# ---- pictures ----------------------------------------------------------------

def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:     # Pillow < 10.1
        return ImageFont.load_default()


def graph_tile(s):
    """The true curve as a plain HR graph on the face's own time axis."""
    img = Image.new("RGB", (cp.W, cp.H), (250, 248, 244))
    d = ImageDraw.Draw(img)
    lo_bpm, hi_bpm = 40.0, 170.0
    top, bottom = 0.18 * cp.H, 0.86 * cp.H

    def y_of(bpm):
        return bottom - (bpm - lo_bpm) / (hi_bpm - lo_bpm) * (bottom - top)

    for bpm in range(50, 171, 20):
        d.line([(0, y_of(bpm)), (cp.W, y_of(bpm))], fill=(225, 220, 212), width=1)
        d.text((6, y_of(bpm) - 8), str(bpm), fill=(150, 144, 136), font=font(14))
    x0, x1 = s["columns"][0], s["columns"][-1]
    d.line([(x0, bottom), (x0, top)], fill=(200, 194, 186))
    d.line([(x1, bottom), (x1, top)], fill=(200, 194, 186))
    d.text((x0 - 20, bottom + 6), "-4h", fill=(120, 114, 106), font=font(14))
    d.text((x1 - 14, bottom + 6), "now", fill=(120, 114, 106), font=font(14))
    pts = []
    for x, v in zip(s["columns"], s["truth"]):
        if v is None:
            if len(pts) > 1:
                d.line(pts, fill=(176, 52, 38), width=3)
            pts = []
            continue
        pts.append((x, y_of(v)))
    if len(pts) > 1:
        d.line(pts, fill=(176, 52, 38), width=3)
    return img


def analysis_tile(s):
    """The painted skyline (ink) against the data on the crest scale (red,
    exactly where the overlay draws it)."""
    img = Image.new("RGB", (cp.W, cp.H), (250, 248, 244))
    d = ImageDraw.Draw(img)
    for x in range(cp.W):
        t = s["tops"][x]
        if t is not None:
            d.line([(x, t), (x, BASE_Y)], fill=(200, 196, 190))
    sky = [(x, s["tops"][x]) for x in range(cp.W) if s["tops"][x] is not None]
    if len(sky) > 1:
        d.line(sky, fill=(24, 18, 14), width=2)
    x0, x1 = s["columns"][0], s["columns"][-1]
    d.line([(x0, 0.15 * cp.H), (x0, BASE_Y)], fill=(160, 154, 146))
    d.line([(x1, 0.15 * cp.H), (x1, BASE_Y)], fill=(160, 154, 146))
    pts = []
    for x, v in zip(s["columns"], s["truth"]):
        if v is None:
            if len(pts) > 1:
                d.line(pts, fill=(176, 52, 38), width=3)
            pts = []
            continue
        pts.append((x, cp.trace_y(cp.norm_hr(v))))
    if len(pts) > 1:
        d.line(pts, fill=(176, 52, 38), width=3)
    for crest in (s["layout"]["host_crest"], s["layout"]["guest_crest"]):
        if crest is not None:
            cx, cy = crest
            d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], outline=(24, 18, 14), width=2)
    return img


def fmt(v, spec):
    return "-" if v is None else spec % v


def contact_sheet(results, path):
    label_h = 44
    sheet = Image.new("RGB", (TILE * 3, (TILE + label_h) * len(results) + 30), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    d.text((8, 8), "true HR graph  |  the face (compose_preview)  |  painted skyline (ink) vs data on the crest scale (red)",
           fill=(40, 40, 40), font=font(13))
    y = 30
    for name, blurb, s in results:
        face = cp.compose(s["history"], minute_of_day=14 * 60 + 42, hr_now=s["hr_now"],
                          trace=s["trace"])
        for i, img in enumerate((graph_tile(s), face, analysis_tile(s))):
            sheet.paste(img.resize((TILE, TILE), Image.LANCZOS), (i * TILE, y + label_h))
        d.text((8, y + 4), "%s: %s" % (name, blurb), fill=(20, 20, 20), font=font(15))
        d.text((8, y + 23), "r %s   peak off %s min   peaks %d true / %d painted   overlay gap %s px   %s bpm -> %s px"
               % (fmt(s["r"], "%.2f"), fmt(s["peak_err"], "%.0f"), s["true_peaks"],
                  s["painted_peaks"], fmt(s["gap_px"], "%.0f"), fmt(s["true_range"], "%.0f"),
                  fmt(s["relief"], "%.0f")),
               fill=(90, 90, 90), font=font(13))
        y += TILE + label_h
    # A 256-color palette keeps a committed sheet near a third of the size.
    sheet.quantize(colors=256, method=Image.Quantize.MEDIANCUT).save(path, optimize=True)


# ---- report ------------------------------------------------------------------

def mean(vals):
    vals = [v for v in vals if v is not None]
    return sum(vals) / len(vals) if vals else None


def write_report(results, md_path, sheet_name, stamp):
    lines = [
        "# Ink face fidelity: %s" % stamp,
        "",
        "How well the painted landscape (horizon + masses) shows the four-hour",
        "heart-rate graph, per `scripts/fidelity_test.py`. Columns are the face's",
        "time axis (the full width). See [README](README.md) for the metrics.",
        "",
        "| Case | What | r | Peak off (min) | Peaks true / painted | Overlay gap (px) | True range (bpm) | Painted relief (px) |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for name, blurb, s in results:
        lines.append("| %s | %s | %s | %s | %d / %d | %s | %s | %s |" % (
            name, blurb, fmt(s["r"], "%.2f"), fmt(s["peak_err"], "%.0f"),
            s["true_peaks"], s["painted_peaks"], fmt(s["gap_px"], "%.0f"),
            fmt(s["true_range"], "%.0f"), fmt(s["relief"], "%.0f")))
    rs = [s["r"] for _, _, s in results]
    matched = sum(1 for _, _, s in results if s["true_peaks"] == s["painted_peaks"])
    lines += [
        "",
        "## Summary",
        "",
        "- Mean r: %s (1.00 = the skyline follows the data)" % fmt(mean(rs), "%.2f"),
        "- Mean peak timing error: %s min" % fmt(mean([s["peak_err"] for _, _, s in results]), "%.0f"),
        "- Peak count matches: %d of %d cases" % (matched, len(results)),
        "- Mean overlay-to-ink gap: %s px" % fmt(mean([s["gap_px"] for _, _, s in results]), "%.0f"),
        "- HR scale: 60 -> 100 bpm moves the host crest %.0f px of %d"
        % (cp.crest_y(cp.height_for_hr(60)) - cp.crest_y(cp.height_for_hr(100)), cp.H),
        "",
        "![contact sheet](%s)" % sheet_name,
        "",
    ]
    with open(md_path, "w", newline="\n") as fh:
        fh.write("\n".join(lines))


def main(argv):
    opts, it = {}, iter(argv[1:])
    for a in it:
        if a in ("--real", "--out"):
            opts[a] = next(it)
    results = []
    for k, (name, blurb, fn) in enumerate(CASES):
        results.append((name, blurb, score(synthetic_rows(fn, seed=k + 1))))
    if "--real" in opts:
        for k, rows in enumerate(real_windows(opts["--real"])):
            results.append(("real-%d" % (k + 1), "real four-hour window", score(rows)))
    default_out = os.path.join(REPO, "bin", "fidelity") if "--real" in opts \
        else os.path.join(REPO, "common", "fidelity")
    out_dir = opts.get("--out", default_out)
    os.makedirs(out_dir, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M")
    sheet_name = stamp + "_fidelity-sheet.png"
    contact_sheet(results, os.path.join(out_dir, sheet_name))
    md_path = os.path.join(out_dir, stamp + "_fidelity.md")
    write_report(results, md_path, sheet_name, stamp.replace("_", " "))
    print("report ->", md_path)
    print("mean r %s, peak count matches %d/%d" % (
        fmt(mean([s["r"] for _, _, s in results]), "%.2f"),
        sum(1 for _, _, s in results if s["true_peaks"] == s["painted_peaks"]), len(results)))


if __name__ == "__main__":
    main(sys.argv)
