# Procedural Ink-Wash Watch Face Blueprint Driven by 4‑Hour Heart Rate History on Forerunner 265

## Current codebase review and bottlenecks

Your project already has one of the most important battery-saving patterns in place: **off-screen rendering with a cached buffer** and a lightweight `onUpdate(dc)` that blits the buffer to screen. Specifically, `JapaneseInkHeartrateView.onUpdate(dc)` delegates to `mScene.draw(dc)`, and the heavy work (building anchors, washes, silhouettes, bleed) happens inside the scene only when a “minute key” changes (so the full landscape is not regenerated every second).

That said, your current pipeline is still doing a few things that will **look cool but fight your goal** (HR-history-driven, not “clock-driven”) and can be tightened for both performance **and** aesthetic control:

Your regeneration trigger is time-based rather than data-based  
Right now, your `Scene` is keyed on the minute (`getMinuteKey()`), so **it re-seeds and re-renders every minute even if the HR history snapshot hasn’t meaningfully changed**. That guarantees constant stylistic drift. For generative art that’s meant to feel like a “biological memory” of the last 4 hours, you want the landscape to be **stable until the underlying HR history meaningfully shifts** (new samples, trend change, variability change), then “re-ink” in a deliberate way.

High-level drawing operations are good; allocation churn is the silent killer  
Your scene code builds lots of short-lived arrays (polygons, anchors, jitter paths), which is fine at minute cadence, but it becomes a problem if you later decide to re-render on HR updates more frequently than once a minute. On Connect IQ, heap limits vary per device, and general advice is to avoid unnecessary object churn and rely on stable, pooled resources where possible. citeturn6search6

You’re already halfway to “ink”: you should lean more on CIQ 4+ alpha tools and textures  
You are using `Graphics.createColor(a,r,g,b)` and semi-transparent fills, which is aligned with Connect IQ 4’s expanded alpha capabilities (`Dc.setFill()`, `Dc.setStroke()`, and blend modes). citeturn16view0turn17search10  
But you can push the ink illusion much further (without per-pixel rendering) by structuring your drawing into **wash layers**, **edge bloom**, and **granulation** using `BitmapTexture` fills and careful layering order (details below). citeturn17search1turn4search14

AOD / low-power mode needs to stay minimal even if “paper is black”  
Your stated target palette is AMOLED-friendly (“paper” = true black), which is great in **high power mode**. However, in **low power / always-on mode**, CIQ may enforce burn-in rules (10% pixel usage, per-pixel time limits). The rules are explicitly described under `DeviceSettings.requiresBurnInProtection`. citeturn23search2turn24view0  
So: keep your full landscape for high power mode; in low power, show a minimal zen mark (one ridge + time), like your current ridge approach, but updated to be consistent with the new HR-based “world.”

## Connect IQ graphics primitives on Forerunner 265 worth exploiting

The Forerunner 265 class is in the 416×416 AMOLED tier and is listed as Connect IQ “5.2” compatible on Garmin’s current device list. citeturn6search2  
More importantly for your request: the Forerunner 265 series is explicitly named as a **System 7 / API 5.0.0** device class in Garmin’s SDK announcement. citeturn10view0  
That means you can safely design around CIQ 4+ graphics improvements and CIQ 5 display-mode features, with runtime guards where needed.

Graphics pool + references: treat big buffers as “graphics memory,” not heap  
Connect IQ 4 introduced a **graphics pool** separate from your app heap. Runtime-loaded bitmaps/fonts and `BufferedBitmap` allocations can live there, and you interact with them through `Graphics.ResourceReference` objects. citeturn16view0turn2search15  
`Graphics.createBufferedBitmap()` returns a `BufferedBitmapReference`, and calling `.get()` yields a locked `BufferedBitmap` (locking prevents purge but can exhaust the pool if you hoard many resources). citeturn2search6turn16view0  
For your use case, hoarding **one** 416×416 landscape buffer (and maybe one tiny texture buffer) is exactly what the pool is for.

Alpha blending + textures: your “ink transparency” toolbox  
Connect IQ 4 added:

- `Dc.setFill()` and `Dc.setStroke()` that accept **32‑bit AARRGGBB**, making real alpha layering possible. citeturn16view0turn17search10  
- `Dc.setBlendMode()` plus additional blend modes (including multiply and additive) on supported devices. citeturn18view0  
- `Graphics.BitmapTexture` so primitives can be filled/stroked with a repeating bitmap pattern (your “paper grain” and “dry brush” workhorse). citeturn17search1turn16view0

