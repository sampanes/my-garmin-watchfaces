# Art Pipeline — Baked Benchmark Planes

Last updated: 2026-10-27. This is the methods document for the current
architecture. It records *how* the assets are made and *why* each technique
exists, so the pipeline can be extended without re-deriving it.

Companions:

- [RENDERER_PLAN.md](RENDERER_PLAN.md) — diagnosis history, acceptance criteria, anti-goals, §13 API audit
- [PROCEDURE.md](PROCEDURE.md) — build/push/capture loop mechanics
- `playgrounds/ink-sandbox/main.js` — the browser benchmark this pipeline ports

---

## 1. The architecture in one paragraph

Garmin's `Graphics.Dc` has no gradients, no blur, and no per-shape softness,
so **any** runtime composition of primitives exposes the primitive (ten
iterations of evidence: bands, dots, pillars, fog slabs, charts). The
2026-06 "complete painting" kit baked two isolated mountains as blurred
vertical gradients and read as airbrush, in the sim and on the wrist alike.
What *does* read as shanshui is the browser benchmark: gradient-filled
ridges with scattered cun strokes, dry-brush dashes, ink-bleed blobs and
small branching trees, stacked as ghost / far / mid / foreground planes with
organic mist between them. `scripts/gen_ink_layers.py` ports those exact
primitives to numpy/Pillow and bakes each **plane** as one PNG with the
brushwork inside. The watch places seven planes with `drawScaledBitmap`,
driven by the four-hour HR history. It contributes layout, not brushwork.

```
gen_ink_layers.py  ──writes──>  resources/drawables/*.png   (the planes)
gen_ink_font.py    ──writes──>  resources/fonts/*.fnt+.png  (the digits)
compose_preview.py ──reads──>  art/kit_preview.png         (416x416 mock)
        │  layout numbers proven here are ported 1:1, as fractions
        ▼
JapaneseInkHeartrateScene.mc   (7 drawScaledBitmap calls + sun/moon + paper)
JapaneseInkHeartrateView.mc    (hour column in KanjiHours, minutes in InkDigits, HR seal in SealDigits)
```

**Iterate in Python, not on-device.** Bake plus preview takes about two
seconds; a build+push+capture cycle takes a minute and adds sim-focus
failure modes. The device capture verifies the port, it does not explore art.

---

## 2. The generator (`scripts/gen_ink_layers.py`)

Everything renders at `SS = 3` supersample and is LANCZOS-downsampled; that
is where the analog edge softness comes from. All randomness goes through
seeded numpy RNGs and seeded value noise, so **regeneration is
deterministic**: same script, byte-identical PNGs.

### 2.1 Silhouette: Gaussian peaks plus three scales of noise

Each plane's ridge is `max` over Gaussian peak descriptors `(nx, h, s)`,
exactly the benchmark's `profile()`, plus domain-warped fbm (folded-rock
edges), mid-frequency fbm (hill-scale variation) and turbulence (micro
crags), all scaled by `rough`. Two departures from the benchmark, both
because a plane is a *stamp* and not a full-width polygon:

- the noise rides on the peak envelope (`0.25 + 0.75·v`), so the skirts
  between and beyond peaks stay calm instead of growing a hill band;
- an edge envelope takes the ridge to zero at the stamp's left/right edge
  (foreground masses keep their outer edge open, they are placed off-screen).

### 2.2 Ink: the benchmark's gradient, then marks

| Layer | What it is | Why |
|---|---|---|
| gradient fill | alpha by depth below the plane's highest point: 1.0 → .88 at 15% → .55 at 38% → .20 at 65% → .05 at 88%, times `ink` | the ink-wash body; this *is* the missing `createLinearGradient` |
| crown | `crown · exp(−depth / (crown_k · local height))` | brush-redefined ridge; the one addition to the benchmark, so silhouettes read as drawn edges |
| dry brush | near-horizontal dashed marks just under the ridge, alpha ≤ .07·ink | bristles on washi |
| cun | 3–17 px pressure-varying strokes scattered through the body (`sin(πt)^0.6` pressure, noise-modulated) | the texture strokes of the rock faces |
| flying white | short dashed marks hugging the ridge, alpha ≤ .16·ink | dry-brush breaks at the stroke |
| trees | recursive 3-deep branches with noise-perturbed foliage polygons, `tree_prob` per 1x column along the ridge | life; sparse on mid planes, dense on the foreground |
| bleed | radial blobs at the ridge (28% of columns) | ink wicking into fibers |
| base dissolve | smoothstep fade with a wobbling boundary before the stamp's bottom | the stamp must never show its rectangle |

