# Japanese Ink Heartrate — Renderer Plan

Last updated: 2026-11-05 (the library is the 24 ChatGPT mountains, width-stretched to the run, non-flat r 0.91; the foreground is a whole-face sheet painting, one a day)

> **2026-11-05 ART DECISION -- no procedurally generated art anymore (CURRENT).**
> Nothing drawn by the watch's code or painted by our own scripts: every
> piece of art on the face is to come from the ChatGPT and Gemini sheets in
> `art/sheets/` (prompts and lessons in `art/sheets/PROMPTS.md`), cut by
> `scripts/cut_sprite_sheet.py`. More sheets from those image generators are
> wanted, as many as prove useful. Do not extend `gen_shape_library.py` or
> `gen_ink_layers.py` with new script-made art: the shape library is to be cut
> from the mountain sheets and measured into the same profile table, and the
> generated planes (horizon, mist, foreground) replaced by sheet pieces after
> it. Done for the mountains the same day (PROCEDURE.md §10, 2026-11-05):
> the library is the 24 ChatGPT mountains, scaled 1.2x, 70% ink, each
> stretched in width to its run (0.67x to 1.5x); non-flat `r` 0.91 against
> 0.80 for the painted library. The foreground followed the same afternoon
> (ten whole-face paintings from the sheets, one a day:
> `scripts/bake_foregrounds.py`). The far range, mist and near hills are
> still script-made: they come next.

> **2026-11-05 DECISION -- whole library mountains stay the silhouette (CURRENT).**
> The 2026-11-03 direction stands: each run of buckets over the window's floor
> is one whole painted mountain chosen from the shape library to fit the HR.
> The sixteen-bucket profile is the reference that fit is scored against, not a
> polygon drawn as the ridge. Where the 2026-11-01 note below says the data
> ridge owns the silhouette with the art beneath it, read it as history.
> Why: the library already meets the gap, timing and flat-rest targets; a
> drawn ridge's crest would be a hard `fillPolygon` edge (Connect IQ cannot
> mask a painted bitmap to a polygon), and the crest is what the eye reads
> first; the wrist verdicts (zigzag horizon, primitives assembled into a shape
> look worse than whole shapes) count against it. The open number is `r`
> (0.72 then, target 0.80; 0.91 non-flat since the ChatGPT library and the
> width stretch, 2026-11-05), to be raised through the fit and the library, not by
> drawing the curve.

> **2026-11-01 PIVOT -- measured HR-shape fidelity (CURRENT MILESTONE).** The committed
> four-hour fidelity harness proved that the host/guest landmark system throws
> away too much physiology: mean skyline correlation `r = 0.43`, correct peak
> count in `2/13` deterministic cases, `34 px` mean data-to-ink gap, and
> `98 px` of relief for nearly flat resting HR. In the Phase 4b target, the
> complete lightly smoothed sixteen-bucket profile will own the primary
> mid-plane silhouette. Authored
> PNGs remain essential, but as tonal texture, atmosphere, and sparse event
> accents beneath and subordinate to that data-shaped ridge -- not as two fixed
> outlines standing in for four hours. Any partial real history must remain
> real and partial rather than becoming a full mock window. The current
> harness records the baseline; extending it into the Phase 4b A/B gate is part
> of the milestone. [The fidelity reports](../../common/fidelity/README.md) are
> the record. Since then (2026-11-02 round 6, 2026-11-03 the shape library;
> see PROCEDURE.md) each run of buckets over the window's floor is one whole
> library mountain sunk onto the run's peak, and the newest report (2026-11-05
> 10:59, the ChatGPT library) measures `r = 0.84` over all cases (`0.91`
> non-flat), `11/13`, a `5 px` gap and `1 px` of flat-rest relief.

