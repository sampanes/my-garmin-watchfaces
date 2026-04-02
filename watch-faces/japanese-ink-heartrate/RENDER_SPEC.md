# Japanese Ink Heartrate Render Spec

Last updated: 2026-03-29

Related docs:

- [Project Vision](JAPANESE_INK_HEARTRATE.md)
- [Feasibility Assessment](FEASIBILITY_ASSESSMENT.md)
- [Design Decisions](DESIGN_DECISIONS.md)
- [Research Directions](RESEARCH_DIRECTIONS.md)
- [Checkpoint Postmortem: 2026-03-29 Codex 1 and 2](CHECKPOINT_2026-03-29_CODEX1_POSTMORTEM.md)
- [HR Facts](ROOT_HR_FACTS.md)
- [Asset Plan](art/ASSET_PLAN.md)

## Purpose

This document turns the current art research and checkpoint postmortems into a concrete rendering target for the Garmin implementation.

The goal is not to describe every possible ink idea.

The goal is to define:

- the visual grammar the renderer should use
- how HR data should influence that grammar
- which previous mistakes must not return
- a production-safe draw order for Connect IQ

## Core Rendering Rule

The heart-rate history graph should disappear inside a mountain grammar.

The watch face should not render:

- a literal left-to-right chart
- a single full-width ridge line
- repeated stamped peaks at every local maximum
- isolated vertical pillars that do not belong to a shared landform

The watch face should render:

- one shared main mountain body
- 2 to 4 grouped structural anchors inside that body
- one dominant crest accent and at most one or two secondary accents
- selective vertical descents as accents, not as the whole mountain
- mist that conceals joins, bases, and valleys to create depth

Inference from the repo checkpoints and references:

- the successful experiments gain quality when the scene is built from selective vertical structure inside a broader form
- the unsuccessful ones expose the primitive too clearly, either as bands, dots, repeated peaks, or disconnected ink columns

## Visual Target

The renderer should aim for these qualities at a glance:

- time remains the dominant read
- mountain reads as a scene, not a collection of marks
- mountain reads as ink, not as geometry
- darkest marks are sparse and near crests
- the mountain has a visible middle register, not only caps and fades
- mist removes information as much as it adds atmosphere
- negative space is active, not leftover

This aligns with the current design rules in [Design Decisions](DESIGN_DECISIONS.md) and the external references summarized in [Research Directions](RESEARCH_DIRECTIONS.md).

## Data To Scene Mapping

HR should influence mountain character, not direct chart position.

Recommended mapping:

- recent max HR -> main body height and dominant crest emphasis
- recent min HR -> valley openness and mist depth
- HR volatility -> edge roughness and how broken the descents become
- current HR zone -> local ink density near the dominant anchor
- sustained effort duration -> width and grouping of the main landform
- cadence of change -> whether the body resolves as one broad mass or a split range

Recommended non-mapping:

- do not map each HR sample directly to one x-position on the ridge
- do not place one decorative mark for every local peak in the history
- do not let the newest sample create an obvious right-edge chart tip
- do not let volatility create a skyline of equal spikes

## Layer Grammar

### 1. Sky / paper layer

Use a warm washi ground with very subtle tonal variation.

Requirements:

- mostly flat paper tone
- slight vertical or radial variation is acceptable
- no obvious texture tiling
- celestial marker must stay subordinate to time

### 2. Ghost layer

This is a barely-there distant range.

Requirements:

- 2 to 3 broad forms only
- cooler and lighter than the main layer
- almost no hard accents
- mostly present to create depth behind the time

### 3. Main HR layer

This is the primary artistic response to the heart-rate history.

Requirements:

- one shared body first
- 2 to 4 grouped anchors inside that body
- one dominant anchor, one secondary anchor, remaining anchors quieter
- crest darkness concentrated in short sections, not continuous outlines
- visible mid-tone body mass before the final fade
- descents only on selected anchors
- lower third partially erased by mist

Failure mode:

- if the layer reads as separate pillars or smoke plumes, the body is too weak

### 4. Foreground framing masses

These are optional framing masses, not a mandatory full-width silhouette.

Requirements:

- use at most 1 left mass and 1 right mass
- keep central time window open
- avoid forming a dark horizontal belt across the whole lower screen
- do not let framing masses become equal competitors with the main range

### 5. Mist

Mist is an erasure system.

Requirements:

- irregular top edge
- uneven density
- stronger around valleys and mountain bases
- allowed to cut into mountain mass
- should help merge grouped anchors into one atmosphere
- should simplify lower joins rather than only blur edges

Failure mode:

- if mist reads as a rectangle or banner, the pass is wrong
- if mist is only softness and not concealment, the pass is too passive

