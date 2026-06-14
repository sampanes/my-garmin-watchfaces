#!/usr/bin/env python
"""Generate the full sumi-e asset kit for the japanese-ink-heartrate face.

Strategy (2026-06-10 rewrite): instead of small abstract stamps composed at
runtime, author COMPLETE mountain paintings as PNGs. Each asset carries the
ink-wash gradient, facet shading, dry-brush streaks, flying-white ridge gaps,
mist-dissolved base, and tiny crowning pines that Garmin's Dc cannot produce.
Monkey C only places/scales them.

Outputs (RGBA, straight alpha, pre-colored — no runtime tinting needed):
    host_mountain.png   320x290  dark hero spire cluster (3 spires + pines)
    guest_mountain.png  250x210  paler 2-spire companion (authored mirrored)
    far_range.png       320x85   very pale atmospheric band
    mist_band.png       360x96   paper-colored erasure band
    shore_foreground.png 320x100 bottom-left dry-brush shore + grass ticks

All rendering happens at SS x supersample and is box-downsampled, which is
what gives edges their analog softness. Deterministic seeds throughout.
"""

import numpy as np
from PIL import Image, ImageFilter
import os

SS = 3  # supersample factor

OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..",
    "watch-faces", "japanese-ink-heartrate", "resources", "drawables")

# ---------------------------------------------------------------- noise utils

def smoothstep_t(t):
    return t * t * (3.0 - 2.0 * t)


def vnoise1(n, cell, seed, octaves=3, gain=0.55):
    """1-D value noise, output in [0,1], length n."""
    rng = np.random.default_rng(seed)
    out = np.zeros(n)
    amp, total = 1.0, 0.0
    c = float(cell)
    for o in range(octaves):
        k = max(int(np.ceil(n / c)) + 2, 2)
        pts = rng.random(k)
        x = np.arange(n) / c
        i0 = np.floor(x).astype(int)
        t = smoothstep_t(x - i0)
        out += amp * (pts[i0] * (1 - t) + pts[i0 + 1] * t)
        total += amp
        amp *= gain
        c = max(c * 0.5, 1.5)
    return out / total


