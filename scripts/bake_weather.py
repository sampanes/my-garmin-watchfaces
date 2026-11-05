#!/usr/bin/env python
"""The weather (2026-11-05, round 10): one whole-face painting per kind of
weather, drawn behind the grasses (after the masses and the air props,
before the near hills, the mist and the foreground), so it falls through
the scene while the near ground frames it (John, 11-05).

The art is round 10's sheets (art/sheets/*_rain|storm|snowfall|wind-a/b,
prompts and verdicts in art/sheets/PROMPTS.md), each painted for the whole
face and cut whole-frame by scripts/cut_art_kit.py; the snow was painted
white on black and cut by brightness. John's picks (11-05):

    rain_light  ChatGPT's rain thinned to KEEP of its strokes (whole strokes
                dropped, none redrawn): drizzle, light rain, showers
    rain        ChatGPT's rain as painted: rain, heavy rain
    storm       ChatGPT's storm, lightning and all, faded to TONE: storms
    snow        Gemini's snow; by day over a grey WASH, the ink painter's
                way of letting white flakes show on white paper
    wind        Gemini's maple leaves on the wind: windy, or a wind over
                WIND_LEAVES (the Scene)

One copy, sized to the face: never tiled, never mirrored (John). Nothing
is kept clear for the clock: the inscription's paper halos already fade
whatever lies under the time (John: a blank corner "looks like we missed a
spot"). Which one shows is the Scene's weatherForCondition /
compose_preview.weather_veil; precipitation replaces the sun or moon, wind
does not.

Day and night, each a 256-color palette PNG like the foregrounds.

Writes into watch-faces/japanese-ink-heartrate:
    resources/drawables/wx_<name>.png, wx_<name>_night.png
    resources/drawables/weather.xml           their bitmap declarations
    source/JapaneseInkHeartrateWeather.mc     the indices and the loader

    py -3.11 scripts/bake_weather.py           bake and write tables (needs scipy)
    py -3.11 scripts/bake_weather.py --check   exit 1 if a table is stale
"""
import os
import random
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
CUTS = os.path.join(FACE, "art", "cuts")
SRC = os.path.join(FACE, "source")
W = 416

# name, cut set, alpha tone, share of strokes kept, day sky wash (alpha share)
WEATHER = [
    ("rain_light", "rain-b", 1.0, 0.35, 0.0),
    ("rain", "rain-b", 1.0, 1.0, 0.0),
    ("storm", "storm-b", 0.55, 1.0, 0.0),
    ("snow", "snowfall-a", 1.0, 1.0, 0.22),
    ("wind", "wind-a", 1.0, 1.0, 0.0),
]
WASH = (90, 86, 80)    # the snow day's grey sky, a warm ink grey
KEEP_SEED = 5          # which strokes the thinned rain keeps (repeatable)
STROKE_FLOOR = 8       # alpha (0..255) a stroke must reach to count as one
PALETTE = 256


def cut_path(cut, night):
    kind = cut.rsplit("-", 1)[0]
    p = os.path.join(CUTS, cut, "01_%s%s.png" % (kind, "_night" if night else ""))
    if not os.path.exists(p):
        raise SystemExit("no cut %s (run scripts/cut_art_kit.py --only %s)" % (p, cut))
    return p


def keep_mask(alpha, keep):
    """1 over the strokes kept, 0 over the dropped ones; each stroke whole."""
    from scipy import ndimage
    lab, n = ndimage.label(alpha >= STROKE_FLOOR)
    rnd = random.Random(KEEP_SEED)
    kept = np.zeros(n + 1, dtype=bool)
    kept[1:] = [rnd.random() < keep for _ in range(n)]
    # every pixel belongs to its nearest stroke, so the faint edges go with it
    _, (iy, ix) = ndimage.distance_transform_edt(lab == 0, return_indices=True)
    return kept[lab[iy, ix]].astype(float)


