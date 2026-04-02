# Getting from “vector-y watch face” to real ink-wash vibes on a Forerunner 265

## What your reference images are actually doing

Across your references (the wide ridgeline with the red sun, the tall “gritty trees” scene, the misty shanshui compositions), there are a few repeatable “physics illusions” that make them read as ink-wash instead of digital illustration:

The ink is built from **layered translucent glazes**, not single flat fills  
Even when the mountains look “black,” the interior is actually a stack of uneven values: light gray under-wash, darker strokes on top, then fog “lifts” and paper shows through. This layer-based mental model is exactly how classic watercolor simulation research describes convincing watercolor: an **ordered set of translucent glazes** plus substrate/edge phenomena. citeturn8search0turn8search6

Edges have **mixed sharpness**  
A big giveaway in “silly watch faces” is when every silhouette edge is equally crisp. Your references alternate between:
- hard ridge cuts (dry-ish brush, confident stroke),
- soft dissolves into mist (wet-on-wet),
- “bloom” / pooling at edges (pigment gathering),
- occasional runs/drips in verticals.

Substrate (paper) is always present  
Even in the cleanest reference (wide mountains + red sun), there’s subtle grain and uneven absorption. A convincing renderer needs some kind of substrate modulation or it will always look like pure vector shapes.

Composition is intentional: “negative space carries the scene”  
The tall landscape references put *huge* weight on empty paper (“sky” / mist). The scene feels like it’s *emerging* from fog, not “drawn everywhere.” This is aligned with how the **Mustard Seed Garden Manual of Painting** is taught/structured: landscape is decomposed into components (trees, rocks, figures) and constructed deliberately rather than “fill the canvas.” citeturn8search22turn8search18

## Why your current output reads as “silly” (and where your code is already close)

Looking at your current render outputs (the “derp” style faces) versus the references, the big gaps aren’t “missing more stuff.” They’re missing the *right* kinds of imperfection:

Flat regions + repeated geometric motifs read as UI decoration  
The repeated circles and uniform bands (especially in sky/mist) read like “pattern overlay,” not fluid ink. Real ink randomness is *locally coherent*—it changes smoothly across space rather than repeating stamped circles in a line.

Your `JapaneseInkHeartrateScene` already has the right scaffold  
The good news: your scene code is not naïve. You already:
- cache an off-screen buffer (`BufferedBitmap`) and blit it in `draw()` (so you’re not doing full procedural redraw every second),
- stage the scene into multiple ranges (ghost/far/main/frame),
- add dissolves in `drawSpineShape()` and light “bleed” blobs.

Those are the right *categories* of tricks. The reason the output still feels “digital” is that your “texture vocabulary” is mostly:
- **clean polygons**
- **clean ellipses**
- **short straight grain lines**

Those primitives are fine—what’s missing is a better way to *modulate* them so they stop looking like geometry.

The biggest structural issue: you’re still “clock-seeding” the world  
Your scene regeneration is currently keyed on minute-of-day (`mLastMinuteKey`). That means the art changes because *time passes*, not because *HR history changed*. So even if you perfect the ink engine, it still won’t feel like “biological memory”; it’ll feel like a random wallpaper that keeps re-rolling.

## The Connect IQ features on Forerunner 265 that really unlock ink-wash

On the Forerunner 265 specifically, you have a very favorable baseline: 416×416 round AMOLED and current Connect IQ compatibility listed as 5.2. citeturn0search0

The key capabilities that move you from “flat shapes” to “ink” are:

Textured fills for primitives via `BitmapTexture`  
Connect IQ’s `Dc.setFill()` and `Dc.setStroke()` can take either a 32-bit color (0xAARRGGBB) **or a `BitmapTexture`**, meaning you can fill a polygon *with a tiled ink/paper texture*, not a flat color. This is supported since API level 4.0.0, and the supported-device list includes the Forerunner 265. citeturn2view0turn14search9

This is the single highest-leverage shift you can make for “paper + ink granulation” without doing per-pixel simulation.

Proper alpha glazes and blending controls  
Connect IQ 4 introduced modern alpha handling for fills/strokes plus blend modes (including `setBlendMode()`), letting you build the “layered glaze” illusion in a way that matches the watercolor research framing. citeturn0search3turn9view0

Rotated/scaled stamping via `drawBitmap2()` + `AffineTransform`  
This is huge: `drawBitmap2()` accepts an options dictionary including `:transform` as an `AffineTransform`. That means you can build a small brush stamp bitmap (like an alpha mask / textured daub), then stamp it along a curve with rotation and scale based on stroke direction—exactly the kind of primitive you need for tree limbs, ridge cuts, and dry brush. citeturn1view0

Graphics memory pool + resource references  
On CIQ 4+, offscreen bitmaps and other assets live in a **graphics memory pool** accessed through `ResourceReference` objects; the pool can purge resources when strong references are gone, and `get()` is what triggers allocation/loading. citeturn14search2turn14search0  
Practically: you can afford a couple of small “material” textures + one cached landscape buffer, and keep your heap happy.

Display-mode + burn-in constraints are explicit and usable  
For AMOLED always-on, you must respect burn-in requirements on devices that set `DeviceSettings.requiresBurnInProtection` (10% pixels lit, and per-pixel limits over minute updates). citeturn4search0turn6view0  
Also, watch faces update every second in high power and at the top of every minute in low power. citeturn7view0  
This is why the art should be cached and only recomputed on HR-snapshot change—not on every `onUpdate()`.