> **2026-10-27 PIVOT -- baked benchmark planes (CURRENT ASSET BASELINE).** The 2026-06
> complete-painting kit below read as airbrush (two blurred towers) in the sim
> and on the wrist. The benchmark in §1 was always the target, so
> `scripts/gen_ink_layers.py` now ports its primitives (gradient fill, cun,
> dry brush, flying white, bleed, branching trees, organic mist) and bakes
> each PLANE as one PNG: far haze, guest, host, fg_left, fg_right, mist,
> grain. Methods: [ART_PIPELINE.md](ART_PIPELINE.md). The 2026-06 note below
> is kept as history.

> **2026-06-10 PIVOT -- complete-painting grammar (superseded).** The historical
> small-stamp asset family and composer preserved in sections 6-7 are superseded. The
> working architecture,
> proven on-device in iter11/11b, inverts it: each mountain is authored
> offline as a FINISHED sumi-e painting (tower-profile spires `h·(1-t^q)^p`,
> facet shading, domain-warped dry-brush streaks, cun hatch, flying-white
> ridge gaps, blob-cluster pines, mist-dissolved base — all baked into PNG
> alpha at 3x supersample). Monkey C places ~7 bitmaps per scene, positioned/
> scaled by the same 3-peak HR descriptor.
>
> - Authoring: `scripts/gen_sumie_kit.py` (deterministic; regen = identical)
> - Layout iteration: `scripts/compose_preview.py` (offline 416x416 mock of
>   the exact Monkey C recipe — iterate THERE, then port numbers 1:1)
> - Kit: host_mountain, guest_mountain, far_range, mist_band(+lite),
>   shore_foreground, paper_grain — all tuned-import (§3 contract holds)
> - Mist rule: mist RGB must equal the paper fill EXACTLY (0xF2EEE6) so it
>   only erases ink, never shows over bare paper
> - Time: inscription column (FONT_LARGE, ink 0x342A22, upper-left void) +
>   vermillion seal w/ live HR — replaces face-center digits
>
> §1–§3 (gradient diagnosis, failure catalog, tuned-import contract), §5
> (HR pipeline), §8 caps-in-spirit, §10 anti-goals, §11 acceptance criteria
> all remain authoritative.
>
> **Full methods documentation: [ART_PIPELINE.md](ART_PIPELINE.md)** —
> generator techniques, ink model, asset inventory, preview→port contract,
> and the Python→device translation gaps.

This is the single authoritative implementation document for the watch face. It replaces:

- `FEASIBILITY_ASSESSMENT.md`
- `DESIGN_DECISIONS.md`
- `RESEARCH_DIRECTIONS.md`
- `RENDER_SPEC.md`
- `CHECKPOINT_2026-03-29_CODEX1_POSTMORTEM.md`
- `ROOT_JAPANESE_IDEAS.md`
- `STEP_0_STATUS.md`
- `art/ASSET_PLAN.md`

Surviving cross-references:

- [Project Vision](JAPANESE_INK_HEARTRATE.md) — north-star, unchanged
- [HR Facts](ROOT_HR_FACTS.md) — Garmin HR API behavior
- [Working Procedure](PROCEDURE.md) -- build/run/checkpoint loop

## 1. Benchmark And The Missing Primitive

The working aesthetic already exists — in the browser, not on the watch.

Reference renderer: `playgrounds/ink-sandbox/main.js`. It produces scenes that read as shanshui. Every Garmin port has tried to reproduce it and drifted.

The sandbox leans on three Canvas 2D features Garmin's `Graphics.Dc` does not provide:

1. `createLinearGradient` / `createRadialGradient` — `fillMtn()` is literally "dark ink at the ridgeline, fading by ~40% depth." This gradient *is* the ink-wash look.
2. `ctx.filter = 'blur(Npx)'` — dissolves ghost and far layers into atmosphere.
3. `shadowBlur` + per-shape `globalAlpha` — feathered edges on every stroke.

Monkey C can vary alpha per call (`Graphics.createColor(alpha, r, g, b)`) but cannot blend it into a gradient. Every procedural attempt to fake a gradient has produced one of five failure modes (§2).