Two key caveats from the docs:

- `ALPHA_BLENDING_PARTIAL` buffered surfaces can behave inconsistently for partially translucent pixels between device and simulator; for nuanced ink, prefer `ALPHA_BLENDING_FULL`. citeturn2search6turn18view0  
- Multiply/additive blend modes are **only supported on devices with GPU** (so keep a fallback path that uses default source-over layering). citeturn18view0

Layers: let the system bitblit your background for you  
`WatchUi.Layer` is designed to be drawn by the system during normal updates/animations. It has its own `getDc()` and can be stacked onto your view. citeturn19view0turn20view0  
For a watch face with one expensive background and lightweight text overlays, this is extremely aligned with your goal: **only redraw the art layer when HR data changes, but keep your time overlay independent**.

Display mode detection: stop guessing low/high power state  
In API 5.0.0, `System.getDisplayMode()` is available on AMOLED/LCD devices and explicitly distinguishes **high power / low power / off**. citeturn12view0  
That gives you a cleaner decision boundary than relying only on `onEnterSleep/onExitSleep`, while still supporting your current approach as a fallback.

## A procedural ink-wash renderer that fits Connect IQ constraints

Your art target is not “simulate physics,” it’s “evoke ink.” The best way to get there on a constrained watch GPU/CPU is a layered, painterly illusion: **wash → structure → texture → bloom/bleed → accents**. This matches how real watercolor/ink systems are often modeled: translucent layers (glazes), turbulence/granulation, and edge phenomena—without requiring full fluid simulation. citeturn3search23turn3search19

image_group{"layout":"carousel","aspect_ratio":"1:1","query":["sumi-e landscape ink wash painting","shanshui ink wash landscape painting","Japanese ink wash mountain landscape minimal","Mustard Seed Garden Manual of Painting landscape page"],"num_per_query":1}

Aesthetic-to-primitive mapping (Connect IQ friendly)  
You can recreate the most recognizable ink-wash cues with only polygons, ellipses, textures, and alpha:

Paper (AMOLED “black paper”)  
- Fill the whole buffer with `COLOR_BLACK`. citeturn18view0  
- Add “paper tooth” via a tiny 16×16 or 32×32 `BufferedBitmap` used as a `BitmapTexture` (random speckle pattern). Fill a very low-alpha rectangle over the full screen using that texture; occasionally jitter the texture offset so it doesn’t look tiled. citeturn17search1turn16view0

Wash layers (the atmospheric depth)  
- Far mountains: very low contrast ink (dark gray on black paper would be invisible; so instead use **slightly lighter** grays/near-black whites depending on your inversion choice).  
- Mid mountains: higher contrast.  
- Fore mountains: crisp edges, occasional “dry brush breaks.”

This is conceptually similar to the “ordered translucent glazes” idea commonly used in watercolor rendering research. citeturn3search23

Bleed / bloom at edges  
True diffusion is expensive (grid/particle fluid, CA diffusion). citeturn3search4turn3search6turn3search27  
But visually, you mostly need: (a) slightly fuzzy edges, (b) occasional blooms, (c) granulation.

On CIQ you can fake this with:
- A second silhouette pass offset by 1–2 px with lower alpha  
- Stamping small ellipses along ridge edges at random intervals (“capillary blooms”)  
- Overlaying a grain texture only inside the wash area (done by drawing the wash with a `BitmapTexture` fill, or by drawing a clipped rectangle; see below)

Stroke construction (structure lines and “bone”)  
Your existing spine-based polygon fill strategy is exactly the right kind of primitive: build a centerline, compute a left/right border with varying width, `fillPolygon`. That is the same conceptual approach used by many digital brush stroke models (including methods based on Bézier-defined stroke outlines). citeturn3search10turn4search14

Bezier agitation without a native Bézier primitive  
Monkey C doesn’t give you a direct “bezier curve draw” primitive. That’s fine: you can still use the “jittery Bezier” idea by sampling points from a cubic Bezier you compute yourself, then drawing short lines or building a thick polygon around the sampled centerline. The core artistic trick—**randomizing control points / tangents**—is well summarized in a classic “jittery Bezier” recipe discussed on entity["organization","Stack Overflow","q-a site"]. citeturn5view0

Noise as the unifying “organic” signal  
p5.js frames Perlin noise as organic randomness (smooth, not white-noise jitter), which is exactly what you want for ink bleed, ridge perturbation, and texture warping. citeturn3search28turn4search17  
In Monkey C, you’ll implement a small deterministic gradient/value noise (1D and 2D). Don’t chase perfect Perlin; chase **stable smoothness** with cheap math.

