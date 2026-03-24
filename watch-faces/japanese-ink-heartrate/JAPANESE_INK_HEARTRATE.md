# Mononoke Ink Heart Watch Face
_A product vision + iterative build plan for a Garmin Connect IQ watch face_
_Target audience: coding LLM / coding agent / Codex-style implementation assistant_

Engineering reality check: see [FEASIBILITY_ASSESSMENT.md](FEASIBILITY_ASSESSMENT.md) for the current Garmin-specific feasibility read, scope trims, and recommended implementation constraints.

Shared technical references:
- [Master Map](../../common/MASTER_MAP.md)
- [Bird's Eye View](../../common/BIRDSEYE_VIEW.md)
- [Build and Sideload](../../common/workflow/BUILD_AND_SIDELOAD.md)
- [App Lifecycle and Power](../../common/architecture/APP_LIFECYCLE_AND_POWER.md)
- [Forerunner 265 Spec](../../common/architecture/SPEC_FORERUNNER_265.md)
- [Vivoactive 6 Spec](../../common/architecture/SPEC_VIVOACTIVE_6.md)
- [Design Decisions](DESIGN_DECISIONS.md)
- [Research Directions](RESEARCH_DIRECTIONS.md)

## Project Summary

Build a Garmin watch face that feels like a subtly evolving ink painting rather than a gadget dashboard.

The watch face should present a bold, readable digital clock in the foreground, while the background behaves like a minimalist Japanese ink landscape whose mountain contours are influenced by recent heart rate data. Over time, the face should become expressive without becoming noisy: subtle mist, sparse tree marks, and a sun or moon that moves according to real local time.

This should begin as a small, testable watch face that runs at all on the user's real device, then gradually evolve into something beautiful and quietly responsive.

The artistic target is not photorealism and not AI-image generation. It is restrained, procedural, elegant, memory-conscious visual design: a face that looks expensive and intentional because a few carefully chosen drawing rules create a lot of mood.

---

## Core Vision

The final watch face should evoke the feeling of:

- a paper or parchment-like watch background
- one or more misty ink mountain ridges
- the mountain shape changing over time based on recent heart-rate history
- a sun or moon moving in the sky based on actual time of day
- sparse tiny trees or foliage marks placed on ridges
- large, highly readable time text in front
- minimal clutter and strong composition

The data should feel transformed into art, not displayed as a chart.

The watch face should not scream “fitness dashboard.”
It should feel like “a subtly evolving Japanese ink painting that happens to be a clock.”

---

## Artistic Direction

### Desired mood
- calm
- elegant
- slightly mystical
- minimal but not sterile
- readable at a glance
- expressive without being busy

### Visual style
- sumi-e / ink wash inspired
- soft layered depth
- restrained palette
- plenty of negative space
- subtle asymmetry is welcome
- procedural but hand-touched in feeling
- vertical ink structure is preferred over one dominant ridge silhouette

### Palette direction
- warm washi / mulberry-paper background
- dense sumi black for the main ridge and key contrast
- diluted gray washes for distant layers and mist
- a restrained vermillion accent used sparingly

### Not the goal
- not a literal line chart of HR
- not a crowded widget dashboard
- not a full-color fantasy illustration
- not heavy bitmap art if it can be avoided
- not so abstract that the time becomes hard to read

---

## Functional Goals

### Must-have
- works as a Garmin Connect IQ watch face
- displays current time clearly and prominently
- runs on the user's Forerunner 265 first
- has a stable “hello world” baseline that compiles and renders on-device

### Strongly desired
- mountain silhouette influenced by heart-rate data
- sun and moon shown in the sky based on real time
- simple layered depth and mist
- visually pleasant idle state even if heart-rate data is limited
- support for the user's own watch first, then ideally similar watches

### Nice-to-have later
- sunrise/sunset-aware sky behavior
- battery indicator integrated elegantly
- date/day shown subtly
- settings for 12h/24h, contrast, or style intensity
- compatibility with multiple devices that support heart rate and enough graphics features

---

## Compatibility Priority

Implementation should be guided by this order:

1. **Primary target:** Forerunner 265
2. **Secondary target:** Vivoactive 6
3. **Tertiary target:** similar Garmin watches with heart-rate support
4. **Best case:** broad compatibility across watches with compatible Connect IQ graphics/device capabilities

The project should not over-optimize for universal compatibility too early.
It is acceptable for early phases to work only on the Forerunner 265 if that speeds progress.

When there are tradeoffs:
- prefer correctness and beauty on the primary target
- degrade gracefully where possible
- avoid architecture that assumes all watches are identical

---

## Design Principles for the Coding Agent

### 1. Favor procedural drawing over static imagery
Use draw calls, buffered composition, and small reusable marks rather than large background assets whenever practical.

Important clarification:

- "procedural" does not have to mean "everything is synthesized from raw primitives"
- a disciplined hybrid of procedural placement plus tiny grayscale assets is still consistent with the project

### 2. Keep memory use low
Prefer:
- a few arrays of points
- small reusable calculations
- sparse decorative marks
- simple palettes
- minimal retained state

Avoid:
- giant image backgrounds
- excessive per-frame allocations
- expensive redraw logic that is unnecessary for a watch face

### 3. Make beauty emerge from a few strong rules
A small number of thoughtfully chosen visual rules is better than many weak effects.

Examples of useful high-level rules:
- the lower portion of the screen contains mountain mass
- the upper portion contains sky and sun/moon
- the time sits in open negative space
- heart rate influences the mountain silhouette, not every part of the design
- mist appears mainly in valleys and overlaps ridges softly
- trees are sparse accents, not dense detail
- mountain structure should emerge from a few vertical ink spines, not one hard-edged cutout band
- body wash may need to come from a small reusable asset family rather than pure geometry

### 4. Separate the artistic system from the device/data system
Try to keep these concerns conceptually distinct:
- data acquisition
- normalization / shaping
- scene composition
- drawing
- device compatibility / fallbacks

The exact code architecture can be simple, but the thinking should preserve those separations.

### 5. Build in layers
At every stage, the watch face should still look intentional, even if incomplete.

---

## Conceptual Scene Breakdown

### Foreground
- large bold digital time
- extremely readable
- central or near-central placement
- likely the strongest contrast element on screen

### Midground
- primary mountain silhouette
- this is the main artistic response to recent heart-rate data
- should feel like a ridge line, not a graph

### Background
- softer secondary ridge or mist layer
- optional subtle paper/sky tone
- sun or moon moving through upper sky region

### Small accents
- tiny trees or brush marks on one ridge
- maybe one larger isolated tree if composition allows
- decorative but sparse
- a later vermillion seal motif is acceptable if it remains subordinate to time and landscape

---

## Heart Rate as Art

The heart-rate data should be treated as inspiration for mountain geometry, not plotted literally.

### Concept
Recent heart-rate samples become a ridge shape.

### Desired effect
- lower, steadier heart rate produces gentler terrain
- spikes or activity create sharper or taller peaks
- smoothing transforms “data noise” into landscape form
- the most recent data should feel like the present edge of the landscape

### Important artistic constraint
The result should read as “mountain silhouette” first, “data-driven” second.

### Acceptable fallback
If real heart-rate history is hard to access or inconsistent across devices, a plausible fallback visual should still exist:
- use current HR
- use a rolling synthetic terrain seeded by HR
- use cached or simplified historical behavior
- temporarily use mock/sample data during development

Do not let lack of perfect HR history block the entire project early.

---

## Sun and Moon Concept

The sky should contain a small celestial marker:
- sun during the day
- moon at night

### Behavior goals
- position changes with time
- should feel calm and natural
- should not dominate the watch face
- can be simple and symbolic

### Progressive realism options
Early:
- place sun/moon by time-of-day on an arc

Later:
- incorporate sunrise/sunset logic if practical
- color/intensity shift between dawn/day/dusk/night

The visual should remain subtle.

---

## Mist Concept

Mist is one of the easiest ways to make the face feel painterly.

### Desired look
- pale horizontal or softly curved bands
- concentrated in valleys or lower mid-screen areas
- partially obscuring some mountain layers
- very restrained

### Purpose
- adds depth
- hides visual harshness
- helps mountain layers feel atmospheric
- gives the face more beauty without much geometric complexity

### Important refinement
Mist should often behave like concealment or erasure.

If it reads as a decorative stripe, the rendering has gone in the wrong direction.

If needed, mist should be one of the first things allowed to become asset-driven.

---

## Tree Concept

Trees should be tiny, sparse, and stylized.

### Desired look
- little ink marks
- perhaps a few clustered strokes
- maybe one slightly more deliberate tree silhouette
- only enough to suggest forest or life

### Rule
If the trees begin to look like a clip-art forest, the design has gone too far.

For now, trees remain subordinate to solving mountain rendering itself.

---

## Readability Rules

The time must always win.

The artistic background is successful only if it makes the watch face more beautiful without reducing readability.

### Time display should be:
- large
- bold
- high contrast
- visible in both active and dim conditions if relevant
- not merged into mountain texture
- horizontal first; more experimental calligraphic layouts only after standard readability is proven

Avoid placing detailed ridge lines directly through the time unless the contrast is handled carefully.

---

## Engineering Philosophy

This project should be approached as an iterative art-and-systems build.

The coding agent should:
- keep code understandable
- favor small verifiable steps
- avoid giant rewrites unless necessary
- preserve working milestones
- leave comments where the Garmin/Monkey C behavior is non-obvious
- help debug with realism, not overconfidence

There will likely be several points where the implementation runs into:
- Connect IQ quirks
- Monkey C syntax annoyances
- resource declaration weirdness
- device capability differences
- heart-rate API limitations
- simulator vs real-watch mismatch

The plan should expect these and absorb them.

---

# Iterative Plan

## Step 0: Prove the toolchain and device loop
Goal: prove that this repository can produce a watch face binary that installs and renders on the actual Forerunner 265.

### Deliverable
A minimal digital watch face project in this repo that:
- builds from the local SDK/toolchain without manual guesswork
- targets the Forerunner 265 explicitly
- installs on the real watch
- renders the current time correctly
- uses no HR logic, no scene generation, and no artistic extras yet

### Success criteria
- repository contains the actual project skeleton, not just concept docs
- `manifest.xml`, `.jungle`, source layout, and resources are all understood and valid
- simulator launch works
- real-device sideload works
- a photo or direct user confirmation from the watch establishes that it rendered successfully

### Failure conditions
If any of these happen, Step 0 is not done:
- build only works in simulator but not on device
- watch installs but shows an IQ error
- time renders incorrectly
- project structure is still ambiguous enough that the next edit would be guesswork

### Why this is Step 0 instead of Phase 0
This is narrower than a normal first milestone. Its only job is to remove uncertainty around SDK setup, project structure, and on-device deployment.

---

## Phase 0: Project sanity / hello world
Goal: compile, install, and display a basic watch face on the user's Forerunner 265.

### Deliverable
A trivial watch face that:
- compiles cleanly
- runs on the simulator
- runs on the real watch
- displays the current time

### Success criteria
- no build-system confusion remains
- project structure is understood
- app/view/watchface lifecycle is understandable enough to modify safely

### If blocked
Possible issues to solve:
- jungle/manifest/resource configuration
- wrong class names or inheritance
- draw/update methods not firing as expected
- simulator success but real-watch install issues

This phase matters more than aesthetics.

---

## Phase 1: Minimal beautiful baseline
Goal: create a visually pleasant watch face without HR-driven terrain yet.

### Deliverable
A simple watch face with:
- bold time
- clean background color or subtle paper tone
- optional single decorative ridge or horizon line
- optional tiny sun/moon placeholder

### Purpose
This establishes composition before introducing dynamic data.

### Success criteria
- the user can wear it and not hate it
- the face already feels intentional
- time readability is strong

### If blocked
Possible issues to solve:
- text placement on round screen
- font choice limitations
- update frequency and battery considerations
- anti-aliasing / jagged visuals

---

## Phase 2: First mountain silhouette
Goal: render a procedural mountain form from fake or sample data.

### Deliverable
A mountain system that:
- is generated from an array of values
- uses a small number of vertical ink spines or anchors
- visually reads as mountain structure rather than a chart
- can be drawn consistently on-device
- sits behind the time

### Notes
Use mock data first if needed.
Do not wait on real heart-rate integration.
Avoid reverting to one dark filled polygon if it starts looking cleaner in code but worse in art.
Be willing to use a tiny grayscale asset family if pure procedural rendering keeps failing aesthetically.

### Success criteria
- mountain structure looks like landscape, not graph
- composition still feels clean
- code path for data-to-structure exists
- the result does not read as cut paper or rows of dots
- the renderer stays within watch-face runtime limits

### If blocked
Possible issues to solve:
- polygon fill or contour drawing behaving strangely
- screen coordinate mapping looking too sharp or too flat
- update logic creating flicker or heavy redraw cost

---

## Phase 3: Sky object tied to time
Goal: add a simple sun/moon system based on current local time.

### Deliverable
A celestial object that:
- appears in the sky
- changes by time of day
- remains subtle
- improves mood rather than cluttering the screen

### Early version
A time-of-day arc is sufficient.

### Later refinement
Optionally incorporate more accurate day/night transition behavior.

### Success criteria
- day/night is visually legible at a glance
- object placement feels balanced
- no conflict with time display

### If blocked
Possible issues to solve:
- time APIs
- arc mapping that looks awkward on round displays
- over-bright or distracting celestial rendering

---

## Phase 4: Use real heart-rate input
Goal: replace mock terrain data with real heart-related data.

### Deliverable
A version where mountain geometry is influenced by actual heart-rate information available on-device.

### Important
Be pragmatic here. If direct access to a full recent history is difficult, use a fallback path and continue.

### Acceptable progressive levels
1. current HR affects terrain intensity or scaling
2. short rolling history affects contour
3. richer history, if available, shapes the ridge more meaningfully

### Success criteria
- visual behavior responds to the user's physiology in some way
- it is stable and believable
- it does not become ugly when HR is flat or noisy

### If blocked
Possible issues to solve:
- API access limitations
- permission/context limitations in watch faces
- inconsistent data availability by device
- simulator not representing real data well

---

## Phase 5: Atmospheric depth
Goal: add mist and possibly a second ridge layer.

### Deliverable
A scene with:
- one foreground ridge
- one softer background layer and/or mist
- stronger sense of depth

### Success criteria
- face feels substantially richer than earlier versions
- added layers do not clutter readability
- performance remains acceptable

### If blocked
Possible issues to solve:
- too much visual noise
- mist looking like random blobs instead of atmosphere
- low contrast making the face muddy

---

## Phase 6: Sparse trees / brush accents
Goal: add a very small amount of life and detail.

### Deliverable
A few procedural tree-like marks or brush accents placed intentionally.

### Constraints
- very sparse
- visually subordinate to mountain and time
- should feel hand-suggested, not literal

### Success criteria
- face feels more alive
- accents improve composition
- no “stamp tool” repetition feeling

### If blocked
Possible issues to solve:
- trees too large
- trees too numerous
- procedural marks looking gimmicky

---

## Phase 7: Refinement toward the dream
Goal: unify all components into the intended final watch face.

### Desired final composition
- bold readable time
- HR-shaped mountain ridge
- supporting atmospheric layers
- time-based sun/moon
- sparse organic accents
- elegant and wearable

### Success criteria
- user would genuinely want to use it daily
- looks intentional on the Forerunner 265
- adaptable to Vivoactive 6 if feasible
- degrades gracefully on similar devices

---

# Testing Strategy

## Primary real-device test path
Always keep the Forerunner 265 as the main truth source.

The simulator is useful but not sufficient.

### For each phase
Verify:
- build succeeds
- watch face launches
- time is correct
- layout is readable
- visuals are centered and balanced on the actual watch
- battery/performance seems reasonable

## Secondary compatibility path
After a phase works on the primary device:
- test on simulator(s) for similar models
- identify anything device-specific
- add fallback logic only where actually needed

---

# Definition of Done by Stage

## Done for Phase 0
The watch face works at all.

## Done for Phase 1
The watch face is plain but pleasant.

## Done for Phase 2
The mountain exists and looks like a mountain.

## Done for Phase 3
The sky reacts to time.

## Done for Phase 4
The mountain is meaningfully connected to heart-rate input.

## Done for Phase 5
The face has atmosphere and depth.

## Done for Phase 6
The face has organic accents.

## Done for Phase 7
The watch face feels like the original dream.

---

## Non-Goals for Early Iterations

Do not front-load these unless they are easy:
- perfect cross-device support
- advanced settings UI
- overly realistic brush simulation
- excessive metrics display
- exact sunrise/sunset astronomy
- polished app-store packaging
- hyper-optimized code before visuals are proven

What is acceptable to front-load:

- rendering experiments that significantly improve the artistic primitive
- buffered-bitmap architecture in active mode
- tiny reusable grayscale stamp assets if they materially improve the scene

---

# Guidance for Debugging Sessions

When implementation gets stuck, the coding assistant should respond in a grounded, diagnostic way.

Useful categories of “oh shoot help me solve this issue” moments include:
- project file / jungle / manifest issues
- drawables/resources not loading
- watchface lifecycle confusion
- simulator vs real-device mismatch
- text rendering/layout issues
- incompatible APIs between devices
- heart-rate data not accessible as expected
- performance or memory concerns
- visuals looking technically correct but artistically wrong

When debugging, prefer:
- minimal targeted fixes
- explanations tied to the actual code
- preserving working behavior
- keeping the artistic vision in view

Avoid:
- rewriting everything casually
- inventing APIs or behavior without checking
- sacrificing the project vision just to get “some output”

---

# Implementation Tone Request to the Coding Agent

Please treat this as a serious small art-engineering project, not a throwaway watchface tutorial.

Priorities in order:
1. get it running on the user's watch
2. keep it visually elegant
3. evolve in clear stages
4. preserve simplicity and memory awareness
5. help debug honestly when Garmin/Monkey C quirks appear

The implementation should stay flexible enough to discover what works best on the real device, but the overall north star should remain:

**A calm, beautiful Garmin watch face where time sits over a procedural ink landscape whose mountains are shaped by heart-rate data, with a subtle sun or moon and a few atmospheric details.**