**Architectural consequence:** the gradient has to be *baked into authored PNGs*, not reconstructed at draw time.

## 2. Why Prior Attempts Failed

| Attempt | Rendered as | Root cause |
|---|---|---|
| Cut-paper ridge polygons | Flat bands | `fillPolygon` = one alpha = one band |
| Rows of circles/ellipses | Visible stamped dots | Spacing readable at 416px |
| `drawPoint` raster body | Dust speckling, or watchdog timeout | Full-field per-pixel loops blow draw budget |
| Vertical pillars (Codex 1–3) | Smoke-column skyline | Isolated primitives with no shared body |
| Shared wash slab (Codex 4) | Gray fog bank | Wash had no internal tonal structure |
| 72-sample ridge (rtruth) | Waveform zig-zag | HR sampled too densely → reads as chart |

The superseded 2026-06 renderer ran *all of these simultaneously*
(`drawRangeBody` + `drawSharedMountainMass` + `drawHostRidgeBone` +
`drawGuestCrest` + `drawRidgeBlots` + `drawMistCuts`). None replaced the
missing gradient, so that scene still looked algorithmic.

Secondary repeating mistake: `generateField(72, seed)` in `scene.mc:267` made
raw sample noise look like a waveform. The current milestone uses sixteen
lightly smoothed time buckets for truthful large-scale geometry. Avoiding a
stock-chart look is a rendering constraint, not permission to discard the
history's chronology.

## 3. What Already Works

- The tuned day/night plane set proves that authored grayscale-alpha ink assets
  survive Garmin import and can carry convincing wash, cun, dry-brush, bleed,
  mist, and sparse trees.
- Tuned bitmap import settings: `dithering="none"`, `automaticPalette="false"`, `packingFormat="png"`, `compress="false"`. Default import is unacceptable.
- Warm paper tone.
- Five-minute-keyed `BufferedBitmap` cache (`mBuffer`, `getSceneKey()`).
- Upper-left kanji/minutes/seal inscription column, clear of the main ridge.
- AOD fallback with tiny abstracted ridge.

## 4. Strategy

(2026-11-05: "primary ridge" in this section and section 5 is the fit
reference; the drawn silhouette is whole library mountains. See the decision
at the top.)

**Use the complete coarse HR profile for large-scale geometry and authored PNGs
for the ink material. Fidelity determines the landform; art determines how the
landform is painted.**

Four tracks:

1. **Data -> primary ridge** (cheap, runs on the five-minute scene key): real
   history -> sixteen 15-minute buckets -> short-gap interpolation -> light
   smoothing -> one oldest-to-newest ridge profile.
2. **Data -> sparse accents:** extract two to four prominent episodes only for
   crest texture, descents, and trees. Accent descriptors never replace the
   primary profile.
3. **Asset family** (authored once): tuned-import PNGs carry the tonal variation
   and brush character Garmin cannot generate dynamically.
4. **Composer** (runs into the buffered bitmap): draw the data-shaped wash,
   keep texture and landmark art below its skyline, then dissolve the base with
   mist and cache the result.

## 5. HR Pipeline

Window: last 4 hours. API: `ActivityMonitor.getHeartRateHistory(new Time.Duration(4 * 3600), false)` (oldest-first). Filter `INVALID_HR_SAMPLE`. Tolerate sparse or partial history.

Reduction:

1. Bin by timestamp into sixteen 15-minute buckets. Never infer chronology from
   iterator position alone.
2. Interpolate only short internal holes. Preserve leading, trailing, and long
   unknown spans instead of drawing invented history through them.
3. Lightly smooth each contiguous real segment (initial kernel `[1, 2, 1]`) so
   sensor noise does not become chart-like teeth while real climbs, plateaus,
   dips, and distinct efforts survive.