## Heart-rate snapshot to landscape mapping

Data source: 4‑hour history via `SensorHistory`  
`SensorHistory.getHeartRateHistory()` returns an iterator of `SensorSample` values (bpm), and you can request a period using `Time.Duration` (or a count). The time between samples is device-dependent, so you must assume uneven sampling and missing sections. citeturn13view0

Mapping goals  
You said: “Heart Rate Over Time determines peaks and valleys of the mountain silhouettes,” and you want to avoid a “digital graph.” The key is to treat HR history as a **latent field** that shapes a landscape, not as something you plot.

Proposed mapping pipeline (4 hours → three mountain ranges)  

Normalize and de-trend  
- Collect samples for the last 4 hours.
- Compute a robust min/max (ignore outliers, or clamp to percentiles).
- Normalize to `[0..1]`.

Resample to an art-friendly control set  
- Resample to a fixed number of control points (e.g., 48–96 across the width). This avoids rendering a 240+ point polygon and reduces the “graph look.”  
- Use smoothing (moving average) to erase the “fitness tracker jaggedness.”

Derive three “distances” (far/mid/near) from the same HR field  
Rather than drawing one ridge, draw three interpretations:

- Far range: heavily smoothed HR curve → big slow silhouettes (calm atmosphere)
- Mid range: moderately smoothed HR curve → readable peaks
- Near range: lightly smoothed HR curve + noise agitation → expressive “brush energy”

This aligns well with painterly layering concepts (order and layering matter for style). citeturn4search14

Map HR features to ink behaviors (not extra UI widgets)  
- Mean HR (last 4h): controls overall ink value (how bright the “ink” is on black paper)
- HR variability (stddev or MAD): controls **edge turbulence** and **bleed intensity**
- Recent HR slope (last ~20–30 minutes): controls composition tilt (mountain leans left/right)
- Peak density: controls number of crest accents / rock cuts

AMOLED palette strategy  
- High power: black background, grayscale “ink” (use 2–4 main tones + 1 accent later). The Forerunner 265 is AMOLED and supports the 416×416 watch-face canvas listed in Garmin’s device compatibility list. citeturn6search2  
- Low power / AOD: do not render the full landscape. CIQ’s low-power watch face mode typically updates once per minute and expects reduced pixel usage; with burn-in protection, exceeding constraints can blank the display. citeturn20view0turn23search2turn24view0

## Proposed Monkey C architecture and code skeleton

This is a blueprint that stays close to your current structure, but swaps the “minute-key world generator” into a “HR-snapshot world generator,” and uses CIQ 4+ graphics features more aggressively for ink.

Core design rule  
One expensive render pass should happen only when the landscape key changes. Every other update is just:
1) draw cached landscape layer/buffer  
2) draw time text (and later small complications)

Suggested class layout  
- `HrHistorySampler`: pulls and preprocesses 4h HR into a fixed array of normalized points  
- `LandscapeKey`: builds a stable hash from the HR series + “composition parameters”  
- `InkLandscapeRenderer`: renders into a `BufferedBitmap` or `WatchUi.Layer` dc  
- `JapaneseInkHeartrateView`: decides display mode, draws time overlay, and triggers re-render only when needed

Key decision: BufferedBitmap vs WatchUi.Layer  
If you want maximum control and simplest mental model: keep your `BufferedBitmapReference` cache and blit with `dc.drawBitmap`.  
If you want system-level compositing and potentially faster updates: put the landscape in a `WatchUi.Layer` and let the system bitblit it automatically. Layers are explicitly designed for this. citeturn19view0turn20view0

Landscape invalidation logic (data-change driven)  
Instead of `minuteKey`, define:

- `hrKey = hash(resampledNormalizedHrPoints, newestSampleTimeBucket, …)`
- Re-render only if:
  - `hrKey != mLastHrKey`, or
  - screen dimensions changed

High vs low power behavior  
- Use `System.getDisplayMode()` when available to branch rendering behavior. citeturn12view0  
- In low power, render minimal AOD mark only if `requiresBurnInProtection` is true or if you’re in `DISPLAY_MODE_LOW_POWER`. citeturn23search2turn12view0

Code skeleton (architecture, not final art code)  
(Notes: this is structured to compile under CIQ 4+; you’d add `has` checks where you want cross-device compatibility, but you explicitly said you don’t care about generality.)

