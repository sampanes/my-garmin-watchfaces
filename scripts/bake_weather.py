#!/usr/bin/env python
"""The weather (2026-11-05, round 10): one whole-face painting per kind of
weather, drawn behind the grasses (after the masses and the air props,
before the near hills, the mist and the foreground), so it falls through
the scene while the near ground frames it (John, 11-05).

The art is round 10's sheets (art/sheets/*_rain|storm|snowfall|wind-a/b,
prompts and verdicts in art/sheets/PROMPTS.md), each painted for the whole
face and cut whole-frame by scripts/cut_art_kit.py; the snow was painted
white on black and cut by brightness. John's picks (11-05):

    rain_light  ChatGPT's sparse rain (rain2-b) at a tone: drizzle, light
                rain, showers
    rain        the same rain doubled (John: "double it in some clever way",
                each copy fainter): over it the same painting shifted SHIFT
                and wrapped (John's pick over turned, which "looks like
                rain is shooting back up", and enlarged); a mirror only
                across the rain's own slant would keep its direction
    storm       ChatGPT's storm, lightning and all, faded to TONE: storms
    snow        Gemini's fuller snow (snowfall2-a, flakes over the whole
                face; the first left the middle bare); by day over a grey
                WASH, the ink painter's
                way of letting white flakes show on white paper
    wind        ChatGPT's second wind (wind2-b): a few maple leaves riding
                long wind streaks, quieter than Gemini's busier leaves
                (John: "new wind is def better"); windy, or a wind over
                WIND_LEAVES (the Scene)

Sized to the face, never tiled, never mirrored (John); only the heavy rain
lays its one painting twice. Nothing
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

    py -3.11 scripts/bake_weather.py           bake and write tables
    py -3.11 scripts/bake_weather.py --check   exit 1 if a table is stale
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
FACE = os.path.join(HERE, "..", "watch-faces", "japanese-ink-heartrate")
DRAW = os.path.join(FACE, "resources", "drawables")
CUTS = os.path.join(FACE, "art", "cuts")
SRC = os.path.join(FACE, "source")
W = 416

# name, layers [(cut set, alpha tone, how)], day sky wash (alpha share).
# how: "" as painted, "rot180" turned half round (same slant, strokes
# elsewhere), "near" enlarged NEAR_SCALE about the center (bigger strokes,
# nearer rain), "shift" moved SHIFT of the face and wrapped.
WEATHER = [
    ("rain_light", [("rain2-b", 0.8, "")], 0.0),
    ("rain", [("rain2-b", 0.75, ""), ("rain2-b", 0.6, "shift")], 0.0),
    ("storm", [("storm-b", 0.55, "")], 0.0),
    ("snow", [("snowfall2-a", 1.0, "")], 0.22),
    ("wind", [("wind2-b", 1.0, "")], 0.0),
]
NEAR_SCALE = 1.6
SHIFT = (0.37, 0.21)
WASH = (90, 86, 80)    # the snow day's grey sky, a warm ink grey
PALETTE = 256


def cut_path(cut, night):
    kind = cut.rsplit("-", 1)[0]
    p = os.path.join(CUTS, cut, "01_%s%s.png" % (kind, "_night" if night else ""))
    if not os.path.exists(p):
        raise SystemExit("no cut %s (run scripts/cut_art_kit.py --only %s)" % (p, cut))
    return p


def layer(cut, night, tone, how):
    im = Image.open(cut_path(cut, night)).convert("RGBA").resize((W, W), Image.LANCZOS)
    if how == "rot180":
        im = im.rotate(180)
    elif how == "near":
        big = im.resize((round(W * NEAR_SCALE), round(W * NEAR_SCALE)), Image.LANCZOS)
        o = (big.width - W) // 2
        im = big.crop((o, o, o + W, o + W))
    elif how == "shift":
        from PIL import ImageChops
        im = ImageChops.offset(im, round(SHIFT[0] * W), round(SHIFT[1] * W))
    p = np.asarray(im, dtype=float).copy()
    p[..., 3] *= tone
    return Image.fromarray(np.round(p).astype(np.uint8), "RGBA")


def bake_one(layers, wash):
    out = []
    for night in (False, True):
        im = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        if not night and wash > 0:
            im = Image.new("RGBA", (W, W), WASH + (int(round(255 * wash)),))
        for cut, tone, how in layers:
            im = Image.alpha_composite(im, layer(cut, night, tone, how))
        out.append(im)
    return out


def pack(img):
    if not PALETTE:
        return img
    return img.quantize(colors=PALETTE, method=Image.Quantize.FASTOCTREE)


def camel(s):
    return "".join(p[:1].upper() + p[1:] for p in s.split("_"))


def bake_all():
    for name, layers, wash in WEATHER:
        day, night = bake_one(layers, wash)
        for im, sfx in ((day, ""), (night, "_night")):
            pack(im).save(os.path.join(DRAW, "wx_%s%s.png" % (name, sfx)), optimize=True)
        print("baked wx_%s from %s" % (name, " + ".join(l[0] + (" " + l[2] if l[2] else "") for l in layers)))


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
