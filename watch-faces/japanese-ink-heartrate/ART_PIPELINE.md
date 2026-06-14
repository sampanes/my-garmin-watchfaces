# Art Pipeline — Complete-Painting Method

Last updated: 2026-06-11 (iter11b). This is the methods document for the
architecture that finally worked. It records *how* the assets are made and
*why* each technique exists, so the pipeline can be extended without
re-deriving it.

Companions:

- [RENDERER_PLAN.md](RENDERER_PLAN.md) — diagnosis history, acceptance criteria, anti-goals
- [PROCEDURE.md](PROCEDURE.md) — build/push/capture loop mechanics
- Checkpoints `art/checkpoints/procedural/2026-06-10_2241_*` and `_2245_*` — the proof captures

---

## 1. The architecture in one paragraph

Garmin's `Graphics.Dc` has no gradients, no blur, and no per-shape softness,
so **any** runtime composition of primitives exposes the primitive (ten
iterations of evidence: bands, dots, pillars, fog slabs, charts). The working
inversion: author each landscape element offline as a **finished sumi-e
painting** — every gradient, texture, and soft edge baked into PNG alpha —
and reduce the watch renderer to *placing* ~7 bitmaps, positioned and scaled
by the HR descriptor. The watch contributes layout, not brushwork.

```
gen_sumie_kit.py  ──writes──>  resources/drawables/*.png   (the paintings)
compose_preview.py ──reads──>  art/kit_preview.png         (416x416 mock)
        │  layout numbers proven here are ported 1:1, as fractions
        ▼
JapaneseInkHeartrateScene.mc   (7 drawScaledBitmap calls + sun/moon + paper)
JapaneseInkHeartrateView.mc    (inscription time + vermillion HR seal)
```

**Iterate in Python, not on-device.** A preview render takes ~2 s; a
build+push+capture cycle takes ~1 min and adds sim-focus failure modes. The
on-device capture is for *verifying* the port, not for exploring art.

---

## 2. The generator (`scripts/gen_sumie_kit.py`)

Everything renders at `SS = 3` supersample and is LANCZOS-downsampled — this
is where the "analog" edge softness comes from. All randomness goes through
seeded `numpy` RNGs and two value-noise helpers (`vnoise1`, `vnoise2`,
octaved, smoothstep-interpolated), so **regeneration is deterministic**:
same script → byte-identical PNGs.

### 2.1 Mountain silhouettes — tower profile, not cones

Each mountain is a cluster of "spires," each contributing a ridge height
profile over x:

```
h(x) = H · (1 − t^q)^p      t = |x − cx| / w, clamped to [0,1]
```

- `q` (3–4.5) holds the profile near full height until t ≈ 0.7, then
  plunges → **near-vertical rock walls with flattish crowns**, the
  Huangshan-tower grammar of the reference paintings.
- `q` low + `p` ≈ 1 → gentle hills (don't — that's the failed gaussian-bump
  look; v1 of this kit proved it reads as spray-painted cones).
- The cluster takes the max over spires; per-x bookkeeping records which
  spire "owns" the ridge and which side of its apex you're on (drives facet
  shading).
- Three noise layers roughen the ridge: medium undulation, **quantized
  "ledge" noise** (`round(noise·3)/3` — gives stepped rock shelves), and
  fine jitter. All scaled by local height so valleys stay calm.

### 2.2 Ink model — what replaces the missing gradient

Ink density at a pixel `d` px below the ridgeline, local spire height `Hloc`:

| Layer | Formula (shape) | Role |
|---|---|---|
| crown | `exp(−d / (crown_k·Hloc))` | dark brush-redefine band at the ridge |
| body | `(1 − d/(body_depth·Hloc))^1.1` | broad wash keeping the face toned (exponent ≥1.5 hollows the mountain out — v1 mistake) |
| facet | `1 ± facet_strength` by apex side | one face lit, one shadowed, per spire |
| streaks | 1-D noise sampled through a **y-warped x** (domain warp ±17 px) | vertical dry-brush pull-downs; warp is what stops it reading as wood grain |
| cun | thresholded 2-D noise, weighted by crown | broken hatch texture on upper faces |
| flying white | where ridge-band noise > 0.74, cut density to 30% | the dry-brush gaps in the ridge stroke |
| base dissolve | smoothstep fade starting at `fade_top`·height, noisy boundary | mountain dissolves into mist; never reaches the bitmap bottom |
| edge guards | smoothstep fades at bitmap x-edges and bottom | the stamp must never reveal its rectangle |

Then: small gaussian blur (ink bleed, ~0.8 px at 1×) + a faint wide-blur
halo, pines stamped **after** the blur so they stay crisp.

### 2.3 Pines — blob clusters with needle ticks

At 13–20 px a pine is: a leaning 2-segment trunk hint, 2–3 irregular
noise-eroded foliage clumps shrinking upward, and 2–4 **radiating needle
ticks** per clump. The ticks are what flip the read from "boulder" to
"pine" (v2 lesson: stacked clean ellipses = TV antenna; clean blobs =
boulders). Pines are placed via `ridge_y_at()` (mirrors the silhouette math
exactly) so they sit *on* crowns and shoulders.

### 2.4 Bands

- **far_range** — gentle noise ridge, heavy blur, alpha ≤ ~0.46. It is the
  third depth plane; at 0.34 it vanished on-device.
