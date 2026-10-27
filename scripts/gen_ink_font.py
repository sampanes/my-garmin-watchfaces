#!/usr/bin/env python
"""Author the inscription font: brush-written digits baked as a BMFont.

The painting's planes come out of gen_ink_layers.py; the time was still set
in Garmin's Roboto on top of them. This script writes the ten digits and the
colon with the same brush the planes use. Each glyph is a hand-set stroke
skeleton (the order and direction a calligrapher would write it) rendered as
a bundle of bristles: the brush is set down with a pressed head that pools
ink, swells through the body, and either lifts while moving (tapered tail)
or stops bluntly; outer bristles are lighter and some run dry into flying
white; the finished strokes bleed a little into the paper fibers.

Output is a BMFont text descriptor plus a one-row PNG atlas, the pair the
Connect IQ resource compiler loads from resources/fonts/fonts.xml.

    ink_digits.fnt / ink_digits.png    cap 40 px, line height 54, "0123456789:"
    seal_digits.fnt / seal_digits.png  cap 15 px, line height 19, carved style
                                       for the vermillion HR seal

Atlas pixels carry the coverage in BOTH the alpha and the gray channels
(premultiplied white), so a reader that keys on alpha and one that keys on
luminance see the same glyph.

Rendering happens at SS x supersample and is LANCZOS-downsampled. Every
random draw is seeded: regeneration is byte-identical.

Usage: python scripts/gen_ink_font.py [--sheet out.png]
"""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from gen_ink_layers import over, smoothstep, vnoise, vnoise2  # noqa: E402

SS = 4
PAPER = (242, 238, 230)
FONT_DIR = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate",
                        "resources", "fonts")

EM_W = 0.64        # glyph box width as a fraction of the cap height
PAD = 10           # 1x canvas padding around the box (heads and bleed spill)
N_BRISTLES = 16


# ------------------------------------------------------------ skeletons
# Glyph box: x in [0, 1] spans EM_W * cap, y in [0, 1] runs cap top to
# baseline. A stroke is one or more segments (a corner sits between
# segments; each segment is Catmull-Rom smoothed) plus how the brush lands
# and leaves:
#   head "press": set down, ink pools    "land": arrives moving, thin
#   tail "stop":  blunt, slight pool     "taper": lifts while moving

def S(*segs, head="press", tail="taper", w=1.0):
    return {"segs": [list(s) for s in segs], "head": head, "tail": tail, "w": w}


GLYPHS = {
    "0": [S([(0.34, 0.03), (0.16, 0.14), (0.07, 0.38), (0.08, 0.66), (0.19, 0.90),
             (0.35, 0.98), (0.51, 0.88), (0.58, 0.62), (0.56, 0.34), (0.47, 0.11),
             (0.38, 0.05)], head="press", tail="taper")],
    "1": [S([(0.12, 0.17), (0.23, 0.09), (0.34, 0.02)],
            [(0.34, 0.02), (0.35, 0.45), (0.35, 0.98)], head="land", tail="stop")],
    "2": [S([(0.09, 0.26), (0.15, 0.10), (0.31, 0.02), (0.49, 0.07), (0.57, 0.22),
             (0.50, 0.42), (0.32, 0.64), (0.14, 0.82), (0.07, 0.95)],
            [(0.07, 0.95), (0.32, 0.96), (0.60, 0.95)], head="land", tail="stop")],
    "3": [S([(0.10, 0.15), (0.20, 0.04), (0.38, 0.02), (0.54, 0.10), (0.55, 0.28),
             (0.42, 0.43), (0.31, 0.47)], head="land", tail="taper"),
          S([(0.29, 0.47), (0.46, 0.50), (0.58, 0.63), (0.57, 0.82), (0.43, 0.97),
             (0.24, 0.97), (0.09, 0.86)], head="press", tail="taper")],
    "4": [S([(0.44, 0.02), (0.31, 0.25), (0.17, 0.50), (0.04, 0.72)],
            [(0.04, 0.72), (0.34, 0.72), (0.64, 0.71)], head="land", tail="stop", w=0.55),
          S([(0.48, 0.16), (0.48, 0.60), (0.48, 0.98)], head="land", tail="stop", w=0.85)],
    "5": [S([(0.21, 0.04), (0.40, 0.03), (0.59, 0.03)], head="land", tail="stop", w=0.9),
          S([(0.18, 0.03), (0.15, 0.24), (0.11, 0.46)],
            [(0.11, 0.46), (0.27, 0.39), (0.45, 0.42), (0.58, 0.57), (0.57, 0.79),
             (0.43, 0.96), (0.23, 0.97), (0.08, 0.87)], head="press", tail="taper")],
    "6": [S([(0.52, 0.03), (0.36, 0.11), (0.20, 0.30), (0.10, 0.52), (0.08, 0.75),
             (0.18, 0.93), (0.36, 0.98), (0.53, 0.90), (0.58, 0.72), (0.50, 0.56),
             (0.33, 0.50), (0.17, 0.57), (0.10, 0.70)], head="land", tail="taper")],
    "7": [S([(0.07, 0.06), (0.31, 0.03), (0.58, 0.03)],
            [(0.58, 0.03), (0.49, 0.28), (0.36, 0.62), (0.25, 0.97)],
            head="press", tail="taper")],
    "8": [S([(0.50, 0.12), (0.40, 0.03), (0.22, 0.04), (0.12, 0.17), (0.15, 0.33),
             (0.32, 0.45), (0.50, 0.57), (0.58, 0.75), (0.48, 0.94), (0.28, 0.98),
             (0.10, 0.89), (0.08, 0.70), (0.20, 0.55), (0.36, 0.45), (0.50, 0.33),
             (0.52, 0.17), (0.45, 0.07)], head="press", tail="taper")],
    "9": [S([(0.56, 0.28), (0.49, 0.09), (0.32, 0.02), (0.14, 0.09), (0.08, 0.28),
             (0.15, 0.45), (0.33, 0.51), (0.50, 0.45), (0.57, 0.30), (0.57, 0.50),
             (0.51, 0.74), (0.37, 0.92), (0.17, 0.98)], head="press", tail="taper")],
    ":": [S([(0.14, 0.30), (0.27, 0.41)], head="press", tail="stop", w=1.15),
          S([(0.14, 0.68), (0.27, 0.79)], head="press", tail="stop", w=1.15)],
}
ORDER = "0123456789:"


