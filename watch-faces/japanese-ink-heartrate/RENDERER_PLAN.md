# Japanese Ink Heartrate — Renderer Plan

Last updated: 2026-04-22

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
- [Procedural Pass Workflow](art/checkpoints/procedural/PROCEDURAL_PASS_WORKFLOW.md) — build/run/checkpoint loop

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

Current `JapaneseInkHeartrateScene.mc` runs *all of these simultaneously* (`drawRangeBody` + `drawSharedMountainMass` + `drawHostRidgeBone` + `drawGuestCrest` + `drawRidgeBlots` + `drawMistCuts`). None replace the missing gradient, so the scene still looks algorithmic.

Secondary repeating mistake: `generateField(72, seed)` in `scene.mc:267`. A shanshui painting has 2–4 major forms, not 72 samples. Every push toward "more ridge fidelity" drags the renderer back toward chart aesthetics.

## 3. What Already Works

- `VerticalFadeDescentTuned` PNG — first and only Garmin-imported asset with convincing grayscale-alpha survival. Proof that the authored-asset path is viable.
- Tuned bitmap import settings: `dithering="none"`, `automaticPalette="false"`, `packingFormat="png"`, `compress="false"`. Default import is unacceptable.
- Warm paper tone.
- Minute-keyed `BufferedBitmap` cache (`mBuffer`, `getSceneKey()`).
- Time placed low (`centerY = (height * 72) / 100`) so the ridge owns the center.
- AOD fallback with tiny abstracted ridge.

## 4. Strategy

**Replace the missing gradient with authored PNG stamps. Drive their placement from a tiny HR descriptor, not a ridge field.**

Three tracks:

1. **Data → scene descriptor** (cheap, runs at minute boundaries): HR history → 3–5 Gaussian peak descriptors.
2. **Asset family** (authored once): 5 small tuned-import PNGs that carry the tonal variation the gradient used to carry.
3. **Composer** (runs into the buffered bitmap): fixed 12-step draw recipe that places assets based on the descriptor.

## 5. HR Pipeline

Window: last 4 hours. API: `ActivityMonitor.getHeartRateHistory(new Time.Duration(4 * 3600), false)` (oldest-first). Filter `INVALID_HR_SAMPLE`. Tolerate sparse or partial history.

Reduction:

1. Smooth with a ~15–20 min Gaussian window (kills short noise, preserves effort shape).
2. Extract **3–5 local maxima** above a baseline → `{nx, h, s}` descriptors exactly like `hrToPeaks()` in `ink-sandbox/main.js:156`.
3. `nx` = normalized time-of-peak within the window (oldest → left edge, newest → right edge).
4. `h` = normalized HR relative to the window's min/max.
5. `s` = base spread, slightly jittered.

Parallel aggregates derived from the same samples:

- `maxHR` → host peak height amplifier
- `minHR` → valley depth, mist opacity
- `stddev(HR)` → edge roughness selector
- `latest zone` → ink density modifier on host only

Fallbacks in order:

1. Full 4hr history → 5 peaks
2. Partial history (≥ 30 min) → 3 peaks
3. Current HR only → seed a deterministic 3-peak landscape
4. No HR → seed a calm default landscape by time-of-day

## 6. Asset Family (5 PNGs, All Tuned Import)

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

## 7. Scene Composer (Fixed 12-Step Recipe)

All draws go into the minute-cached `BufferedBitmap`. `View.onUpdate` blits the buffer and draws the time over it.

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

- ≤ 5 HR peaks, ever
- ≤ 2 descent stamps
- ≤ 2 crest stamps (1 dominant + 1 subordinate)
- ≤ 2 mist strips per scene
- ≤ 2 trees
- No procedural per-pixel loops in `onUpdate` path
- Redraw buffer only on scene-key change (20-min bucket) or HR refresh

## 9. Current `JapaneseInkHeartrateScene.mc` Teardown List

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
- HR influence is believable, not literal
- No single stamp repeats at the same scale within one scene

## 12. Build Order

1. Author the 4 new PNGs. Commit with tuned-import XML entries alongside `vertical_fade_descent.png`.
2. Strip `JapaneseInkHeartrateScene.mc` per §9.
3. Implement `hrToPeaks` on mock HR data.
4. Implement the 12-step composer.
5. Build, sideload to simulator, save checkpoint pair (`YYYY-MM-DD_name.png` + `.md`) per the procedural workflow doc.
6. Iterate asset tuning before touching composition logic.
7. Replace mock HR with `ActivityMonitor.getHeartRateHistory` once composition reads correctly.
