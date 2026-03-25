# Asset Plan

This folder is reserved for painterly assets now that the bitmap-fidelity path is proving workable.

Planned grayscale assets:

- `wash_blob_soft`
- `mist_strip_feathered`
- `dry_brush_edge`
- `paper_noise_tile`
- `seal_mark`
- `vertical_fade_descent`
- `crest_anchor_fragment`

Current status:

- rendering pipeline uses a cached buffered-bitmap scene
- procedural stamps (WashStamp, BrushStamp) are implemented and in use
- scene uses alpha-based accumulation for tonal mass
- mist is rendered as graduated atmospheric layers
- structural anchors use dry-brush accents for edge sharpening
- first imported PNG asset test revealed a resource-fidelity problem: source alpha softness did not survive on-screen as expected

Recommended reference folder:

- `watch-faces/japanese-ink-heartrate/art/references/`

Use that for:

- ink landscape references
- watch-face references
- "wrong but informative" examples
- close-ups of crest, fade, mist, and seal behavior

Recommended checkpoint folder:

- `watch-faces/japanese-ink-heartrate/art/checkpoints/`

Use that for a small curated set of milestone screenshots from the simulator or real watch.

Suggested naming pattern:

- `YYYY-MM-DD_step-short-note.png`
- `2026-03-24_vertical-spine-first-pass.png`
- `2026-03-24_time-layout-cleaner.png`

Recommendation:

- ignore `art/references/` from git if it is mostly scraped inspiration, private material, or raw working context
- keep `art/checkpoints/` in git only if the set stays small and intentional
- do not dump every screenshot there; keep only milestone images that help explain what changed

If the project goes asset-driven, keep the asset family extremely small and general:

- one or two wash bodies
- one mist erasure strip
- one or two structural dark accents

The goal is a coherent grammar, not a collage.

Technical caution:

- authored PNG quality is not the only variable
- Garmin bitmap-resource rendering may quantize or dither alpha in ways that materially change the artwork
- asset production should continue, but bitmap import/render fidelity must be validated in parallel

Current fidelity test configuration:

- default bitmap import
- tuned bitmap import using:
  - `dithering="none"`
  - `automaticPalette="false"`
  - `packingFormat="png"`
  - `compress="false"`

Current conclusion from the fidelity harness:

- default import is not acceptable for this art direction
- tuned import is the only fair basis for evaluating grayscale alpha assets in this project
- `vertical_fade_descent.png` under tuned import is the first asset that has looked genuinely promising on-screen

## Confirmed Result From `codexrevamp2`

Checkpoint:

- `watch-faces/japanese-ink-heartrate/art/checkpoints/2026-03-24_codexrevamp2.png`

Result summary:

- `VerticalFadeDescentTuned` is the first asset in this project that has looked genuinely good on-screen
- `VerticalFadeDescentSimpleTuned` is acceptable, but weaker
- both default imports remain unacceptable

Asset-production rule from this point forward:

- all serious asset evaluation should use tuned bitmap import settings
- default-import output should be treated only as a warning case, not as an artistic reference

Default tuned settings:

- `dithering="none"`
- `automaticPalette="false"`
- `packingFormat="png"`
- `compress="false"`

Interpretation:

- the authored asset style is not being invalidated by the watch
- the Garmin default import path was invalidating it
- this means asset work is now worth real effort, provided the import settings stay disciplined

## `codexrevamp3` Production Lesson

Checkpoint:

- `watch-faces/japanese-ink-heartrate/art/checkpoints/2026-03-24_codexrevamp3.png`

Result:

- the non-simple tuned asset is clearly the stronger repeating building block
- the simple tuned asset is acceptable in isolation but weakens faster when repeated in a mountain pattern

Practical asset-authoring guidance:

- prioritize internal variation, broken softness, and asymmetry
- do not over-simplify the first-generation assets
- expect layered composition to increase darkness substantially
- author assets lighter than the intended final mass so overlap can do the darkening naturally

## `codexrevamp4` Directional Lesson

Checkpoint:

- `watch-faces/japanese-ink-heartrate/art/checkpoints/2026-03-24_codexrevamp4.png`

What improved:

- repeated use of the stronger main asset is finally producing believable soft mountain mass
- the project is no longer stuck in the "circles / rectangles / obvious primitives" failure mode

What still needs work:

- the crest line needs more structure and should not simply dissolve into the body
- repetition is visible because the current composition is relying on one asset too literally

Near-term asset strategy:

- keep the current non-simple asset family as the primary base
- consider a thinner companion descent asset later
- prefer a small related family over many unrelated one-off images
- if technically feasible, mirrored/flipped use of the same asset is worth testing to increase variation cheaply

Composition strategy:

- assets should provide the body mass
- a softer procedural crest/ridge line should provide top structure
- this is now a stronger direction than trying to make one asset solve both body and ridge