Then one Gaussian blur per plane (0.5 px foreground, 0.9–1.2 px mid,
3.5–7 px far), as in the benchmark. One ink RGB per PNG; alpha carries tone.

### 2.3 Mist

`organic_mist()` is the benchmark's three passes: an fbm-displaced band with
a vertical alpha ramp, overlapping cloud puffs, long thin wisps, plus
along-length gaps so it never reads as a stripe. **Its RGB equals the paper
fill exactly (0xF2EEE6)**, so it only erases ink and is invisible over bare
paper. `mist_band_lite.png` is the same image at 62% alpha, baked because
`drawScaledBitmap` has no global-alpha knob (API audit: `drawBitmap2
:tintColor` may be that knob, unverified on hardware).

### 2.4 Asset inventory

| File | Native | Ink RGB | Role |
|---|---|---|---|
| far_range.png | 416×120 | 70,66,60 | ghost (ink .09, blur 7) over far (ink .19, blur 3.5) |
| guest_mountain.png | 260×190 | 12,9,7 | second landmark, ink .36, crown .16, apex nx .42 |
| host_mountain.png | 340×260 | 12,9,7 | strongest landmark, ink .62, crown .30, apex nx .47 |
| fg_left.png | 300×200 | 11,8,6 | foreground, ink .90, open left edge, tree_prob .042 |
| fg_right.png | 280×180 | 11,8,6 | foreground, ink .86, open right edge, tree_prob .034 |
| mist_band.png (+_lite) | 416×110 | 242,238,230 | organic mist, alpha .58 (lite ×.62) |
| paper_grain.png | 240×240 | 96,84,70 | washi grain, upscaled on-device, alpha ≤ .16 |
| `*_night.png` (all but grain) | same | 168,164,152 ink; far 120,118,110; mist 0,0,0 | night mode's pale ink on black paper; alpha × .75 fg, .80 host, .85 guest, .90 far, mist as is (`write_pair`) |

Decoded pixel budget is about 450k px, up from 300k in the 2026-06 kit. The
old kit ran on the FR265; this one is unverified there (first build will tell).
The night set is the same budget again on disk (~80 KB of PNG), but
`loadPlanes()` holds only one set in the graphics pool at a time.

All registered in `drawables.xml` with the tuned-import contract
(`dithering="none" automaticPalette="false" packingFormat="png"
compress="false"`); default import quantizes alpha and wrecks softness.

### The inscription fonts (`scripts/gen_ink_font.py`)

The time and the seal's HR were the last thing on the face still drawn by
Garmin: Roboto digits sitting on an ink painting. `gen_ink_font.py` writes
them with the same brush as the planes and bakes the result as three BMFont
pairs in `resources/fonts/`, registered in `fonts.xml` with
`antialias="true"` (the digit fonts with a digit-only `filter`; the kanji
font unfiltered, so the XML stays ASCII and every glyph in the descriptor
is included):

| font | id | cap / line | how it is written |
|---|---|---|---|
| ink_digits.fnt/.png | `InkDigits` | 40 / 54 px | brush: a bristle bundle on a hand-set stroke skeleton |
| kanji_hours.fnt/.png | `KanjiHours` | 36 / 48 px | the same brush; the numerals 〇一二三四五六七八九十廿 for the hour column |
| seal_digits.fnt/.png | `SealDigits` | 15 / 19 px | carved stamp: one even stroke, chipped edges |

Each glyph is a **stroke skeleton** (`GLYPHS` for the digits in a box
EM_W (0.64) × cap wide, `KANJI` for the numerals in the em square): the
segments a calligrapher would write, in order and direction; corners sit
between segments and each segment is Catmull-Rom smoothed. Per stroke,
`head` says how the brush lands (`press`: set down, ink pools; `land`:
arrives moving, thin), `tail` how it leaves (`taper`: lifts while moving;
`stop`: blunt with a small pool), and `body` the pressure floor through
the middle (0.70 for the digits; a kanji bar, `yoko()`, thins to 0.50
between its pressed ends, a vertical, `tate()`, holds 0.62). `pressure()`
turns that into a width profile (0.045 to 0.20 of cap) with value noise
riding on it, and `draw_bundle()` lays sixteen bristles along the path,
each with its own alpha, the outer ones lighter, some running dry partway
(flying white). Press heads get a soft pooled disc; the finished glyph gets
a 1 px ink bleed and a paper-fiber modulation. The seal style uses one
bristle at even width, no dry brush, and a noise chip on the edges.

