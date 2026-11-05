# Sprite sheet prompts

Generated sheets of ink subjects on flat white, cut into RGBA cutouts by
`scripts/cut_sprite_sheet.py`:

```
py -3.11 scripts/cut_sprite_sheet.py SHEET --out DIR --preview contact.png
        [--grid 4x4] [--names a,b,...] [--solid moon_full,moon_crescent]
```

The cutter finds every ink blob, hands it to the grid cell that holds its
centre, and takes alpha from "how much ink" (un-composited against the paper
white). It writes a day cutout (face ink colour) and a night cutout (light
ink for black paper) per subject, plus a contact sheet on day and night paper.

## Round 1 (2026-11-04): props-a.jpg, props-b.png

Both generators obeyed the 4x4 layout, the subject order, the white
background, "no text" and the red-only rule. Every subject cut cleanly on
the first try. What we learned:

- Ask for **PNG**. The JPG sheet (a) has ringing around thin lines; the PNG
  sheet (b) cut cleaner.
- **Pale subjects need a closed rim.** Sheet a's full moon has a white patch
  with no edge, so its disc cannot be recovered; sheet b's moon has a soft
  grey rim all the way round and cut perfectly.
- **Readable at thumbnail size.** On the watch a bird is 30-50 px. Sheet a's
  geese are hairline outlines and will vanish; sheet b's are solid ink
  silhouettes and will survive. Prefer solid ink masses over outlines.
- **White-bodied subjects go dark at night.** The night cutout is light ink
  on black, so anything drawn as a white body with ink outlines (the crane)
  reads as an outline at night. Ink-mass subjects carry over best.