4. Map bucket time directly to the shared oldest-to-newest x axis and map HR on
   a stable absolute scale. Do not normalize a flat window into a huge range.
5. Keep the full smoothed profile as the reference the mountain fit is scored
   against; it is not drawn as the ridge.
6. Separately extract **2-4 prominent episodes** for optional `{nx, h, s}`
   texture/accent placement. Their deterministic roughness may change brush
   character, never peak time or height.

Parallel aggregates derived from the same samples:

- `minHR` -> bounded mist/floor treatment below the ridge
- `stddev(HR)` -> bounded edge-roughness selector
- `latest zone` -> optional ink-density/material modifier near the current edge

These aggregates may change material treatment below the computed skyline;
they must not move its time or HR coordinates.

Fallbacks in order:

1. Full four-hour history -> a fitted library mountain per run plus sparse
   accents.
2. Partial history with any valid samples -> draw only the evidence-supported
   segment(s); keep unknown time visually unknown.
3. Current HR only -> a small recent form at "now", not a fabricated four-hour
   story.
4. No HR -> a calm static fallback whose blank HR seal makes its non-data state
   honest. Mock windows remain explicit simulator/test fixtures only.

## 6. Historical Small-Stamp Asset Family (Superseded)

This five-stamp proposal predates the baked benchmark planes now in
`resources/drawables/`. Do not create these missing files for Phase 4b; reuse
the current baked art beneath the new data ridge unless an A/B report proves a
new asset is needed.

All authored as grayscale + alpha. All under 2KB. All scalable via `drawScaledBitmap`.

| Asset | Role | Substitutes for |
|---|---|---|
| `body_wash_soft.png` — broad, soft, horizontally-scalable blob with internal asymmetric tonal falloff | Mid-tone atmospheric body grouping peaks | `createLinearGradient` in `fillMtn` |
| `vertical_fade_descent.png` *(already have, tuned)* | Cliff descent from crest | `shadowBlur` + gradient |
| `crest_anchor.png` — small, dark, calligraphic dab | Dominant crest accent | `flyWhite` + darkest gradient stop |
| `mist_strip.png` — horizontal feathered strip, asymmetric density | Erasure / valley carving | `organicMist` three-pass |
| `pine_tree.png` — ~20×30 px sumi-e pine | Life accent | `ridgeTrees` / `generateBranch` |

Asset-authoring rules:

- Author **lighter than intuition suggests**; repeated placement does the darkening.
- Prefer internal variation and asymmetry over ultra-simple shapes.
- Never render the same stamp at the same scale twice in one scene.
- Mirrored/flipped reuse is fine if the Garmin bitmap path handles it cleanly.

## 7. Historical Small-Stamp Composer (Superseded)

All draws go into the five-minute-keyed `BufferedBitmap`. `View.onUpdate` blits the buffer and draws the time over it.