def vnoise2(h, w, cell_y, cell_x, seed, octaves=3, gain=0.55):
    """2-D value noise, output in [0,1], shape (h, w)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((h, w))
    amp, total = 1.0, 0.0
    cy, cx = float(cell_y), float(cell_x)
    for o in range(octaves):
        ky = max(int(np.ceil(h / cy)) + 2, 2)
        kx = max(int(np.ceil(w / cx)) + 2, 2)
        grid = rng.random((ky, kx))
        ys = np.arange(h) / cy
        xs = np.arange(w) / cx
        y0 = np.floor(ys).astype(int)
        x0 = np.floor(xs).astype(int)
        ty = smoothstep_t(ys - y0)[:, None]
        tx = smoothstep_t(xs - x0)[None, :]
        g00 = grid[np.ix_(y0, x0)]
        g01 = grid[np.ix_(y0, x0 + 1)]
        g10 = grid[np.ix_(y0 + 1, x0)]
        g11 = grid[np.ix_(y0 + 1, x0 + 1)]
        top = g00 * (1 - tx) + g01 * tx
        bot = g10 * (1 - tx) + g11 * tx
        out += amp * (top * (1 - ty) + bot * ty)
        total += amp
        amp *= gain
        cy = max(cy * 0.5, 1.5)
        cx = max(cx * 0.5, 1.5)
    return out / total


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0 + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------- pine stamps

def draw_pine(alpha, cx, cy, size, rng, lean=0.0, dens=1.0):
    """Stamp a tiny sumi-e pine silhouette into `alpha` (float 0..1 array).

    cx, cy = base of trunk (supersampled coords). size = full height in
    supersampled px. Organic blob-cluster grammar: a leaning trunk hint plus
    3-5 irregular foliage clumps forming a loose cone — reads as the classic
    pine "tick" at 13-22 px without the barcode look of stacked ellipses.
    """
    h_img, w_img = alpha.shape
    yy, xx = np.mgrid[0:h_img, 0:w_img]
    trunk_h = size * (0.55 + 0.15 * rng.random())
    top_x = cx + lean * size * 0.55
    # trunk: a few short thick segments with curvature toward the lean
    steps = max(5, int(trunk_h / (1.5 * SS)))
    tw = max(1, int(0.045 * size) + 1)
    for i in range(steps):
        f = i / max(steps - 1, 1)
        x0 = int(cx + (top_x - cx) * f * f + rng.normal(0, 0.3 * SS))
        y0 = int(cy - trunk_h * f)
        for dx in range(-tw, tw + 1):
            x1 = x0 + dx
            if 0 <= x1 < w_img and 0 <= y0 < h_img:
                alpha[y0, x1] = min(1.0, alpha[y0, x1] + 0.85 * dens)
    # foliage: sparse irregular clumps + radiating needle ticks. The ticks
    # are what make it read "pine" instead of "boulder" at 14-20 px.
    n_cl = 2 + int(rng.integers(0, 2))
    for c in range(n_cl):
        f = c / max(n_cl - 1, 1)                  # 0 low .. 1 crown
        py = cy - trunk_h * (0.60 + 0.50 * f) + rng.normal(0, 0.05 * size)
        px = cx + (top_x - cx) * (0.60 + 0.50 * f) \
            + rng.normal(0, 0.08 * size) + (1 if c % 2 else -1) * 0.13 * size * (1 - f)
        cw = size * (0.40 - 0.16 * f) * (0.75 + 0.5 * rng.random())
        ch = cw * (0.34 + 0.14 * rng.random())
        d = ((xx - px) / (cw + 1e-9)) ** 2 + ((yy - py) / (ch + 1e-9)) ** 2
        clump = np.clip(1.15 - d, 0, 1) ** 0.8
        rag = rng.random((h_img, w_img)) * 0.65
        clump = np.clip(clump - rag * (d > 0.35), 0, 1)
        alpha += clump * 0.85 * dens
        # 2-4 needle ticks radiating outward-downward from the clump edge
        for tkn in range(2 + int(rng.integers(0, 3))):
            ang = rng.uniform(-0.45, 0.45) + (np.pi if rng.random() < 0.5 else 0.0)
            tl = cw * (0.7 + 0.7 * rng.random())
            steps_t = max(3, int(tl))
            for sti in range(steps_t):
                ft = sti / steps_t
                x1 = int(px + np.cos(ang) * tl * ft)
                y1 = int(py + abs(np.sin(ang)) * tl * 0.22 * ft + 0.3 * sti)
                if 0 <= x1 < w_img and 0 <= y1 < h_img:
                    alpha[y1, x1] = min(1.0, alpha[y1, x1] + 0.7 * dens * (1 - 0.5 * ft))
    np.clip(alpha, 0, 1, out=alpha)


def add_pines(alpha_layer, spots, rng, dens=1.0):
    """spots = list of (cx, cy, size_1x, lean). Coordinates at 1x scale."""
    for (cx, cy, size, lean) in spots:
        draw_pine(alpha_layer, cx * SS, cy * SS, size * SS, rng,
                  lean=lean, dens=dens)


# ------------------------------------------------------------ mountain maker

def spire_ridge(W, spires, seed):
    """Return ridge height profile h(x) in pixels (0 = base, + = up).

    spires: list of dicts {cx, h, w, q, pL, pR} at supersampled coords.
    Profile per spire: h * (1 - t^q)^p. High q (3-5) keeps the profile near
    full height until t ~ 0.7 then plunges — vertical-sided rock towers like
    the references, NOT cones. p < 1 flattens the crown slightly.
    """
    x = np.arange(W, dtype=float)
    ridge = np.zeros(W)
    owner = np.full(W, -1)
    side = np.zeros(W)  # -1 left of owning apex, +1 right
    for i, s in enumerate(spires):
        dx = x - s["cx"]
        t = np.clip(np.abs(dx) / s["w"], 0, 1)
        p = np.where(dx < 0, s["pL"], s["pR"])
        prof = s["h"] * (1.0 - t ** s["q"]) ** p
        better = prof > ridge
        ridge = np.where(better, prof, ridge)
        owner = np.where(better, i, owner)
        side = np.where(better, np.sign(dx) + (dx == 0), side)
    # craggy detail: ledge-y stepped noise + fine jitter, scaled by height
    n_med = vnoise1(W, 17 * SS, seed + 1, octaves=2) - 0.5
    n_ledge = np.round(vnoise1(W, 34 * SS, seed + 9, octaves=1) * 3.0) / 3.0 - 0.5
    n_fine = vnoise1(W, 5 * SS, seed + 2, octaves=2) - 0.5
    hgt = np.clip(ridge / (ridge.max() + 1e-9), 0.12, 1.0)
    detail = (n_med * 10 * SS + n_ledge * 12 * SS + n_fine * 3.5 * SS) * hgt
    ridge = np.maximum(ridge + detail, 0)
    return ridge, owner, side


def make_mountain(W1, H1, spires_1x, ink_rgb, seed,
                  density_mul=1.0, blur_1x=1.1, halo=0.16,
                  fade_top=0.58, fade_feather=0.30,
                  crown_k=0.085, body_depth=1.05, body_w=0.50,
                  pine_spots=None, pine_dens=1.0,
                  streak_strength=0.50, facet_strength=0.22,
                  edge_fade_frac=0.05):
    """Render one complete sumi-e mountain. Returns RGBA PIL Image (W1 x H1)."""
    W, H = W1 * SS, H1 * SS
    spires = [{"cx": s["cx"] * SS, "h": s["h"] * SS, "w": s["w"] * SS,
               "q": s["q"], "pL": s["pL"], "pR": s["pR"]} for s in spires_1x]
    ridge, owner, side = spire_ridge(W, spires, seed)
    ridge_y = H - 1 - ridge                       # screen y of ridgeline
    yy = np.arange(H, dtype=float)[:, None]
    xx = np.arange(W, dtype=float)[None, :]

    d = yy - ridge_y[None, :]                     # px below ridgeline (<0 = sky)
    inside = d >= 0
    Hloc = np.maximum(ridge[None, :], 14 * SS)    # local spire height

    # --- tonal core: crown (dark band at ridge) + broad body wash.
    # body uses a *milder* falloff so the rock face keeps real tone instead
    # of hollowing out two steps below the ridgeline.
    crown = np.exp(-np.clip(d, 0, None) / (crown_k * Hloc))
    body = np.clip(1.0 - d / (body_depth * Hloc), 0, 1) ** 1.1
    dens = (0.85 * crown + body_w * body) * inside

    # --- facet shading: each spire's right face darker, left lighter
    facet = 1.0 + facet_strength * side[None, :] * (0.40 + 0.60 * body)
    per_spire = 1.0 + 0.12 * np.where(owner[None, :] % 2 == 0, 1.0, -1.0)
    dens *= facet * per_spire

    # --- vertical dry-brush streaks (brush pulled downward), domain-warped.
    # Two scales: broad tonal bands + fine fibers. Strong warp keeps the
    # fibers wobbling so the face doesn't read as wood grain.
    warp = (vnoise1(H, 26 * SS, seed + 3, octaves=2) - 0.5) * 17 * SS
    xw = np.clip(xx + warp[:, None], 0, W - 1).astype(int)
    broad = vnoise1(W, 16 * SS, seed + 14, octaves=2)[xw]
    fine = vnoise1(W, 3.0 * SS, seed + 4, octaves=3, gain=0.66)[xw]
    streak = 0.65 * broad + 0.35 * fine
    dens *= (1.0 - streak_strength) + 2.2 * streak_strength * streak

    # --- cun texture: broken diagonal hatch over the upper rock faces
    cun = vnoise2(H, W, 2.6 * SS, 8.5 * SS, seed + 5, octaves=2)
    cun_mask = np.clip((cun - 0.52) * 6.0, 0, 1)
    dens += cun_mask * (0.34 * crown + 0.10 * body) * inside

    # --- flying white: occasional gaps right at the ridge stroke
    fly = vnoise1(W, 17 * SS, seed + 6, octaves=2)
    fly_cut = np.where(fly[None, :] > 0.74, 0.30, 1.0)
    ridge_band = np.exp(-np.clip(d, 0, None) / (0.030 * Hloc))
    dens *= 1.0 - (1.0 - fly_cut) * ridge_band

    # --- base dissolve into mist (noisy boundary), never reaches bitmap bottom
    fade_line = ridge_y[None, :] + fade_top * ridge[None, :] \
        + (vnoise1(W, 30 * SS, seed + 7, octaves=2)[None, :] - 0.5) * 0.18 * H
    fade = 1.0 - smoothstep(fade_line, fade_line + fade_feather * H, yy)
    dens *= fade

    # --- edge guards so the stamp never reveals its rectangle
    ef = edge_fade_frac * W
    dens *= smoothstep(0, ef, xx) * smoothstep(W, W - ef, xx)
    dens *= smoothstep(H, H * 0.93, yy)

    dens = np.clip(dens * density_mul, 0, 1)

    # --- pines BEFORE bleed-blur would soften them too much; stamp after blur.
    a_img = Image.fromarray((dens * 255).astype(np.uint8), "L")
    a_img = a_img.filter(ImageFilter.GaussianBlur(blur_1x * SS))
    a = np.asarray(a_img, dtype=float) / 255.0
    if halo > 0:
        halo_img = a_img.filter(ImageFilter.GaussianBlur(4.2 * SS))
        a = np.clip(a + halo * (np.asarray(halo_img, dtype=float) / 255.0), 0, 1)

    if pine_spots:
        pine_a = np.zeros_like(a)
        rng = np.random.default_rng(seed + 11)
        add_pines(pine_a, pine_spots, rng, dens=pine_dens)
        pine_a_img = Image.fromarray((pine_a * 255).astype(np.uint8), "L") \
            .filter(ImageFilter.GaussianBlur(0.45 * SS))
        pine_a = np.asarray(pine_a_img, dtype=float) / 255.0
        a = np.clip(a + pine_a * 1.1, 0, 1)

    # --- compose RGBA, downsample
    rgb = np.zeros((H, W, 3), dtype=np.uint8)
    rgb[..., 0], rgb[..., 1], rgb[..., 2] = ink_rgb
    out = np.dstack([rgb, (a * 255).astype(np.uint8)])
    img = Image.fromarray(out, "RGBA").resize((W1, H1), Image.LANCZOS)
    return img


# ------------------------------------------------------------------- helpers

def ridge_y_at(spires, x, H1):
    """1x-scale ridge screen-y at x for pine placement (mirrors spire_ridge)."""
    best = 0.0
    for s in spires:
        t = min(abs(x - s["cx"]) / s["w"], 1.0)
        p = s["pL"] if x < s["cx"] else s["pR"]
        prof = s["h"] * (1.0 - t ** s["q"]) ** p
        best = max(best, prof)
    return H1 - 1 - best


# --------------------------------------------------------------- band assets

def make_far_range(W1, H1, seed, ink_rgb=(150, 152, 146)):
    W, H = W1 * SS, H1 * SS
    yy = np.arange(H, dtype=float)[:, None]
    xx = np.arange(W, dtype=float)[None, :]
    prof = vnoise1(W, 60 * SS, seed, octaves=3)
    ridge = (0.25 + 0.55 * prof) * H * 0.9
    ridge_y = H - ridge
    d = yy - ridge_y[None, :]
    inside = d >= 0
    dens = (np.exp(-np.clip(d, 0, None) / (0.5 * H)) * 0.8 + 0.2) * inside
    fade = 1.0 - smoothstep(0.55 * H, 0.98 * H, yy)
    dens *= fade
    ef = 0.07 * W
    dens *= smoothstep(0, ef, xx) * smoothstep(W, W - ef, xx)
    dens = np.clip(dens * 0.46, 0, 1)
    a_img = Image.fromarray((dens * 255).astype(np.uint8), "L") \
        .filter(ImageFilter.GaussianBlur(2.6 * SS))
    a = np.asarray(a_img, dtype=float) / 255.0
    rgb = np.zeros((H, W, 3), dtype=np.uint8)
    rgb[..., 0], rgb[..., 1], rgb[..., 2] = ink_rgb
    out = np.dstack([rgb, (a * 255).astype(np.uint8)])
    return Image.fromarray(out, "RGBA").resize((W1, H1), Image.LANCZOS)


def make_mist_band(W1, H1, seed, rgb_col=(242, 238, 230)):
    """Mist colored EXACTLY like the paper fill so it is invisible over bare
    paper and only erases ink it overlaps. Lumpy drift, not a uniform band."""
    W, H = W1 * SS, H1 * SS
    yy = np.arange(H, dtype=float)[:, None]
    xx = np.arange(W, dtype=float)[None, :]
    lump = vnoise1(W, 48 * SS, seed, octaves=3)
    gaps = smoothstep(0.30, 0.62, vnoise1(W, 75 * SS, seed + 2, octaves=2))
    cy = H * (0.45 + 0.40 * (vnoise1(W, 70 * SS, seed + 1, octaves=2) - 0.5))
    thick = H * (0.24 + 0.34 * lump)
    dens = np.exp(-((yy - cy[None, :]) / (thick[None, :] + 1e-9)) ** 2)
    dens *= (0.25 + 0.95 * lump[None, :]) * gaps[None, :]
    ef = 0.10 * W
    dens *= smoothstep(0, ef, xx) * smoothstep(W, W - ef, xx)
    dens = np.clip(dens, 0, 1)
    a_img = Image.fromarray((dens * 255).astype(np.uint8), "L") \
        .filter(ImageFilter.GaussianBlur(3.0 * SS))
    a = np.asarray(a_img, dtype=float) / 255.0 * 0.95
    rgb = np.zeros((H, W, 3), dtype=np.uint8)
    rgb[..., 0], rgb[..., 1], rgb[..., 2] = rgb_col
    out = np.dstack([rgb, (a * 255).astype(np.uint8)])
    return Image.fromarray(out, "RGBA").resize((W1, H1), Image.LANCZOS)


def make_shore(W1, H1, seed, ink_rgb=(52, 44, 36)):
    """Bottom-left foreground: layered dry-brush shore strokes + grass ticks."""
    W, H = W1 * SS, H1 * SS
    yy = np.arange(H, dtype=float)[:, None]
    xx = np.arange(W, dtype=float)[None, :]
    dens = np.zeros((H, W))
    rng = np.random.default_rng(seed)
    # Overlapping wavy strokes that fuse into one dry-brush mass (separated
    # straight rows read as a barcode on-device).
    for i in range(4):
        wave = (vnoise1(W, 40 * SS, seed + 20 + i, octaves=2) - 0.5) * 0.16 * H
        cy = H * (0.50 + 0.115 * i) + wave[None, :]
        th = H * (0.115 - 0.012 * i)
        reach = W * (0.98 - 0.17 * i)
        body = np.exp(-((yy - cy) / th) ** 2)
        taper = np.clip(1.0 - xx / reach, 0, 1) ** 1.1
        streak = vnoise1(W, 7 * SS, seed + 10 + i, octaves=3, gain=0.65)[None, :]
        dens += body * taper * (0.70 + 0.55 * streak) * (1.0 - 0.16 * i)
    # sparse reed ticks on the top edge
    for g in range(5):
        gx = W * (0.05 + 0.16 * g) + rng.normal(0, 4 * SS)
        gy = H * 0.52 + rng.normal(0, 2 * SS)
        gh = H * (0.18 + 0.12 * rng.random())
        lean = rng.normal(0.22, 0.14)
        steps = int(gh)
        gw = max(2, int(0.6 * SS))
        for sgi in range(steps):
            x0 = int(gx + lean * sgi)
            y0 = int(gy - sgi)
            taper = 1.0 - 0.55 * (sgi / max(steps, 1))
            for dx in range(gw):
                x1 = x0 + dx
                if 0 <= x1 < W and 0 <= y0 < H:
                    dens[y0, x1] = min(1.0, dens[y0, x1] + 0.8 * taper)
    dens *= smoothstep(0, 0.02 * W, xx)  # tiny left guard
    dens *= smoothstep(H, H * 0.92, yy)
    dens = np.clip(dens * 0.92, 0, 1)
    a_img = Image.fromarray((dens * 255).astype(np.uint8), "L") \
        .filter(ImageFilter.GaussianBlur(1.4 * SS))
    a = np.asarray(a_img, dtype=float) / 255.0
    rgb = np.zeros((H, W, 3), dtype=np.uint8)
    rgb[..., 0], rgb[..., 1], rgb[..., 2] = ink_rgb
    out = np.dstack([rgb, (a * 255).astype(np.uint8)])
    return Image.fromarray(out, "RGBA").resize((W1, H1), Image.LANCZOS)


def make_paper_grain(size, seed):
    """Subtle washi fiber grain: low-freq mottle + sparse flecks + rim
    vignette. Max alpha kept tiny so it tones rather than speckles."""
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

    dark = np.clip(
        (mottle - 0.5) * 0.5 + (fibers - 0.5) * 0.25, 0, 1) * 0.055 \
        + flecks * 0.10 + vign * 0.05
    a = (np.clip(dark, 0, 0.16) * 255).astype(np.uint8)
    rgb = np.zeros((Hp, Wp, 3), dtype=np.uint8)
    rgb[..., 0], rgb[..., 1], rgb[..., 2] = (96, 84, 70)
    return Image.fromarray(np.dstack([rgb, a]), "RGBA")


# ----------------------------------------------------------------------- main

def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    # ---- HOST: tight massif — dominant tower + attached buttress + spur.
    # Tower q-values 3-4.5 give near-vertical rock walls like the references.
    W1, H1 = 320, 290
    host_spires = [
        {"cx": 158, "h": 250, "w": 60, "q": 4.2, "pL": 0.85, "pR": 0.95},  # main tower
        {"cx": 116, "h": 196, "w": 54, "q": 3.4, "pL": 0.95, "pR": 0.90},  # buttress
        {"cx": 212, "h": 132, "w": 52, "q": 3.0, "pL": 0.90, "pR": 1.10},  # right spur
        {"cx": 64,  "h": 88,  "w": 46, "q": 2.6, "pL": 1.00, "pR": 0.95},  # left toe
    ]
    pine_spots = []
    for (px, sz, ln) in [(150, 19, -0.35), (170, 15, 0.4), (122, 13, -0.25),
                         (210, 14, 0.35)]:
        py = ridge_y_at(host_spires, px, H1)
        pine_spots.append((px, py + 3, sz, ln))
    host = make_mountain(
        W1, H1, host_spires, ink_rgb=(44, 38, 31), seed=70,
        density_mul=1.0, blur_1x=0.8, halo=0.05,
        fade_top=0.66, fade_feather=0.24,
        crown_k=0.07, body_w=0.46,
        pine_spots=pine_spots, pine_dens=1.0,
        streak_strength=0.60, facet_strength=0.26)
    host.save(os.path.join(OUT_DIR, "host_mountain.png"))

    # ---- GUEST: single paler tower + low shoulder, one pine
    W1g, H1g = 250, 210
    guest_spires = [
        {"cx": 100, "h": 170, "w": 56, "q": 3.6, "pL": 0.90, "pR": 1.00},
        {"cx": 168, "h": 92,  "w": 56, "q": 2.7, "pL": 0.95, "pR": 1.05},
    ]
    g_pines = []
    for (px, sz, ln) in [(94, 14, 0.35), (166, 11, -0.3)]:
        py = ridge_y_at(guest_spires, px, H1g)
        g_pines.append((px, py + 3, sz, ln))
    guest = make_mountain(
        W1g, H1g, guest_spires, ink_rgb=(104, 98, 89), seed=41,
        density_mul=0.60, blur_1x=1.2, halo=0.10,
        fade_top=0.62, fade_feather=0.28,
        crown_k=0.085, body_w=0.50,
        pine_spots=g_pines, pine_dens=0.70,
        streak_strength=0.50, facet_strength=0.20)
    guest.save(os.path.join(OUT_DIR, "guest_mountain.png"))

    # ---- bands + paper
    make_far_range(320, 85, seed=7).save(os.path.join(OUT_DIR, "far_range.png"))
    mist = make_mist_band(360, 96, seed=19)
    mist.save(os.path.join(OUT_DIR, "mist_band.png"))
    # Garmin drawScaledBitmap has no global-alpha knob, so the lighter
    # between-planes mist pass is baked as a separate asset.
    lite = mist.copy()
    lite.putalpha(lite.getchannel("A").point(lambda v: int(v * 0.62)))
    lite.save(os.path.join(OUT_DIR, "mist_band_lite.png"))
    make_shore(320, 100, seed=33).save(os.path.join(OUT_DIR, "shore_foreground.png"))
    # Grain authored small and upscaled on-device: subtle noise survives the
    # stretch and the decoded-bitmap cost drops ~5x vs authoring at 416.
    make_paper_grain(240, seed=99).save(os.path.join(OUT_DIR, "paper_grain.png"))

    print("kit written to", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
