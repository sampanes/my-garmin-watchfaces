#!/usr/bin/env python
"""Bake the ink-sandbox benchmark grammar into the watch face's bitmap layers.

playgrounds/ink-sandbox/main.js is the renderer whose output reads as
shanshui. It draws every ridge as a gradient-filled polygon (most ink at the
ridgeline, nearly gone by 40% depth), then scatters pressure-varying cun
strokes, near-horizontal dry-brush dashes, flying-white marks and ink-bleed
blobs along the ridge, grows small branching trees on it, and separates the
planes with organic mist. Garmin's Dc has none of that, so this script ports
those primitives to numpy/Pillow and bakes each PLANE as one PNG with the
brushwork inside. Monkey C places the planes (see compose_preview.py for the
recipe and JapaneseInkHeartrateScene.mc for the port).

Outputs (RGBA, straight alpha, one ink color per file):
    far_range.png        416x120  ghost + far ridges, heavily blurred
    guest_mountain.png   260x190  paler mid-plane peak (second HR landmark)
    host_mountain.png    340x260  the hero mid-plane peak (strongest landmark)
    fg_left.png          300x200  dark foreground mass, anchored bottom-left
    fg_right.png         280x180  dark foreground mass, anchored bottom-right
    mist_band.png        416x110  paper-colored organic mist (band+puffs+wisps)
    mist_band_lite.png   same at 62% alpha (no runtime alpha knob on device)
    paper_grain.png      240x240  washi grain, upscaled on-device
    *_night.png          every plane but the grain again as pale ink for the
                         night mode's black paper (mist becomes black)

Rendering happens at SS x supersample and is LANCZOS-downsampled. Every
random draw goes through seeded numpy RNGs: regeneration is byte-identical.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS = 3
PAPER = (242, 238, 230)
OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..",
    "watch-faces", "japanese-ink-heartrate", "resources", "drawables")


# ------------------------------------------------------------------ noise

def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def vnoise(pos, seed, n=4096):
    """1-D value noise sampled at float positions (cell = 1), output [0,1]."""
    tab = np.random.default_rng(seed).random(n + 2)
    p = np.mod(np.asarray(pos, dtype=float), n)
    i0 = np.floor(p).astype(int)
    t = p - i0
    t = t * t * (3.0 - 2.0 * t)
    return tab[i0] * (1.0 - t) + tab[i0 + 1] * t


def fbm(pos, seed, octaves=4, lacunarity=2.0, gain=0.5):
    """Fractal value noise in about [-1, 1]."""
    out = np.zeros_like(np.asarray(pos, dtype=float))
    amp, freq, total = 1.0, 1.0, 0.0
    for i in range(octaves):
        out += amp * (2.0 * vnoise(pos * freq + i * 17.3, seed + i * 101) - 1.0)
        total += amp
        amp *= gain
        freq *= lacunarity
    return out / total


def turbulence(pos, seed, octaves=3):
    out = np.zeros_like(np.asarray(pos, dtype=float))
    amp, freq, total = 1.0, 1.0, 0.0
    for i in range(octaves):
        out += amp * np.abs(2.0 * vnoise(pos * freq + i * 7.1, seed + i * 37) - 1.0)
        total += amp
        amp *= 0.5
        freq *= 2.0
    return out / total


def domain_warp(pos, seed, strength=0.3):
    """Nested fbm, the benchmark's 'folded rock' edge quality (1-D form)."""
    q0 = fbm(pos, seed + 1)
    q1 = fbm(pos + 5.2, seed + 2)
    r0 = fbm(pos + strength * q0 + 1.7, seed + 3)
    r1 = fbm(pos + strength * q1 + 9.2, seed + 4)
    return fbm(pos + strength * (r0 + 0.5 * r1), seed + 5)


