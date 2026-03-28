# Ink Sandbox

This is a fast local playground for testing generative ink / wash ideas outside Garmin.

Design goals:

- fixed `416x416` canvas to stay close to the Forerunner 265 screen
- immediate-mode 2D drawing
- alpha compositing
- simple procedural ridge / stamp / mist experiments
- fast browser iteration

## Files

- `index.html`
- `style.css`
- `main.js`
- `package.json`

## Recommended workflow

If Node is installed:

```bash
npm install
npm run dev
```

Then open the local URL Vite prints, usually:

```text
http://localhost:5173
```

This gives you live reload on save.

## If you do not want Vite

You can also serve this as a plain static folder:

```bash
python -m http.server 4173
```

Then open:

```text
http://localhost:4173/playgrounds/ink-sandbox/
```

That path will not live reload automatically, but it is still useful.

## Current rendering approach

The current `main.js` uses a fill-first strategy:

- mountains are filled shapes, not outlines
- the ridge is defined by where the fill stops, never by a drawn line
- each layer uses a rapid gradient falloff: most ink lives in the top ~20% of the shape, then fades aggressively toward transparent
- `shadowBlur` with a slight upward offset fakes wet-ink bleed at the ridge without extra computation
- a second diluted fill pass over the same shape simulates ink thinning as the brush runs dry
- sparse near-vertical cliff marks at the 2-3 tallest peaks only add calligraphic "bones"

The HR data drives the middle layer directly. Smoothing window size is the main control:
- window ~65 → 3–4 gentle humps (distant range character)
- window ~24 → 8–10 peaks (main mountain range character)
- window ~80 → 2–3 humps (simple foreground silhouette)

## What to experiment with next

- gradient falloff curve (more aggressive = more painterly; currently quadratic-ish via multi-stop)
- shadowBlur magnitude and upward offset — too much and it glows, too little and the edge is dry
- Y range positioning for each layer — affects how much sky is visible above the far mountains
- color temperature of distant vs near layers (slightly cooler grey-blue far, warmer dark-brown near)
- whether sparse horizontal dry-brush texture inside the fill body adds or distracts
- mist band width and opacity — currently 9–11 ellipses, may benefit from a second pass at a shifted Y

## What has failed

**Stamp clusters on peaks** (first iteration): placing brush stamps at every local maximum, at 2px point spacing, produced a curtain of vertical columns. The stamps need to be placed at major peaks only, or not at all for the mid-layer.

**Explicit ridge line drawn over the fill** (first iteration): drawing a stroke along the top of the mountain after filling it produces an EKG-on-mountains effect. The ridge character should come from the fill shape and gradient only.

**Small smoothing window** (first iteration, window=9): with 180–220 HR points mapped to 416px, a 9-point smooth still left ~50 micro-peaks per layer — spiky terrain instead of mountains. A window of 20+ is the minimum for mountain-shaped output.

## The Language of the Shapes (NPR Engine)

The current sandbox has evolved into a sophisticated **Non-Photorealistic Rendering (NPR)** engine. It treats the canvas not as a UI, but as a physical medium.

### 1. The Anatomy of a Stroke: "Bone and Flesh"
The engine follows traditional sumi-e philosophy:
- **The Flesh (`fillMtn`):** Uses rapid-falloff gradients (6+ stops) where ink is concentrated at the ridge and dissolves by 40% depth, mimicking water-carried pigment.
- **The Bones (`cun` and `flyWhite`):** 
    - **Cun (皴法):** Internal texture strokes for rock mass.
    - **Flying White (飛白):** Dry-brush texture near ridges using low-opacity dashed lines.
- **The Bleed (`bleedEdge`):** Radial micro-blobs scattered along ridges to simulate wicking into paper fibers.

### 2. Generative Grammar
- **Gaussian Summation:** Ridges are built by summing Gaussian "peaks" derived from HR data.
- **Multi-Octave Noise:** Layered value noise (low-freq for hills, high-freq for rock grit).
- **Three-Pass Mist:** Combines noise-displaced bands, cloud puffs, and thin wisps for believable atmospheric depth.

### 3. Material Simulation
- **Paper Grain:** Thousands of micro-lines simulate physical washi fibers.
- **Vignette & Lighting:** Radial gradients simulate a soft "studio light" on the parchment.

## Rule of thumb

The mountain IS the fill. Shape and gradient carry the whole weight.

1. choose a smoothed profile that reads as terrain, not signal
2. fill it with a gradient that fades fast — most ink at the ridge, nearly gone by midpoint
3. let shadowBlur do the wet-edge work
4. add mist between layers, not as decoration but as concealment
5. add no more than 2–3 calligraphic marks total; everything else is subtraction
