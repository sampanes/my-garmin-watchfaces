# Japanese Ink Heartrate Design Decisions

Last updated: 2026-03-24

This note consolidates the strongest ideas from the private concept exploration into the public project docs, while keeping scope aligned with the current feasibility and build stages.

## Strong Ideas To Keep

These fit both the artistic goal and the Garmin constraints well.

### 1. Tight palette discipline

Adopt this general palette direction:

- paper / washi background
- dense sumi black for primary ridge and time accents
- diluted gray washes for distant layers and mist
- restrained vermillion for one symbolic accent

Representative palette:

- background: `#F2EFE9`
- primary ink: `#1A1A1B`
- mid-tones: `#5A5A5A`, `#8E8E8E`, `#C0C0C0`
- accent: `#C23B22`

This is a useful north star even if exact hex values shift in implementation.

### 2. HR mapped to mountain character, not chart position

This is the best conceptual framing from the ideas file.

- max HR can influence summit height
- min HR can influence valley openness / mist depth
- volatility can influence edge roughness
- current HR zone can influence ink density or contrast

That stays consistent with the existing feasibility guidance: landscape first, data second.

### 3. Vermillion seal as a later UI motif

The "hanko" battery concept is good.

Not because it is culturally decorative, but because it gives one compact place for symbolic status information without turning the face into a dashboard.

This should remain a later refinement, not a Phase 1 requirement.

### 4. Hand-touched rendering rules

The phrasing around stochastic jitter, dry-brush edges, and dissolving bases is useful design guidance.

Those should be treated as rendering tendencies:

- avoid perfect geometry
- vary ridge edges slightly
- let lower mountain areas dissolve into mist or paper tone

### 5. Prefer vertical ink structure over horizontal silhouette logic

This is the biggest rendering-direction update so far.

The mountain should not primarily be built as:

- one horizontal ridge polygon
- one filled dark mass
- one row of repeated wash dots

The mountain should primarily be built as:

- a small number of vertical ink spines
- darkest near the crest or top
- increasingly broken and faint downward
- partially erased by mist at the base

This better matches the project references and reduces the "cut paper" problem.

## Good Ideas To Delay

These are not bad. They are just not first-order priorities.

### 1. Vertical time as a calligraphy column

Interesting idea, but risky for glance readability.

Default direction should remain:

- large horizontal digital time

Vertical time can be explored only after the standard layout already feels strong.

### 2. Tree or bamboo responding to current HR

The single-tree motif is visually appealing, but it adds semantic and compositional complexity too early.

It should stay in the "later accent" bucket.

### 3. Kanji battery numerals inside the seal

This could become elegant, but it also introduces:

- legibility risk at small size
- custom asset or glyph decisions
- more room for gimmick than gain

Keep the seal concept. Delay the full numeral treatment until the main face is already wearable.

## Ideas To Reject For Now

### 1. Literal "live" mountain framing

The private notes still lean slightly toward a continuously living visual system.

The public project direction should remain:

- subtly evolving
- sampled
- minute-scale believable

### 2. Too many symbolic motifs at once

Mountain + mist + sun/moon + tree + seal + calligraphy time can quickly become costume rather than composition.

The face needs one dominant idea first:

- time over mountain

Everything else should earn its place.

## Current Recommended Priority Order

1. Make the time feel premium and intentional.
2. Make the mountain read as ink structure, not a horizontal graphic shape.
3. Make mist function like erasure and depth, not decoration.
4. Add a single vermillion accent carefully.
5. Introduce mock-data-driven terrain variation.
6. Add status motifs only after the above work.

## Prototype Lessons To Keep

These are now explicit project rules.

### 1. Hard-edged ridge bands fail aesthetically

They read as layered construction paper, not ink wash.

### 2. Repeated circles and ellipses also fail if the pattern is obvious

Even with alpha and buffered rendering, regular repeated marks read as dots on a line, not paint.

### 3. Buffered rendering was still the correct technical pivot

The artistic result was not good enough yet, but cached off-screen rendering remains the correct place to keep experimenting in active mode.

### 4. Mist should conceal and dissolve

If mist reads as a stripe or banner, it is wrong.

### 5. Dark accents must be sparse

The references work because the darkest marks are selective and structural, not spread evenly across the whole form.

### 6. Dense full-field procedural raster is not the preferred production path

The point-field prototype was useful, but it revealed two problems:

- enough density to look interesting risks watchdog timeouts
- reduced density survives but loses tonal mass

That means dense full-body per-pixel rendering should not be the default plan.

### 7. A hybrid system is acceptable if the grammar is coherent

"Hybrid" should not mean patchwork.

It should mean:

- procedural placement and variation rules
- a very small, reusable family of grayscale wash/stroke assets
- all assets sharing one visual language

If the asset family is disciplined, the result can still look unified rather than assembled.

### 7a. Bitmap import settings are part of the visual language