The atlas stores the coverage in alpha AND gray (premultiplied white), so
whichever channel the resource compiler keys on, it sees the same glyph.
Metrics: `xoffset` = bearing (3 px ink, 2 px kanji, 1 px seal), `xadvance`
= ink width + 2 bearings (proportional), `yoffset` from a 7 px (kanji 6 px,
seal 2 px) top margin so `TEXT_JUSTIFY_VCENTER` centers the cap. A glyph
that spills above the line is clipped, so keep skeleton heads at y ≥ 0.02.
The kanji `char id`s are the Unicode code points (一 = 19968); the View
builds each one-glyph string from the code point with `toChar().toString()`
so no source file carries a non-ASCII literal.

`python scripts/gen_ink_font.py --sheet out.png` also writes a taste sheet:
every glyph at 2×, the inscription at 1×, three HR seals. Change a digit by
editing its skeleton, rebake, read the sheet, then run the preview. Never
hand-edit the `.fnt`.

---

## 3. The preview compositor (`scripts/compose_preview.py`)

A pixel-level mock of the Monkey C recipe: same paper color, same plane
order, same placement math (mock HR → 16 buckets → two hour-separated
landmarks → host/guest apex x and height; oldest and newest buckets → the two
foreground heights), circular mask + dark surround to match the sim. **The
contract: layout numbers live here first and are ported to
`JapaneseInkHeartrateScene.mc` as the same fractions, unchanged.**

Plane order (both sides): paper → sun/moon → far_range → mist_lite → guest →
host → mist → fg_left → fg_right → grain → (View) inscription + seal.

`compose_preview.py [out.png]` writes `art/kit_preview.png` by default.
Flags: `--night`, `--no-trace`, `--24h`, `--time HH:MM`, and `--data hr.csv
[--end YYYY-MM-DDTHH:MM]` to compose a **real window** instead of the mock:
`epoch,hr_avg[,hr_max]` rows (one per live bucket; the merged Friend logs
or any HR export), binned by time exactly as `refreshHistory` does, averages
into the sixteen buckets, maxima into the overlay, leading and trailing
emptiness left empty, the clock set to the window's end in Arizona time. It
is the only way to see what the painting does with a window that starts
empty or holds one episode, which is what real days look like.

---

## 4. The watch side