## The rendering shift that gets you out of “watch-face graphics” and into ink-wash

If you want results that visually track toward your references, you need to stop thinking “polygon = mountain.” Instead, treat the scene as **materials + stamps**:

Your new core abstraction: Ink Materials (tiny bitmaps)  
Create (procedurally, at runtime) 3–5 small `BufferedBitmap` “material tiles” once, and reuse them forever:

- **Paper grain tile** (e.g., 64×64): low-contrast speckle + faint fiber streaks.
- **Granulation tile** (e.g., 64×64): clustered noise that forms “pigment clumps.”
- **Dry-brush stamp** (e.g., 32×16): an oval-ish daub with holes/gaps.
- **Mist stamp** (e.g., 96×48): soft irregular cloud with uneven edge.
- **Bleed/bloom stamp** (e.g., 24×24): fuzzy blob with darker center.

Then you deploy them like this:

Texture-first washes  
Instead of: `setFill(color); fillPolygon(mountainPoly)`  
You do: `setFill(BitmapTexture(grainTile)); fillPolygon(mountainPoly)` and you change the texture offset per layer so the tiling doesn’t read.

`BitmapTexture` explicitly supports an offset and a runtime `setOffset()` call, so you can shift the texture each pass. citeturn14search9

Edge effects without simulation: “stamp the boundary”  
Your references have edge pooling and dry-brush breaks. You can fake both by stamping:

- Take ridge polyline points (your mountain crest samples).
- For each segment, compute tangent angle.
- Stamp the dry-brush bitmap along it with `drawBitmap2(..., {:transform => ...})`. citeturn1view0

This one trick is what closes a massive portion of the “looks vector” gap.

Mist as subtraction, not addition  
In your references, mist is where the world is *not* fully drawn. On black-paper mode (AMOLED), mist should mostly be “returning to black.”
You can do this in two workable ways:
- Stamp black mist blobs with partial alpha (simple, portable).
- Or, for bitmap stamping passes, use blend mode controls where appropriate (CIQ supports `setBlendMode()`; note the doc caveat that `BLEND_MODE_NO_BLEND` has limited support contexts). citeturn9view0turn0search3

Tie the ink randomness to coherent noise, not `rand()`  
Your current noise table is okay for quick jitter, but to avoid obvious repetition you want a coherent noise signal (the same artistic reason p5.js pushes Perlin-like noise: nearby inputs yield nearby values, which reads organic). citeturn8search1turn8search3  
Practically, you want **multi-scale** noise:
- low frequency for mountain macro shape,
- mid frequency for ridge agitation,
- high frequency for texture offsets and micro-breaks.

This is how you get “alive” without getting “busy.”

This matches what watercolor stylization literature focuses on: edge-based effects and substrate-based effects (stuff that happens because paint meets paper), not just shape outlines. citeturn8search12turn8search21

## Composition and HR mapping that feels like Shanshui, not a hidden graph

To make the result feel like your references, the HR mapping cannot directly “draw HR.” It has to **choose composition constraints** and **ink behavior**.

Getting 4-hour HR history is supported, but sample spacing is device dependent  
`Toybox.SensorHistory.getHeartRateHistory()` provides a history iterator with options like `:period` (Number or `Time.Duration`) and `:order`. citeturn0search2  
Garmin forum discussion also notes HR history sampling intervals can be around a minute or two depending on device/conditions. citeturn0search10  
So your mapping needs to resample into a fixed set of control points for visuals.

Use HR to pick “host/guest” landforms and ink load  
A practical shanshui mapping that avoids graph tropes:

- **Mean HR (4h)** → ink load (overall brightness/opacity of “ink” on black paper)
- **Variability (MAD/stddev)** → edge turbulence + granulation density
- **Peak count / peak sharpness** → number of ridges and how knife-cut the crests are
- **Recent trend (last ~20–30 min)** → composition bias (host peak left vs right, valley placement)

Then enforce a compositional rule set inspired by the way the Mustard Seed manual teaches components and structure (trees/rocks/humans as modules, landscape as a constructed hierarchy). citeturn8search22turn8search18  
On a 416×416 watch face, the most important rule is: **protect a clear “breathing space” for the time**, like the mist openings in your references.

Finally: stop regenerating the “world” on clock minutes  
Once the art is driven by HR snapshot, the “landscape key” should come from:
- quantized HR resample array,
- coarse stats (mean/var/trend bucket),
- maybe the newest sample timestamp bucket.

Then you only rerender the big buffer when that key changes (which also aligns with watch face high/low power update behavior). citeturn7view0turn14search2

## Verdict

Yes—I think you can move decisively away from the current “silly watch face” look and toward your ink-wash references on the Forerunner 265, **but the path is not “more polygons and more circles.”** The path is:

- treat the scene as **layered translucent glazes** (like watercolor research describes) citeturn8search0turn8search6  
- use **textured fills** (`BitmapTexture`) for washes instead of flat colors citeturn2view0turn14search9  
- use **rotated/scaled stamping** (`drawBitmap2` + `AffineTransform`) for dry-brush, ridge cuts, and later trees citeturn1view0  
- drive regeneration off **HR snapshot change**, not minute-of-day, and keep the expensive art cached citeturn0search2turn7view0  
- respect AMOLED always-on burn-in rules via `requiresBurnInProtection` + display mode handling citeturn4search0turn6view0  

That combination is the “engine change” that gets you into the visual territory of your references, within Connect IQ’s real constraints.