This is now a design rule, not just a build detail.

For grayscale-alpha painterly assets in this project:

- default Garmin bitmap import is not visually trustworthy
- tuned import settings preserve the intended softness much better

Working baseline:

- `dithering="none"`
- `automaticPalette="false"`
- `packingFormat="png"`
- `compress="false"`

Implication:

- asset reviews should only be taken seriously when they are rendered through the tuned import path
- otherwise the project risks rejecting good art because of bad import behavior

### 8. Procedural vertical fade descents remain worth testing

One procedural option still fits the references well:

- dark crest anchors
- repeated vertical descents with random dropout and fade

This is much more promising than:

- repeated circles
- repeated rectangles
- broad point clouds

## Ink Sandbox Iteration Log

The `playgrounds/ink-sandbox` browser canvas prototype has been the main proving ground for the mountain rendering approach. These lessons are from direct iteration and should inform the Garmin implementation.

### Iteration 1: stamp clusters on peaks (failed)

Approach: build the mountain silhouette from HR data, then place vertical brush stamps at every local maximum along the ridge to add ink texture.

Result: at 160–240 HR data points mapped to a 416px canvas, local maxima appear every 2–4 pixels. Stamps placed that densely formed a curtain of vertical columns — a city skyline, not a mountain. The "texture" overwhelmed the shape.

Secondary failure: drawing an explicit stroke line along the ridge (to reinforce the crest) produced an EKG trace layered on top of the fill. The ridge became data-visible again, defeating the purpose of treating it as terrain.

Rule added: no stamps on mid-layer peaks. No drawn ridge lines. Ever.

### Iteration 2: fill + shadowBlur approach (current, working but unfinished)

Approach:
- mountain is a filled closed polygon (ridge silhouette, extended down to canvas bottom)
- fill is a gradient: most ink at the ridge, fades aggressively downward — ~70% of opacity gone by 20% depth
- `ctx.shadowBlur` with a slight upward offset fakes wet-ink bleed at the ridge boundary
- a second, lighter fill pass over the same shape simulates ink dilution as the brush runs dry
- 2–3 near-vertical cliff marks placed only at the tallest peaks provide calligraphic structure

HR data smoothing levels used per layer:
- far mountains: window ~65 → 3–4 gentle undulations
- mid mountains (main HR layer): window ~24 → 8–10 peaks, reads as a range
- foreground silhouette: window ~80 → 2–3 simple humps

Result: working. The scene reads as layered mountains on parchment with atmospheric mist between layers. The core logic is sound. The current output is "okay, not perfect" — the ridgelines can feel slightly too smooth/cloud-like, and the three layers may not be differentiated enough in character.

### Open questions from sandbox work

These need more iteration before they are resolved:

**Gradient falloff curve.** The current gradient uses four stops with values tuned by hand. A steeper initial falloff (dropping from 0.62 opacity to 0.10 by 10% depth rather than 18%) may push the result closer to the references, where ink pools tightly at the crest and the body reads as very light wash.

**Layer color temperature.** Distant mountains in sumi-e references often carry a faint cool blue-grey. Near mountains are warm dark ink. The sandbox currently approximates this (`rgb(88,97,106)` for far, `rgb(33,26,18)` for near) but the contrast between them may need to be pushed further.

**Texture within the fill body.** Real ink wash has subtle variation — pooling, brush direction, fiber of the paper. The sandbox has none of that. A few barely-visible near-horizontal strokes clipped to the mountain fill body, at very low opacity, may add that quality without cost. Needs testing.

**Smoothing vs. HR fidelity.** At window=24, the mid layer loses most short-interval HR variation. This is correct for aesthetics but means a short 3-minute sprint may not be distinguishable from a 10-minute effort zone. The right tradeoff is still open — possibly: use the smoothed version for the fill body but let a slightly less-smoothed version define just the topmost few pixels of the ridge, so the overall shape is mountain-like but the crest still carries some true data texture.

**Garmin translation.** The browser canvas approach uses `shadowBlur`, `createLinearGradient`, and `globalAlpha` compositing. Garmin's `Dc` does not support any of these directly. The fill + gradient behavior will need to be approximated in Monkey C with:
- repeated horizontal spans at decreasing opacity (simulating gradient)
- a small pre-authored PNG descent asset for the wet-edge bleed (as already explored in `codexrevamp` work)
- the crest line in Garmin will need to come from a structural asset or explicit stroke, not shadowBlur

The sandbox is still useful because it establishes what the target should look like. Garmin translation is a separate step.

## Custom Digit Assets

Custom digit images are possible and may become useful later.

However, they should be treated as a deliberate art-direction decision, not a rescue for weak composition.

Use them only if:

- built-in fonts cannot achieve the right tone
- the layout is already proven
- the memory cost is acceptable

Until then, built-in fonts plus better spacing, contrast, and layering are the right path.