- `JapaneseInkHeartrateScene.mc` places the planes into the 5-minute-keyed
  `BufferedBitmap`. HR: real 4 h history → 16 fifteen-minute buckets →
  `landmarkPeaks()` (strongest bucket = host; strongest bucket **with data**
  ≥ 1 h away = guest, else no guest plane at all: an empty bucket is not a
  landmark, and until 2026-10-29 a window missing its first hours grew a
  full-size guest out of nothing), `edgeHr()` (oldest / newest bucket with
  data → fg_left / fg_right height). The guest crest sits on the host's
  crest scale (`crestY`) and `GUEST_RECESS` (3% of the height) lower, so a
  lower heart rate is always a lower peak; before 2026-10-29 it stood on
  its own base at 0.71 H and out-topped the host even at a lower rate.
  **One time axis**, `axisX(nx)` = 0.36..0.80 of the width for four hours
  ago..now, places both landmarks clear of the inscription; the guest apex
  is also floored at x 0.34 and pushed ≥ 0.30 from the host (crossing to the
  host's other side when its own side has no room).
- **True-HR overlay** (setting `trueHrOverlay`, default on): the data as a
  silhouette in the painting's own grammar. The window's samples (≤ 58
  columns, thinned by group maximum so peaks survive; `fillPolygon` takes at
  most 64 points) are drawn on `axisX` and the host's **crest scale**
  (`traceY`: the y the host crest would have if the host were sized for that
  HR; the crest sits 31% down the host bitmap, `HOST_APEX_Y`) as a
  translucent vermilion wash whose floor hugs the lowest sample, a 2 px edge
  along the skyline, and a dot on each painted crest (`HOST_APEX_Y`,
  `GUEST_APEX_Y` = 12%). Where the wash rises above the ink the painting
  under-states; where ink stands above the edge it over-states. The guest
  dot will usually sit off the data: it is recessed on purpose (smaller
  height formula) and often moved along the axis. The 2026-10-28 cut was a
  hairline plotted against the top of the host's bitmap rectangle, which put
  it in the sky 100 px above the paint.
- **Night mode** (settings `nightStart`/`nightEnd`, hours, default 21–6,
  equal = off): black paper, the `*_night.png` plane set (pale ink, no
  grain), pale inscription ink, dimmed seal. `loadPlanes()` keeps only one
  set in the graphics pool; the hour boundary is always a 5-minute key, and
  a settings change calls `invalidate()` through the App.
- `JapaneseInkHeartrateView.mc` draws the inscription as a rakkan column at
  x 22%: the hour as one or two kanji numerals in `Rez.Fonts.KanjiHours`
  stacked on a 10% pitch with the bottom glyph at y 26.5% (0 = 〇, 1-9,
  10 = 十, 11-19 = 十X, 20 = 廿, 21-23 = 廿X; twenty is the single character
  廿 so no hour needs a third line, which would clip on the bezel), the
  minutes in `Rez.Fonts.InkDigits` at y 37.5%, ink `0x18120E`, and the
  vermillion seal (8.5% of width, y 46.5%) with live HR in
  `Rez.Fonts.SealDigits`; the three fonts load in `initialize()`. AOD path:
  same column in white on black, no seal, burn-in pixel shift.

---

## 5. Preview → device translation (what is known)

1. **The old "low alpha renders fainter on-device, budget ×1.3" note was a
   preview bug**: `Image.paste(im, box, im)` squares the alpha. Fixed
   2026-10-27; the preview now composites like `drawScaledBitmap`. Expect the
   device to look like the preview, and if it looks paler, that is new data.
2. **Fonts**: no system fonts remain on the face. The preview draws the
   baked `.fnt` pairs with the metrics the compiler reads, so the digits
   should match to the pixel. Unverified: that the compiler keys on the
   atlas alpha (the gray channel carries the same coverage as a hedge) and
   that `antialias="true"` gives 8-level glyphs on the FR265 rather than a
   1-bit mask. A face whose digits look jagged or heavier than the preview
   is that, not the skeletons.
3. **Scaling filter**: the device's bitmap scaling is crisper than LANCZOS
   (thin parallel strokes sharpened into a barcode in June). Trees and cun
   strokes are short and non-parallel on purpose. If the hardware still
   sharpens them, RENDERER_PLAN §13 row 2 (`drawBitmap2` bilinear) is the fix.
4. **Alpha depth**: whether the hardware blends 8-bit bitmap alpha into the
   BufferedBitmap is unverified (RENDERER_PLAN §13 row 1). A face that looks
   like hard cut-outs on the wrist is that, not the art.
5. **The circle eats the corners**: content below
   `y = 208 + √(208² − (208−x)²)` is invisible, which is why the foreground
   masses sit as high as they do.
6. A capture showing a black screen + play triangle is the sim's "no app"
   screen (push race), not a crash: re-push and recapture.

---

## 6. How to iterate (recipes)

- **Change a plane's character**: edit its `render_plane(...)` call in
  `gen_ink_layers.py` (peaks, `rough`, `ink`, `crown`, `cun_count`,
  `tree_prob`, blur) → `python scripts/gen_ink_layers.py && python
  scripts/compose_preview.py` → Read `art/kit_preview.png`. Build for the
  watch only when the preview reads right.
- **Move/resize a plane**: change `compose_preview.py`, verify, then port the
  same fractions into `renderScene()`.
- **Add a plane**: a `render_plane` call → tuned-import entry in
  `drawables.xml` → load in `initialize()` → one `drawScaledBitmap` in
  `renderScene()` → preview parity first.
- **Change a digit**: edit its skeleton in `GLYPHS` (`gen_ink_font.py`),
  `python scripts/gen_ink_font.py --sheet <path>.png`, Read the sheet, then
  `compose_preview.py`. Weight lives in `pressure()` and the 0.045–0.20 cap
  fraction; a glyph whose strokes pool into a blob wants `w=` below 1 on its
  thinner strokes (the 4 is the worked example).
- **Capture checkpoint**: `bash scripts/build-and-run.sh <abs-path>.png`
  with filename `YYYY-MM-DD_HHMM_<name>.png` (HHMM mandatory, never
  overwrite), paired `.md` per PROCEDURE.md §4.

Parked: the benchmark's water band and ripples under the foreground;
seasonal/time-of-day ink tints (needs `:tintColor`); pines instead of bare
branching trees; kanji minutes (the hour went kanji on 2026-10-28, see
§4; the minutes stay Arabic for at-a-glance reading); three-glyph hours
(二十三) if 廿 reads wrong on the wrist.