The recipe below is retained as a historical small-stamp proposal, not as the
current baked-plane composition. The current watch-side order is documented in
[ART_PIPELINE section 4](ART_PIPELINE.md#4-the-watch-side). For Phase 4b, the
fitted library masses stay the primary silhouette (decision, 2026-11-05).
Section 12 below is the Phase 4b implementation order.

```
1.  paper fill (flat warm #F2EFE9)
2.  sun/moon on time-of-day arc (subtle)
3.  far range — body_wash scaled very wide+low, reduced amplitude, 3 soft peaks
4.  mist_strip pass 1 — separates far from mid
5.  mid range — ONE body_wash scaled to span host+guest peaks (the missing mid-tone mass)
6.  vertical_fade_descent at host peak (full scale)
7.  vertical_fade_descent at guest peak (~60% scale, lower alpha)
8.  crest_anchor at host only (dominant)
9.  optional crest_anchor at guest (~40% scale, lower alpha)
10. mist_strip pass 2 — asymmetric, erases lower joins between forms
11. pine_tree near host base; optionally one smaller on a ridge shoulder (≤ 2 total)
12. subtle paper grain
```

Step 5 is the pivot. One broad body-wash scaled to span grouped peaks provides the shared landform mass Codex 4 was reaching for, *with internal tonal variation baked into the PNG* — which Codex 4 lacked.

## 8. Hard Caps

- <= 31 primary ridge control points (including interpolation), under the
  64-point `fillPolygon` cap with floor corners
- <= 4 prominent-event descriptors for accents
- ≤ 2 descent stamps
- ≤ 2 crest stamps (1 dominant + 1 subordinate)
- ≤ 2 mist strips per scene
- ≤ 2 trees
- No procedural per-pixel loops in `onUpdate` path
- Redraw buffer only on the five-minute scene-key change or an explicit refresh

## 9. Historical `JapaneseInkHeartrateScene.mc` Teardown List

This teardown was completed by the baked-plane pivot and is retained as failure
history. It is not a list of functions in the current Scene.

Delete:

- `drawRangeBody` — polygon wash, produces bands
- `drawSharedMountainMass` — the Codex 4 slab
- `drawRidgeBlots` — adds chart-like peak markers
- `drawSpineMass`, `drawAnchorMasses`, `drawCrestAccents`, `drawDescents` — old pillar code
- `drawFrameMass` — framing masses no longer needed
- `generateField(72, …)` — replace with 3–5-peak descriptor from HR

Keep:

- `fastNoise`, `signedNoise`, `gaussian` — used for stamp jitter
- `BufferedBitmap` plumbing (`mBuffer`, `ensureBuffer`, `renderBufferedScene`, `getSceneKey`)
- `drawPaper` (simplify — drop tiled texture, keep flat + subtle radial)
- `drawCelestial`
- `stampBitmap`
- `mPaperTile` / `mWashTile` textures — can be removed once the flat paper proves sufficient
- `mVerticalFadeDescent` resource load
- All helpers: `clamp01`, `clampIndex`, `maxFloat`, `maxNum`, `minNum`

Add:

- `hrToPeaks(samples, count)` — port from `ink-sandbox/main.js:156`
- Resource loads for the 4 new PNG assets
- New composer function matching the 12-step recipe

## 10. Anti-Goals (Preserved)

Do not reintroduce:

- Hard stacked ridge bands
- Chart-like ridge lines
- Repeated peak stamps at every local maximum
- Full-bottom dark slabs
- Rectangular mist bands
- Dense whole-scene raster loops
- Equal dark caps on multiple anchors
- Disconnected vertical pillars with no shared body
- Cap → fade → paper with no mid-tone mass
- Symbolic motif overload (tree + seal + kanji battery + calligraphy time all at once)

## 11. Acceptance Criteria

A scene is acceptable when:

- Mountain reads as a scene, not a graph
- Time window stays legible
- Darkest values occupy less area than mid-tones
- The main range reads as one shared landform first, anchors second
- Mist visibly conceals at least part of the lower body
- No single primitive is obvious on first glance
- HR chronology and large-scale shape are faithful; sumi-e treatment prevents
  the faithful ridge from reading as a stock chart
- No single stamp repeats at the same scale within one scene

Provisional Phase 4b targets are:

- mean skyline `r >= 0.80` across non-flat core synthetic cases
- mean overlay-to-ink gap `<= 12 px`
- mean dominant-peak timing error `<= 15 min` on cases with a prominent peak
- prominent-episode precision and recall each `>= 0.80` within `+/-15 min`
- `flat_rest` relief `<= 15 px` with no prominent painted peak
- deterministic same-input raster, no bridge across unknown spans

The current harness does not enforce all of these yet: it reports one recipe,
counts host/guest landmarks rather than detecting skyline peaks, includes the
flat case in aggregate timing, and does not rerender for a determinism check or
assert gap preservation. Section 12 must add those measurements and an explicit
baseline/candidate A/B sheet. Calibrate the final binding gates from that
prototype, then change them only with a checked-in report and visible evidence.

## 12. Build Order

1. Preserve the newest committed fidelity report (2026-11-03, the shape
   library) as the baseline.
2. Implement one shared `ridgeProfile` contract in `compose_preview.py`: sixteen
   time buckets, short-gap policy, light smoothing, stable HR scale. It is the
   reference the mountain fit and the harness score against, not a drawn ridge.
3. Extend the contact sheet to show baseline and candidate together; tune the
   fit and the library (not a drawn curve) until the candidate passes section
   11 without losing the shanshui read.
4. Port any accepted fit change to `JapaneseInkHeartrateScene.mc` in step with
   the mock; the two change together.
5. Add sparse/partial/outlier and rolling-window stability cases, then rerun the
   deterministic suite.
6. Compile for `fr265`, compare simulator raster with the preview, and record a
   checkpoint pair (`YYYY-MM-DD_HHMM_name.png` + `.md`).
7. Sideload only the passing candidate and confirm legibility, performance, and
   real-history behavior on the physical watch.

## 13. API Audit (2026-10-27): What The FR265 Can Do That This Renderer Does Not Use

Trigger: FR265 firmware 29.05 (stable 2026-08-26, newest as of 2026-10-27) and
Connect IQ SDK 9.3.0 (2026-10). Neither moves the watch. The FR265 stays at
**API level 5.2** on Garmin's compatible-devices page; API 6.0 is the fenix 8/9,
Forerunner 570/970, Venu 4 and vivoactive 6 generation. 29.05 is three bug
fixes (strength PR sync, HR/power field config). SDK 9.2's sleep-score
complication, and SDK 9.3's `DynamicResource` (API 6.0.3), Audio and LTE, do
not reach it. The firmware opportunity is zero.

The real opportunity is API 4.0–5.2 graphics this face has never called.
Every row below is available on the FR265 by API level; the Status column is
what the forums say about hardware behavior, which is the part that matters.

| Feature (API level) | What it replaces here | Status |
|---|---|---|
| `createBufferedBitmap({... :alphaBlending => ALPHA_BLENDING_FULL})` (4.0.0) | Nothing yet: `ensureBuffer()` creates the scene buffer without it | Forum thread 340936: an 8-bit-alpha PNG drawn bitmap-over-bitmap rendered **1-bit** (opaque or clear) on a real epix 2, same AMOLED/5.2 generation, while the sim blended fine; `ALPHA_BLENDING_FULL` was the suggested fix and nobody tested it (and the docs make it the default, see the probe below). This face's whole grammar is alpha PNGs into a BufferedBitmap, so whether the hardware blends 8-bit alpha is the first thing to know. John's verdict (2026-10-27): it looked bad on the wrist **and** in the sim, so this row is a hardware unknown to settle, not the explanation for the look. |
| `drawBitmap2(x, y, bmp, {:transform => AffineTransform, :filterMode => FILTER_MODE_BILINEAR})` (4.2.1) | `drawScaledBitmap` (point sampling): translation gap 3 ("device scaling is crisper than LANCZOS, thin strokes become a barcode"); horizontal flips and rotations without extra PNGs | Documented, device list not given. Bug CIQQA-3176 (`drawScaledBitmap` pixelated on a real vivoactive 6, fine in the sim) says scaling quality is a hardware question. Unverified on FR265. |
| `drawBitmap2 ... :tintColor` (4.2.1) | `mist_band_lite.png` (alpha baked at 62% because there was no global-alpha knob); the parked time-of-day ink tints | Mixed reports: works for some, a no-op for others, and "Source must be native color format" crashes on cheaper AMOLEDs in the SDK 8.3 sim (venusq2, fr165, instinct 3). Needs `automaticPalette="false"` (already in the tuned-import contract). Probe. |
| `setBlendMode(BLEND_MODE_MULTIPLY)` (4.2.1) | The ink glaze itself: overlapping washes darken like real ink instead of alpha-over going muddy | Docs: "Only supported on devices with GPU." Could not confirm the FR265 has one. Probe: two overlapping washes under multiply vs source-over. |
| `setFill(new BitmapTexture({:bitmap => ...}))` (4.0.0) | The 1 px memory-ridge hairline; could become a grain-filled polygon, paper showing through | Listed for the FR265 (common/deep-research-report-2.md). Never tried here. |
| `getVectorFont({:face, :size})`, `drawAngledText`, `drawRadialText` (4.2.1; `:scale` 5.1.0) | `FONT_LARGE` inscription (translation gap 1: system fonts render larger than the mock) | FR265 is in `getVectorFont`'s supported-device list. Faces unverified for it; the FR965 reports only RobotoCondensedBold and RobotoRegular. Read `Devices/fr265/simulator.json` in the installed SDK (entries with `type: system_ttf`). |

Probe plan, one build at home: a `PROBE` flag in `JapaneseInkHeartrateScene`
that (a) creates the buffer with `ALPHA_BLENDING_FULL`, (b) draws the host
mountain through `drawBitmap2` with a scale transform and bilinear filtering
beside the current `drawScaledBitmap`, (c) stamps the mist once with a
50%-alpha `:tintColor` instead of `mist_band_lite`, and (d) overlaps two
guest washes under `BLEND_MODE_MULTIPLY`. Sideload, photograph the wrist,
and keep whichever rows survive. Note that "on-device" in ART_PIPELINE.md
means a simulator capture. John's verdict is that the current grammar looks
bad in the sim and on the wrist alike, so the probe answers only "what can
the hardware blend"; the art problem is upstream of it and stays open.

**Probe written 2026-10-29, uncompiled** (`const PROBE` in
`JapaneseInkHeartrateScene.mc`; the comment above it is the spec, the
procedure is PROCEDURE.md §10 under the same date). Four rows on one card,
each tile its image or the word `ERR` (threw, caught) / `n/a` (absent):

| Row | Left | Right | Reads as |
|---|---|---|---|
| A | the mist's middle (8-bit alpha) into a buffer made with `ALPHA_BLENDING_FULL` | the same into a `PARTIAL` buffer, then the same straight onto the screen | soft everywhere = the surfaces blend 8-bit alpha; a hard cut-out in a tile = that surface is 1-bit (row 1) |
| B | the host via `drawScaledBitmap` | `drawBitmap2` + `AffineTransform.scale` + `FILTER_MODE_BILINEAR` | barcode left, smooth right = row 2 is the fix |
| C | `mist_band_lite` as baked (62%) | `mist_band` under `createColor(0x80, 255, 255, 255)` as `:tintColor` | paler right = the global-alpha knob exists (row 3); full density = the tint's alpha is ignored; a word = the "native color format" refusal |
| D | two guests overlapping, source-over | the same under `BLEND_MODE_MULTIPLY` | darker overlap right = multiply works (row 4); identical = ignored, no GPU path |

Facts from the API docs read while writing it: `ALPHA_BLENDING_FULL` (0) is
"Default surface for buffered bitmap with maximum alpha blending support"
and `PARTIAL` (1) "at least a 1-bit alpha channel"; there is no `NONE`. So
row 1's suggested fix is a no-op by the docs and row A tests the three
surfaces instead. `setBlendMode` is 4.0.0, `BLEND_MODE_MULTIPLY` 4.2.1
(formula `S(1-Da) + D(1-Sa) + SD`, "only supported on devices with GPU"),
`drawBitmap2` 4.2.1 (`:filterMode` defaults to `FILTER_MODE_POINT`;
`:transform` is "applied to the source image while drawing", origin
unstated, so the probe scales about the bitmap's own corner and a displaced
right tile in row B is itself a finding), `AffineTransform` 4.2.0. Expected
card: `python scripts/compose_preview.py --probe out.png`.