# ------------------------------------------------------------ paths

def catmull_rom(pts, per=24):
    """Centripetal-free Catmull-Rom through pts (endpoints duplicated)."""
    p = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(per):
            t = k / per
            t2, t3 = t * t, t * t * t
            x = 0.5 * (2 * p1[0] + (-p0[0] + p2[0]) * t
                       + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2
                       + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * (2 * p1[1] + (-p0[1] + p2[1]) * t
                       + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2
                       + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(p[-2])
    return out


def resample(path, step):
    """Uniform arc-length resampling of an (n,2) path."""
    d = np.sqrt(((path[1:] - path[:-1]) ** 2).sum(axis=1))
    s = np.concatenate([[0.0], np.cumsum(d)])
    total = s[-1]
    n = max(int(total / step) + 1, 3)
    u = np.linspace(0.0, total, n)
    return np.stack([np.interp(u, s, path[:, 0]), np.interp(u, s, path[:, 1])], axis=1)


def stroke_path(stroke, cap):
    pts = []
    for seg in stroke["segs"]:
        pts.extend(catmull_rom(seg))
    arr = np.array(pts, dtype=float)
    arr[:, 0] = (PAD + arr[:, 0] * EM_W * cap) * SS
    arr[:, 1] = (PAD + arr[:, 1] * cap) * SS
    return resample(arr, 0.5 * SS)


# ------------------------------------------------------------ pressure

def pressure(t, head, tail, seed):
    body = 0.70 + 0.30 * np.sin(np.pi * t) ** 0.6
    if head == "press":
        p = np.maximum(body, np.exp(-((t - 0.04) / 0.07) ** 2))
        p = p * smoothstep(0.0, 0.02, t)
    else:
        p = body * smoothstep(0.0, 0.22, t)
    if tail == "taper":
        p = p * (1.0 - smoothstep(0.62, 1.0, t)) ** 0.9
    else:
        p = np.maximum(p, 0.92 * np.exp(-((t - 0.96) / 0.05) ** 2))
        p = p * (1.0 - smoothstep(0.985, 1.0, t))
    wobble = vnoise(t * 7.0 + seed * 0.37, seed + 300)
    return np.clip(p * (1.0 + 0.22 * (wobble - 0.5)), 0.0, 1.0)


# ------------------------------------------------------------ brush

def draw_bundle(canvas, path, hw, rng, *, n_bristles=N_BRISTLES, dry=True,
                edge_light=0.30, a_lo=0.55):
    """Lay a bristle bundle along path. hw = half-width per sample (SS px)."""
    H, W = canvas.shape
    n = len(path)
    t = np.linspace(0.0, 1.0, n)
    tang = np.gradient(path, axis=0)
    tang /= np.maximum(np.linalg.norm(tang, axis=1), 1e-6)[:, None]
    nrm = np.stack([-tang[:, 1], tang[:, 0]], axis=1)
    if n_bristles == 1:
        us = np.array([0.0])
    else:
        us = np.linspace(-1.0, 1.0, n_bristles) + (rng.random(n_bristles) - 0.5) * (0.6 / n_bristles)
    for u in us:
        a_b = (a_lo + (1.0 - a_lo) * rng.random()) * (1.0 - edge_light * abs(u))
        if dry:
            t_dry = 0.30 + rng.random() * 1.1
            a_t = a_b * (1.0 - 0.9 * smoothstep(t_dry, t_dry + 0.25, t))
        else:
            a_t = np.full(n, a_b)
        pos = path + nrm * (u * hw * 0.95)[:, None]
        wb = np.maximum(1.0, 2.0 * hw / max(n_bristles, 1) * 1.7) if n_bristles > 1 else 2.0 * hw
        im = Image.new("L", (W, H), 0)
        d = ImageDraw.Draw(im)
        for k in range(n - 1):
            a = int(255 * min(a_t[k], 1.0))
            if a <= 0:
                continue
            wk = max(1, int(round(wb[k])))
            d.line([tuple(pos[k]), tuple(pos[k + 1])], fill=a, width=wk)
            r = wk / 2.0
            d.ellipse([pos[k, 0] - r, pos[k, 1] - r, pos[k, 0] + r, pos[k, 1] + r], fill=a)
        canvas = over(canvas, np.asarray(im, dtype=float) / 255.0)
    return canvas


def soft_disc(canvas, cx, cy, r, alpha, blur):
    H, W = canvas.shape
    im = Image.new("L", (W, H), 0)
    ImageDraw.Draw(im).ellipse([cx - r, cy - r, cx + r, cy + r], fill=int(255 * alpha))
    im = im.filter(ImageFilter.GaussianBlur(blur))
    return over(canvas, np.asarray(im, dtype=float) / 255.0)


def render_glyph(ch, cap, seed, style="ink"):
    """Returns the glyph's alpha at 1x on a (cap + 2 PAD) canvas."""
    W1, H1 = int(round(EM_W * cap + 2 * PAD)), cap + 2 * PAD
    W, H = W1 * SS, H1 * SS
    canvas = np.zeros((H, W))
    rng = np.random.default_rng(seed)
    for si, st in enumerate(GLYPHS[ch]):
        path = stroke_path(st, cap)
        t = np.linspace(0.0, 1.0, len(path))
        if style == "ink":
            p = pressure(t, st["head"], st["tail"], seed + si)
            hw = 0.5 * (0.045 + (0.20 - 0.045) * p) * cap * SS * st["w"]
            canvas = draw_bundle(canvas, path, hw, rng)
            if st["head"] == "press":
                canvas = soft_disc(canvas, path[0, 0], path[0, 1], hw.max() * 1.05, 0.80, 0.6 * SS)
        else:
            # Carved seal script: one even stroke, no pressure, no dry brush.
            hw = np.full(len(path), 0.5 * 0.17 * cap * SS * st["w"])
            canvas = draw_bundle(canvas, path, hw, rng, n_bristles=1, dry=False,
                                 edge_light=0.0, a_lo=1.0)
    if style == "ink":
        a_img = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "L")
        bleed = np.asarray(a_img.filter(ImageFilter.GaussianBlur(1.1 * SS)), dtype=float) / 255.0
        canvas = over(canvas, np.clip(bleed - 0.04, 0, 1) * 0.40)
        fiber = vnoise2(H, W, 2.2 * SS, 2.2 * SS, seed + 9, octaves=2)
        canvas = canvas * (0.88 + 0.12 * fiber)
    else:
        # Chipped edges: the stamp's carving and uneven inking.
        chip = vnoise2(H, W, 1.3 * SS, 1.3 * SS, seed + 9, octaves=2)
        canvas = np.clip(canvas - np.clip(chip - 0.62, 0, 1) * 1.6, 0, 1)
    out = Image.fromarray((np.clip(canvas, 0, 1) * 255).astype(np.uint8), "L") \
        .resize((W1, H1), Image.LANCZOS)
    return np.asarray(out, dtype=float) / 255.0


# ------------------------------------------------------------ BMFont

def build_font(name, cap, top_margin, bearing, seed0, style):
    line_h = cap + 2 * top_margin
    glyphs = []
    for i, ch in enumerate(ORDER):
        a = render_glyph(ch, cap, seed0 + i * 11, style)
        ys, xs = np.where(a > 0.012)
        y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
        yoff = int(y0) - (PAD - top_margin)
        if yoff < 0:                      # spilled above the line: clip
            y0 -= yoff
            yoff = 0
        if y1 > PAD - top_margin + line_h:
            y1 = PAD - top_margin + line_h
        bmp = a[y0:y1, x0:x1]
        glyphs.append({"ch": ch, "bmp": bmp, "xoff": bearing, "yoff": yoff,
                       "adv": bmp.shape[1] + 2 * bearing})
    atlas_w = sum(g["bmp"].shape[1] + 1 for g in glyphs) + 1
    atlas_h = max(g["bmp"].shape[0] for g in glyphs) + 2
    atlas = np.zeros((atlas_h, atlas_w))
    x = 1
    for g in glyphs:
        h, w = g["bmp"].shape
        atlas[1:1 + h, x:x + w] = g["bmp"]
        g["x"], g["y"] = x, 1
        x += w + 1
    cov = (np.clip(atlas, 0, 1) * 255).astype(np.uint8)
    rgba = np.dstack([cov, cov, cov, cov])
    os.makedirs(FONT_DIR, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(os.path.join(FONT_DIR, name + ".png"))

    lines = [
        'info face="%s" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 '
        'smooth=1 aa=1 padding=0,0,0,0 spacing=1,1 outline=0' % (name, cap),
        'common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 '
        'alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4' % (line_h, top_margin + cap, atlas_w, atlas_h),
        'page id=0 file="%s.png"' % name,
        'chars count=%d' % len(glyphs),
    ]
    for g in glyphs:
        h, w = g["bmp"].shape
        lines.append('char id=%d x=%d y=%d width=%d height=%d xoffset=%d yoffset=%d '
                     'xadvance=%d page=0 chnl=15'
                     % (ord(g["ch"]), g["x"], g["y"], w, h, g["xoff"], g["yoff"], g["adv"]))
    lines.append("kernings count=0")
    with open(os.path.join(FONT_DIR, name + ".fnt"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return {"name": name, "line_h": line_h, "glyphs": {g["ch"]: g for g in glyphs}}


# ------------------------------------------------------------ sheet

def draw_string(img, font, text, cx, cy, rgb, scale=1):
    """Paint text centered at (cx, cy) with the baked glyphs (preview only)."""
    adv = sum(font["glyphs"][c]["adv"] for c in text) * scale
    pen = cx - adv / 2.0
    top = cy - font["line_h"] * scale / 2.0
    for c in text:
        g = font["glyphs"][c]
        h, w = g["bmp"].shape
        a = Image.fromarray((g["bmp"] * 255).astype(np.uint8), "L")
        if scale != 1:
            a = a.resize((w * scale, h * scale), Image.LANCZOS)
        tile = Image.new("RGBA", a.size, rgb + (255,))
        tile.putalpha(a)
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        layer.paste(tile, (int(round(pen + g["xoff"] * scale)), int(round(top + g["yoff"] * scale))))
        img.alpha_composite(layer)
        pen += g["adv"] * scale
    return img


def sheet(ink, seal, path):
    """Every glyph at 2x on paper, plus the inscription at 1x, for a taste pass."""
    Wp, Hp = 760, 420
    img = Image.new("RGBA", (Wp, Hp), PAPER + (255,))
    ink_rgb = (24, 18, 14)
    draw_string(img, ink, "0123456789:", Wp // 2, 110, ink_rgb, scale=2)
    draw_string(img, ink, "12:42", 150, 270, ink_rgb)
    draw_string(img, ink, "7", 300, 240, ink_rgb)
    draw_string(img, ink, "08", 300, 300, ink_rgb)
    draw_string(img, ink, "10", 400, 240, ink_rgb)
    draw_string(img, ink, "59", 400, 300, ink_rgb)
    d = ImageDraw.Draw(img, "RGBA")
    for i, hr in enumerate(["62", "128", "95"]):
        sx, sy, sz = 520 + i * 70, 250, 35
        d.rounded_rectangle([sx, sy, sx + sz, sy + sz], radius=sz // 7, fill=(176, 52, 38, 235))
        draw_string(img, seal, hr, sx + sz / 2.0, sy + sz / 2.0, (244, 238, 226))
    draw_string(img, seal, "0123456789", 600, 330, ink_rgb, scale=2)
    img.convert("RGB").save(path)


def main(argv):
    ink = build_font("ink_digits", cap=40, top_margin=7, bearing=3, seed0=7000, style="ink")
    seal = build_font("seal_digits", cap=15, top_margin=2, bearing=1, seed0=9000, style="seal")
    print("fonts written to", os.path.abspath(FONT_DIR))
    for f in (ink, seal):
        advs = " ".join("%s:%d" % (c, g["adv"]) for c, g in f["glyphs"].items())
        print("  %s lineHeight=%d advances %s" % (f["name"], f["line_h"], advs))
    if "--sheet" in argv:
        out = argv[argv.index("--sheet") + 1]
        sheet(ink, seal, out)
        print("sheet ->", os.path.abspath(out))


if __name__ == "__main__":
    main(sys.argv)
