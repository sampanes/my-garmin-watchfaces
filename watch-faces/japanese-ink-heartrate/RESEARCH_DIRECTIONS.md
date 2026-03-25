# Japanese Ink Heartrate Research Directions

Last updated: 2026-03-25

This note records the more serious research pass on how to move the watch face from "stacked cut paper" toward something that reads as painterly, atmospheric, and intentional.

It combines:

- what the current prototype is doing wrong
- what digital ink/watercolor rendering research suggests
- what Garmin Connect IQ can realistically support
- which implementation paths seem most promising for this project

## Prototype Postmortem

The first few visual experiments were useful failures.

### Failure 1: ridge polygon / cut-paper mountain

The earliest versions treated the mountain as a small number of clean layered shapes.

That produced:

- hard silhouette edges
- flat value bands
- mist that read as design strips instead of atmosphere
- a construction-paper / poster-cutout look

### Failure 2: circles and ellipses as fake wash

The next experiments introduced alpha and buffered rendering, which was the right architectural move, but the visual primitive was still wrong.

Those versions produced:

- rows of translucent dots
- rows of translucent ellipses
- repeated stamp spacing the eye could immediately detect
- "MS Paint with shape tools" instead of ink wash

### Failure 3: point-field raster body

The next experiment moved the mountain body to `drawPoint()` accumulation inside a cached `BufferedBitmap`.

That produced two useful findings:

- the visible-primitive problem was reduced
- but the renderer became too slow and tripped the watch-face watchdog when the point field was dense enough to matter

When reduced enough to survive, the result became:

- faint scratches
- dust-like speckling
- not enough tonal mass
- not enough believable mist/body relationship

### What was still valuable

Even though the output was not good enough, two things were learned:

- alpha accumulation is necessary
- cached off-screen rendering is still the right architectural foundation for active mode
- full-screen dense procedural point fields are probably not the right production path on this device

### Failure 4: first imported bitmap assets lost fidelity

The first two authored PNG assets survived on disk correctly but did not survive visually once drawn through the Garmin resource path.

What was observed:

- source PNGs contained real varying alpha
- imported resources looked materially more binary / dithered / quantized on screen
- the rendered look no longer matched the authored softness

This means the first asset test did not actually test only the art.

It also tested:

- Garmin resource packing
- resource color depth / palette conversion
- bitmap alpha behavior at draw time

### Resolution: tuned bitmap import restored credibility to the asset path

After introducing an explicit bitmap-fidelity harness, the same asset imported with tuned resource settings looked materially better than the default import.

The key tested settings were:

- `dithering="none"`
- `automaticPalette="false"`
- `packingFormat="png"`
- `compress="false"`

Outcome:

- default imports remained visibly poor
- the tuned main asset looked genuinely promising
- the tuned simple asset was acceptable, though weaker than the tuned main asset

This is the first evidence that the asset idea itself is not the problem.

The main problem was import fidelity.

### 2026-03-24 checkpoint result: `codexrevamp2`

The tuned-import comparison has now produced a result strong enough to change project direction with confidence.

Checkpoint:

- `art/checkpoints/2026-03-24_codexrevamp2.png`

Observed result:

- default imports still looked clearly bad
- the tuned main asset looked genuinely good
- the tuned simple asset looked acceptable but not as strong

Research implication:

- authored grayscale-alpha assets can survive the Garmin pipeline well enough for this project
- bitmap import settings are not an implementation detail; they are part of the visual system
- future research and testing should treat tuned import as the default baseline, not as an optional optimization

### 2026-03-24 checkpoint result: `codexrevamp3`

The next useful test was not fidelity but repetition.

Checkpoint:

- `art/checkpoints/2026-03-24_codexrevamp3.png`

Observed result:

- the tuned non-simple asset remains visually stronger when used repeatedly in a mountain-like cluster
- the tuned simple asset loses richness faster when repeated

Research implication:

- the project should bias toward assets with more internal tonal/event structure, not ultra-minimal simplified shapes
- source assets should probably start lighter than intuition suggests, because repeated placement creates the final density

### 2026-03-24 checkpoint result: `codexrevamp4`

This is the first checkpoint that meaningfully restores confidence in the asset-driven path.

Checkpoint:

- `art/checkpoints/2026-03-24_codexrevamp4.png`

Observed result:

- the repeated main asset is starting to create convincing soft mountain bodies
- the scene is still rough, but it no longer reads primarily as visible primitive experiments
- the remaining problem is no longer "can assets create mass"
- the remaining problem is "how do we give the mountain a structured crest without losing softness"

Research implication:

- assets appear well suited for body mass
- crest definition may be better handled by a separate system:
  - a related narrow asset family
  - a soft procedural ridge line
  - or both

Additional implementation thought:

- mirrored or flipped asset use is worth testing if the Garmin bitmap path supports it cleanly, because repetition is now one of the main visible limitations

## The Core Diagnosis

The current face still reads as vector composition, not ink wash.

The main issue is not just "hard edges." It is that the rendering logic is still shape-first:

- one ridge equals one form
- each form has a stable local value
- mist is still mostly band-like
- the mountain is treated as an object silhouette instead of pigment accumulating and dissolving on paper

Traditional ink wash and successful digital watercolor/ink stylization rely much more on:

- tonal variation inside the same form
- edge instability
- local drying / bleeding behavior
- granulation or substrate texture
- selective dark accents rather than uniform filled masses
- strong negative space

That suggests the next leap should not be "add more objects."

It should be "change the rendering grammar."

## The New Core Primitive

The most important visual insight so far is that the mountain should not be conceived primarily as a horizontal silhouette.

The better primitive is:

- a vertical ink spine or pillar
- darkest near the crest or top
- broken and dissolving as it descends
- partially erased by mist toward the base

This matches the shared references much better than either:

- one filled mountain polygon
- many repeated circular wash marks

So the new question is not:

- how do we draw a mountain shape

It is:

- how do we place a handful of vertical ink spines and let faint wash and mist connect or erase them

Another related framing now worth tracking:

- how do we create structural dark anchors near the crest and let the body below be implied by selective fade, wash, and erasure

## What The Research Suggests

### 1. Ink and watercolor effects are built from a small set of recurring phenomena

Across both art explanations and NPR research, the key recurring effects are:

- edge darkening
- bleeding / feathering
- dry-brush broken strokes
- paper substrate texture / granulation
- tonal gradation within one painted region
- negative space doing compositional work

This matters because it means we do not need a magical all-in-one painterly system.

We need a compact approximation of a few specific effects.

### 2. "Painterly" mountain rendering usually separates wash, stroke, and substrate

The strongest NPR work on ink/wash mountains does not rely on one solid fill.

Instead, it tends to separate:

- base wash
- structural strokes or wrinkle/texture strokes
- paper/canvas texture
- fading transitions

That maps well to this project.

### 3. Garmin is capable enough for controlled stylization, but not for heavy image-space simulation

Official Garmin docs confirm the relevant parts:

- `Toybox.Graphics` supports watch-face drawing
- alpha-aware buffered bitmaps are available
- blend modes exist, though more advanced ones may depend on GPU support
- AMOLED watch faces still have low-power constraints

Inference:

We should not attempt a full watercolor simulator.

We should attempt a stylized approximation using:

- a few off-screen buffers in active mode
- careful alpha compositing
- deterministic noise/jitter
- small stamp-like textures

## Three Serious Paths Forward

## Path A: Vertical Spine Wash Renderer

This is the safest path and my current top recommendation.

### Idea

Stop drawing "the mountain" as a single filled polygon.

Instead:

1. Generate 3 to 8 vertical spine anchors.
2. Paint narrow dark crest columns near the top of each spine.
3. Expand each column downward into lighter, wider, broken wash passes.
4. Use mist and paper tone to erase or dissolve the lower body.
5. Connect only some adjacent spines with faint lateral washes.

### Why it may work

This directly attacks the current failure mode.

Instead of one stable mass, the mountain becomes a small family of vertical ink accumulations.

### Garmin fit

Good.

This can be done with repeated translucent fills in a buffered bitmap, even without fancy shaders.

### Risk

If overdone, it can become muddy or stripe-like rather than painterly.

### What would make it work

- 3 to 8 main spines
- limited palette
- strong top-to-bottom fade
- only selective lateral linking
- mist acting as erasure, not decoration

## Path B: Stamp-Based Brush Engine

