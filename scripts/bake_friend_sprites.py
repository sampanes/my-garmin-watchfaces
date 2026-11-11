"""Bake Friend's creature sprites and belly emblems from the generator sheets.

The sheets in garmin-pet/art/sheets/ are the source (one pose sheet per
character and one emblem sheet, all color on black; see PROMPTS.md there).
Everything the watch needs is decided here, so the watch only copies pixels:

  - each pose is cut out of the black, cropped and shrunk to the size it is
    drawn at (a home size and a card size);
  - the six colorways are made here by swapping the hue of the blue body, so
    the watch never tints anything;
  - the poses of one character in one color and one size are packed into one
    strip, loaded once and drawn with setClip + drawBitmap;
  - every pose carries its foot anchor and the middle of its belly patch;
  - each emblem is one small strip: six colorways by three brightness levels,
    at both sizes.

Writes (all generated, never edited by hand):

    garmin-pet/probes/wrist-diary/resources/drawables/pet_<name>_<color>.png      home size
    garmin-pet/probes/wrist-diary/resources/drawables/pet_<name>_<color>_s.png    card size
    garmin-pet/probes/wrist-diary/resources/drawables/emblem_<name>.png
    garmin-pet/probes/wrist-diary/resources/drawables/sprites.xml
    garmin-pet/probes/wrist-diary/source/FriendSpriteTable.mc

    python scripts/bake_friend_sprites.py            # rebuild all of the above
    python scripts/bake_friend_sprites.py --check    # the committed files match the sheets
    python scripts/bake_friend_sprites.py --contact DIR   # also write review sheets

Needs numpy and Pillow.
"""
import argparse
import io
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SHEETS = os.path.join(REPO, "garmin-pet", "art", "sheets")
APP = os.path.join(REPO, "garmin-pet", "probes", "wrist-diary")
DRAWABLES = os.path.join(APP, "resources", "drawables")
TABLE = os.path.join(APP, "source", "FriendSpriteTable.mc")
XML = os.path.join(DRAWABLES, "sprites.xml")

# The colorways, in the order of FriendArt's palettes: body, shade, belly.
PALETTES = [
    ("mint", 0x6ED6A8, 0x3E9C78, 0xC8F5E0),
    ("peach", 0xFFB15C, 0xD9822B, 0xFFE2B8),
    ("sky", 0x6EC1FF, 0x3A8BD1, 0xCDEBFF),
    ("lilac", 0xB79CFF, 0x8468D6, 0xE4DAFF),
    ("sun", 0xF2D550, 0xC9A21E, 0xFFF3B8),
    ("rose", 0xFF8FAF, 0xD65C82, 0xFFD6E2),
]

# The twelve pose slots every character answers to, in sheet order.
SLOTS = ["idle", "breathe", "droop", "back", "crouch", "hop", "cheer", "flex",
         "run_a", "run_b", "effort", "asleep"]
SLOT_BACK = 3
SLOT_ASLEEP = 11

# name, sheet, columns, rows, height of the idle pose on the watch (home
# size), and which sheet cell stands in each slot. The hatchling's sheet has
# eight poses (idle, breathe, droop, back / crouch, hop, strain, asleep), so
# some of its slots share a cell.
PETS = [
    ("nub", "2026-11-10_body-nub-b.png", 4, 2, 106, [0, 1, 2, 3, 4, 5, 5, 6, 4, 5, 6, 7]),
    ("sprig", "2026-11-10_body-sprig-b.png", 4, 3, 140, list(range(12))),
    ("dash", "2026-11-10_body-dash-b.png", 4, 3, 158, list(range(12))),
    ("chonk", "2026-11-10_body-chonk-b.png", 4, 3, 150, list(range(12))),
    ("scamp", "2026-11-10_body-scamp-b.png", 4, 3, 154, list(range(12))),
]
SMALL = 52          # the card size, as a percentage of the home size

EMBLEM_SHEET = "2026-11-10_emblems-b.png"
EMBLEMS = ["heart", "star", "leaf", "swirl", "paw", "apple", "mountain", "wing",
           "crown", "bolt", "flame", "dumbbell", "sun", "moon", "flower", "gem"]