- The hex colour was only roughly followed (sheet a's sun drifted orange).
  Recolouring is easy afterwards; do not fight the generator over it.

## Rounds 2 and 3 (2026-11-05): props2-a/b, mountains-a/b

The "a" sheets are Gemini (JPG, 2000 px), the "b" sheets ChatGPT (PNG,
1254 px); the C2PA metadata in each file says so.

- **Gemini** draws the more painterly, varied ink: real cun strokes, soft
  misty bases, elegant line. It drifts on the rules: still JPG when asked for
  PNG, green moss and a blue heron despite "ink only" (the cutter snaps
  non-red colour to ink, so this costs nothing), outline subjects (spotted
  deer, ring-shaped "oval seal", double-bordered square seal), and one
  subject (snow pine) run off the sheet edge.
- **ChatGPT** follows the rules closely: solid ink masses, filled seals,
  consistent height and baseline across the mountain sheet. Its ink is
  heavier and more uniform, closer to illustration than to brush.
- Use both. Gemini for character pieces where the line is bold (enso,
  waterfall, spire, plateau, dome); ChatGPT where consistency matters
  (seals, small silhouettes, a matched mountain set, pale far ranges).
- Mountains cut with `--backed` hide what stands behind them, verified on a
  watch-size skyline with a horizon line behind the shapes.
- After the first sheet the generator keeps the preamble in its chat
  context; later sheets in the same chat only need the subject list.

## Shared preamble (paste at the top of every sheet prompt)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel
color screen. The face is a Japanese sumi-e ink landscape: soft grey-black
brush mountains fading into mist on warm off-white rice paper, small dry-brush
grasses in the foreground, and a single red sun disc. The look is restrained,
quiet and traditional, with lots of empty space. Not anime, not cartoon, not
colorful watercolor.

I need a sprite sheet that I will cut apart by machine and layer onto that
landscape. The rules matter more than the art:

- Output a PNG. Background pure flat white (#FFFFFF) everywhere: no paper
  texture, no vignette, no grid lines, no borders, no frames, no shadows.
- One subject per cell, centered, with wide empty white space around it.
  Nothing may touch or cross into another cell.
- No text, labels, signatures, seals or watermarks anywhere.
- Ink only: black and greys with real brush character (wet wash edges,
  dry-brush texture, varied stroke weight). The ONLY color allowed is a
  vermilion red (#B83A2E) where a subject says so.
- Every subject must read at thumbnail size: favor solid ink masses and bold
  strokes over hairline outlines and fine detail.
- Pale subjects must still have a soft but complete grey edge all the way
  round, so their shape is never lost into the white.
- Same brush, same hand, same scale feel across the whole sheet.
```

## Sheet: props round 2 (4x4)

```
Make one square image, 2048x2048, laid out as a 4x4 grid of 16 subjects.
Left to right, top to bottom:
Row 1: (1) a torii gate standing in shallow water, ink only;
       (2) a stone lantern (toro) with a little moss;
       (3) a small thatched hermit hut under one bare tree;
       (4) a grey heron standing on one leg in reeds.
Row 2: (5) a deer standing, head raised, side view;
       (6) a narrow waterfall dropping between two dark rocks;
       (7) a distant sailboat with one square sail, very simple;
       (8) a cluster of three tiny village roofs among trees.
Row 3: (9) a sprig of maple leaves in vermilion red (#B83A2E) on an ink twig;
       (10) a scatter of about ten falling red (#B83A2E) petals, no branch;
       (11) a patch of falling snow: soft round grey dabs of varied size;
       (12) a pine bough heavy with snow, snow left as white with ink edges.
Row 4: (13) a blank square red (#B83A2E) seal stamp, brushy worn edges,
            solid fill, nothing carved inside;
       (14) a blank oval red (#B83A2E) seal stamp, same treatment;
       (15) an enso: one bold brush circle, open at the top right;
       (16) a thick horizontal band of drifting mist, light grey wash with
            a soft complete edge.
```

## Sheet: atomic mountains (3 wide x 4 high)

Each is one mountain, to replace the generated shape library
(`gen_shape_library.py`). The face fits shapes to the heart-rate curve by
their ridge line, and nearer mountains hide farther ones, so each must be a
single closed silhouette with a clean ridge and a base that dissolves.
Cut with `--solid` covering every name (paper-backed, opaque body).

```
Make one square image, 2048x2048, laid out as a grid of 3 columns by 4 rows
(12 wide cells). Each cell holds ONE isolated mountain, side view, in the
classic Chinese/Japanese shanshui manner:

- Darkest ink along the ridge line and upper slopes, with texture strokes
  (cun) and dry-brush marks down the faces, getting paler toward the base.
- The base fades smoothly into white mist and disappears; there is no
  ground line, no water, no foreground, no hard bottom edge.
- The ridge line itself is crisp and continuous from the left foot to the
  right foot: one closed silhouette, no gaps, no floating rocks.
- At most two or three tiny trees on the ridge; nothing else.
- All twelve at the same ink strength and the same height in their cells;
  only the silhouette changes. Each fills about 80% of its cell's width.

The twelve silhouettes, left to right, top to bottom:
Row 1: (1) a single sharp peak, symmetric;
       (2) a rounded dome;
       (3) a flat-topped plateau with steep sides.
Row 2: (4) a long ridge with three uneven humps;
       (5) a ramp rising from low left to a high right summit;
       (6) a ramp falling from a high left summit to low right.
Row 3: (7) a tall narrow spire, karst pinnacle style;
       (8) twin peaks with a saddle between them;
       (9) a peak leaning left, long gentle slope on the right.
Row 4: (10) a peak leaning right, long gentle slope on the left;
        (11) a broad low hill, very wide and gentle;
        (12) a jagged crest of several small sharp teeth.
```

## Round 4: a full scene kit (2026-11-05)

Scene layers, back to front (compose_preview.py): paper, sun/moon, far
range, mist_lite, masses (the HR skyline), near range, mist, fg corners,
paper grain. The bottom stays static per scene; only the masses follow HR.
Target scenes: misty peaks, lake, pine cliffs, autumn, winter.

Each prompt opens with a one-line rules reminder so it works in a fresh chat.
Cut strips with `--grid 1x6` (or `1x4`), corners with `--grid 2x4`.

### 4.1 More mountains (cut with --grid 3x4 --backed)

```
Same rules as the last sheets: PNG, pure flat white background, no text, ink
only, one subject per cell, nothing crossing cells, bold and readable at
thumbnail size. Same mountain style as the last mountain sheet: one isolated
mountain per cell, darkest ink along a crisp continuous ridge line, cun
texture strokes, base fading into white mist with no ground line.

2048x2048, a grid of 3 columns by 4 rows. Left to right, top to bottom:
Row 1: (1) a sheer cliff face on the left with a long slope down to the right;
       (2) the mirror: long slope up from the left to a sheer cliff on the right;
       (3) a two-tier stepped mountain, one shelf halfway up.
Row 2: (4) a cluster of three thin karst spires of different heights;
       (5) two rounded domes side by side, the right one smaller;
       (6) a cone with a small shoulder peak on its left flank.
Row 3: (7) a long low ridge with one sharp notch in the middle;
       (8) a craggy summit of broken rock blocks;
       (9) a wedge rising steeply from the left, flat top, gentle drop right.
Row 4: (10) a headland dropping steeply into nothing on the left;
        (11) the same on the right;
        (12) a very tall single peak, narrow at the top, wide at the base.
```

### 4.2 Horizon, mist and near-range strips

```
Same rules as the last sheets: PNG, pure flat white background, no text, ink
only, bold and readable at thumbnail size. Sumi-e landscape style as before.

2048x2048, six horizontal strips stacked top to bottom, one per row, with a
clear white gap between rows. Each strip runs all the way from the left edge
of the image to the right edge with no fade at the ends.
(1) a very pale distant mountain range, low, many small soft peaks;
(2) a pale distant range of rounded hills, a little darker than (1);
(3) a dense band of drifting mist, light grey wash, soft complete edges top
    and bottom;
(4) thin broken wisps of mist, several separate ribbons in one band;
(5) a dark low rolling near ridge, crisp top edge, base fading to white;
(6) a dark near ridge with a few small pine trees along its crest, base
    fading to white.
```

### 4.3 Water and ground strips

```
Same rules as the last sheets: PNG, pure flat white background, no text, ink
only, bold and readable at thumbnail size. Sumi-e landscape style as before.

2048x2048, six horizontal strips stacked top to bottom, one per row, with a
clear white gap between rows. Each strip runs all the way from the left edge
of the image to the right edge with no fade at the ends.
(1) a calm lake surface: a few long horizontal ripple strokes, pale grey;
(2) a shoreline: a dark bank of reeds and grass along the bottom, open water
    strokes above;
(3) faint vertical reflections of distant mountains in still water;
(4) a low bank of ground fog, thick at the bottom, thinning upward;
(5) a rocky foreshore: low dark boulders and pebbles in a row;
(6) a distant tree line, small pines and broadleaf trees, pale grey.
```

### 4.4 Foreground corners

```
Same rules as the last sheets: PNG, pure flat white background, no text, ink
only except vermilion red (#B83A2E) where named, bold and readable at
thumbnail size. Sumi-e style as before.

2048x2048, a grid of 2 columns by 4 rows (8 wide cells). These are foreground
pieces for the bottom corners of a round watch face. LEFT column pieces lean
into the bottom-left corner: tallest at their left side, trailing off to the
right. RIGHT column pieces are the opposite. Each sits on a flat dark ground
mass with a straight bottom edge, with white space below it in the cell.
Row 1: (1) left and (2) right: tall dry-brush grasses and small wildflowers
       on a rock;
Row 2: (3) left and (4) right: mossy boulders with a few ferns;
Row 3: (5) left and (6) right: a gnarled pine root and rock, low pine
       branches reaching inward;
Row 4: (7) left and (8) right: maple saplings with vermilion red (#B83A2E)
       leaves on a rock, a few leaves fallen on the ground.
```

### 4.5 Bottom arcs (one-piece foregrounds)

```
Same rules as the last sheets: PNG, pure flat white background, no text, ink
only except vermilion red (#B83A2E) where named, bold and readable at
thumbnail size. Sumi-e style as before.

2048x2048, four wide strips stacked top to bottom with white gaps between.
Each is a complete foreground for the bottom of a ROUND watch face: dense and
tall at both ends, rising up toward the sides, dipping low and sparse in the
middle so the center stays mostly clear. Flat straight bottom edge. Each
spans the full width of the image.
(1) grasses, wildflowers and small rocks;
(2) reeds and a water edge with ripple strokes in the middle dip;
(3) snowy rocks and low snow-laden pine boughs, snow as pale grey wash with
    complete ink edges;
(4) rocks and grass with a scatter of vermilion red (#B83A2E) maple leaves.
```

## Round 4 results (2026-11-05)

All ten sheets cut cleanly. Gemini painted two water strips touching (the
shoreline straight into the reflections); the cutter now splits any blob
that spans more than one grid cell along the grid lines.

A five-scene mock (misty peaks, lake, pine cliffs, autumn, winter; day and
night) built from the parts alone reads as finished paintings. Lessons:

- **Square corners do not exist on a round face.** A foreground painted to
  a flat bottom edge loses its best part, the dense ends, outside the
  circle. Next arcs/corners prompt: "the ground line follows the inside of
  a circle: it curves up at both sides like the bottom of a bowl".
- **Grey snow reads as dirt on day paper.** In sumi-e, snow is the paper
  left white. Snow should come from a pale grey wash sky with white
  flakes left out, not grey dabs.
- **Night foregrounds are too faint.** The night cutout is NIGHT_INK at
  0.80 alpha; foreground and near-range pieces need a stronger night ink
  than the far planes do (tune per layer, not per sheet).
- ChatGPT let the winter subject leak into its other arcs (snow on the
  grass and maple rocks). Gemini again added colour (green moss, sepia
  ground), which the cutter turns into ink.

## Round 5 (2026-11-05): arcs2-a/b, the bowl-shaped foreground retry

Gemini edited its earlier arcs sheet instead of repainting (0.92
correlation with arcs-a): it trimmed strips 1-2 to a bowl and left 3-4 as
they were. ChatGPT repainted (0.58 correlation) on the same layout and
again put snow on every strip's rocks.

The bowl does not need to come from the generator: lifting each column of a
flat arc by lift * u^2 (u = -1..1 across its width) bends the ground line
to the inside of the round face, and keeps verticals vertical. Width 420
with a 90 px lift on the 416 face reads well; 140 px shears the rocks.
So any flat-bottomed foreground is usable; only ask a generator for new
subjects, not for shape fixes.

Correction to round 4: the "grey snow reads as dirt" problem was the
snowfall prop (grey dabs), not the arcs; both generators' arcs already
leave snow as white paper.

## Round 6 (2026-11-05): fg-<season>-a/b, one whole-face foreground per image

The flat arcs lost their ends to the round screen, so each foreground became
its own painting, composed inside the circle. `circle_reference.png` was
attached to the first message (left: the flat arc cut off by the bezel;
right: the circle with the foreground zone in grey, tall at the sides, low in
the middle). Later messages in the same chat went without it. Run in both
generators: five images each.

Message 1 (with circle_reference.png attached):
```
I needed that last foreground sheet to fit in a circle, and it didn't: the
watch screen is round, so the ends of a flat foreground get cut off (left side
of the attached image). From now on, paint ONE foreground per image, composed
for the circle (right side of the attached image).

Rules for every image from now on:
- PNG, 2048x2048 square. The watch face is the circle that touches all four
  edges of the square. Everything outside that circle stays pure flat white.
- Do NOT draw the circle outline, the grey zone or any text. They are only a
  layout guide.
- Paint only in the grey zone: the foreground hugs the circle's lower edge,
  rising tall up both sides and staying low and sparse in the middle. Grasses
  and branches may reach a little above the zone at the sides, never into the
  middle of the circle.
- The foreground's ink runs right to the circle's edge at the bottom, as if
  the painting continues past the watch bezel.
- Above the zone stays pure white: no sky, no mountains, no mist, no sun.
- Same sumi-e style as before: black and grey ink with real brush character,
  bold and readable at small size. The only color is vermilion red (#B83A2E)
  where named.

First image: SPRING. Tall dry-brush grasses, small wildflowers and a few
rocks, with one low plum branch reaching in from the left bearing a few
vermilion red (#B83A2E) blossoms.
```

Message 2:
```
Same rules. SUMMER: tall reeds and cattails rising up both sides, and in the
low middle a narrow strip of still water with a few ripple strokes.
```

Message 3:
```
Same rules. AUTUMN: rocks and grass up both sides, small maple trees whose
leaves are vermilion red (#B83A2E), and a few red leaves fallen along the
low middle.
```

Message 4:
```
Same rules. WINTER: snowy rocks and low pine boughs heavy with snow rising up
both sides. The snow is the white paper left bare, shaped only by grey ink
shadows underneath. No snow on anything outside the grey zone.
```

Message 5:
```
Same rules. MOUNTAIN PASS: dark craggy rocks and one gnarled pine rising up
the left side, mossy boulders and ferns up the right side, bare ground in
the low middle. Ink only, no red.
```

Results, judged on the real preview face (mountains, sun, time, HR seal):

- **ChatGPT (b): all five work as painted,** day and night. The mountains
  stay visible and the inscription stays readable.
- **Gemini (a) spring and summer work.** Grass and reeds reach the text
  column but are light enough to read through (and, since round 7, the
  paper halo fades them back around each glyph).
- **Gemini autumn, winter and pass are too tall:** trees cover the time and
  HR, and the right sides cover the newest HR data. A soft rectangle faded
  out of the painting behind the text was tried and rejected: solid trunks
  cannot fade believably, so it leaves a ghostly slice.
- Gemini built all five on the same rocks and path: one place through the
  seasons. Worth keeping.
- The red maple stays full red at night, which is loud. Dim red at night in
  code; no new art needed.

## Round 7 (2026-11-05): fg-redo-a, Gemini's autumn, winter and pass again

`circle_reference_v2.png` attached (left: Gemini's winter covering the text;
right: the allowed zone, with the text column as a red box, the left side
allowed higher, the right side kept low). Same chat as round 6:

```
Close, and beautiful, but too tall for this watch (left side of the attached
image): the trees cover the time and heart rate, which are printed in the red
box, and the right side covers the newest data. Please repaint AUTUMN, WINTER
and MOUNTAIN PASS, one image each, keeping the same place, rocks and path you
used, with these new limits (right side of the attached image):
- Nothing at all inside the red box: no branches, leaves or rocks crossing it.
  Trees on the left grow from the far left edge and lean OUTWARD, away from
  the box, or stay below it.
- The left side may rise higher than the right, but only outside the box.
- The right side stays low: nothing above the grey zone.
- Everything else as before: same circle, pure white outside it and above the
  zone, no outline or text, same brush and ink.
```

Gemini returned all three circles on ONE sheet. `scripts/cut_art_kit.py`
splits it into three square paintings (each square is its circle's ink
width, sat on its ink bottom) and cuts them as fg-autumn-c, fg-winter-c and
fg-pass-c.

- **Winter fits on its own.**
- **Autumn and pass still put the tree crown where the time goes;** their
  right sides now stay low. The paper halo (`scripts/gen_halo.py`, on the
  face since c73b9f1) makes the time read cleanly over them, so no further
  redo is needed.

## Round 8 (2026-11-05): trees-b, tiny ridge trees

Small trees to stand on a fitted mountain's ridge, where the heart rate rose
a little above the shape (a mock test: up to 3 trees, each at most 16-22 px
tall, raised r from 0.883 to 0.890 and made short efforts read as trees on
the crest). The props sheets' pines are close-up bonsai with needles and
roots and turn to blobs at that size, so this sheet asks for silhouettes.
ChatGPT only so far (the PNG's C2PA metadata says OpenAI); cut with
`--grid 4x4` (recipe `trees` in `scripts/cut_art_kit.py`).

```
Same rules as the last sheets: PNG, pure flat white background, no text, ink only, one subject per cell, nothing crossing cells, bold and readable at thumbnail size.

2048x2048, a grid of 4 columns by 4 rows, 16 cells. Each cell holds tiny distant trees as seen standing on a far mountain ridge in a classic shanshui painting. Draw them large enough to fill the cell, but simple enough to still read when shrunk to 15 pixels tall: solid dark ink silhouettes, no fine needles, at most one stroke of trunk, no ground, no rocks, no grass. The bottom of every tree ends in a flat horizontal cut where it would stand on the ridge.

Row 1: (1) one upright pine, narrow; (2) one upright pine, wider crown; (3) one pine leaning left; (4) one pine leaning right.
Row 2: (5) two pines side by side, different heights; (6) three pines in a tight cluster; (7) one tall slender fir; (8) one round broadleaf tree.
Row 3: (9) a row of five small pines; (10) a row of five small pines of uneven heights; (11) one bare winter tree; (12) one pine heavy with snow, the snow left as white paper with ink edges.
Row 4: (13) one flat-topped umbrella pine; (14) two umbrella pines; (15) one tall narrow cypress; (16) two cypresses of different heights.
```

- **Every subject cut cleanly and every one has the flat foot asked for.**
  The sheet came back at 1254 px, not 2048; at ridge size that costs nothing.
- **They read at ridge size.** Rendered at 12, 16 and 22 px tall, day and
  night, all sixteen are trees at 16 px and up. Two are weak: `bare` goes
  hairline at 12 px, and `snow_pine`'s white snow vanishes at night (the
  white-bodied-subject problem from round 1).
- The umbrella pines (13, 14) read as savanna acacias more than Japanese
  pines; fine on a far ridge, odd up close.

## The picks, and rebuilding the cuts

Ten usable whole-face foregrounds: ChatGPT's five (fg-spring-b, fg-summer-b,
fg-autumn-b, fg-winter-b, fg-pass-b) and Gemini's fg-spring-a, fg-summer-a,
fg-autumn-c, fg-winter-c, fg-pass-c (one place through the seasons).

The cutouts are build output, not committed. From the repo root:

```
py -3.11 scripts\cut_art_kit.py
py -3.11 scripts\preview_foreground.py art-picks.png
```

The first rebuilds every sheet's cutouts into
`watch-faces/japanese-ink-heartrate/art/cuts/` (git-ignored), with the grid,
names and flags recorded in its RECIPE table; `--only fg-` limits it to the
foregrounds. The second renders the ten picks on the preview face (time,
seal, halo, mock HR day), day over night, one column each; pass cut folders
to render others. Both need Pillow, numpy and scipy.

`scripts/bake_foregrounds.py` bakes the same ten onto the face
(`resources/drawables/fg_*.png`, day and night), one a day by season and
painter (PROCEDURE.md section 10, 2026-11-05).

`scripts/bake_planes.py` bakes five of ChatGPT's six strips (4.2) into the
face's fixed planes: far_hills is the far range, mist_dense and mist_wisps
the two mist bands, near_pines and near_ridge the near hills. far_pale went
unused: at the face's size it all but vanished. The water sheet (4.3) is
cut but not on the face yet.

`scripts/bake_props.py` bakes nine props, each shown by one rule (PROCEDURE.md
section 10): props-b's sun, full moon, crescent (and its mirror), geese and
hiker; props2-b's village, hut and lantern.