This is the most promising "artistic leap" path if Path A is not enough.

### Idea

Build a tiny library of hand-authored stamp textures:

- soft wash blot
- dry brush fragment
- feathered mist strip
- vertical ink falloff stroke

Then compose the landscape from repeated stamped placements rather than from pure geometric shapes.

### Why it may work

Most painterly feel comes from edge and fill behavior, not perfect geometry.

Even a very small set of good stamps could make the rendering feel much more organic.

### Garmin fit

Reasonable if the assets stay small and reused aggressively.

This path is much more viable than a large painted bitmap background because the stamps can be:

- tiny
- grayscale or low-color
- layered repeatedly

### Risk

- too many stamps can look like clip art or visual noise
- asset workflow gets more involved
- resource fidelity may not match the original authored PNG if the bitmap path quantizes or dithers alpha aggressively

### What would make it work

- 3 to 5 stamps total
- used asymmetrically
- randomization in placement, opacity, and slight scale
- a verified import/render path that preserves enough softness to justify authored assets

Current status:

- this path is now materially de-risked by the tuned-import result
- the main remaining question is not whether assets can survive import
- the main remaining question is how small and coherent the asset family can stay while still producing convincing landscapes

## Path C: Hybrid Buffered-Bitmap Wash Layer

This is the most technically ambitious path.

### Idea

Render a low-resolution wash layer into a buffered bitmap in active mode, then scale/composite it behind the time.

The wash layer would include:

- per-pixel noise
- soft paper texture
- blurred-looking wash accumulation
- low-frequency tonal breakup

### Why it may work

It could create the first truly non-flat paint field in the current project.

### Garmin fit

Possible, but riskier.

The official Graphics docs expose buffered bitmaps and alpha blending, but memory and active-mode complexity still matter.

### Risk

- memory
- implementation complexity
- low-power fallback duplication

### What would make it work

- very low internal resolution
- cached results
- active mode only
- a separate simplified AOD rendering path

## Path D: Procedural Vertical Fade Lines

This is a new avenue worth testing because it is closer to the reference mountain logic than either ridge polygons or dot clouds.

### Idea

Instead of drawing mountains as filled bodies, render many narrow vertical descents from a sparse crest.

Each descent would:

- start with a darker top pixel or short cap
- continue downward with probabilistic dropout
- drift slightly left/right
- fade toward near-nothing as it approaches the lower body

Placed repeatedly from left to right, these could create:

- structural cliff faces
- hanging ink descents
- implied body without obvious shapes

### Why it may work

This matches the reference images better than:

- repeated ellipses
- repeated rectangles
- broad point-cloud fill

It is also one of the few procedural approaches that naturally creates:

- verticality
- erosion
- disappearance

### Garmin fit

Potentially reasonable if the number of descents is kept small and each descent is short and sparse.

The danger is obvious: if implemented as too many per-pixel operations, it becomes another watchdog problem.

### What would make it work

- derive a small number of crest anchors first
- emit only a few descents per anchor
- keep each descent sparse
- combine with mist erasure and maybe one soft wash stamp behind it

## 2026-03-24 Research Update: The Stamp-Based Pivot

Following a deep dive into Monkey C Graphics capabilities (API 4.0.0+), we are pivoting from pure geometry/point-based rendering to a **Procedural Stamp-Based Engine**.

### New Technical Strategy

1.  **Procedural Stamps:** Instead of drawing `drawPoint` or `fillCircle` directly into the main scene, we will pre-render a small set of "brush tips" into `BufferedBitmap` objects during initialization.
    - `WashStamp`: A feathered, low-alpha circle with organic jitter.
    - `BrushStamp`: A textured, higher-contrast fragment for structural edges.
2.  **Graduated Mist:** Mist will be rendered as a series of overlapping, low-alpha rectangles or stamps to create a "dissolving" effect at the base of mountains, rather than solid bands.
3.  **Alpha Accumulation:** By drawing these stamps repeatedly with low alpha (e.g., 5-10%), we can build "tonal mass" that looks like pigment accumulating on paper.
4.  **Anti-Aliasing:** We will explicitly enable `setAntiAlias(true)` to ensure smooth edges on AMOLED displays.