EMBLEM_PX = 30      # the longer side of an emblem at home size
EMBLEM_PAD = 4      # room around it for the glow
EMBLEM_LEVELS = 3   # dull, steady, glowing
GLOW = 0xFFC83D
GLOW_CORE = 0xFFF6D6

DARK = 40           # a channel below this is the sheet's black
COLORS = 128        # colors (with their alpha) kept in each baked image


# ------------------------------------------------------------------ pixels

def rgb_of(color):
    return ((color >> 16) & 255, (color >> 8) & 255, color & 255)


def to_hsv(rgb):
    """rgb in 0..1, shape (..., 3) -> h in degrees, s, v."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    v = rgb.max(axis=-1)
    c = v - rgb.min(axis=-1)
    safe = np.where(c == 0, 1.0, c)
    h = np.where(v == r, ((g - b) / safe) % 6,
                 np.where(v == g, (b - r) / safe + 2, (r - g) / safe + 4))
    h = np.where(c == 0, 0.0, h) * 60.0
    s = np.where(v == 0, 0.0, c / np.where(v == 0, 1.0, v))
    return h, s, v


def from_hsv(h, s, v):
    h6 = (h % 360.0) / 60.0
    c = v * s
    x = c * (1 - np.abs(h6 % 2 - 1))
    z = np.zeros_like(c)
    i = np.floor(h6).astype(int) % 6
    r = np.choose(i, [c, x, z, z, x, c])
    g = np.choose(i, [x, c, c, x, z, z])
    b = np.choose(i, [z, z, x, c, c, x])
    m = v - c
    return np.stack([r + m, g + m, b + m], axis=-1)


def runs(flags, gap, least):
    """[start, end) spans of True in a 1-D array, joined across short gaps."""
    spans = []
    start = None
    for i, on in enumerate(flags):
        if on and start is None:
            start = i
        elif not on and start is not None:
            spans.append([start, i])
            start = None
    if start is not None:
        spans.append([start, len(flags)])
    joined = []
    for span in spans:
        if joined and span[0] - joined[-1][1] < gap:
            joined[-1][1] = span[1]
        else:
            joined.append(span)
    return [s for s in joined if s[1] - s[0] >= least]


def split_grid(ink, cols, rows, gap, margin=6):
    """The cells of a sheet, found from the black between them: row, column order."""
    bands = runs(ink.any(axis=1), gap, 20)
    if len(bands) != rows:
        raise SystemExit("expected %d rows of art, found %d" % (rows, len(bands)))
    boxes = []
    for top, bottom in bands:
        spans = runs(ink[top:bottom].any(axis=0), gap, 20)
        if len(spans) != cols:
            raise SystemExit("expected %d cells in a row, found %d" % (cols, len(spans)))
        for left, right in spans:
            boxes.append((max(left - margin, 0), max(top - margin, 0),
                          min(right + margin, ink.shape[1]), min(bottom + margin, ink.shape[0])))
    return boxes


def outside_of(dark):
    """The dark pixels joined to the border: the sheet's background, not an eye."""
    h, w = dark.shape
    padded = np.zeros((h + 2, w + 2), dtype=np.uint8)
    padded[1:-1, 1:-1] = np.where(dark, 0, 255)
    img = Image.fromarray(padded, "L").copy()
    ImageDraw.floodfill(img, (0, 0), 128)
    return np.asarray(img)[1:-1, 1:-1] == 128


def cut_out(cell):
    """A cell of the sheet (uint8 RGB) as straight-alpha float RGBA in 0..1.

    The sheet is color on black, so along the outline a pixel is the art's
    color dimmed toward black. Reading that dimming as alpha and brightening
    the color back gives a cutout that looks the same on black and has a
    clean edge on anything else.
    """
    rgb = cell.astype(np.float32) / 255.0
    peak = rgb.max(axis=2)
    outside = outside_of(peak < DARK / 255.0)
    alpha = np.where(outside, 0.0, 1.0).astype(np.float32)

    peak8 = Image.fromarray((peak * 255).astype(np.uint8), "L")
    around = np.asarray(peak8.filter(ImageFilter.MaxFilter(7))).astype(np.float32) / 255.0
    near = np.asarray(Image.fromarray((outside * 255).astype(np.uint8), "L")
                      .filter(ImageFilter.MaxFilter(5))) > 0
    rim = near & ~outside & (around > 0)
    cover = np.clip(peak / np.where(around > 0, around, 1.0), 0.0, 1.0)
    alpha = np.where(rim, cover, alpha)
    lift = np.where(rim & (cover > 0.05), 1.0 / np.maximum(cover, 0.05), 1.0)
    rgb = np.clip(rgb * lift[..., None], 0.0, 1.0)
    return np.dstack([rgb, alpha])


