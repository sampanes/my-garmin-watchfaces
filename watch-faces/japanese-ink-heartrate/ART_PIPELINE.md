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
compose_preview.py ──reads──>  art/kit_preview.png         (416x416 mock)
        │  layout numbers proven here are ported 1:1, as fractions
        ▼
JapaneseInkHeartrateScene.mc   (7 drawScaledBitmap calls + sun/moon + paper)
JapaneseInkHeartrateView.mc    (inscription time + vermillion HR seal)
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

Decoded pixel budget is about 450k px, up from 300k in the 2026-06 kit. The
old kit ran on the FR265; this one is unverified there (first build will tell).

All registered in `drawables.xml` with the tuned-import contract
(`dithering="none" automaticPalette="false" packingFormat="png"
compress="false"`); default import quantizes alpha and wrecks softness.

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

---

## 4. The watch side

- `JapaneseInkHeartrateScene.mc` places the planes into the 5-minute-keyed
  `BufferedBitmap`. HR: real 4 h history → 16 fifteen-minute buckets →
  `landmarkPeaks()` (strongest bucket = host, strongest ≥ 1 h away = guest),
  `edgeHr()` (oldest / newest bucket with data → fg_left / fg_right height).
  Host x is confined to `0.36 + peakX(nx)·0.40` so the upper-left void always
  survives for the inscription; guest is pushed ≥ 0.30 away and clamped.
- `JapaneseInkHeartrateView.mc` draws the inscription (hour over minutes,
  `FONT_LARGE`, ink `0x342A22`, column at x 22%, rows 21%/33%), the
  vermillion seal at y 42.5% with live HR, and a "4h" caption. AOD path: same
  column in white on black, no seal, burn-in pixel shift.

---

## 5. Preview → device translation (what is known)

1. **The old "low alpha renders fainter on-device, budget ×1.3" note was a
   preview bug**: `Image.paste(im, box, im)` squares the alpha. Fixed
   2026-10-27; the preview now composites like `drawScaledBitmap`. Expect the
   device to look like the preview, and if it looks paler, that is new data.
2. **Fonts**: Garmin system fonts render larger than desktop mocks;
   `FONT_LARGE` matches the preview's Arial-58 inscription.
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
- **Capture checkpoint**: `bash scripts/build-and-run.sh <abs-path>.png`
  with filename `YYYY-MM-DD_HHMM_<name>.png` (HHMM mandatory, never
  overwrite), paired `.md` per PROCEDURE.md §4.

Parked: the benchmark's water band and ripples under the foreground;
seasonal/time-of-day ink tints (needs `:tintColor`); pines instead of bare
branching trees; 24h-mode inscription.
