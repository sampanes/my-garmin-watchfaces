# Asset Plan

This folder is reserved for future painterly assets once the buffered-bitmap scene pipeline is stable.

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
