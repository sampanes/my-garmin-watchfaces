# Asset Plan

This folder is reserved for future painterly assets once the buffered-bitmap scene pipeline is stable.

Planned grayscale assets:

- `wash_blob_soft`
- `mist_strip_feathered`
- `dry_brush_edge`
- `paper_noise_tile`
- `seal_mark`

Current status:

- rendering pipeline has pivoted to a cached buffered-bitmap scene
- assets are not wired yet
- current scene uses procedural alpha-based placeholder marks

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