def vnoise2(h, w, cell_y, cell_x, seed, octaves=3, gain=0.55):
    """2-D value noise in [0,1], shape (h, w). Used for stroke modulation."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    cy, cx = float(cell_y), float(cell_x)
    for _ in range(octaves):
        ky = max(int(np.ceil(h / cy)) + 2, 2)
        kx = max(int(np.ceil(w / cx)) + 2, 2)
        grid = rng.random((ky, kx))
        ys = np.arange(h) / cy
        xs = np.arange(w) / cx
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        ty = (ys - y0)[:, None]
        tx = (xs - x0)[None, :]
        ty = ty * ty * (3 - 2 * ty)
        tx = tx * tx * (3 - 2 * tx)
        top = grid[np.ix_(y0, x0)] * (1 - tx) + grid[np.ix_(y0, x0 + 1)] * tx
        bot = grid[np.ix_(y0 + 1, x0)] * (1 - tx) + grid[np.ix_(y0 + 1, x0 + 1)] * tx
        out += amp * (top * (1 - ty) + bot * ty)
        total += amp
        amp *= gain
        cy = max(cy * 0.5, 1.5)
        cx = max(cx * 0.5, 1.5)
    return out / total


# ------------------------------------------------------------ ridge profile

def profile(W, peaks, y_base, amp, rough, seed, edge_left=0.10, edge_right=0.10):
    """Ridge screen-y per supersampled column.

    peaks: list of (nx, h, s) Gaussian descriptors in asset-normalized x.
    Noise (warp + detail + micro) rides on the peak envelope so the skirts
    between and beyond peaks stay calm instead of growing a hill band.
    """
    nx = np.arange(W) / W
    v = np.zeros(W)
    for (pnx, ph, ps) in peaks:
        d = nx - pnx
        v = np.maximum(v, ph * np.exp(-(d * d) / (2.0 * ps * ps)))
    warp = domain_warp(nx * 3.5, seed) * rough
    detail = fbm(nx * 12.0, seed + 7, 4) * rough * 0.35
    micro = turbulence(nx * 38.0, seed + 9, 3) * rough * 0.12
    noise = (warp + detail + micro) * (0.25 + 0.75 * np.clip(v, 0, 1))
    v = np.maximum(v + noise, 0.0)
    env = np.ones(W)
    if edge_left > 0:
        env *= smoothstep(0.0, edge_left, nx)
    if edge_right > 0:
        env *= smoothstep(1.0, 1.0 - edge_right, nx)
    v *= env
    return y_base - v * amp


# ---------------------------------------------------------------- fill

def fill_gradient(ridge_y, H, W, ink_max, fade):
    """The benchmark's fillMtn: alpha by depth below the layer's highest peak."""
    peak_y = float(ridge_y.min())
    yy = np.arange(H, dtype=float)[:, None]
    t = np.clip((yy - peak_y) / max(H - peak_y, 1.0), 0.0, 1.0)
    stops_t = [0.0, 0.15, 0.38, 0.65, 0.88, 1.0]
    stops_a = [1.0, 0.88, 0.55, 0.20, 0.05, fade / max(ink_max, 1e-6)]
    a = np.interp(t, stops_t, stops_a) * ink_max
    inside = yy >= ridge_y[None, :]
    return np.broadcast_to(a, (H, W)) * inside


def over(a, s):
    """Source-over of a stroke alpha s onto canvas alpha a (same ink)."""
    return a + s * (1.0 - a)


def scratch(H, W):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im, "RGBA")


def alpha_of(im):
    return np.asarray(im.getchannel("A"), dtype=float) / 255.0


# ---------------------------------------------------------------- strokes

INK = (10, 7, 4)


def brush_stroke(d, mod, x0, y0, x1, y1, w_min, w_max, alpha):
    """Pressure-varying segmented stroke (benchmark drawBrushStroke). SS coords."""
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    steps = max(4, int(math.ceil(length / (2.0 * SS))))
    h, w = mod.shape
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        tm = 0.5 * (t0 + t1)
        px, py = x0 + dx * tm, y0 + dy * tm
        nv = mod[min(max(int(py), 0), h - 1), min(max(int(px), 0), w - 1)]
        pressure = (math.sin(math.pi * tm) ** 0.6) * (1.0 + 0.3 * nv)
        pressure = min(max(pressure, 0.0), 1.0)
        width = w_min + (w_max - w_min) * pressure
        a = alpha * max(0.15, pressure)
        d.line([(x0 + dx * t0, y0 + dy * t0), (x0 + dx * t1, y0 + dy * t1)],
               fill=INK + (int(255 * min(a, 1.0)),), width=max(1, int(round(width))))


def dashed_line(d, x0, y0, x1, y1, on, off, width, alpha):
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    if length < 1e-6:
        return
    ux, uy = dx / length, dy / length
    pos = 0.0
    fill = INK + (int(255 * min(alpha, 1.0)),)
    while pos < length:
        end = min(pos + max(on, 0.5), length)
        d.line([(x0 + ux * pos, y0 + uy * pos), (x0 + ux * end, y0 + uy * end)],
               fill=fill, width=max(1, int(round(width))))
        pos = end + max(off, 0.5)


def cun(d, mod, ridge, H, W, count, ink, rng):
    """Scattered short brush marks inside the body (皴)."""
    for _ in range(count):
        x = rng.random() * W
        xi = min(W - 1, int(x))
        t = rng.random() ** 1.6
        y = ridge[xi] + (H - ridge[xi]) * t * 0.82
        if y < ridge[xi] + 1 or y > H * 0.97:
            continue
        ang = (0.35 + rng.random() * 0.55) * math.pi
        length = (3 + rng.random() * 14) * SS
        alpha = (0.18 + rng.random() * 0.55) * ink
        w_max = (0.4 + rng.random() * 1.4) * SS
        brush_stroke(d, mod, x, y, x + math.cos(ang) * length, y + math.sin(ang) * length,
                     0.2 * SS, w_max, alpha)


def fly_white(d, ridge, H, W, ink, rng):
    """Dry-brush marks hugging the ridge (飛白)."""
    for _ in range(int(W / SS * 0.4)):
        x = rng.random() * W
        xi = min(W - 1, int(x))
        y = ridge[xi] + (rng.random() - 0.5) * 7 * SS
        if y < 4 * SS or y > H * 0.95:
            continue
        alpha = rng.random() * 0.16 * ink
        width = (0.3 + rng.random()) * SS
        on, off = rng.random() * 4 * SS, (1 + rng.random() * 6) * SS
        x1 = x + (rng.random() - 0.5) * (4 + rng.random() * 15) * SS
        y1 = y + (rng.random() - 0.3) * 4 * SS
        dashed_line(d, x, y, x1, y1, on, off, width, alpha)


def dry_brush(d, ridge, H, W, ink, rng):
    """Near-horizontal dashes just below the ridge: bristles on washi."""
    for _ in range(int(W / SS * 0.3)):
        x = rng.random() * W
        xi = min(W - 1, int(x))
        depth_t = (rng.random() ** 0.8) * 0.35
        y = ridge[xi] + (H - ridge[xi]) * depth_t
        if y < 4 * SS or y > H * 0.95:
            continue
        length = (5 + rng.random() * 22) * SS
        ang = (rng.random() - 0.5) * 0.25
        on, off = rng.random() * 3 * SS, (0.8 + rng.random() * 5) * SS
        alpha = rng.random() * 0.07 * ink
        width = (0.3 + rng.random() * 0.7) * SS
        dashed_line(d, x, y, x + math.cos(ang) * length, y + math.sin(ang) * length,
                    on, off, width, alpha)


def bleed_edge(a, ridge, H, W, alpha, rng):
    """Radial micro-blobs at the ridge: ink wicking into fibers."""
    blobs = np.zeros_like(a)
    for x in range(W):
        if rng.random() > 0.28 / SS:        # per-column probability at 1x density
            continue
        y = ridge[x]
        sz = (0.8 + rng.random() * 4.5) * SS
        ox = x + (rng.random() - 0.5) * 5 * SS
        oy = y - rng.random() * sz * 1.4
        ry = sz * (1.1 + rng.random() * 0.8)
        a0 = alpha * (0.3 + rng.random() * 0.7)
        r = int(math.ceil(max(sz, ry))) + 1
        x0, x1 = int(max(ox - r, 0)), int(min(ox + r + 1, W))
        y0, y1 = int(max(oy - r, 0)), int(min(oy + r + 1, H))
        if x1 <= x0 or y1 <= y0:
            continue
        yy, xx = np.mgrid[y0:y1, x0:x1]
        inside = ((xx - ox) / sz) ** 2 + ((yy - oy) / ry) ** 2 <= 1.0
        dist = np.sqrt((xx - ox) ** 2 + (yy - oy) ** 2)
        g = np.clip(1.0 - dist / (2.6 * sz), 0.0, 1.0) * a0 * inside
        blobs[y0:y1, x0:x1] = np.maximum(blobs[y0:y1, x0:x1], g)
    return over(a, blobs)


# ---------------------------------------------------------------- trees

def foliage_cluster(d, cx, cy, radius, rng, seed):
    n_blobs = 3 + int(rng.random() * 5)
    for b in range(n_blobs):
        bx = cx + (rng.random() - 0.5) * radius * 2.0
        by = cy - radius * 0.3 + (rng.random() - 0.5) * radius * 1.5
        br = radius * (0.25 + rng.random() * 0.4)
        if br < 1.0 * SS:
            continue
        alpha = 0.35 + rng.random() * 0.45
        pts = 10 + int(rng.random() * 6)
        angs = np.arange(pts + 1) / pts * 2 * math.pi
        wobble = fbm(np.arange(pts + 1) * 0.9 + rng.random() * 100, seed + b, 2)
        rr = br * (0.65 + 0.35 * wobble)
        rr = np.maximum(rr, 0.5)
        poly = [(bx + math.cos(a) * r, by + math.sin(a) * r) for a, r in zip(angs, rr)]
        d.polygon(poly, fill=INK + (int(255 * alpha),))


def generate_branch(d, mod, x, y, angle, length, width, depth, rng, seed):
    if depth <= 0 or length < 1.5 * SS:
        return
    h, w = mod.shape
    steps = max(3, int(math.ceil(length / (3.0 * SS))))
    cx, cy = x, y
    for i in range(steps):
        t = (i + 0.5) / steps
        pressure = math.sin(math.pi * t) ** 0.6
        wd = max(0.3 * SS, width * (1 - t * 0.65) * pressure)
        nv = mod[min(max(int(cy), 0), h - 1), min(max(int(cx), 0), w - 1)]
        na = nv * 0.4
        nx = cx + math.cos(angle + na) * (length / steps)
        ny = cy + math.sin(angle + na) * (length / steps)
        alpha = 0.60 + rng.random() * 0.35
        d.line([(cx, cy), (nx, ny)], fill=INK + (int(255 * alpha),),
               width=max(1, int(round(wd))))
        cx, cy = nx, ny
    if depth == 1:
        foliage_cluster(d, cx, cy, length * 0.72, rng, seed)
        return
    nv = mod[min(max(int(cy), 0), h - 1), min(max(int(cx), 0), w - 1)]
    angle_noise = nv * 0.15
    spread = 0.30 + rng.random() * 0.35
    generate_branch(d, mod, cx, cy, angle - spread + angle_noise,
                    length * (0.60 + rng.random() * 0.15), width * 0.60, depth - 1, rng, seed + 1)
    generate_branch(d, mod, cx, cy, angle + spread + angle_noise,
                    length * (0.60 + rng.random() * 0.15), width * 0.60, depth - 1, rng, seed + 2)
    if rng.random() > 0.60 and depth > 2:
        generate_branch(d, mod, cx, cy, angle + angle_noise * 0.5,
                        length * (0.45 + rng.random() * 0.10), width * 0.50, depth - 2, rng, seed + 3)


def ridge_trees(d, mod, ridge, H, W, prob, rng, seed, size_lo=6.0, size_hi=18.0):
    for x1 in range(6, W // SS - 6):
        if rng.random() > prob:
            continue
        x = x1 * SS
        y = ridge[min(x, W - 1)]
        if y > H * 0.87 or y < 12 * SS:
            continue
        sz = (size_lo + rng.random() * (size_hi - size_lo)) * SS
        generate_branch(d, mod, x + (rng.random() - 0.5) * 3 * SS, y, -math.pi / 2,
                        sz, sz * 0.14, 3, rng, seed + x1)


# ------------------------------------------------------------ one plane

def render_plane(W1, H1, peaks, amp_frac, rough, ink, fade, seed, *,
                 y_base_frac=1.0, blur_1x=1.0, cun_count=0, tree_prob=0.0,
                 bleed=0.0, dry=True, fly=True, edge_left=0.10, edge_right=0.10,
                 base_fade=(0.72, 0.99), tree_size=(6.0, 18.0), crown=0.0, crown_k=0.07):
    """Returns the plane's alpha as a float array at 1x (H1, W1)."""
    W, H = W1 * SS, H1 * SS
    rng = np.random.default_rng(seed)
    ridge = profile(W, peaks, y_base_frac * H, amp_frac * H, rough, seed,
                    edge_left, edge_right)
    a = fill_gradient(ridge, H, W, ink, fade)
    if crown > 0:
        # Brush-redefined ridge: a dark band hugging the silhouette, scaled by
        # the local height so low skirts get a thin line, peaks a real crown.
        yy = np.arange(H, dtype=float)[:, None]
        depth = yy - ridge[None, :]
        local_h = np.maximum(y_base_frac * H - ridge, 14 * SS)[None, :]
        band = crown * np.exp(-np.clip(depth, 0, None) / (crown_k * local_h)) * (depth >= 0)
        a = over(a, band)
    mod = 2.0 * vnoise2(H, W, 25 * SS, 25 * SS, seed + 55, octaves=2) - 1.0

    im, d = scratch(H, W)
    if dry:
        dry_brush(d, ridge, H, W, ink, rng)
    if cun_count:
        cun(d, mod, ridge, H, W, cun_count, ink, rng)
    if fly:
        fly_white(d, ridge, H, W, ink, rng)
    a = over(a, alpha_of(im))

    if tree_prob > 0:
        tim, td = scratch(H, W)
        ridge_trees(td, mod, ridge, H, W, tree_prob, rng, seed + 500, *tree_size)
        a = over(a, alpha_of(tim))

    if bleed > 0:
        a = bleed_edge(a, ridge, H, W, bleed, rng)

    # The stamp must dissolve before its own bottom edge shows.
    yy = np.arange(H, dtype=float)[:, None] / H
    wob = (fbm(np.arange(W) / W * 6.0, seed + 77, 3) * 0.06)[None, :]
    a *= 1.0 - smoothstep(base_fade[0] + wob, base_fade[1] + wob, yy)

    a_img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")
    if blur_1x > 0:
        a_img = a_img.filter(ImageFilter.GaussianBlur(blur_1x * SS))
    a_img = a_img.resize((W1, H1), Image.LANCZOS)
    return np.asarray(a_img, dtype=float) / 255.0