def body_mask(h, s, v):
    return (h > 185) & (h < 235) & (s > 0.10) & (v > 0.2)


def body_tone(cells):
    """The sheet's own body blue: median hue, saturation and value of the solid body."""
    hs, ss, vs = [], [], []
    for cell in cells:
        h, s, v = to_hsv(cell[..., :3])
        solid = body_mask(h, s, v) & (s > 0.4) & (cell[..., 3] > 0.99)
        hs.append(h[solid])
        ss.append(s[solid])
        vs.append(v[solid])
    return (float(np.median(np.concatenate(hs))), float(np.median(np.concatenate(ss))),
            float(np.median(np.concatenate(vs))))


def recolor(cell, tone, body):
    """The cell with its blue body turned to a colorway's body color.

    Only the hue of the blue pixels moves; their shading and the pale belly
    scale with it, so one sheet gives every colorway. A colorway darker than
    the sheet's blue darkens the solid body in full and the pale belly less,
    so the belly stays light. The cheeks are pink: on a pink or orange body
    they are deepened so they still read.
    """
    th, ts, tv = (float(x) for x in to_hsv(np.array(rgb_of(body), dtype=np.float32) / 255.0))
    sh, ss, sv = tone
    h, s, v = to_hsv(cell[..., :3])
    blue = body_mask(h, s, v)
    h2 = np.where(blue, th + (h - sh), h)
    s2 = np.where(blue, np.clip(s * ts / ss, 0.0, 1.0), s)
    solid = np.clip(s / ss, 0.0, 1.0)
    lit = np.clip(v * (1.0 - solid + solid * tv / sv), 0.0, 1.0)
    v2 = np.where(blue, lit, v)

    # Where a cheek fades into the body the sheet's pixels are violet (pink
    # over blue). Rebuild those as pink over the new body color.
    fringe = (h >= 235) & (h < 325) & (s > 0.10) & (v > 0.6)
    mix = np.clip((h - 235.0) / 90.0, 0.0, 1.0)
    warm = abs(((th - 346.0 + 180.0) % 360.0) - 180.0) < 60.0
    cheek = ((h >= 325) | (h < 15)) & (s > 0.12) & (s < 0.6) & (v > 0.8)
    if warm:
        s2 = np.where(cheek, np.clip(s * 1.9, 0.0, 0.8), s2)
        v2 = np.where(cheek, v * 0.93, v2)
    out = from_hsv(h2, s2, v2)
    if fringe.any():
        base = from_hsv(np.full_like(h, th), np.full_like(s, ts), np.clip(v * tv / sv, 0, 1))
        pink = from_hsv(np.full_like(h, 346.0), np.full_like(s, 0.6 if warm else 0.33),
                        np.full_like(v, 0.93 if warm else 1.0))
        blend = base * (1 - mix[..., None]) + pink * mix[..., None]
        out = np.where(fringe[..., None], blend, out)
    return np.dstack([out, cell[..., 3]])