def bake_one(cut, tone, keep, wash):
    day = Image.open(cut_path(cut, False)).convert("RGBA").resize((W, W), Image.LANCZOS)
    night = Image.open(cut_path(cut, True)).convert("RGBA").resize((W, W), Image.LANCZOS)
    mask = keep_mask(np.asarray(day)[..., 3], keep) if keep < 1.0 else 1.0
    out = []
    for im, is_day in ((day, True), (night, False)):
        p = np.asarray(im, dtype=float).copy()
        p[..., 3] *= mask * tone
        im = Image.fromarray(np.round(p).astype(np.uint8), "RGBA")
        if is_day and wash > 0:
            under = Image.new("RGBA", (W, W), WASH + (int(round(255 * wash)),))
            im = Image.alpha_composite(under, im)
        out.append(im)
    return out


def pack(img):
    if not PALETTE:
        return img
    return img.quantize(colors=PALETTE, method=Image.Quantize.FASTOCTREE)


def camel(s):
    return "".join(p[:1].upper() + p[1:] for p in s.split("_"))


def bake_all():
    for name, cut, tone, keep, wash in WEATHER:
        day, night = bake_one(cut, tone, keep, wash)
        for im, sfx in ((day, ""), (night, "_night")):
            pack(im).save(os.path.join(DRAW, "wx_%s%s.png" % (name, sfx)), optimize=True)
        print("baked wx_%s from %s" % (name, cut))


def tables():
    xml = ['<drawables xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
           'xsi:noNamespaceSchemaLocation="https://developer.garmin.com/downloads/'
           'connect-iq/resources.xsd">',
           "    <!-- Generated by scripts/bake_weather.py; do not edit. The weather:",
           "         one whole-face painting per kind, day and night. -->"]
    for name, *_ in WEATHER:
        for sfx in ("", "_night"):
            n = "wx_%s%s" % (name, sfx)
            xml.append('    <bitmap id="%s" filename="%s.png" dithering="none" '
                       'automaticPalette="false" packingFormat="png" compress="false" />' % (camel(n), n))
    xml.append("</drawables>")
    mc = ["using Toybox.Graphics;", "using Toybox.Lang;", "using Toybox.WatchUi;", "",
          "// Generated by scripts/bake_weather.py; do not edit.",
          "// The weather: %d whole-face paintings, %d px square, drawn behind the" % (len(WEATHER), W),
          "// grasses. The Scene's weatherForCondition picks one.", "",
          "const WX_NONE = -1;"]
    for i, (name, *_) in enumerate(WEATHER):
        mc.append("const WX_%s = %d;" % (name.upper(), i))
    mc.append("const WX_COUNT = %d;" % len(WEATHER))
    mc += ["", "// Weather painting i, day or night; the caller catches a refusal.",
           "function loadWeatherBitmap(i as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {"]
    for night in (False, True):
        mc.append("    if (%snight) {" % ("" if night else "!"))
        for i, (name, *_) in enumerate(WEATHER):
            rid = camel("wx_%s%s" % (name, "_night" if night else ""))
            mc.append("        if (i == %d) { return WatchUi.loadResource(Rez.Drawables.%s) as Graphics.BitmapType; }"
                      % (i, rid))
        mc.append("    }")
    mc += ["    return null;", "}", ""]
    return {os.path.join(DRAW, "weather.xml"): "\n".join(xml) + "\n",
            os.path.join(SRC, "JapaneseInkHeartrateWeather.mc"): "\n".join(mc)}


def main(argv):
    if "--check" not in argv:
        bake_all()
    stale = 0
    for path, text in tables().items():
        if "--check" in argv:
            cur = open(path).read() if os.path.exists(path) else None
            if cur != text:
                print("stale:", os.path.relpath(path, os.path.join(HERE, "..")))
                stale += 1
        else:
            with open(path, "w", newline="\n") as f:
                f.write(text)
            print("wrote", os.path.relpath(path, os.path.join(HERE, "..")))
    if "--check" in argv:
        print("weather:", "current" if not stale else "%d stale" % stale)
        return 1 if stale else 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