## Primitive Set

The production renderer should use a very small family of primitives.

Recommended primitives:

- `crest_anchor_fragment`
- `vertical_fade_descent`
- one soft body-wash asset
- one feathered mist-erasure asset
- sparse procedural dry-brush accents
- sparse procedural paper grain

Not recommended as primary primitives:

- repeated circles
- repeated ellipses
- repeated rectangles
- dense point clouds
- full-width filled polygons without additional structure
- isolated descent columns with no shared wash behind them

## Asset Roles

Assets should be narrow in responsibility.

### `crest_anchor_fragment`

Purpose:

- provide the darkest structural mark
- create a broken calligraphic crest accent

Rules:

- use selectively
- place only near major anchors
- never assemble a continuous outline from repeated copies
- do not give every anchor an equal dark cap

### `vertical_fade_descent`

Purpose:

- imply cliff face and falling wash
- carry vertical motion from crest toward the body

Rules:

- vary scale slightly
- vary opacity slightly
- use uneven spacing
- let some descents terminate early
- place only inside or immediately under a shared body wash
- never let the scene become primarily a curtain of descent assets

### `body_wash_soft`

Purpose:

- provide shared landform mass
- unify grouped anchors into one mountain body
- create the middle tonal register that the recent regressions lost

Rules:

- broad and soft
- lower contrast than crest accents
- should exist before descents are added
- may overlap multiple anchors intentionally

### `mist_erasure`

Purpose:

- conceal the lower body
- separate planes
- create negative-space breathing room around the time

Rules:

- overlap mountain bodies asymmetrically
- break continuity
- never center it as a symmetric stripe
- use it to carve valleys and hide joins between grouped forms

## Draw Order

Recommended active-mode draw order:

1. paper background
2. celestial marker
3. ghost range wash
4. first mist separation pass
5. main HR body wash
6. grouped anchor reinforcement inside the main body
7. selective crest accents
8. selective vertical descents
9. very sparse dry-brush accents
10. foreground framing masses if needed
11. base mist erasure
12. subtle paper grain

The time should still sit above this stack in the watch-face view.

## Garmin-Safe Implementation Strategy

Use minute-cached buffered rendering.

Recommended structure:

1. sample or reuse recent HR data
2. reduce the data to a handful of scene descriptors
3. generate one main landform plus grouped anchor descriptors
4. render the full scene once into a `BufferedBitmap`
5. draw the cached result until the next minute or state change

Safe assumptions:

- `BufferedBitmap` is the right place for experimentation
- small alpha PNG assets are viable if imported with tuned settings
- repeated low-cost passes are safer than dense per-pixel simulation

Current asset-import rule from the repo:

- `dithering="none"`
- `automaticPalette="false"`
- `packingFormat="png"`
- `compress="false"`

See [Asset Plan](art/ASSET_PLAN.md) and [Design Decisions](DESIGN_DECISIONS.md).

## Explicit Anti-Goals

Do not reintroduce these:

- hard stacked ridge bands
- chart-like ridge lines
- obvious repeated peak stamps
- full-bottom dark slabs
- rectangular mist bands
- dense whole-scene raster loops
- too many symbolic motifs at once
- equal dark caps on many anchors
- disconnected vertical pillars with no shared body
- cap -> fade -> paper with no mid-tone body mass

## Acceptance Criteria For The Next Renderer

The next serious renderer should satisfy all of these:

- the mountain reads as a scene, not a graph
- the time window remains open and legible
- the darkest values occupy less area than the mid-tones
- the main range reads as one shared landform first
- grouped anchors feel related rather than isolated
- mist visibly conceals at least part of the lower mountain body
- no single primitive is obvious on first glance
- HR influence is believable but not literal
- the image does not read as a field of smoke-columns or tassels

## Updated Working Rule After 2026-03-29 Codex 1 and 2

The renderer must balance three things at once:

- shared landform mass
- selective vertical ink structure
- active mist concealment

The recent regression happened because the renderer kept the second item and lost too much of the first.

If a future iteration looks organic but no longer reads as mountain, it is still wrong.

## Suggested Build Sequence

1. Establish a shared body-wash layer that can connect grouped anchors.
2. Limit the number of strong crest accents to one primary and one or two secondary marks.
3. Reintroduce descents only after the body reads as mountain without them.
4. Use mist to carve valleys and hide joins between grouped forms.
5. Re-evaluate with checkpoint screenshots against `art/references/` and [Checkpoint Postmortem: 2026-03-29 Codex 1 and 2](CHECKPOINT_2026-03-29_CODEX1_POSTMORTEM.md).