def to_image(cell):
    return Image.fromarray((np.clip(cell, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def shrink(img, scale):
    """Shrunk to watch pixels (Pillow blends RGBA with the alpha weighed in)."""
    w = max(1, int(round(img.width * scale)))
    h = max(1, int(round(img.height * scale)))
    out = np.array(img.resize((w, h), Image.LANCZOS))
    out[out[..., 3] < 10] = 0
    return Image.fromarray(out, "RGBA")


def largest_blob(mask):
    """Bounding box (left, top, right, bottom) and size of the biggest patch."""
    img = Image.fromarray(np.where(mask, 255, 0).astype(np.uint8), "L").copy()
    best = None
    label = 1
    data = np.asarray(img)
    while True:
        ys, xs = np.nonzero(data == 255)
        if len(ys) == 0:
            break
        ImageDraw.floodfill(img, (int(xs[0]), int(ys[0])), label)
        data = np.asarray(img)
        got = data == label
        size = int(got.sum())
        if best is None or size > best[1]:
            gy, gx = np.nonzero(got)
            best = ((int(gx.min()), int(gy.min()), int(gx.max()) + 1, int(gy.max()) + 1), size)
        label = label % 200 + 1
        if label == 1:
            data = np.where(data < 255, 0, 255).astype(np.uint8)
            img = Image.fromarray(data, "L").copy()
    return best


def belly_of(cell, tone):
    """The middle of the pale belly patch in a cell, with its size, or None."""
    h, s, v = to_hsv(cell[..., :3])
    pale = body_mask(h, s, v) & (s < tone[1] * 0.62) & (v > 0.85) & (cell[..., 3] > 0.99)
    pale = np.asarray(Image.fromarray(np.where(pale, 255, 0).astype(np.uint8), "L")
                      .filter(ImageFilter.MinFilter(5))) > 0
    blob = largest_blob(pale)
    if blob is None:
        return None
    (left, top, right, bottom), size = blob
    if size < 0.03 * float((cell[..., 3] > 0.5).sum()):
        return None
    return ((left + right) / 2.0, (top + bottom) / 2.0, right - left + 4, bottom - top + 4)


# ----------------------------------------------------------------- sprites

class Sprite:
    def __init__(self, img, foot_x, belly):
        self.img = img          # RGBA, cropped to its ink
        self.foot_x = foot_x    # column of the cell the feet are centered on
        self.belly = belly      # (x, y) inside the cell, or None


def bake_pet(name, sheet, cols, rows, height, slot_cells):
    """{(palette, small): (strip image, table numbers)} for one character."""
    # A light median takes the painted grain off the flat areas (it would
    # come back as blotches once the colors are flattened) and keeps the edges.
    src = np.asarray(Image.open(os.path.join(SHEETS, sheet)).convert("RGB")
                     .filter(ImageFilter.MedianFilter(3)))
    ink = src.max(axis=2) >= DARK
    cells = [cut_out(src[top:bottom, left:right])
             for left, top, right, bottom in split_grid(ink, cols, rows, 24)]
    tone = body_tone(cells)
    bellies = [belly_of(cell, tone) for cell in cells]

    idle = np.nonzero(cells[0][..., 3] > 0.5)[0]
    scale = height / float(idle.max() + 1 - idle.min())
    out = {}
    for small in (False, True):
        k = scale * (SMALL / 100.0 if small else 1.0)
        emblem = emblem_px(small)
        for pal, (pal_name, body, _shade, _belly) in enumerate(PALETTES):
            sprites = []
            for index, cell in enumerate(cells):
                img = shrink(to_image(recolor(cell, tone, body)), k)
                alpha = np.asarray(img)[..., 3]
                ys, xs = np.nonzero(alpha)
                left, top, right, bottom = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
                weight = alpha.astype(np.float64).sum(axis=0)
                foot = (weight * np.arange(alpha.shape[1])).sum() / weight.sum()
                belly = None
                found = bellies[index]
                # The emblem may reach a little past a small patch, never far.
                if (found is not None and found[2] * k >= emblem * 0.9
                        and found[3] * k >= emblem * 0.8):
                    belly = (int(round(found[0] * k)) - left, int(round(found[1] * k)) - top)
                sprites.append(Sprite(img.crop((left, top, right, bottom)),
                                      int(round(foot)) - left, belly))
            out[(pal, small)] = pack(sprites, cols, slot_cells)
    return out, int(round(height * SMALL / 100.0))


def pack(sprites, cols, slot_cells):
    """One strip: the sprites on a grid, and the table rows for the twelve slots."""
    rows = (len(sprites) + cols - 1) // cols
    widths = [max(s.img.width for s in sprites[c::cols]) + 2 for c in range(cols)]
    heights = [max(s.img.height for s in sprites[r * cols:(r + 1) * cols]) + 2
               for r in range(rows)]
    strip = Image.new("RGBA", (sum(widths), sum(heights)), (0, 0, 0, 0))
    place = []
    for i, sprite in enumerate(sprites):
        x = sum(widths[:i % cols]) + 1
        y = sum(heights[:i // cols]) + 1
        strip.paste(sprite.img, (x, y))
        place.append((x, y))
    numbers = []
    for slot, cell in enumerate(slot_cells):
        sprite = sprites[cell]
        belly = sprite.belly
        if slot in (SLOT_BACK, SLOT_ASLEEP):
            belly = None
        numbers += [place[cell][0], place[cell][1], sprite.img.width, sprite.img.height,
                    sprite.foot_x, belly[0] if belly else -1, belly[1] if belly else -1]
    return strip, numbers


# ----------------------------------------------------------------- emblems

def emblem_px(small):
    return int(round(EMBLEM_PX * SMALL / 100.0)) if small else EMBLEM_PX


def emblem_tile(small):
    return emblem_px(small) + 2 * (EMBLEM_PAD // 2 if small else EMBLEM_PAD)


def flat(color, alpha):
    """An RGBA image of one color under an alpha plane (float 0..1)."""
    h, w = alpha.shape
    out = np.zeros((h, w, 4), dtype=np.float32)
    out[..., :3] = np.array(rgb_of(color), dtype=np.float32) / 255.0
    out[..., 3] = alpha
    return to_image(out)


def bake_emblems():
    """{name: strip}: six colorway columns by three levels, home size over card size."""
    src = np.asarray(Image.open(os.path.join(SHEETS, EMBLEM_SHEET)).convert("L"))
    boxes = split_grid(src >= 96, 4, 4, 40, margin=2)
    out = {}
    big, small = emblem_tile(False), emblem_tile(True)
    for name, (left, top, right, bottom) in zip(EMBLEMS, boxes):
        shape = Image.fromarray(src[top:bottom, left:right], "L")
        strip = Image.new("RGBA", (len(PALETTES) * big, EMBLEM_LEVELS * (big + small)),
                          (0, 0, 0, 0))
        for is_small in (False, True):
            px, tile = emblem_px(is_small), emblem_tile(is_small)
            k = px / float(max(shape.width, shape.height))
            fit = shape.resize((max(1, int(round(shape.width * k))),
                                max(1, int(round(shape.height * k)))), Image.LANCZOS)
            plane = Image.new("L", (tile, tile), 0)
            plane.paste(fit, ((tile - fit.width) // 2, (tile - fit.height) // 2))
            alpha = np.asarray(plane).astype(np.float32) / 255.0
            halo = np.asarray(plane.filter(ImageFilter.GaussianBlur(1.2 if is_small else 2.2))
                              ).astype(np.float32) / 255.0
            core = np.asarray(plane.filter(ImageFilter.MinFilter(3))
                              .filter(ImageFilter.GaussianBlur(0.8 if is_small else 1.4))
                              ).astype(np.float32) / 255.0
            for pal, (_n, _body, shade, _belly) in enumerate(PALETTES):
                # Dull and steady are the colorway's own deep shade, faint then solid;
                # glowing is gold with a pale core and a soft halo.
                levels = [flat(shade, alpha * 0.4), flat(shade, alpha)]
                glow = flat(GLOW, np.clip(halo * 1.6, 0.0, 1.0) * 0.55)
                glow.alpha_composite(flat(GLOW, alpha))
                glow.alpha_composite(flat(GLOW_CORE, core * 0.85))
                levels.append(glow)
                for level, img in enumerate(levels):
                    y = level * tile + (EMBLEM_LEVELS * big if is_small else 0)
                    strip.paste(img, (pal * tile, y))
        out[name] = strip
    return out


# ------------------------------------------------------------------ output

def camel(*parts):
    return "".join(p[:1].upper() + p[1:] for part in parts for p in part.split("_"))


def png_bytes(img):
    """A palette PNG with alpha, as the ink face ships its paintings. The sheets
    carry a fine painted texture that costs ten times the bytes and cannot be
    seen at this size, so the colors are flattened to COLORS first."""
    data = np.array(img)
    data[data[..., 3] == 0] = 0
    flat = Image.fromarray(data, "RGBA").quantize(colors=COLORS,
                                                  method=Image.Quantize.FASTOCTREE)
    buf = io.BytesIO()
    flat.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def build():
    """{relative path: bytes} of every generated file."""
    files = {}
    xml = ['<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/'
           'connect-iq/resources.xsd">',
           "    <!-- Generated by scripts/bake_friend_sprites.py; do not edit. -->"]
    flags = 'dithering="none" automaticPalette="false" packingFormat="png" compress="false"'
    loaders = {False: [], True: []}
    tables = {False: [], True: []}
    units = {False: [], True: []}
    for pet, (name, sheet, cols, rows, height, slot_cells) in enumerate(PETS):
        baked, small_height = bake_pet(name, sheet, cols, rows, height, slot_cells)
        units[False].append(height)
        units[True].append(small_height)
        for small in (False, True):
            for pal, (pal_name, _b, _s, _l) in enumerate(PALETTES):
                strip, numbers = baked[(pal, small)]
                ident = camel("pet", name, pal_name) + ("S" if small else "")
                filename = "pet_%s_%s%s.png" % (name, pal_name, "_s" if small else "")
                files[os.path.join(DRAWABLES, filename)] = png_bytes(strip)
                xml.append('    <bitmap id="%s" filename="%s" %s />' % (ident, filename, flags))
                loaders[small].append(
                    "        if (k == %d) { return WatchUi.loadResource(Rez.Drawables.%s) "
                    "as Graphics.BitmapType; }" % (pet * len(PALETTES) + pal, ident))
                if pal == 0:
                    tables[small].append(
                        "        if (pet == %d) { return [%s] as Lang.Array<Lang.Number>; }"
                        % (pet, ", ".join(str(n) for n in numbers)))
    emblem_loaders = []
    for index, (name, strip) in enumerate(bake_emblems().items()):
        ident = camel("emblem", name)
        filename = "emblem_%s.png" % name
        files[os.path.join(DRAWABLES, filename)] = png_bytes(strip)
        xml.append('    <bitmap id="%s" filename="%s" %s />' % (ident, filename, flags))
        emblem_loaders.append(
            "    if (emblem == %d) { return WatchUi.loadResource(Rez.Drawables.%s) "
            "as Graphics.BitmapType; }" % (index + 1, ident))
    xml.append("</drawables>")
    files[XML] = ("\n".join(xml) + "\n").encode("utf-8")

    mc = """using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

// Generated by scripts/bake_friend_sprites.py; do not edit.
// The friend's baked sprites. A strip holds every pose of one character in
// one colorway at one size; a pose is a rectangle of it. Characters in
// order: %(pets)s. Colorways in the order of FriendArt's
// palettes: %(palettes)s. Pose slots in order:
// %(slots)s.

const FRIEND_PETS = %(pet_count)d;
const FRIEND_SLOTS = %(slot_count)d;
// Numbers per slot: x, y, width, height of the pose in the strip, the column
// its feet are centered on, and the middle of its belly patch (-1: no patch
// to put an emblem on). The last three are measured from the pose's corner.
const FRIEND_SLOT_FIELDS = 7;
const FRIEND_EMBLEMS = %(emblem_count)d;
// An emblem strip is six colorway columns by three brightness rows (dull,
// steady, glowing) at the home size, with the card size under it.
const FRIEND_EMBLEM_LEVELS = %(levels)d;
const FRIEND_EMBLEM_TILE = %(tile)d;
const FRIEND_EMBLEM_TILE_SMALL = %(tile_small)d;

// The height of each character's idle pose, home size then card size.
function friendHeights(small as Lang.Boolean) as Lang.Array<Lang.Number> {
    if (small) {
        return [%(units_small)s] as Lang.Array<Lang.Number>;
    }
    return [%(units)s] as Lang.Array<Lang.Number>;
}

function friendEmblemNames() as Lang.Array<Lang.String> {
    return [%(names)s] as Lang.Array<Lang.String>;
}

// The slot table of one character at one size.
function friendCells(pet as Lang.Number, small as Lang.Boolean) as Lang.Array<Lang.Number> {
    if (!small) {
%(table)s
    } else {
%(table_small)s
    }
    return [] as Lang.Array<Lang.Number>;
}

// The strip of one character in one colorway; the caller catches a refusal.
function loadFriendStrip(pet as Lang.Number, pal as Lang.Number,
                         small as Lang.Boolean) as Graphics.BitmapType? {
    var k = pet * %(palette_count)d + pal;
    if (!small) {
%(loaders)s
    } else {
%(loaders_small)s
    }
    return null;
}

// Emblem 1 to %(emblem_count)d (0 is a bare belly); the caller catches a refusal.
function loadFriendEmblem(emblem as Lang.Number) as Graphics.BitmapType? {
%(emblem_loaders)s
    return null;
}
""" % {
        "pets": ", ".join(p[0] for p in PETS),
        "palettes": ", ".join(p[0] for p in PALETTES),
        "slots": ", ".join(SLOTS),
        "pet_count": len(PETS), "slot_count": len(SLOTS), "emblem_count": len(EMBLEMS),
        "levels": EMBLEM_LEVELS, "tile": emblem_tile(False), "tile_small": emblem_tile(True),
        "units": ", ".join(str(u) for u in units[False]),
        "units_small": ", ".join(str(u) for u in units[True]),
        "names": ", ".join('"%s"' % n.upper() for n in EMBLEMS),
        "table": "\n".join(tables[False]), "table_small": "\n".join(tables[True]),
        "palette_count": len(PALETTES),
        "loaders": "\n".join(loaders[False]), "loaders_small": "\n".join(loaders[True]),
        "emblem_loaders": "\n".join(emblem_loaders),
    }
    files[TABLE] = mc.encode("utf-8")
    return files


def same(path, data):
    """A PNG is compared by its pixels (encoders differ), text byte for byte."""
    if not os.path.exists(path):
        return False
    if path.endswith(".png"):
        old = Image.open(path).convert("RGBA")
        new = Image.open(io.BytesIO(data)).convert("RGBA")
        return old.size == new.size and old.tobytes() == new.tobytes()
    return open(path, "rb").read().replace(b"\r\n", b"\n") == data


def contact(files, out):
    """Review sheets: every strip of one colorway, and every emblem, on black and gray."""
    os.makedirs(out, exist_ok=True)
    for pal_name in [p[0] for p in PALETTES]:
        strips = [Image.open(io.BytesIO(data)).convert("RGBA") for path, data in sorted(files.items())
                  if path.endswith("_%s.png" % pal_name) or path.endswith("_%s_s.png" % pal_name)]
        sheet = Image.new("RGB", (max(s.width for s in strips) + 20,
                                  sum(s.height + 10 for s in strips) + 10), (0, 0, 0))
        y = 10
        for strip in strips:
            sheet.paste(strip, (10, y), strip)
            y += strip.height + 10
        sheet.save(os.path.join(out, "strips-%s.png" % pal_name))
    emblems = [Image.open(io.BytesIO(data)).convert("RGBA") for path, data in sorted(files.items())
               if os.path.basename(path).startswith("emblem_")]
    sheet = Image.new("RGB", (4 * (emblems[0].width + 10) + 10,
                              4 * (emblems[0].height + 10) + 10), (40, 40, 48))
    for i, strip in enumerate(emblems):
        sheet.paste(strip, (10 + (i % 4) * (strip.width + 10),
                            10 + (i // 4) * (strip.height + 10)), strip)
    sheet.save(os.path.join(out, "emblems.png"))
    print("[wrote] review sheets in", out)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed files differ from a fresh bake")
    parser.add_argument("--contact", metavar="DIR", help="also write review sheets here")
    args = parser.parse_args()
    files = build()
    if args.contact:
        contact(files, args.contact)
    if args.check:
        stale = [os.path.relpath(p, REPO) for p, data in sorted(files.items())
                 if not same(p, data)]
        extra = [n for n in sorted(os.listdir(DRAWABLES))
                 if (n.startswith("pet_") or n.startswith("emblem_"))
                 and os.path.join(DRAWABLES, n) not in files]
        for name in stale:
            print("[fail] stale:", name)
        for name in extra:
            print("[fail] not baked by this script:", name)
        if stale or extra:
            return 1
        print("[pass] Friend sprites: %d generated files match the sheets" % len(files))
        return 0
    total = 0
    for path, data in sorted(files.items()):
        if path.endswith(".png"):
            total += len(data)
        if not same(path, data):
            with open(path, "wb") as f:
                f.write(data)
    pngs = [p for p in files if p.endswith(".png")]
    print("[wrote] %d strips and emblems, %d KB of PNG; %s; %s" % (
        len(pngs), total // 1024, os.path.relpath(XML, REPO), os.path.relpath(TABLE, REPO)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
