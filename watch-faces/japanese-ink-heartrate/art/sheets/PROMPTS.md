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

John's verdicts on the unused props (2026-11-05, day beside night): the
**sun in mist** (props 02, both painters) looks great by day and by night;
the **snow pine** (props2 12) is poor at night, its snow lost on black (the
same fault that kept trees-b's snow pine off the ridges).

## Round 9 (2026-11-05, to send): weather, and the inscription's numerals

John agreed the signals assessment the same evening (weather in the sky
slot, a heron for sitting too long, a small swallow for unread
notifications, and the rest; PROCEDURE.md section 10). Four sheets fill its
gaps and replace the last script-made art (gen_ink_font.py's digits and
kanji). Send each to both painters, a new chat each, and pick per piece as
before.

- **Weather.** The moon in mist is the night twin of the sun in mist. The
  snow is asked as white paper in grey rings because grey dabs read as dirt
  on day paper; at night the old dabs (props2 11) stay, since white paper
  vanishes on black. The lightning is asked in black ink for the same
  reason.
- **Minute digits, hour kanji, seal digits.** The halos (gen_halo.py) are
  made from whatever glyphs the font has, so they carry over. The seal
  digits are asked in black and recolored to paper at the bake. Image
  models often garble kanji: if both painters do, the script kanji stay.

### 9.1 Weather (3x3)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, small dry-brush grasses in the foreground, and a single red sun disc. The look is restrained, quiet and traditional, with lots of empty space. Not anime, not cartoon, not colorful watercolor.

I need a sprite sheet that I will cut apart by machine and layer onto that landscape. The rules matter more than the art:
- Output a PNG. Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no grid lines, no borders, no frames, no shadows.
- One subject per cell, centered, with wide empty white space around it. Nothing may touch or cross into another cell.
- No text, labels, signatures, seals or watermarks anywhere.
- Ink only: black and greys with real brush character (wet wash edges, dry-brush texture, varied stroke weight). The ONLY color allowed is a vermilion red (#B83A2E) where a subject says so.
- Every subject must read at thumbnail size: favor solid ink masses and bold strokes over hairline outlines and fine detail.
- Pale subjects must still have a soft but complete grey edge all the way round, so their shape is never lost into the white.
- Same brush, same hand, same scale feel across the whole sheet.

This sheet is weather for the sky. Make one square image, 2048x2048, laid out as a 3x3 grid of 9 subjects. Left to right, top to bottom:
Row 1: (1) a full moon half hidden behind two soft bands of mist, the moon a pale grey wash disc with a darker grey rim, no red; (2) falling snow: about twenty round flakes of varied size, each flake left as bare white paper inside a soft grey wash ring; (3) heavier snowfall in the same style, more flakes, slanting slightly.
Row 2: (4) a storm: dark slanted rain strokes with one thin jagged lightning stroke in solid black ink through them; (5) dark clouds gathering: a heavy grey-black cloud bank with a flat underside, as if rolling in from the left edge of the sky; (6) a long, low, flat band of grey overcast cloud, wide and thin, with a soft complete edge.
Row 3: (7) about eight loose maple leaves tumbling on the wind along a diagonal, three of them vermilion red (#B83A2E), the rest grey ink, no branch; (8) about eight loose dry winter leaves, grey ink only, blown along a diagonal, no branch; (9) light drizzle: short, fine, sparse slanted grey strokes, much lighter than rain.
```

### 9.2 Minute digits (5x2)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, small dry-brush grasses in the foreground, and a single red sun disc. The look is restrained, quiet and traditional, with lots of empty space. Not anime, not cartoon, not colorful watercolor.

I need a sprite sheet that I will cut apart by machine and layer onto that landscape. The rules matter more than the art:
- Output a PNG. Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no grid lines, no borders, no frames, no shadows.
- One subject per cell, centered, with wide empty white space around it. Nothing may touch or cross into another cell.
- The only writing on the sheet is the numerals asked for below: no other text, labels, signatures, seals or watermarks.
- Ink only: black and greys with real brush character (wet wash edges, dry-brush texture, varied stroke weight). The ONLY color allowed is a vermilion red (#B83A2E) where a subject says so.
- Every subject must read at thumbnail size: favor solid ink masses and bold strokes over hairline outlines and fine detail.
- Pale subjects must still have a soft but complete grey edge all the way round, so their shape is never lost into the white.
- Same brush, same hand, same scale feel across the whole sheet.

This sheet is the clock's minute digits. Make one wide image, 2560x1024, laid out as a 5x2 grid of 10 cells. Row 1: 0, 1, 2, 3, 4. Row 2: 5, 6, 7, 8, 9. Each cell holds one Western Arabic numeral written with a single loaded sumi brush, the way a calligrapher writes the date in an ink painting's inscription: bold, upright, dark ink, wet edges, a little dry-brush at the stroke ends. All ten digits the same height (about 70% of the cell) and the same stroke weight, standing on one shared baseline, each centered in its cell. Legible first: no serifs, no flourishes, no slant. Nothing else on the sheet.
```

### 9.3 Hour kanji (4x3)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, small dry-brush grasses in the foreground, and a single red sun disc. The look is restrained, quiet and traditional, with lots of empty space. Not anime, not cartoon, not colorful watercolor.

I need a sprite sheet that I will cut apart by machine and layer onto that landscape. The rules matter more than the art:
- Output a PNG. Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no grid lines, no borders, no frames, no shadows.
- One subject per cell, centered, with wide empty white space around it. Nothing may touch or cross into another cell.
- The only writing on the sheet is the numerals asked for below: no other text, labels, signatures, seals or watermarks.
- Ink only: black and greys with real brush character (wet wash edges, dry-brush texture, varied stroke weight). The ONLY color allowed is a vermilion red (#B83A2E) where a subject says so.
- Every subject must read at thumbnail size: favor solid ink masses and bold strokes over hairline outlines and fine detail.
- Pale subjects must still have a soft but complete grey edge all the way round, so their shape is never lost into the white.
- Same brush, same hand, same scale feel across the whole sheet.

This sheet is the clock's hour numerals in kanji. Make one image, 2048x1536, laid out as a 4x3 grid of 12 cells. Row 1: 〇, 一, 二, 三. Row 2: 四, 五, 六, 七. Row 3: 八, 九, 十, 廿. Each cell holds exactly that one character, correctly formed, written with a sumi brush in regular script (kaisho): bold, dark ink, wet edges, a little dry-brush at the stroke ends. 〇 is a brushed circle for zero; 廿 is twenty. All twelve the same visual size and stroke weight, each centered in its cell (一 sits in the vertical middle of its cell, not at the top or bottom). Nothing else on the sheet.
```

### 9.4 Seal digits (5x2)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, small dry-brush grasses in the foreground, and a single red sun disc. The look is restrained, quiet and traditional, with lots of empty space. Not anime, not cartoon, not colorful watercolor.

I need a sprite sheet that I will cut apart by machine and layer onto that landscape. The rules matter more than the art:
- Output a PNG. Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no grid lines, no borders, no frames, no shadows.
- One subject per cell, centered, with wide empty white space around it. Nothing may touch or cross into another cell.
- The only writing on the sheet is the numerals asked for below: no other text, labels, signatures, seals or watermarks.
- Ink only: black and greys with real brush character (wet wash edges, dry-brush texture, varied stroke weight). The ONLY color allowed is a vermilion red (#B83A2E) where a subject says so.
- Every subject must read at thumbnail size: favor solid ink masses and bold strokes over hairline outlines and fine detail.
- Pale subjects must still have a soft but complete grey edge all the way round, so their shape is never lost into the white.
- Same brush, same hand, same scale feel across the whole sheet.

This sheet is small digits for an artist's seal stamp. Make one wide image, 2560x1024, laid out as a 5x2 grid of 10 cells. Row 1: 0, 1, 2, 3, 4. Row 2: 5, 6, 7, 8, 9. Each cell holds one Western Arabic numeral in the blocky carved style of a Chinese seal stamp: squared strokes of even weight, slightly chiseled, worn edges, in solid black ink (I will recolor them). They will be shown only 12 pixels tall, so keep them simple, heavy and open: no thin strokes, no closed-up counters. All ten the same height and width, on one shared baseline, each centered in its cell. Nothing else on the sheet.
```

## Round 9 results (2026-11-05)

Back from both painters, except Gemini's seal digits (not sent yet), plus
one extra gathering-clouds sheet each (`clouds-a/b`, asked alone so the cloud
is not cramped by a cell). Cut by `scripts/cut_art_kit.py` (recipes
`weather` 3x3, `clouds` 1x1, `digits` and `sealdigits` 5x2, `kanji` 4x3).
Every sheet matches its own prompt: running several in one chat did not
leak one sheet's subjects into another.

- **Both painters wrote all twelve kanji correctly**, so the script kanji
  can go. `scripts/bake_glyphs.py` bakes any painter's digits, kanji and
  seal digits into the three fonts at the old line metrics, then
  `gen_halo.py` remakes the halos; the fonts in resources/ are still the
  script ones until John picks a painter.
- **The moon in mist needs a hybrid night cut.** Cut solid, its mist turns
  into an opaque white blob on black; cut plain, the moon goes dark. The
  answer (prototyped, for the weather bake): the moon disc keeps its own
  color and only the mist turns to light ink. That works on ChatGPT's moon;
  Gemini's moon is a drawn ring that defeats the disc fit.
- **Snow:** the white-paper flakes read as snow by day on both; at night
  they nearly vanish, as expected, so the night keeps props2 11's dabs.
- The gathering clouds come in from the right (mirrored), not the left,
  where the time column is.
- **Out (garbage pass, 11-05):** Gemini's moon in mist (a glass ring, the
  mist shows through the disc), Gemini's heavy snow (grey diagonal smears
  read as dirt), Gemini's gathering clouds in the weather sheet (a faint
  wash runs straight into both sides of its cell: a visible box on the
  face), ChatGPT's drizzle (too faint to read at watch size, gone at
  night). Weak but kept as spares: ChatGPT's storm (smudged rain, thin
  bolt), Gemini's extra cloud sheet (its left side is cropped, usable only
  flush with the rim). Left for John's eyes: moon in mist b, snow b, heavy
  snow b, storm a, gathering clouds b and clouds-b, overcast a and b, both
  maple and both winter leaves, drizzle a.