def to_png(alpha, rgb, path):
    h, w = alpha.shape
    out = np.zeros((h, w, 4), dtype=np.uint8)
    out[..., 0], out[..., 1], out[..., 2] = rgb
    out[..., 3] = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(out, "RGBA").save(path)


# ---------------------------------------------------------------- mist

def organic_mist(W1, H1, seed, alpha=0.68):
    """Benchmark organicMist: fbm-displaced band + cloud puffs + wisps."""
    W, H = W1 * SS, H1 * SS
    rng = np.random.default_rng(seed)
    y_center, thick = H * 0.5, H * 0.42
    nx = np.arange(W) / W
    top_off = (fbm(nx * 4.5, seed, 4, 2.0, 0.55) * 0.62
               + fbm(nx * 14 + 3, seed + 1, 3) * 0.17
               + fbm(nx * 35 + 7, seed + 2, 2) * 0.06) * thick
    bot_off = (fbm(nx * 3.5 + 2, seed + 3, 3) * 0.28
               + fbm(nx * 11 + 9, seed + 4, 2) * 0.10) * thick
    top = y_center - thick * 0.5 + top_off
    bot = y_center + thick * 0.5 + bot_off
    yy = np.arange(H, dtype=float)[:, None]
    inside = (yy >= top[None, :]) & (yy <= bot[None, :])
    t = np.clip((yy - (y_center - thick * 0.75)) / (1.5 * thick), 0, 1)
    band = np.interp(t, [0, 0.25, 0.5, 0.75, 1.0], [0, 0.6, 1.0, 0.5, 0]) * alpha
    # Along-length gaps: stretches where the mist thins to nothing, so the
    # band never reads as a stripe across the whole face.
    gaps = 0.25 + 0.75 * smoothstep(0.28, 0.72, vnoise(nx * 3.2 + 11.0, seed + 9))
    a = np.array(np.broadcast_to(band, (H, W)) * inside * gaps[None, :])

    def puff(px, py, rw, rh, a0):
        nonlocal a
        r = int(max(rw, rh)) + 2
        x0, x1 = int(max(px - r, 0)), int(min(px + r + 1, W))
        y0, y1 = int(max(py - r, 0)), int(min(py + r + 1, H))
        if x1 <= x0 or y1 <= y0:
            return
        yg, xg = np.mgrid[y0:y1, x0:x1]
        rr = np.sqrt(((xg - px) / rw) ** 2 + ((yg - py) / rh) ** 2)
        g = np.interp(rr, [0, 0.45, 0.78, 1.0], [1.0, 0.55, 0.15, 0.0]) * a0
        a = a.copy()
        a[y0:y1, x0:x1] = over(a[y0:y1, x0:x1], g)

    for _ in range(8 + int(rng.random() * 7)):
        px = rng.random() * W
        py = y_center + (rng.random() - 0.5) * thick * 0.75
        rw = (40 + rng.random() * 110) * SS * (W1 / 416.0)
        rh = (10 + rng.random() * 32) * SS * (H1 / 110.0)
        puff(px, py, rw, rh, alpha * (0.28 + rng.random() * 0.50))
    for _ in range(5 + int(rng.random() * 4)):
        wx = rng.random() * W * 1.2 - W * 0.1
        wy = y_center + (rng.random() - 0.5) * thick * 0.55
        wl = (70 + rng.random() * 190) * SS * (W1 / 416.0)
        wh = (5 + rng.random() * 16) * SS * (H1 / 110.0)
        puff(wx, wy, wl, wh, alpha * (0.10 + rng.random() * 0.22))

    # Edge guards: the band must never show its rectangle.
    xx = np.arange(W, dtype=float)[None, :]
    a = a * smoothstep(0, 0.06 * W, xx) * smoothstep(W, 0.94 * W, xx)
    a = a * (1.0 - smoothstep(0.86 * H, 1.0 * H, yy)) * smoothstep(0.0, 0.14 * H, yy)
    a_img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L") \
        .filter(ImageFilter.GaussianBlur(2.2 * SS)).resize((W1, H1), Image.LANCZOS)
    return np.asarray(a_img, dtype=float) / 255.0


