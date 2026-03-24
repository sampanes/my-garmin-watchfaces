# Japanese Ink Heartrate Research Directions

Last updated: 2026-03-23

This note records the more serious research pass on how to move the watch face from "stacked cut paper" toward something that reads as painterly, atmospheric, and intentional.

It combines:

- what the current prototype is doing wrong
- what digital ink/watercolor rendering research suggests
- what Garmin Connect IQ can realistically support
- which implementation paths seem most promising for this project

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

## Path A: Multi-Pass Wash Painting

This is the safest path and my current top recommendation.

### Idea

Stop drawing "the mountain" as a single filled polygon.

Instead:

1. Generate a soft ridge spine.
2. Paint several semi-transparent wash passes around it.
3. Add a few darker accent strokes only near chosen crest segments.
4. Let the base dissolve into paper using lighter overlapping passes.

### Why it may work

This directly attacks the current failure mode.

Instead of one stable mass, the mountain becomes accumulated tone.

### Garmin fit

Good.

This can be done with repeated filled polygons and a few lightly varied offsets, even without fancy shaders.

### Risk

If overdone, it can become muddy rather than painterly.

### What would make it work

- 4 to 7 passes maximum
- limited palette
- much lighter distant ridge
- only sparse dark accents

## Path B: Stamp-Based Brush Engine

This is the most promising "artistic leap" path if Path A is not enough.

### Idea

Build a tiny library of hand-authored stamp textures:

- soft wash blot
- dry brush fragment
- feathered mist strip
- broken ridge accent

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

### What would make it work

- 3 to 5 stamps total
- used asymmetrically
- randomization in placement, opacity, and slight scale

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

## Best Recommendation Right Now

I would not jump straight to the buffered-bitmap path.

The best next experiment is:

### Recommended experiment

Combine Path A and a tiny part of Path B:

- use multi-pass wash rendering for the mountain body
- introduce 1 or 2 tiny feathered stamp textures for mist and dark accent breakup

That offers the best tradeoff between:

- artistic improvement
- implementation tractability
- Garmin safety

## Concretely, What I Would Change Next

### 1. Replace "one ridge polygon" with a wash stack

One generated ridge spine should drive:

- a pale underwash
- a mid-tone body pass
- a sparse dark edge pass
- a very low-opacity foot fade

### 2. Add one reusable feathered mist stamp

Instead of drawing mist as rectangles, draw a feathered horizontal wash stamp multiple times with varied widths and x positions.

### 3. Add one reusable dry-brush accent stamp

Use it only on selected crest sections.

This gives the ridge some "bone" without outlining the whole shape.

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

1. Implement a real wash-stack mountain renderer.
2. Add one feathered mist stamp.
3. Add one dry-brush accent stamp.
4. Test in simulator.
5. Test on watch.
6. Only then decide whether the project needs buffered-bitmap rendering.

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
