# Checkpoint Postmortem: 2026-03-29 Codex 1 to 4

Last updated: 2026-03-29

Related docs:

- [Project Vision](JAPANESE_INK_HEARTRATE.md)
- [Render Spec](RENDER_SPEC.md)
- [Design Decisions](DESIGN_DECISIONS.md)
- [Research Directions](RESEARCH_DIRECTIONS.md)
- [Asset Plan](art/ASSET_PLAN.md)

Checkpoint images:

- [`art/checkpoints/2026-03-29_codex1.png`](art/checkpoints/2026-03-29_codex1.png)
- [`art/checkpoints/2026-03-29_codex2.png`](art/checkpoints/2026-03-29_codex2.png)
- [`art/checkpoints/2026-03-29_codex3.png`](art/checkpoints/2026-03-29_codex3.png)
- [`art/checkpoints/2026-03-29_codex4.png`](art/checkpoints/2026-03-29_codex4.png)

## Bottom Line

These checkpoints are regressions in overall scene believability.

It is not a total failure, because it confirms a few useful constraints:

- the open time window is still working
- vertical ink descent remains directionally correct
- soft paper tone still supports the concept

But the scene does not yet read as mountain landscape.

It reads as a field of separate smoke-columns or hanging ink tassels.

## What The Image Is Actually Doing

The image is built from narrow, mostly isolated vertical forms.

At a glance, the eye reads:

- repeated pillar shapes
- repeated dark caps
- weak lower-body connection
- too much empty space between main forms
- no convincing mountain plane behind the time

The result is airy and soft, but not grounded.

The renderer has escaped the old "cut paper ridge band" problem, but it has over-corrected into "disconnected vertical artifacts."

## Main Failure Modes

### 1. The anchors are too separate

Each vertical form behaves like its own object.

That creates:

- no shared landform
- no believable contour continuity
- no mountain-range rhythm

The forms feel placed next to each other rather than emerging from one geography.

### 2. Crest caps are too repeated

The darker top accents are similar in size, value, and shape.

That repetition makes the primitive visible.

Instead of one dominant anchor and a few subordinate supports, the scene presents many near-equal marks competing for attention.

### 3. The body wash is too thin

The descents have softness, but not enough mass.

Real ink mountains often rely on:

- a dark structural crest
- a mid-tone body wash
- then mist erasure

These checkpoints have the crest and some descent, but the middle body is too weak.

That makes the forms feel suspended rather than rooted.

### 4. There is not enough plane hierarchy

The scene needs:

- one clear main range
- one quieter distant layer
- maybe one framing mass

These checkpoints have many similar-value vertical events instead.

That flattens depth.

### 5. Mist is not yet doing enough compositional work

The image has softness, but not enough active concealment.

The mist is not strongly carving valleys or tying separate forms into a believable shared atmosphere.

It is acting more like soft air than structural erasure.

## Why It Feels Like A Step Back

Earlier failures were too geometric.

This one is less geometric, but it also loses too much landscape structure.

That matters because the target is not:

- abstract ink texture

It is:

- a readable landscape transformed from HR data

These checkpoints drift toward abstraction faster than they gain mountain character.

## What To Keep

These parts are worth preserving:

### 1. The time window stays open

The central composition still leaves room for the digits.

That is good and should remain a hard rule.

### 2. The paper tone is still helping

The warm background continues to support the ink-on-paper feel.

### 3. Vertical descent logic is still promising

The problem is not that vertical descent is wrong.

The problem is that vertical descent cannot carry the whole mountain by itself.

It needs a larger body-wash system around it.

## What To Change Next

### 1. Reintroduce shared mountain mass behind the descents

Not a hard polygon band.

A soft, broader, low-contrast body wash.

The descents should sit inside a mountain body, not replace it.

### 2. Reduce the number of dark caps

Use:

- one dominant crest anchor
- one secondary crest anchor
- maybe one tertiary accent

Everything else should stay lighter and less explicit.

### 3. Merge nearby anchors into grouped landforms

Do not treat every anchor as an independent pillar.

Instead:

- 2 to 3 anchors can belong to one mountain mass
- only one of them needs the strongest crest accent

This will help the scene read as terrain rather than posts.

### 4. Increase mid-tone body density before the final fade

The mountain needs a middle register.

Right now the image jumps too quickly from:

- dark cap
- to pale descent
- to paper

That is too little tonal structure.

### 5. Make mist erase valleys and bases more intentionally

Mist should:

- conceal the lower joins between forms
- create depth breaks
- simplify the bottom

It should not merely soften edges.

## Updated Practical Rule

The renderer should not be built from isolated vertical pillars.

It should be built from:

- a shared mountain body
- a few structural crest anchors
- selective vertical descents
- mist that erases and separates

That is a better balance between:

- mountain readability
- sumi-e softness
- Garmin-safe rendering

## Updated Anti-Goals

Do not let the next iteration become:

- a skyline of equal vertical columns
- a necklace of repeated dark caps
- an abstract curtain of descents
- a scene with no dominant landform

## Short Version

These checkpoints prove that:

- "more vertical" is not enough
- "more organic" is not enough

The missing ingredient is shared landform mass.

The next renderer should restore a soft mountain body first, then use vertical descents as accents inside that body.

## Codex 3 Read

`codex3` confirms that the current renderer is still expressing the same underlying grammar as `codex1` and `codex2`.

What improved slightly:

- some columns are broader
- the lower fades feel a little heavier
- the time window is still open

What did not change enough:

- the scene still reads as separate vertical plumes
- dark caps still repeat across too many anchors
- the mountain still lacks a convincing shared middle body
- the descents still carry too much of the composition

Interpretation:

- the implementation changed
- the visual grammar did not change enough

That means further tuning of the same anchor-by-anchor approach is unlikely to solve the problem cleanly.

The next step has to be structural:

- add a shared body-wash pass behind grouped anchors
- reduce crest accents to one dominant and one secondary mark
- make descents subordinate to the body instead of equal to it

## Codex 4 Read

`codex4` is the first checkpoint in this branch that clearly reflects the structural code change.

What improved:

- there is now a visible shared middle body behind the anchors
- the scene no longer reads only as separate tassels
- the bottom half starts to feel more connected

What is still wrong:

- the new shared body reads more like a gray fog bank or soft slab than a mountain plane
- the central mass is too broad and too uniform under the time
- the left and right edge pillars are still visually loud
- crest accents are still not selective enough in feel, even if there are fewer of them technically
- the scene has moved from "separate columns" toward "columns plus a soft mound," but not yet to "mountain landscape"

Interpretation:

- the renderer is now moving in the correct direction
- but the new body-wash pass is too blunt

The shared mass solved one problem and exposed the next one:

- we now have connectivity
- but not enough mountain character inside that connected mass

## Updated Diagnosis After Codex 4

The current failure is no longer primarily "there is no shared landform."

Now the failure is:

- the shared landform is too soft, too even, and too low-information

It sits behind the time like a generalized gray mound instead of a shaped shan shui body.

So the next stage is not:

- add more mass

It is:

- shape the mass more intelligently

## What The Next LLM Should Do

This is the handoff point.

Do not go back to isolated pillar logic.

Do not keep tuning `codex1` through `codex3` behavior.

The shared body-wash direction in `codex4` is the correct branch, but it needs refinement.

Recommended priorities for the next model:

### 1. Keep the shared body-wash pass

That was the right structural move.

Do not remove it.

### 2. Make the body read as mountain, not fog

The body contour needs:

- stronger asymmetry
- more believable ridge-to-shoulder shape
- less uniform central width
- clearer dominant peak hierarchy inside the mass

### 3. Reduce the visual weight of edge pillars

The left and right side masses are still behaving like isolated posts.

They should frame the scene quietly, not compete with the center.

### 4. Let the body do more of the work and the descents do less

Descents should be sparse structural accents inside the body.

If they remain too visible, the renderer will slide back toward tassels.

### 5. Carve the shared body with mist, not blur it into existence

Mist should remove parts of the landform to create valleys and depth breaks.

It should not merely make the mass softer.

### 6. Keep the time window open

This remains one of the few consistently successful constraints across all four checkpoints.

## Current Best Summary

`codex1` to `codex3` proved that isolated vertical structure fails.

`codex4` proves that shared mass is necessary, but crude shared mass is not sufficient.

The next renderer should aim for:

- shared body first
- shaped hierarchy inside the body
- selective crest accents
- sparse descents
- mist as subtraction

That is the correct handoff state for the next LLM.