# ---------------------------------------------------------------- paper

def make_paper_grain(size, seed):
    """Subtle washi fiber grain: low-freq mottle + sparse flecks + rim
    vignette. Max alpha kept tiny so it tones rather than speckles. Authored
    small and upscaled on-device. (Unchanged from the 2026-06 kit.)"""
    Wp = Hp = size
    mottle = vnoise2(Hp, Wp, 26, 34, seed, octaves=3)
    fibers = vnoise2(Hp, Wp, 1.6, 12, seed + 1, octaves=2)   # horizontal-ish
    rng = np.random.default_rng(seed + 2)
    flecks = (rng.random((Hp, Wp)) > 0.9985).astype(float)
    fleck_img = Image.fromarray((flecks * 255).astype(np.uint8), "L") \
        .filter(ImageFilter.GaussianBlur(0.7))
    flecks = np.asarray(fleck_img, dtype=float) / 255.0
    yy, xx = np.mgrid[0:Hp, 0:Wp].astype(float)
    r = np.sqrt((xx - Wp / 2) ** 2 + (yy - Hp / 2) ** 2) / (Wp / 2)
    vign = smoothstep(0.82, 1.02, r)
    dark = np.clip((mottle - 0.5) * 0.5 + (fibers - 0.5) * 0.25, 0, 1) * 0.055 \
        + flecks * 0.10 + vign * 0.05
    a = (np.clip(dark, 0, 0.16) * 255).astype(np.uint8)
    rgb = np.zeros((Hp, Wp, 3), dtype=np.uint8)
    rgb[..., 0], rgb[..., 1], rgb[..., 2] = (96, 84, 70)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")


