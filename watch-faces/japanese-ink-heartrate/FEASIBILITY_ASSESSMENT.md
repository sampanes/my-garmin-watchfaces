# Japanese Ink Heartrate Feasibility Assessment

Last reviewed: 2026-03-23

## Bottom Line

This watch face is feasible.

More specifically:

- The art direction is very feasible.
- The time-based sun/moon is trivial.
- Procedural mountain generation is feasible and a good fit for Connect IQ.
- The heart-rate-driven part is feasible, but only if the design assumes sampled, imperfect, minute-scale physiological input rather than a constantly repainting live biosignal canvas.

My honest rating:

- `9/10` feasible as a beautiful wearable watch face
- `7/10` feasible as an HR-reactive watch face
- `4/10` feasible if the expectation is continuous, full-screen, real-time animation on AMOLED while always-on

## Why I Think It Is Viable

The core concept matches the platform well in three ways:

1. The visual language is mostly vector-like and procedural.
2. The screen composition can stay sparse and readable.
3. The "data becomes art" layer does not require exact medical-grade heart-rate telemetry to feel convincing.

That combination matters. Garmin watch faces are much better at restrained generative graphics than they are at aggressive real-time rendering or heavy data processing.

## What Is Clearly Feasible

### 1. A strong ink-painting look

This is the safest part of the idea.

You do not need large bitmaps to get there. A convincing result can come from:

- 1 to 3 filled ridge silhouettes
- a few stroked contour lines
- soft mist bands
- sparse tree marks
- a subtle paper-toned background
- disciplined negative space around the clock

This is exactly the kind of design that can look premium without needing a lot of memory.

### 2. Time as the foreground hero

No issue here. Garmin watch faces are naturally good at large digital time with a composed background.

### 3. Sun/moon tied to time of day

Also straightforward. A simple clock-based arc is cheap, readable, and robust. Exact sunrise/sunset astronomy is optional and should not be part of the first serious implementation.

### 4. HR-influenced terrain

This is feasible if the terrain is interpreted loosely:

- smooth a short history window
- quantize it into a limited number of control points
- map it into ridge height, steepness, or roughness
- cache the generated ridge so redraw cost stays low

The visual goal should be "the ridge has a physiological mood" rather than "the ridge is a literal HR graph."

## The Real Constraint: AMOLED Watch Face Behavior

Your primary target, the Forerunner 265, is an AMOLED watch with a `416 x 416` round display and Connect IQ API level `5.2`. Garmin's current compatible device list shows the vivoactive 6 as a `390 x 390` AMOLED device with API level `5.1`.

That matters because AMOLED watch faces are not the same as always-on animated canvases.

Practical implication:

- in high-power mode, the watch face can update every second for a short period after a gesture
- in low-power mode, watch faces update far less aggressively
- AMOLED always-on behavior has stricter display-update constraints than full active mode

So the right mental model is:

- full beauty and subtle motion when the user raises the wrist
- elegant, simplified minute-cadence presence when the watch is idle

If the concept is framed that way, it is strong.

If the concept is framed as "the whole ink landscape keeps dynamically breathing all day in always-on mode," it is not realistic for the primary target.

## The Second Constraint: Heart-Rate Access Is Good Enough, Not Perfect

Garmin officially exposes historical heart-rate access through `Toybox.SensorHistory.getHeartRateHistory()`, and the API docs list both Forerunner 265 and vivoactive 6 as supported devices. That is the best foundation for this concept.

However:

- sample spacing is device dependent
- available history is not guaranteed to feel uniform
- watch-face update cadence is not continuous
- off-wrist or stale data periods happen

So the right implementation target is not "render the user's exact recent waveform."

It is:

- read a short heart-rate window when available
- derive a stable terrain signature from it
- fall back gracefully when samples are sparse or unavailable

## What I Would Change In The Vision Doc

The current doc is artistically strong. The main changes I would make are to tighten its assumptions.

### Change 1: Replace "living" with "minute-evolving"

Keep the mood, but ground the expectation.

Recommended wording:

> The face should feel alive when the user looks at it, and should evolve subtly over time rather than continuously animating at all times.

### Change 2: Reframe HR history as "recent physiological texture"

Recommended wording:

> Recent heart-rate samples influence the character of the ridge line, but the rendering is intentionally smoothed and stylized so it reads as landscape first.

### Change 3: Add an explicit fallback hierarchy

The doc already hints at this, but it should be more concrete:

1. Use short recent HR history if available.
2. Else use the latest HR sample or a tiny rolling cache.
3. Else keep the last good ridge.
4. Else show a pleasing default landscape.

### Change 4: Separate active-mode richness from idle-mode simplicity

This should be in the core vision, not just implied in implementation.

Recommended rule:

- active mode: richer sky object, optional mist drift, sharper composition refresh
- idle mode: static or near-static ridge, no animation assumptions, strongest readability

### Change 5: Remove any hidden assumption of GPS, web, or astronomy dependencies

None of those are required to make this concept work.

For this face, the core should remain:

- time
- local clock
- heart-rate history when available
- procedural drawing

Everything else is optional and should stay out of the critical path.

## What I Would Build First

If the goal is a serious build with the highest chance of surviving contact with the real device, I would implement in this order:

1. A watch face with excellent composition and no HR input.
2. A deterministic ridge generator driven by mock data.
3. A cacheable terrain model with 12 to 24 control samples.
4. Real HR history integration through `SensorHistory`.
5. Active-mode polish only after the idle face is already strong.

That sequence is important because the artistic composition is the real product. HR reactivity is the differentiator, not the base value.

## What I Would Not Promise Yet

I would avoid promising these in the main concept doc:

- continuous full-screen live animation
- exact physiological fidelity
- broad early cross-device compatibility
- sunrise/sunset realism
- heavy bitmap textures
- web-fetched data
- background-service dependencies

None of those are necessary to make the concept compelling, and several add platform risk without improving the core experience much.

## Best Practical Version Of The Idea

The best realistic version of this project is:

"A premium-looking AMOLED Garmin watch face where large readable time sits over a restrained ink landscape. The ridge shape is regenerated from recent heart-rate history when possible, the sun or moon tracks time of day, and the active view becomes a little richer when the user raises the wrist."

That version is strong, wearable, and technically grounded.

## Suggested Scope Statement

If you want a tighter north star for implementation, I would replace the top-level promise with this:

> Build a Garmin watch face for the Forerunner 265 that renders a calm procedural ink landscape behind a highly readable digital clock. The landscape should evolve subtly over time, using recent heart-rate history when available to shape the main ridge line, while remaining beautiful and fully usable when heart-rate data is sparse or stale.

## Sources

Official Garmin sources:

- Connect IQ API docs: `Toybox.SensorHistory`
  - https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory.html
- Connect IQ API docs: `Toybox.WatchUi.WatchFace`
  - https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFace.html
- Connect IQ API docs: `Toybox.WatchUi.WatchFacePowerInfo`
  - https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/WatchFacePowerInfo.html
- Connect IQ compatible devices list
  - https://developer.garmin.com/connect-iq/compatible-devices/

Useful corroborating Garmin forum discussions:

- Current heart rate on watch faces
  - https://forums.garmin.com/developer/connect-iq/f/discussion/5977/how-to-get-current-hearth-rate-on-watch-faces
- Partial update behavior and AMOLED limitations
  - https://forums.garmin.com/developer/connect-iq/f/discussion/383062/is-there-a-list-of-devices-that-support-onpartialupdate