- **Whole-face weather needs its own sheet.** Tiled over the face, these
  cell-sized pieces go too faint to read, by day and worse at night
  (`~/Downloads`-only mock, three depths: behind the horizon, behind the
  grasses, over all but the time column).

## Round 10 (2026-11-05, to send): whole-face weather, one image each

John (11-05): weather should be able to cover the face, from ONE image that
fits the whole place, never a piece tiled or mirrored twice; rain falls one
way, top right to bottom left; leaves mean wind. The round 9 pieces fail it:
they are cell-sized clusters (tiled they go faint, one cell blown up makes
the flakes huge), and the white-paper snow shows the mountain through every
flake. So the snow is asked on black: a cut by brightness lifts white
flakes off black cleanly, where a white-is-transparent cut cannot (cutting
round 9's snow solid fused nearby flakes into white webs). Send each to both
painters, a new chat each; for winter, follow the wind prompt in the same
chat with "the same, but grey dry winter leaves, no red".

Depth (behind the horizon, behind the grasses, over all) is undecided:
the mock (`~/Downloads/ink-face-weather-one-image.png`) has rain at all
three.

### 10.1 Rain

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, dry-brush grasses in the foreground, a red artist's seal. The look is restrained, quiet and traditional. Not anime, not cartoon, not colorful watercolor.

I need ONE image that I will lay over that whole landscape as weather. Rules:
- One square PNG, 2048x2048. Not a grid, not a sprite sheet: a single image whose subject is spread evenly over the entire square, right up to every edge, as if it continues past them.
- Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no shading.
- No landscape, ground, horizon, mountains, clouds, sky color, frame, border, text, seal or watermark: only the weather itself.
- Keep the upper-left area (the left third, top half) noticeably sparser than the rest: the clock sits there.
- Ink only: black and greys with real brush character. No color.
- It must read at thumbnail size without becoming busy: favor fewer, bolder marks over many fine ones.

The weather: steady rain. About 70 straight brush strokes of rain, every one falling in the same direction, from top right to bottom left, at the same angle (about 20 degrees off vertical): no crossing strokes, no wind swirls. Strokes vary in length and in grey (some near-black, most mid grey) and are thick enough to see when the whole image is shrunk to 416 pixels. No lightning, no puddles, no splashes.
```

### 10.2 Storm

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, dry-brush grasses in the foreground, a red artist's seal. The look is restrained, quiet and traditional. Not anime, not cartoon, not colorful watercolor.

I need ONE image that I will lay over that whole landscape as weather. Rules:
- One square PNG, 2048x2048. Not a grid, not a sprite sheet: a single image whose subject is spread evenly over the entire square, right up to every edge, as if it continues past them.
- Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no shading.
- No landscape, ground, horizon, mountains, clouds, sky color, frame, border, text, seal or watermark: only the weather itself.
- Keep the upper-left area (the left third, top half) noticeably sparser than the rest: the clock sits there.
- Ink only: black and greys with real brush character. No color.
- It must read at thumbnail size without becoming busy: favor fewer, bolder marks over many fine ones.

The weather: a heavy storm. About 120 bold dark brush strokes of rain, all falling in the same direction, from top right to bottom left, at the same angle (about 20 degrees off vertical): no crossing strokes. On the right side, one jagged lightning bolt in solid black ink from the top edge about halfway down. No clouds, no ground.
```

### 10.3 Snow (on black, on purpose)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, dry-brush grasses in the foreground, a red artist's seal. The look is restrained, quiet and traditional. Not anime, not cartoon, not colorful watercolor.

I need ONE image that I will lay over that whole landscape as weather. Rules:
- One square PNG, 2048x2048. Not a grid, not a sprite sheet: a single image whose subject is spread evenly over the entire square, right up to every edge, as if it continues past them.
- Background pure flat BLACK (#000000) everywhere, on purpose: the snow is the only light thing in the image, so I can lift it off the black.
- No landscape, ground, horizon, mountains, clouds, sky color, frame, border, text, seal or watermark: only the weather itself.
- Keep the upper-left area (the left third, top half) noticeably sparser than the rest: the clock sits there.
- Ink only: black and greys with real brush character. The snow is white and light greys only; no color.
- It must read at thumbnail size without becoming busy: favor fewer, bolder marks over many fine ones.

The weather: gentle snowfall. About 70 snowflakes as soft round dabs of white ink, solid in the middle and feathered at the edge, a few larger ones (the nearest) and many small ones (far away), drifting very slightly from top right to bottom left. No crystal or star shapes, no rings, no outlines: soft solid dots of white, like flakes in a sumi-e winter scene.
```

### 10.4 Wind (maple leaves)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, dry-brush grasses in the foreground, a red artist's seal. The look is restrained, quiet and traditional. Not anime, not cartoon, not colorful watercolor.

I need ONE image that I will lay over that whole landscape as weather. Rules:
- One square PNG, 2048x2048. Not a grid, not a sprite sheet: a single image whose subject is spread evenly over the entire square, right up to every edge, as if it continues past them.
- Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no shading.
- No landscape, ground, horizon, mountains, clouds, sky color, frame, border, text, seal or watermark: only the weather itself.
- Keep the upper-left area (the left third, top half) noticeably sparser than the rest: the clock sits there.
- Ink only: black and greys with real brush character. The ONLY color allowed is a vermilion red (#B83A2E) on some leaves.
- It must read at thumbnail size without becoming busy: favor fewer, bolder marks over many fine ones.

The weather: wind. About 12 small loose maple leaves blown along one gusting path from the top right to the bottom left of the image, tumbling at different angles, four of them vermilion red (#B83A2E), the rest grey ink. Each leaf SMALL: no wider than one twentieth of the image width. A few faint dry-brush wind streaks along the same path are welcome. No branches, no tree.
```

## Round 10 results (2026-11-05)

All eight back (`rain`, `storm`, `snowfall`, `wind`, each `-a` Gemini and
`-b` ChatGPT; ChatGPT's at 1254 px, Gemini's at 2048). Every one followed
the prompt: rain one way, top right to bottom left; the upper left left
sparse for the clock; the snow on black. Cut whole-frame by
`cut_art_kit.py` (recipes `rain`, `storm`, `snowfall`, `wind`, 1x1 full);
the snow by brightness (`cut_sprite_sheet.py --light`: turned over, it cuts
like any ink sheet; by day the flakes are paper with a faint grey rim, by
night light ink). Mocked on the face, one copy sized to the face, at three
depths and at night (`~/Downloads/ink-face-weather-<kind>.png`):

- **Rain:** both read; Gemini's is heavier and darker, ChatGPT's softer.
- **Storm:** both far too loud at full strength (black slashes across the
  mountain); about 55% alpha reads as a storm, 35% as rain with a grey
  bolt. Gemini's bolt runs into the rim.
- **Snow:** at night both are lovely. By day white flakes vanish on white
  paper; a grey wash over the sky (about 22%) brings them out, the ink
  painter's own way, but the wash needs a soft fade toward the clock, not
  a box (it showed as a band).
- **Wind:** both work; the leaves are small now. On the autumn foreground
  the red leaves blend with the maples.


## Round 11 (2026-11-06, to send): the moon behind cloud, cloud bands, wind leaves for winter and spring

John wore the build (11-06): no cloud ever showed; then, mocked, the
gathering-cloud bank looked stupid cut off flat on one side, and the moon
with a wisp in front was wrong ("the moon should be less bright behind a
cloud"). Round 9's moon in mist, cut either way, reads as a sticker cut out
with scissors: its mist is a hard-edged shape, with no fade. ChatGPT's soft
overcast band (weather-b 06) was the best cloud, a bit subtle. Garmin names
the cloud levels (partly clear, thin clouds, partly cloudy, mostly cloudy,
cloudy), so the cloud sheet asks for bands to build those levels from. The
moon sheet is on black, cut by brightness like the snow, so the cloud can
fade into the night instead of ending at an edge. The two wind prompts are
the ones pinned on 11-05 (the maple blows all year until then). Send each
to both painters, a new chat each.

### 11.1 The moon behind cloud (2x2, on black)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape at night: pale grey ink mountains on black, a small moon in the sky. The look is restrained, quiet and traditional. Not anime, not cartoon, not colorful.

I need a sprite sheet that I will cut apart by machine and layer onto that night sky. The rules matter more than the art:
- One square PNG, 2048x2048, laid out as a 2x2 grid of 4 subjects. Background pure flat BLACK (#000000) everywhere, on purpose: the moon and the cloud are the only light things, so I can lift them off the black by brightness.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No grid lines, borders, frames, text, labels, seals or watermarks.
- Ink only: white, light greys and greys. No color.
- The cloud is the point of this sheet. It must be a soft, thin, translucent wash of grey mist that fades gradually to pure black at every edge, like breath on glass: no outline, no hard edge, no cut-out shape anywhere. Where the cloud crosses the moon, the moon shows through it dimmer and blurred; the moon is never pasted on top of the cloud.
- Every subject must read at thumbnail size (the moon will be about 40 pixels across on the watch).

Left to right, top to bottom:
(1) a full moon, a pale textured disc, with a thin veil of mist drifting across its lower third; most of the moon still bright.
(2) the same full moon mostly hidden behind a thicker drift of cloud: only a dim glow and part of its rim show through; the whole subject much darker than (1).
(3) a waxing crescent moon, lit on the right, with a thin veil of mist across its lower half.
(4) the same crescent mostly hidden behind a thicker drift of cloud, only a faint glow of it showing.
```

### 11.2 Cloud bands (2x2, on white)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, small dry-brush grasses in the foreground, and a single red sun disc. The look is restrained, quiet and traditional, with lots of empty space. Not anime, not cartoon, not colorful watercolor.

I need a sprite sheet that I will cut apart by machine and layer into that sky. The rules matter more than the art:
- One square PNG, 2048x2048, laid out as a 2x2 grid of 4 subjects. Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no grid lines, no borders, no frames, no shadows.
- One subject per cell, centered, with wide empty white space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, signatures, seals or watermarks anywhere.
- Ink only: black and greys, soft wet wash. No color.
- Every cloud is a horizontal band, much wider than tall, and it fades out softly and completely at BOTH ends and along its top and bottom: no flat or cut-off side, no hard outline, nothing that looks like it continues past the cell. Think of the long soft mist bands in a classical ink landscape.
- Mid grey, not pale: each band must still read clearly when the whole sheet is shrunk to 416 pixels.

Left to right, top to bottom:
(1) one thin wisp of cloud, a single soft stroke of grey wash.
(2) one soft cloud band, a little fuller, darker in its middle.
(3) two soft bands, one above and slightly behind the other, overlapping.
(4) a broad overcast bank of three or four soft layered bands, the fullest and darkest of the four, still fading out at both ends.
```

### 11.3 Wind, winter (whole face)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, dry-brush grasses in the foreground, a red artist's seal. The look is restrained, quiet and traditional. Not anime, not cartoon, not colorful watercolor.

I need ONE image that I will lay over that whole landscape as weather. Rules:
- One square PNG, 2048x2048. Not a grid, not a sprite sheet: a single image whose subject is spread evenly over the entire square, right up to every edge, as if it continues past them.
- Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no shading.
- No landscape, ground, horizon, mountains, clouds, sky color, frame, border, text, seal or watermark: only the weather itself.
- Keep the upper-left area (the left third, top half) noticeably sparser than the rest: the clock sits there.
- Ink only: black and greys with real brush character. No color.
- It must read at thumbnail size without becoming busy: favor fewer, bolder marks over many fine ones.

The weather: a cold winter wind. About 12 small dry, curled winter leaves and a few short pine needles blown along one gusting path from the top right to the bottom left of the image, tumbling at different angles, all in grey ink. Each leaf SMALL: no wider than one twentieth of the image width. A few faint dry-brush wind streaks along the same path are welcome. No branches, no tree, no snow.
```

### 11.4 Wind, spring (whole face)

```
I'm building a watch face for a Garmin Forerunner 265, a round 416x416 pixel color screen. The face is a Japanese sumi-e ink landscape: soft grey-black brush mountains fading into mist on warm off-white rice paper, dry-brush grasses in the foreground, a red artist's seal. The look is restrained, quiet and traditional. Not anime, not cartoon, not colorful watercolor.

I need ONE image that I will lay over that whole landscape as weather. Rules:
- One square PNG, 2048x2048. Not a grid, not a sprite sheet: a single image whose subject is spread evenly over the entire square, right up to every edge, as if it continues past them.
- Background pure flat white (#FFFFFF) everywhere: no paper texture, no vignette, no shading.
- No landscape, ground, horizon, mountains, clouds, sky color, frame, border, text, seal or watermark: only the weather itself.
- Keep the upper-left area (the left third, top half) noticeably sparser than the rest: the clock sits there.
- Ink only: black and greys with real brush character. The ONLY color allowed is a soft blossom pink (#E3A9A8) on some petals.
- It must read at thumbnail size without becoming busy: favor fewer, bolder marks over many fine ones.

The weather: a spring wind. About 16 small cherry blossom petals and two or three small whole blossoms blown along one gusting path from the top right to the bottom left of the image, tumbling at different angles, about half of them soft blossom pink (#E3A9A8), the rest pale grey ink with a darker grey edge so they never vanish on white. Each petal SMALL: no wider than one twenty-fifth of the image width. A few faint dry-brush wind streaks along the same path are welcome. No branches, no tree.
```
