# Japanese Ink Heartrate Design Decisions

Last updated: 2026-03-23

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

## Custom Digit Assets

Custom digit images are possible and may become useful later.

However, they should be treated as a deliberate art-direction decision, not a rescue for weak composition.

Use them only if:

- built-in fonts cannot achieve the right tone
- the layout is already proven
- the memory cost is acceptable

Until then, built-in fonts plus better spacing, contrast, and layering are the right path.
