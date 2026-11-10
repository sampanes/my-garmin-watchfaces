# Friend art: the cast and the sheet prompts

Status 2026-11-10: nothing sent yet. The creature the watch draws today
(`probes/wrist-diary/source/FriendArt.mc`) is a placeholder; this is the cast that replaces
it and the prompts for an image generator to paint it, the way the ink face got its art
(`watch-faces/japanese-ink-heartrate/art/sheets/PROMPTS.md`). The names are working names.

## The growth tree

```
                           EGG
                            |   first open: pick a color and a voice
                    NUB, the hatchling             band 0
                            |   100 XP
                    SPRIG, the sprout              bands 1-2
                            |   660 XP and 7 days old: EVOLUTION 1, pick a lane
          +-----------------+-----------------+
        SLEEK             ROUND             WILD
        DASH              CHONK             SCAMP          bands 3-5
          |                 |                 |   2400 XP and 30 days on: EVOLUTION 2
        GALE              BULWARK           BRAMBLE        bands 6-8
          |                 |                 |   5220 XP and 30 days on: EVOLUTION 3
        COMET             SUMMIT            WILDWOOD       band 9 and up
```

Any lane can be picked at each evolution (the evolve screen offers all three every time),
so a Dash may grow into a Bulwark. The pet looks like the lane picked last at the tier it
has reached; the earlier picks stay in its save and are not drawn. That makes nine grown
forms, not 3 + 9 + 27.

## The cast

| # | Name | When | What it is |
|---|---|---|---|
| 1 | Egg | before the first open | Cream egg with one wavy band in the pet's color. Rocks, cracks, hatches. |
| 2 | Nub | band 0 Hatchling, 0 XP | Newborn. Squat blob, no arms, no ears, huge eyes, wears the top of its eggshell as a cap. |
| 3 | Sprig | bands 1-2 Sprout and Trainee, 100 XP | Child. Ears and stubby arms arrive, and the family's leaf: a two-leaf sprout on its head. |
| 4 | Dash | evolution 1, sleek | The runner. Tall slim teardrop on longer legs, ears swept back, the leaf now one long crest blade. |
| 5 | Chonk | evolution 1, round | The strong one. Wide, heavy and low, big mitten fists, the leaf now a clover cap of three round leaves. |
| 6 | Scamp | evolution 1, wild | The playful one. Scruffy, one bent ear, a snaggle tooth, a fluffy tail, the leaf now a tuft of three spikes. |
| 7 | Gale | evolution 2, sleek | Taller and slimmer. Two leaf blades stream behind like ribbons, leaf wings at the ankles, a white swirl on the belly. |
| 8 | Bulwark | evolution 2, round | Broader, round shoulders. A bushy crown of round leaves, a mossy stone on each shoulder like armor. |
| 9 | Bramble | evolution 2, wild | A leaf mane all round the head with red berries, two fangs, a big leaf-tipped tail. |
| 10 | Comet | evolution 3, sleek | Tallest. A plume of leaf blades trails to its heels like a comet tail with white seed-puffs, wings at ankles and wrists. |
| 11 | Summit | evolution 3, round | Biggest and widest, a gentle little mountain. A tiny tree on its head, a moss cloak, stone plates on the forearms. |
| 12 | Wildwood | evolution 3, wild | A great mane of leaves and vines, twig antlers, fangs, berries, a huge leafy tail. Fierce and friendly. |

The lanes are three ways of being fit: sleek is endurance (wind: the leaf streams), round is
strength (earth: the leaf thickens, then stone and moss), wild is play and agility (thicket:
the leaf goes spiky, then mane, berries and antlers). One species, one leaf, three lives.

Earned things that are layered on any of them, not painted into them:

| Thing | When | Sheet |
|---|---|---|
| Headband | band 2, 320 XP | gear 1 |
| Power-up flames (an emote) | band 4, 1120 XP | gear 5, 6 |
| Cape | band 5, 1700 XP | gear 2, 3 |
| Aura | evolution 2, 2400 XP | gear 4 |

The four voices (drill sergeant, cheerleader, deadpan, zen) are words only and need no art.

## How this meets the build

- `FriendArt.setLook(stage, band, form, evos, pal)` already carries everything that picks a
  character: egg, baby (Nub), child (Sprig), then adult by `form` (sleek, round, wild) and
  `evos` (1, 2, 3 or more). **Today the watch draws evolutions 2 and 3 as the evolution 1
  body with an aura; Gale to Wildwood are new looks**, and need no new stored data.