- **mist_band** — **RGB must equal the paper fill EXACTLY (0xF2EEE6 /
  242,238,230).** Mist works by *erasing ink it overlaps*; any RGB lighter
  than paper renders as a visible stripe across the whole face (v1 mistake).
  Lumpy 1-D density + gap noise + strongly varying center-line keep it from
  reading as a rectangle. `mist_band_lite.png` is the same image at 62%
  alpha, baked because `drawScaledBitmap` has no global-alpha knob.
- **shore_foreground** — 4 *overlapping, wavy-centered* dry-brush strokes +
  5 reed ticks, blur 1.4. Separated straight strokes read as a barcode
  on-device (iter11 capture) — overlap and waviness are load-bearing.
- **paper_grain** — authored at 240×240, upscaled on-device (subtle noise
  survives the stretch; saves ~5× decoded memory). Max alpha ~0.16: it
  tones, never speckles.

### 2.5 Asset inventory

| File | Native size | Ink RGB | Drawn at (fractions of screen) |
|---|---|---|---|
| host_mountain.png | 320×290 | 44,38,31 | h = 0.6971·(0.86+0.38·h0), apex x-frac 0.49375 |
| guest_mountain.png | 250×210 | 104,98,89 | h = 0.505·(0.42+0.28·h1), apex x-frac 0.40 |
| far_range.png | 320×85 | 150,152,146 | (−0.024, 0.308, 1.048, 0.269) |
| mist_band.png | 360×96 | 242,238,230 | (−0.029, 0.7115, 1.072, 0.269) |
| mist_band_lite.png | 360×96 | same ×0.62α | (−0.216, 0.543, 1.067, 0.231) |
| shore_foreground.png | 320×100 | 52,44,36 | (−0.019, 0.6875, 0.798, 0.243) |
| paper_grain.png | 240×240 | 96,84,70 | (0, 0, 1, 1) |

All registered in `drawables.xml` with the tuned-import contract
(`dithering="none" automaticPalette="false" packingFormat="png"
compress="false"`) — default import quantizes alpha and wrecks softness.

---

## 3. The preview compositor (`scripts/compose_preview.py`)

A pixel-level mock of the Monkey C recipe: same paper color, same layer
order, same placement math (including the mock-HR → 3-peak descriptor →
host/guest position pipeline), circular mask + dark surround to match the
sim. **The contract: layout numbers live here first, and are ported to
`JapaneseInkHeartrateScene.mc` as the same fractions, unchanged.** If the
preview and the device capture disagree, §5 lists the known translation
gaps; anything else is a porting bug.

Layer order (both sides): paper → sun/moon → far_range → guest →
mist_lite → host → mist → shore → grain → (View) inscription + seal.

---

## 4. The watch side

- `JapaneseInkHeartrateScene.mc` — the placements above, drawn into the
  20-minute-keyed `BufferedBitmap`. The HR descriptor (`computePeaks()`:
  real 4 h history → smooth → 3 peaks → sort by height; deterministic mock
  fallback) refreshes on every scene rebuild. Host x is confined to
  `0.36 + peakX(nx)·0.40` so the upper-left void always survives for the
  inscription; guest is pushed ≥0.30 away and clamped to [0.16, 0.84].
- `JapaneseInkHeartrateView.mc` — inscription time: hour over minutes,
  `FONT_LARGE`, ink `0x342A22`, column at x 22%, rows 21%/33%; vermillion
  seal (rounded square, 6.7% of width) at y 42.5% showing live HR
  (`Activity.getActivityInfo().currentHeartRate`; empty square in sim).
  AOD path: same column in white on black, no seal, burn-in pixel shift.

---

## 5. Python-preview → device translation gaps (learned 2026-06-10)

1. **Fonts**: Garmin system fonts render much larger than equivalent-looking
   desktop mock fonts. `FONT_NUMBER_MILD` overran the layout; `FONT_LARGE`
   matches the preview's Arial-58 inscription scale.
2. **Low alpha renders fainter on-device** than in Pillow compositing —
   budget ~×1.3 on anything below α≈0.4 (far_range needed 0.34→0.46).
3. **Thin parallel strokes sharpen into a barcode** — the device's bitmap
   scaling is crisper than LANCZOS. Overlap strokes and add center waviness.
4. **The circle eats the corners**: bottom-left content below
   `y = 208 + √(208² − (208−x)²)` is invisible. The shore must ride high.
5. **No global alpha at draw time** — bake alpha variants as separate PNGs.
6. A capture showing a black screen + play triangle is the sim's "no app"
   screen (push race), not a crash — re-push and recapture.

---

## 6. How to iterate (recipes)

- **Change a mountain's character**: edit its spire list / make_mountain
  params in `gen_sumie_kit.py` → `python scripts/gen_sumie_kit.py &&
  python scripts/compose_preview.py` → Read `art/kit_preview.png`. Only
  build for the watch when the preview reads right.
- **Move/resize a layer**: change `compose_preview.py`, verify, then port
  the same fractions into `renderScene()`.
- **Add an asset**: generator function → save in `main()` → tuned-import
  entry in `drawables.xml` → load in `initialize()` → one
  `drawScaledBitmap` in `renderScene()` → preview parity first.
- **Capture checkpoint**: `bash scripts/build-and-run.sh <abs-path>.png`
  with filename `YYYY-MM-DD_HHMM_<name>.png` (HHMM mandatory, never
  overwrite), paired `.md` per PROCEDURE.md §4.

Future ideas parked: host variant B (calmer geometry) selected by HR stddev;
seasonal/time-of-day ink tints; 24h-mode inscription ("22" over "45"); on-
wrist validation list in the iter11b checkpoint.