```monkeyc
using Toybox.System;
using Toybox.Time;
using Toybox.Graphics;
using Toybox.WatchUi;
using Toybox.SensorHistory;

class HrHistorySampler {
    // Returns: { :points => Array<Float> (0..1), :keySalt => Number }
    function sample4h() as Dictionary {
        var points = new [64]; // fixed-resolution ridge control points
        for (var i = 0; i < points.size(); i++) { points[i] = 0.5f; }

        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getHeartRateHistory)) {
            return { :points => points, :keySalt => 0 };
        }

        var iter = SensorHistory.getHeartRateHistory({
            :period => new Time.Duration(4 * 60 * 60),
            :order  => SensorHistory.ORDER_OLDEST_FIRST
        });

        // Collect raw samples (bpm) into a temporary array (cap to protect heap)
        var raw = [];
        while (true) {
            var s = iter.next();
            if (s == null) { break; }
            if (s.data != null) { raw.add(s.data.toNumber()); }
            if (raw.size() > 512) { break; } // safety cap
        }

        if (raw.size() < 8) {
            return { :points => points, :keySalt => raw.size() };
        }

        // Compute min/max with clamping, then resample raw -> points (implementation omitted)
        // points[i] = normalize( resample(raw, i), min, max )
        // Also compute keySalt based on coarse stats (mean, var, trend bucket)
        return { :points => points, :keySalt => raw.size() };
    }
}

class InkLandscapeRenderer {
    var mBufferRef;         // Graphics.BufferedBitmapReference
    var mBuffer;            // Graphics.BufferedBitmap
    var mBufferW = 0;
    var mBufferH = 0;
    var mLastKey = null;

    function ensureBuffer(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        if (mBuffer == null || w != mBufferW || h != mBufferH) {
            mBufferW = w; mBufferH = h;

            var options = {
                :width => w, :height => h,
                :alphaBlending => Graphics.ALPHA_BLENDING_FULL
            };

            mBufferRef = Graphics.createBufferedBitmap(options);
            mBuffer = mBufferRef.get(); // lock one big buffer; OK if you only keep one
        }
    }

    function renderIfNeeded(dc as Graphics.Dc, hrPoints as Array<Lang.Float>, keySalt as Number) as Void {
        ensureBuffer(dc);

        var key = computeLandscapeKey(hrPoints, keySalt, mBufferW, mBufferH);
        if (mLastKey != null && key.equals(mLastKey)) {
            return;
        }
        mLastKey = key;

        var bdc = mBuffer.getDc();
        drawInkLandscape(bdc, hrPoints, key);
    }

    function drawToScreen(dc as Graphics.Dc) as Void {
        if (mBuffer != null) {
            dc.drawBitmap(0, 0, mBuffer);
        }
    }

    // --- The rest is your “ink engine” ---
    function drawInkLandscape(dc as Graphics.Dc, hrPoints as Array<Lang.Float>, key as Lang.Object) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 1) paper tooth using BitmapTexture + low alpha glaze (if you build a tiny texture bitmap)
        // 2) far/mid/near ridge silhouettes built from hrPoints at different smoothness
        // 3) edge bloom and granulation passes
        // 4) reserve space for time text region (optional)
    }

    function computeLandscapeKey(hrPoints as Array<Lang.Float>, keySalt as Number, w as Number, h as Number) as Lang.String {
        // Cheap stable hash: quantize floats to bytes and accumulate
        var acc = 146959810; // arbitrary
        for (var i = 0; i < hrPoints.size(); i++) {
            var q = (hrPoints[i] * 255).toNumber();
            acc = ((acc ^ q) * 16777619) % 2147483647;
        }
        acc = ((acc ^ keySalt) * 16777619) % 2147483647;
        acc = ((acc ^ w) * 16777619) % 2147483647;
        acc = ((acc ^ h) * 16777619) % 2147483647;
        return acc.format("%d");
    }
}

class JapaneseInkHeartrateView extends WatchUi.WatchFace {
    var mSampler;
    var mRenderer;

    function initialize() {
        WatchFace.initialize();
        mSampler = new HrHistorySampler();
        mRenderer = new InkLandscapeRenderer();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var mode = null;
        if (System has :getDisplayMode) {
            mode = System.getDisplayMode();
        }

        // Low power / AOD: do minimal render
        if (mode == System.DISPLAY_MODE_LOW_POWER) {
            drawAodMark(dc);
            drawTime(dc);
            return;
        }

        // High power: render cached landscape + time overlay
        var snap = mSampler.sample4h();
        var pts = snap[:points];
        var salt = snap[:keySalt];

        mRenderer.renderIfNeeded(dc, pts, salt);
        mRenderer.drawToScreen(dc);
        drawTime(dc);
    }

    function drawAodMark(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        // Keep pixels minimal if requiresBurnInProtection is true
    }

    function drawTime(dc as Graphics.Dc) as Void {
        var ct = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [ct.hour, ct.min.format("%02d")]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, dc.getHeight()*0.70, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
```