- Each character sheet covers what `setPose` asks for: the four mood faces (cells 1-4),
  effort (5), joy (6), flex (7), spin (the front plus the back view, 8), run (9, 10), hop
  (11) and sleep (12). The idle bob, the jump height and the squash stay in code.
- **Six colors from one sheet.** The sheets ask for the SKY color only and reserve blue for
  the body, so the bake can turn the blue into mint, peach, lilac, sun and rose without
  touching leaves, stones or eyes. Do not ask a generator for the other five.
- **On black, on purpose.** Friend's screen is black, so a sheet painted on black needs no
  clean edge: whatever fringe the cut leaves is black on black. (The ink face's sheets were
  on white because its paper is light; its snow and moon went on black for the same reason
  as here.) The rule that goes with it: nothing dark on a subject's outer edge.
- No cutter for these exists yet. `scripts/cut_sprite_sheet.py` reads ink on white; a
  color-on-black cut (background found from the sheet's edges, cells by grid as before) gets
  written when the first sheet is back, against a real image.

## Order of work

1. **The family lineup first** (prompt 1), to both painters, a new chat each. It decides the
   species. Nothing else is worth sending until one lineup is right; if one row is off, ask
   in the same chat for that row again.
2. Crop each character out of the chosen lineup (the cutter will do this) and **attach the
   crop** to that character's sheet prompt (2.1 to 2.11), a new chat each. The attached
   image is what keeps twelve poses the same animal; the words are the fallback.
3. The egg (3) and the gear (4) need no attachment and can go any time.

Save what comes back beside this file as `<date>_<sheet>-a.jpg` (Gemini) or `-b.png`
(ChatGPT), e.g. `2026-11-12_lineup-b.png`, `2026-11-13_dash-a.jpg`: the ink face's naming.
Lessons carried over from that file: ask for PNG; colors drift and recoloring is cheap, so
do not fight a generator over a hex; Gemini paints with more character and bends the rules,
ChatGPT obeys the grid; a sheet comes back smaller than asked and that costs nothing here.

Not in this file: the sky behind the pet and the small icons (flame, heart, shield,
sparkle). Their code-drawn stand-ins stay until the cast is in.

**The one paragraph to change for a different look** is the one that starts `Style:`. It is
the same in every prompt; swap it everywhere at once (chunky pixel art, or ink brush to
match the ink face, are the two obvious others) and leave the rules alone.

## 1. The family lineup (3x4, send first)

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is the whole family in one picture, so that all twelve share one design. Make one portrait image, 1536x2048, laid out as a grid of 3 columns by 4 rows (12 cells). Every character stands still, seen straight from the front, with a small content smile. Their sizes differ on purpose: the height given for each is a share of its cell's height. Left to right, top to bottom:
Row 1, the young: (1) EGG: a plump egg, cream white (#FFF4DC), with one wide wavy band of the body blue (#6EC1FF) around its middle. No face, no limbs. About 45% of the cell height. (2) NUB: the newborn, and the smallest of the family. A squat little blob, slightly wider than tall, with no arms, no ears and no leaf yet: just two tiny feet and huge eyes that take up a third of its face. It wears the top of its eggshell as a cap: cream white (#FFF4DC) with a jagged broken edge, sitting low over its brow. About 40% of the cell height. (3) SPRIG: the child. A little taller than wide. Small round ears, short stubby arms, a clear belly patch, and a young sprout on top of its head: two small green leaves on a short stem. Bright, eager and curious. About 50% of the cell height.
Row 2, the first grown-up forms. From here down the LEFT column is the sleek family, the MIDDLE column the round family and the RIGHT column the wild family, and each one must look like the one above it grown older: (4) DASH: the first SLEEK form: the runner. Clearly taller than wide, a slim teardrop body on longer legs with proper little running feet. Its ears are longer and swept back. The leaf has become one long narrow leaf blade swept back over the head like a crest. Light on its feet, quick and eager. About 62% of the cell height. (5) CHONK: the first ROUND form: the strong one. Clearly wider than tall, heavy and low to the ground, with short thick arms ending in big round mitten fists, small ears and a large belly patch. The leaf has become a clover of three thick round leaves sitting on its head like a little cap. Planted, solid and calm. About 62% of the cell height. (6) SCAMP: the first WILD form: the playful one. About as tall as wide, with a scruffy outline: fluffy cheeks, one ear bent over at the tip, one small snaggle tooth showing, and a short fluffy tail sticking out at one side. The leaf has become a tuft of three spiky leaves pointing up at odd angles. A mischievous grin and a bouncy stance. About 62% of the cell height.
Row 3, the second forms: (7) GALE: the second SLEEK form: the runner grown up. Taller and slimmer again, on long legs, ears swept back. Its crest is two long green leaf blades streaming back and down behind the head like ribbons in the wind, and a small green leaf stands out like a wing at each ankle. A white swirl mark on the belly patch. Poised and fast. About 72% of the cell height. (8) BULWARK: the second ROUND form: the strong one grown up. Much wider than tall, with big round shoulders, short thick arms and big round mitten fists. On its head a thick bushy crown of round green leaves, and a smooth grey stone with a patch of green moss sits on each shoulder like an armor pad. Immovable and kind. About 72% of the cell height. (9) BRAMBLE: the second WILD form: the playful one grown up. About as tall as wide. A spiky mane of green leaves all the way round its head like a ruff, with three red berries (#E5484D) in it, two small fangs, one ear bent over at the tip, and a big bushy tail tipped with leaves. Wild-eyed and grinning. About 72% of the cell height.
Row 4, the final forms: (10) COMET: the final SLEEK form, the tallest and most graceful of the family. Slim, on long legs. Its crest is a long flowing plume of four or five green leaf blades that trails behind it all the way down to its heels like a comet's tail, with three round white seed-puffs along it. Small leaf wings at the ankles and the wrists, and a white swirl mark on the belly patch. Calm and sure of itself. About 85% of the cell height. (11) SUMMIT: the final ROUND form, the biggest and widest of the family, like a gentle little mountain. A tiny round-topped tree grows on top of its head, green moss covers its shoulders like a short cloak, and grey stone plates guard its forearms. Big round mitten fists. Serene, with a small smile. About 85% of the cell height. (12) WILDWOOD: the final WILD form, the wildest of the family. A great mane of green leaves and curling vines, two short twig antlers with a leaf on each tip, two fangs, clusters of red berries (#E5484D) in the mane, one ear bent over at the tip, and a huge leafy tail. A fierce, delighted grin: thrilling, still friendly, never scary. About 85% of the cell height.
```

## 2. One sheet per character (4x3; attach that character's crop from the lineup)

### 2.1 Nub (4x2: no arms, so eight poses)

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in eight poses. The character is NUB: the newborn, and the smallest of the family. A squat little blob, slightly wider than tall, with no arms, no ears and no leaf yet: just two tiny feet and huge eyes that take up a third of its face. It wears the top of its eggshell as a cap: cream white (#FFF4DC) with a jagged broken edge, sitting low over its brow. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, shell cap) and treat the description as a reminder.

Make one wide image, 2048x1024, laid out as a grid of 4 columns by 2 rows (8 cells). In every cell the character is the same size (about 60% of the cell height) and is seen straight from the front unless the cell says otherwise. It has no arms, so everything is said with the eyes, the mouth, the tilt of the body and the shell cap. Left to right, top to bottom:
Row 1, sitting still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, body sagging a little, cap slipped low. Not crying, not sick: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile. (3) SUNNY: happy. Bright wide eyes, open smile. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, stretched up tall on its feet.
Row 2: (5) EFFORT: trying with all its tiny might. Eyes squeezed shut, cheeks puffed out, cap tilted. (6) HOP: in mid-air at the top of a happy bounce, feet tucked up, mouth wide open. (7) BACK VIEW: sitting still, seen from directly behind: the round back and the back of the shell cap. No face. (8) ASLEEP: settled flat like a dumpling, eyes closed as two curved lines, tiny relaxed mouth, the shell cap slid forward over one eye.
```

### 2.2 Sprig

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is SPRIG: the child. A little taller than wide. Small round ears, short stubby arms, a clear belly patch, and a young sprout on top of its head: two small green leaves on a short stem. Bright, eager and curious. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.3 Dash

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is DASH: the first SLEEK form: the runner. Clearly taller than wide, a slim teardrop body on longer legs with proper little running feet. Its ears are longer and swept back. The leaf has become one long narrow leaf blade swept back over the head like a crest. Light on its feet, quick and eager. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.4 Chonk

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is CHONK: the first ROUND form: the strong one. Clearly wider than tall, heavy and low to the ground, with short thick arms ending in big round mitten fists, small ears and a large belly patch. The leaf has become a clover of three thick round leaves sitting on its head like a little cap. Planted, solid and calm. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.5 Scamp

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is SCAMP: the first WILD form: the playful one. About as tall as wide, with a scruffy outline: fluffy cheeks, one ear bent over at the tip, one small snaggle tooth showing, and a short fluffy tail sticking out at one side. The leaf has become a tuft of three spiky leaves pointing up at odd angles. A mischievous grin and a bouncy stance. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.6 Gale

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is GALE: the second SLEEK form: the runner grown up. Taller and slimmer again, on long legs, ears swept back. Its crest is two long green leaf blades streaming back and down behind the head like ribbons in the wind, and a small green leaf stands out like a wing at each ankle. A white swirl mark on the belly patch. Poised and fast. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.7 Bulwark

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is BULWARK: the second ROUND form: the strong one grown up. Much wider than tall, with big round shoulders, short thick arms and big round mitten fists. On its head a thick bushy crown of round green leaves, and a smooth grey stone with a patch of green moss sits on each shoulder like an armor pad. Immovable and kind. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.8 Bramble

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is BRAMBLE: the second WILD form: the playful one grown up. About as tall as wide. A spiky mane of green leaves all the way round its head like a ruff, with three red berries (#E5484D) in it, two small fangs, one ear bent over at the tip, and a big bushy tail tipped with leaves. Wild-eyed and grinning. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.9 Comet

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is COMET: the final SLEEK form, the tallest and most graceful of the family. Slim, on long legs. Its crest is a long flowing plume of four or five green leaf blades that trails behind it all the way down to its heels like a comet's tail, with three round white seed-puffs along it. Small leaf wings at the ankles and the wrists, and a white swirl mark on the belly patch. Calm and sure of itself. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.10 Summit

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is SUMMIT: the final ROUND form, the biggest and widest of the family, like a gentle little mountain. A tiny round-topped tree grows on top of its head, green moss covers its shoulders like a short cloak, and grey stone plates guard its forearms. Big round mitten fists. Serene, with a small smile. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

### 2.11 Wildwood

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- No floating effects: no sparkles, hearts, sweat drops, motion lines, Zs, stars or glows around a subject. The game adds those itself. All the feeling comes from the face and the body.
- Same design, same colors, same line weight and the same flat front lighting in every cell.
- Color: the body is sky blue (#6EC1FF) with a paler blue belly patch (#CDEBFF) and a darker blue (#3A8BD1) for shading. I will recolor the blue into other colors by machine, so blue is reserved for the body: nothing else may be blue (not the eyes, not the leaves, not anything it wears). Leaves are fresh green (#6CC24A). Eyes are dark brown-black with one white highlight.

The creature (every character is the same species at a different age): a small, soft, round animal with no neck: head and body are one rounded shape, like a mochi or a smooth river pebble. Two big oval dark eyes set wide apart and low on the face, a tiny mouth, no nose, a small pink blush under each eye. A pale belly patch. Two short stubby feet. From childhood on it also has two small rounded ears on the upper sides of its head, two short stubby arms with mitten hands (no fingers), and a green leaf growing from the top of its head. The leaf is the family's signature: what the leaf grows into is what tells the grown-up forms apart.

This sheet is ONE character in twelve poses. The character is WILDWOOD: the final WILD form, the wildest of the family. A great mane of green leaves and curling vines, two short twig antlers with a leaf on each tip, two fangs, clusters of red berries (#E5484D) in the mane, one ear bent over at the tip, and a huge leafy tail. A fierce, delighted grin: thrilling, still friendly, never scary. If an image is attached, it shows this character: match it exactly (shape, proportions, colors, leaf, markings) and treat the description as a reminder.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing still, four moods from low to high: (1) MISTY: quiet and a little low. Half-closed eyes, small flat mouth, ears and leaf drooping, arms hanging. Not crying, not sick, not angry: just a grey-day mood. (2) FAIR: content. Eyes open, small closed smile, relaxed. (3) SUNNY: happy. Bright wide eyes, open smile, leaf perked up. (4) RADIANT: overjoyed. Eyes closed in happy upward arcs, big open smile, arms lifted a little from its sides, leaf standing tall.
Row 2: (5) EFFORT: in the middle of a hard workout and loving the fight. Brows down, determined eyes, gritted grin, fists clenched, leaning forward a little. (6) CHEER: it just won. Both arms thrown straight up, up on its toes, mouth wide open in a shout of joy. (7) FLEX: showing off. Both arms raised in a double-biceps pose, chest out, proud closed-mouth grin. (8) BACK VIEW: the relaxed standing pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward, happy focused face. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) HOP: in mid-air at the top of a happy jump, knees tucked, arms out to the sides, open smile. (12) ASLEEP: sitting slumped on the ground, fast asleep: eyes closed as two curved lines, tiny relaxed mouth, leaf drooped to one side, arms resting on its belly.
```

## 3. The egg hatching (3x2)

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- Same design, same colors, same line weight and the same flat front lighting in every cell.

This sheet is the pet's egg hatching, six steps. The egg: a plump egg, cream white (#FFF4DC), with one wide wavy band of sky blue (#6EC1FF) around its middle. I will recolor the blue by machine, so nothing else may be blue. The same egg, the same size (about 65% of the cell height) and standing on the same spot in every cell. Make one landscape image, 2048x1365, laid out as a grid of 3 columns by 2 rows (6 cells). Left to right, top to bottom:
Row 1: (1) the whole egg, upright and still. (2) the same egg tipped about 15 degrees to the left, as if rocking. (3) upright again, with one bold zigzag crack across its upper third.
Row 2: (4) the crack has opened into a jagged gap, with warm yellow light (#FFE08A) showing inside the gap only. (5) the top of the shell lifted like a lid, and two big round dark eyes with white highlights peeking out of the gap under it. (6) only the empty bottom half of the shell, upright like a bowl with a jagged rim: no creature, no top half.
```

## 4. Gear: headband, cape, aura, flames (3x2)

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

Style: a cute original mascot creature for a cozy virtual-pet game, drawn like a clean vector sticker or a soft vinyl toy: big simple rounded shapes, flat color with one soft shadow tone and one small highlight, smooth edges, no texture, no fur detail, no realism. Friendly and a little goofy. It is an original design: it must not look like any existing game, cartoon or toy character.

I need a sprite sheet that I will cut apart by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere, on purpose, because the watch screen is black: no gradient, no glow, no floor, no cast shadow, no grid lines, no borders, no frames.
- One subject per cell, centered, with wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, labels, numbers, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- Every subject must read at thumbnail size: big simple shapes, few details, no hairlines.
- The whole silhouette must be bright against the black: no black or very dark color on the outer edge of a subject. Any outline is a darker shade of the color it surrounds, never black. Dark colors only inside the body (eyes, mouth).
- Same design, same colors, same line weight and the same flat front lighting in every cell.

This sheet is the things the pet earns as it levels up. Each is drawn ALONE, with no character: the game layers them onto a small round creature that is about as wide as it is tall. Nothing on this sheet may be blue. Make one landscape image, 2048x1365, laid out as a grid of 3 columns by 2 rows (6 cells). Left to right, top to bottom:
Row 1: (1) HEADBAND: a red (#E5484D) athletic headband as it looks when worn on a round head seen from the front: a gently curved horizontal band, with a knot at its right end and two short tails fluttering from the knot. Only the band: no head. (2) CAPE, at rest: a short hero's cape seen from the front, the way it shows behind a round character standing still: it spreads out wide on both sides and hangs to a wavy hem, with one small round gold clasp at the top center. Red (#E5484D), a darker red in the folds. Keep its middle plain: a body will cover it. (3) CAPE, flying: the same cape blown out to the right by the wind.
Row 2: (4) AURA: a soft glowing ring of golden light (#F2D550), big enough to stand behind a whole character: brightest in a band partway out from the center, empty and black in the center, fading smoothly to black at its outer edge. No hard outline anywhere. (5) POWER-UP FLAMES, frame A: a wreath of bold cartoon flames rising around an empty black center where a character will stand: five or six flame tongues, orange (#FF8A3D) with yellow cores, taller at the sides than in the middle. (6) POWER-UP FLAMES, frame B: the same wreath a moment later, every tongue leaning the other way and at a different height, so that A and B alternate as an animation.
```