# ---------------------------------------------------------------- main

def write_pair(alpha, rgb, name, night_rgb, night_scale):
    """Day plane plus its night twin: the same alpha, scaled, in pale ink.
    On black paper the nearest plane carries the most ink and so the most
    light, which keeps the depth order of the day painting."""
    to_png(alpha, rgb, os.path.join(OUT_DIR, name + ".png"))
    to_png(alpha * night_scale, night_rgb, os.path.join(OUT_DIR, name + "_night.png"))


NIGHT_INK = (168, 164, 152)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    ink_rgb = (12, 9, 7)

    # Far plane: ghost (upper, faint, soft) and far (lower, a little firmer).
    W1, H1 = 416, 120
    ghost = render_plane(W1, H1, [(0.17, 0.46, 0.19), (0.50, 0.55, 0.19), (0.83, 0.48, 0.19)],
                         amp_frac=0.58, rough=0.12, ink=0.09, fade=0.0, seed=101,
                         y_base_frac=0.80, blur_1x=7.0, bleed=0.02, dry=False, fly=False,
                         edge_left=0.0, edge_right=0.0, base_fade=(0.70, 0.98))
    far = render_plane(W1, H1, [(0.14, 0.62, 0.17), (0.47, 0.78, 0.17), (0.80, 0.66, 0.17)],
                       amp_frac=0.88, rough=0.18, ink=0.19, fade=0.0, seed=202,
                       y_base_frac=0.97, blur_1x=3.5, bleed=0.04, dry=False, fly=False,
                       edge_left=0.0, edge_right=0.0, base_fade=(0.72, 0.98))
    write_pair(over(ghost, far), (70, 66, 60), "far_range", (120, 118, 110), 0.9)

    # Mid plane, second landmark: paler, softer, one tree or two.
    guest = render_plane(260, 190, [(0.42, 1.0, 0.16), (0.72, 0.52, 0.13)],
                         amp_frac=0.78, rough=0.22, ink=0.36, fade=0.0, seed=303,
                         blur_1x=1.2, cun_count=70, tree_prob=0.012, bleed=0.10,
                         edge_left=0.14, edge_right=0.14, base_fade=(0.70, 0.97),
                         tree_size=(5.0, 10.0), crown=0.16)
    write_pair(guest, ink_rgb, "guest_mountain", NIGHT_INK, 0.85)

    # Mid plane, strongest landmark: the hero. Benchmark mid ink .48, 1 px blur.
    host = render_plane(340, 260, [(0.47, 1.0, 0.14), (0.78, 0.60, 0.12), (0.20, 0.42, 0.11)],
                        amp_frac=0.80, rough=0.27, ink=0.62, fade=0.0, seed=404,
                        blur_1x=0.9, cun_count=150, tree_prob=0.020, bleed=0.14,
                        edge_left=0.12, edge_right=0.12, base_fade=(0.72, 0.98),
                        tree_size=(5.0, 13.0), crown=0.30)
    write_pair(host, ink_rgb, "host_mountain", NIGHT_INK, 0.80)

    # Foreground anchors: dark, textured, tree-lined. Left mass stays low so
    # the inscription keeps its upper-left void; right mass may rise higher.
    fg_left = render_plane(300, 200, [(0.02, 0.70, 0.17), (0.24, 0.64, 0.16),
                                      (0.45, 0.50, 0.12), (0.64, 0.34, 0.10)],
                           amp_frac=0.92, rough=0.30, ink=0.90, fade=0.03, seed=505,
                           blur_1x=0.5, cun_count=170, tree_prob=0.042, bleed=0.24,
                           edge_left=0.0, edge_right=0.22, base_fade=(0.90, 1.05),
                           tree_size=(6.0, 15.0), crown=0.25)
    write_pair(fg_left, (11, 8, 6), "fg_left", NIGHT_INK, 0.75)

    fg_right = render_plane(280, 180, [(0.98, 0.66, 0.14), (0.78, 0.82, 0.13),
                                       (0.56, 0.58, 0.12), (0.36, 0.36, 0.10)],
                            amp_frac=0.92, rough=0.28, ink=0.86, fade=0.02, seed=606,
                            blur_1x=0.5, cun_count=150, tree_prob=0.034, bleed=0.21,
                            edge_left=0.22, edge_right=0.0, base_fade=(0.90, 1.05),
                            tree_size=(6.0, 15.0), crown=0.25)
    write_pair(fg_right, (11, 8, 6), "fg_right", NIGHT_INK, 0.75)

    # Mist, paper-colored so it only ever erases ink: black at night.
    mist = organic_mist(416, 110, seed=1001, alpha=0.58)
    write_pair(mist, PAPER, "mist_band", (0, 0, 0), 1.0)
    write_pair(mist * 0.62, PAPER, "mist_band_lite", (0, 0, 0), 1.0)

    make_paper_grain(240, seed=99).save(os.path.join(OUT_DIR, "paper_grain.png"))

    print("layers written to", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