### Why This Wins
- **Aesthetics:** It solves the "cut-paper" problem by introducing soft edges and internal tonal variation.
- **Performance:** Drawing a bitmap is faster than many individual `drawPoint` calls once the stamp is cached.
- **Flexibility:** Stamps can be scaled or rotated slightly to avoid repetitive patterns.

## Best Recommendation Right Now

The buffered-bitmap pivot has already happened, and that part was correct.

The best next experiment is:

### Recommended experiment

At this point, I no longer recommend a purely procedural full-scene solution as the most likely winner.

The best candidates now are:

- a hybrid asset-driven system
- a limited procedural vertical-fade-line system
- or a hybrid of those two

That offers the best tradeoff between:

- artistic improvement
- implementation tractability
- Garmin safety

## Concretely, What I Would Change Next

### 1. Treat structural anchors and body wash separately

A scene should contain a small set of structural anchors. Each anchor should drive:

- a dark top accent
- a limited number of descending fades or descents
- local breakup so the body is not one clean stripe
- a weak lower dissolve rather than a hard base

### 2. Add one reusable feathered mist stamp

Use it as subtraction by overlap and concealment, not as a decorative stripe.

### 3. Add one reusable dry-brush accent stamp

Use it only near the tops and outer edges of selected spines.

This gives the structure some "bone" without outlining the whole mountain.

### 4. If keeping a procedural path alive, make it narrow and specific

The best surviving procedural experiment is likely:

- sparse vertical fade descents from crest anchors

not:

- full-body point fill
- broad geometric wash construction

### 4. Reduce time contrast slightly only after the background becomes more atmospheric

Right now the time must remain dominant.

Once the wash layer is better, the time can be made slightly more elegant.

### 5. Keep AOD brutally simple

Do not try to replicate painterly richness in low power.

The richer wash system should mostly belong to active mode.

## What I Would Not Do Next

- do not add trees again yet
- do not add kanji status seals yet
- do not add more layers of hard-edged mountains
- do not jump to a full custom-digit pipeline yet
- do not over-detail the sun/moon yet

## Suggested Next Build Sequence

1. Decide whether the next build is:
   - asset-driven hybrid first, or
   - procedural vertical-fade descents first
2. Keep the current watchdog lesson in scope and avoid dense full-field raster loops.
3. Add one feathered mist stamp used as erasure.
4. Add one structural crest or dry-brush stamp.
5. Test in simulator.
6. Test on watch.

## Current Recommendation

My current recommendation is:

- move toward an asset-driven hybrid for the body/wash
- keep procedural logic for placement, variation, timing, and HR influence
- keep the procedural vertical-fade-line idea as the main remaining non-asset experiment worth trying

Important qualification:

- resource fidelity is now partially understood
- default bitmap import should not be trusted for this project
- tuned bitmap import makes the asset-driven path materially more credible
- the first untuned asset screenshots should not be treated as a fair evaluation of the authored art

Stronger version after `codexrevamp2`:

- tuned bitmap import is no longer just "more credible"
- it is the first path that has produced a visually trustworthy asset result in this project

## Sources

Official Garmin sources:

- Graphics API docs
  - https://developer.garmin.com/connect-iq/api-docs/Toybox/Graphics.html
- WatchFace API docs
  - https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html
- AMOLED watch-face guidance
  - https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-make-a-watch-face-for-amoled-products/
- Bitmap optimization FAQ
  - https://developer.garmin.com/connect-iq/connect-iq-faq/how-do-i-optimize-bitmaps/

Art / NPR references:

- Ink wash aesthetics overview
  - https://www.morphstudio.com/article/the-art-of-ink-wash-painting-a-journey-through-eastern-aesthetics
- Digital ink wash art guidance
  - https://www.tourboxtech.com/en/news/ink-wash-painting-digital-art.html
- Dry brush / texture discussion
  - https://www.painting-chinese.com/blog/how-to-add-texture-to-an-abstract-sumi-e-painting-1381517.html
- Ink and wash mountain NPR research
  - https://www.nature.com/articles/s40494-022-00825-z
- Watercolor stylization effects research
  - https://artineering.io/publications/edge-and-substrate-based-effects-for-watercolor-stylization
- Real-time watercolor stylization research overview
  - https://www.sciencedirect.com/science/article/pii/S0097849317300316