Everything above is grounded in CIQ’s documented update cadence: watch faces update once per minute in low power and once per second in high power. citeturn20view0  
And it cleanly integrates System 7 display modes where available. citeturn12view0

## Reference library for low-power generative ink landscapes

Monkey C / Connect IQ APIs that directly matter for your ink engine  
This set is intentionally biased toward “ink illusions” rather than general UI:

- `SensorHistory.getHeartRateHistory({:period, :order})` for your 4h snapshot source. citeturn13view0  
- `Graphics.createBufferedBitmap(options)` + `BufferedBitmapReference.get()` for graphics-pool caching. citeturn2search6turn2search15turn16view0  
- `Dc.setFill()` / `Dc.setStroke()` with AARRGGBB alpha (core for translucent wash). citeturn17search10turn16view0  
- `Graphics.BitmapTexture` to create paper grain / dry brush textures for primitive fills. citeturn17search1turn16view0  
- `Dc.setBlendMode()` (with fallback) if you want multiply/additive stylization. citeturn18view0turn17search2  
- `WatchUi.Layer` + `View.addLayer()` if you want system-managed bitblitting of the art. citeturn19view0turn20view0  
- `System.getDisplayMode()` + `DeviceSettings.requiresBurnInProtection` for correct AMOLED behavior. citeturn12view0turn23search2  
- `Graphics.AffineTransform` for stamp rotation/shear/scale (later: red seal, sun/moon drift). citeturn25view0

External procedural art + ink/watercolor research worth stealing from (conceptually)  
These are not “copy the algorithm wholesale” recommendations; they’re “steal the perceptual levers.”

- **Layered translucent glazes, edge darkening, granulation**: the classic “Computer-Generated Watercolor” paper (Curtis et al.) remains one of the most cited descriptions of what makes watercolor “read” as watercolor. citeturn3search23  
- **Ink diffusion / bloom patterns**: real-time ink diffusion methods exist (grid/particle hybrids, and cellular automata). You won’t implement them fully on-device, but they describe the kinds of edge phenomena to fake with stamping + noise. citeturn3search4turn3search6turn3search27  
- **Bézier-defined brush stroke outlines**: there are stroke display methods rooted in Bézier-defined stroke boundaries and shade variation, which maps conceptually to your polygon-around-centerline strategy. citeturn3search10  
- **Painterly order matters**: “brush stroke ordering techniques” emphasizes that layering order is a style control knob—useful when you decide whether wash comes before texture, or bloom after silhouette. citeturn4search14  
- **Noise as organic structure**: p5.js documentation explicitly frames Perlin noise as organic randomness; that’s a good “north star” for your Monkey C noise function, even if your implementation is simpler than canonical Perlin. citeturn3search28turn4search17  
- **Jittered Beziers as “hand tremor”**: the “successive Bezier segments with randomized x/control points” trick is a minimal recipe for hand-drawn irregularity that translates directly into “sampled curve + thick polygon” in Monkey C. citeturn5view0  
- **Mustard Seed Garden Manual as compositional decomposition**: the manual is explicitly structured around landscape principles plus modular depiction of trees and rocks, and it historically served as a teaching/recipe system. That is exactly how you should think about your future phases (tree module, rock module, seal module) without turning the watch face into UI clutter. citeturn3search0turn3search35turn3search33turn3search9

Cross-language synthesis hooks (how to “translate” ideas, not code)
- From entity["company","Microsoft","windows vendor"] GDI+ you mainly want the mental model of **brushes vs pens**, and especially **texture/hatch brushes** as a stand-in for paper tooth and dry brush. citeturn4search2  
- From Cairo you want the mental model of building paths, then deciding when to fill/stroke, and how clip/stroke-preserve patterns enable layered rendering. citeturn4search34turn4search22  
- From p5/Processing you want the habit of using coherent noise and sampling-based curves (and the framing of Perlin noise as organic randomness). citeturn4search21turn3search28  
- From entity["people","Ken Perlin","computer graphics researcher"] you want the philosophical point: “randomness with continuity” is what reads as natural. citeturn3search28