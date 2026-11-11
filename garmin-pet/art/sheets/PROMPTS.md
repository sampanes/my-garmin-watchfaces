# Friend art: the cast and the sheet prompts

Status 2026-11-10: the lineup, the first five body sheets and the belly emblems are back,
filed beside this file, and baked into Friend 0.9.0 (unbuilt); see "Round 1" to "Round 3" at
the end. Still to paint: Gale to Wildwood (2.6 to 2.11), the faces (3), the egg (4), the gear
(5). This is the cast that replaces the creature drawn from shapes in
`probes/wrist-diary/source/FriendArt.mc`, and the prompts for an image generator to paint it,
the way the ink face got its art (`watch-faces/japanese-ink-heartrate/art/sheets/PROMPTS.md`).
The names are working names.

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
| Belly emblem | one picked at the start, more earned (proposed, see below) | emblems |

The four voices (drill sergeant, cheerleader, deadpan, zen) are words only and need no art.

## How this meets the build

- `FriendArt.setLook(stage, band, form, evos, pal)` already carries everything that picks a
  character: egg, baby (Nub), child (Sprig), then adult by `form` (sleek, round, wild) and
  `evos` (1, 2, 3 or more). **Today the watch draws evolutions 2 and 3 as the evolution 1
  body with an aura; Gale to Wildwood are new looks**, and need no new stored data.
- **The face is its own layer.** A character sheet is body poses only, all with one plain
  face; the cut finds the two eyes in each cell (that is the anchor), erases the face into
  the blue around it and keeps the blank body. Faces come from one small sheet for the whole
  family (prompt 3) and are laid over at the anchor. So any mood goes on any pose, the pet
  can blink and glance, and twelve characters share one set of eyes. Tried on the ChatGPT
  lineup 11-10: the faces erase cleanly and one character's face sits naturally on another.
  The wild lane's snaggle tooth and fangs are part of the face and go with it; a wild-lane
  face sheet can follow if they are missed.
- Each character sheet's cells against what `setPose` asks for: idle is cells 1 and 2 (a
  drawn breath, not a stretch), the misty mood adds the droop (3), spin is the front plus
  the back view (4), hop is crouch, air, crouch (5, 6), joy (7), flex (8), run (9, 10),
  effort (11), sleep (12). Code only moves the whole picture (the hop's height, the run's
  bounce); it never squashes or stretches a bitmap.
- **Six colors from one sheet.** The sheets ask for the SKY color only and reserve blue for
  the body, so the bake can turn the blue into mint, peach, lilac, sun and rose without
  touching leaves, stones or eyes. Do not ask a generator for the other five. Tried 11-10 on
  ChatGPT's Scamp sheet: a hue swap on the blue pixels alone gives all five other colors
  cleanly, shading and belly included. A new color later (a seventh, or a different pink) is
  one more entry in the bake's color table and a rebuild of the watch app, with no new art.
  The pink blush nearly vanished on the rose body; the bake deepens it there ("Round 3").
- **On black, on purpose.** Friend's screen is black, so a sheet painted on black needs no
  clean edge: whatever fringe the cut leaves is black on black. (The ink face's sheets were
  on white because its paper is light; its snow and moon went on black for the same reason
  as here.) The rule that goes with it: nothing dark on a subject's outer edge.
- **The belly emblem is a third layer (John's idea, 11-10; a first pass is in Friend 0.9.0, see
  "Round 3").**
  The wearer picks an emblem that shows on the pet's belly patch, and it brightens and dulls.
  - *How it is drawn:* like the face. The belly patch is a flat pale oval that faces the
    viewer, so the cut records its center and size in each cell, and the watch lays the
    emblem over it. No emblem in the back view or asleep (arms cover the belly); a flattened
    copy for the crouch. One emblem sheet (prompt 6) serves all twelve characters.
  - *What the brightness means:* warmth, the momentum number the pet already keeps (20 to
    100, up with active days, easing down after missed ones; `12-pet-state-and-economy.md`
    §5). Today it shows only as a word on a card. Three baked levels: dull below 70, steady
    from 70, glowing from 90 (the card's "warmed up" and "in the zone" lines). Dull reads as
    resting, never as a penalty. During an effort chapter the emblem pulses between two
    levels, faster with more flames.
  - *How emblems are had:* four to choose from at the start (heart, star, leaf, swirl),
    changed freely like the colorway; the rest earned and kept. Proposed: the five trail
    goals give paw (first km), apple (5 km picnic), mountain (10 km ridge), wing (half
    marathon), crown (marathon); bands 7 and up, which today unlock only "bragging rights",
    give bolt, flame, dumbbell, sun, moon, flower, gem in that order.
  - *Why white on black:* each emblem is asked as one solid white shape, so the cut is a
    plain brightness cut and the three brightness levels and every colorway are made at the
    bake from one drawing. Tinting a bitmap on the watch is unproven, so nothing depends on it.
  - *What it costs:* one new stored number for the equipped emblem and a bitset of the earned
    ones. The pet's 32-slot save is full, so that is a save-version step. Gale and Comet have
    a swirl painted on the belly in the lineup: the swirl becomes an emblem and is erased
    from their bodies, like the face.
- The cut and the bake are one script, `scripts/bake_friend_sprites.py` ("Round 3"). It
  finds the cells from the black between them, so a sheet needs clear black gaps between
  its poses and nothing floating beside a pose.

## Order of work

1. **The family lineup first** (prompt 1), to both painters, a new chat each. It decides the
   species. Nothing else is worth sending until one lineup is right; if one row is off, ask
   in the same chat for that row again.
2. **Then one character's body sheet, Sprig first** (2.2), pasted into the SAME chat that
   drew the chosen lineup. The body prompts are follow-ups, not fresh starts: they point at
   the character's cell in the lineup and say "draw exactly that", with no description to
   fight what was painted. In a fresh chat, attach the lineup image and they work as they
   are. Sprig, Nub and the egg are all the watch can show until the first evolution at
   660 XP; the other nine can wait for it.
3. The faces (3) go best in the lineup chat too, so the eyes match. The egg (4), the gear
   (5) and the belly emblems (6) stand alone and can go anywhere, any time.

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

## 2. One body sheet per character (4x3; follow-ups for the chat that drew the lineup)

### 2.1 Nub (4x2: no arms, so eight poses)

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 1, column 2 (the newborn in the eggshell cap). Draw exactly that character as it appears there: the same shape, proportions, colors, and shell cap in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the feet and the shell cap. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one wide image, 2048x1024, laid out as a grid of 4 columns by 2 rows (8 cells). In every cell the character is the same size (about 60% of the cell height) and is seen straight from the front unless the cell says otherwise. It has no arms, so everything is said with the shape of the body, the feet and the shell cap, which never covers the eyes. Left to right, top to bottom:
Row 1: (1) IDLE: sitting still. (2) BREATHE: the same pose at the top of a breath: puffed up a little taller and rounder. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood: body sagging wider and lower, cap slipped a little to one side. (4) BACK VIEW: sitting still, seen from directly behind: the round back and the back of the shell cap. No face.
Row 2: (5) CROUCH: pressed down flat and wide, the instant before a bounce. (6) HOP: in mid-air at the top of the bounce, stretched a little taller, feet tucked up. (7) STRAIN: trying with all its tiny might: leaning forward, feet planted wide, cap tilted back. (8) ASLEEP: settled flat like a dumpling, cap pushed back on its head.
```

### 2.2 Sprig

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 1, column 3 (the child with the two-leaf sprout). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.3 Dash

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 2, column 1 (the first sleek form, with the single crest leaf). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.4 Chonk

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 2, column 2 (the first round form, with the clover cap). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.5 Scamp

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 2, column 3 (the first wild form, with the spiky tuft and the tail). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.6 Gale

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 3, column 1 (the second sleek form, with the two streaming leaf blades). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.7 Bulwark

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 3, column 2 (the second round form, with the mossy stones on its shoulders). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.8 Bramble

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 3, column 3 (the second wild form, with the leaf mane and the berries). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.9 Comet

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 4, column 1 (the final sleek form, with the long leaf plume). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.10 Summit

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 4, column 2 (the final round form, with the tree on its head). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

### 2.11 Wildwood

```
The family lineup sheet is the design (the one you made earlier in this chat, or the one attached). Now I need a pose sheet for ONE character from it: the one in row 4, column 3 (the final wild form, with the twig antlers). Draw exactly that character as it appears there: the same shape, proportions, colors, leaf and markings in every cell. Do not redesign it and do not add anything to it.

Same rules as the lineup: a PNG, pure flat black background, one subject per cell with wide black space around it, nothing touching another cell or the image edge, no text, no floating effects (sparkles, sweat drops, motion lines, Zs, glows), nothing dark on a subject's outer edge, and blue only on the body.

One new rule: the face is the same in every cell: eyes open, small closed smile, exactly the same size and drawing each time. I replace the face by machine afterward, so do not act with the face at all: all the feeling comes from the body, the limbs, the ears and the leaf. Keep the head upright and facing the viewer in every cell (no tilt, no turn), so the face always sits flat.

Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). In every cell the character is the same size (standing about 70% of the cell height) and is seen straight from the front unless the cell says otherwise. Left to right, top to bottom:
Row 1, standing: (1) IDLE: relaxed, arms at its sides. (2) BREATHE: the same pose at the top of a deep breath: chest a little fuller, shoulders and arms lifted a touch, leaf lifted a little. Cells 1 and 2 alternate as its breathing, so they must differ only by that. (3) DROOP: a grey-day mood said with the body only: shoulders down, ears and leaf drooping, arms hanging limp. (4) BACK VIEW: the idle pose seen from directly behind: the back of the head, the ears, the leaf, and the tail if it has one. No face.
Row 2: (5) CROUCH: knees bent deep, body pressed low and wide, arms swung back: the instant before a jump. (6) HOP: in mid-air at the top of the jump, body stretched a little taller, knees tucked, arms out to the sides. (7) CHEER: it just won. Both arms thrown straight up, up on its toes. (8) FLEX: showing off. Both arms raised in a double-biceps pose, chest out.
Row 3: (9) RUN A: jogging toward the viewer, left knee lifted high, right arm forward. (10) RUN B: the same jog on the other foot: right knee lifted high, left arm forward. (11) EFFORT: in the middle of a hard workout: leaning forward a little, fists clenched, elbows bent, braced. (12) ASLEEP: sitting on the ground with its legs out in front, body slumped and soft, arms resting on its belly, leaf drooped to one side.
```

## 3. The faces (4x3, one sheet for the whole family)

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

This sheet is the creature's faces, which the game lays over its blank-faced body. If you drew the family lineup earlier in this chat, or it is attached, copy its eyes, mouth and blush exactly. The creature has two big oval dark brown-black eyes with one white highlight each, set wide apart, a tiny mouth, no nose, and a small pink blush under each eye. Make one landscape image, 2048x1536, laid out as a grid of 4 columns by 3 rows (12 cells). Every cell holds one plain flat sky-blue (#6EC1FF) disc, the same size in every cell (about 75% of the cell height), with no outline, no shading, no ears and no body: it stands for the creature's skin. On each disc draw ONLY a face: eyes, mouth, blush, and eyebrows only where a cell names them. The eyes sit at exactly the same place and the same distance apart on every disc, and the blush is the same in every cell. Nothing in a face may be blue. Left to right, top to bottom:
Row 1: (1) FAIR: eyes open, small closed smile. (2) BLINK: the same face with the eyes closed as two short curved lines. (3) SUNNY: bright wide eyes, open smile. (4) RADIANT: eyes closed in happy upward arcs, big open smile.
Row 2: (5) MISTY: a grey-day mood: half-closed eyes, small flat mouth. Not crying, not sick, not angry. (6) EFFORT: short eyebrows angled down, determined eyes, gritted grin. (7) SHOUT: a shout of joy: eyes squeezed shut in happy arcs, mouth wide open. (8) PROUD: half-lidded smug eyes, a wide closed-mouth grin.
Row 3: (9) ASLEEP: eyes closed as two downward curves, tiny relaxed open mouth. (10) LOOK LEFT: the fair face with both eyes glancing to the left. (11) LOOK RIGHT: the fair face with both eyes glancing to the right. (12) SURPRISED: wide round eyes, a tiny round open mouth.
```

## 4. The egg hatching (3x2)

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

## 5. Gear: headband, cape, aura, flames (3x2)

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

## 6. Belly emblems (4x4, white on black)

```
I'm making art for a virtual pet that lives on a Garmin Forerunner 265 watch: a round 416x416 pixel AMOLED screen with a pure black background. The pet grows up as its owner exercises. On the watch each character is only about 120 pixels tall.

The pet is a small round sky-blue creature with a pale oval belly patch, and its owner picks an emblem that is shown on the belly, about 35 pixels wide on the watch. I need a sheet of those emblems, which I will cut apart and recolor by machine. The rules matter more than the art:
- Output a PNG. Background pure flat black (#000000) everywhere: no gradient, no glow, no grid lines, no borders, no frames.
- Every emblem is a solid silhouette in pure flat white (#FFFFFF), like a stencil or a rubber stamp: one shape, or a few chunky separate pieces where the emblem needs them (a paw print's toes, a sun's rays). No outline, no shading, no gradient, no grey, no color, no glow, no texture. The only detail allowed inside a shape is a few wide black gaps cut right through it.
- Bold and chunky, with rounded corners, to suit a cute mascot. Each must still read when it is shrunk to 35 pixels wide: no thin lines, no small parts, and every gap at least as wide as a tenth of the emblem.
- One emblem per cell, centered, all the same visual size: each fits inside a circle about 60% of the cell's width. Wide empty black space around it. Nothing may touch or cross into another cell or the image edge.
- No text, letters, numbers, labels, signatures or watermarks anywhere. The names in capitals below are only labels for me: never draw them.
- The same hand and the same weight across the whole sheet, as one matching icon set.

Make one square image, 2048x2048, laid out as a grid of 4 columns by 4 rows (16 cells). Left to right, top to bottom:
Row 1: (1) HEART: a plump heart. (2) STAR: a fat five-pointed star with rounded points. (3) LEAF: one simple leaf with a short stem and a single gap for its center vein. (4) SWIRL: a thick spiral of about one and a half turns.
Row 2: (5) PAW: a paw print: one large pad with three round toes above it. (6) APPLE: an apple with a short stem and one small leaf. (7) MOUNTAIN: two overlapping peaks, the taller one with a zigzag gap for its snow line. (8) WING: one feathered wing spread to the right, three or four thick feathers.
Row 3: (9) CROWN: a simple crown with three rounded points. (10) BOLT: a thick lightning bolt. (11) FLAME: a single plump flame with one gap for its inner flame. (12) DUMBBELL: a dumbbell lying flat, seen from the side: a short thick bar with one big rounded weight at each end.
Row 4: (13) SUN: a round disc with eight short thick rays around it, the rays separate from the disc. (14) MOON: a fat crescent moon. (15) FLOWER: five round petals around a round gap in the middle. (16) GEM: a cut gemstone seen from the front, with three or four wide gaps for its facets.
```

## Round 1 (2026-11-10): the lineup, both painters

- **ChatGPT** (PNG, 1086x1448, on black as asked): one species, every character seen from
  the front, each lane reading as the one above it grown older, flat color with no black
  outline. Usable as painted; the body sheets are written for this.
- **Gemini** (JPG, on white, black outlines): more character, and three different animals
  seen from the side (a whale then a deer in the sleek lane, a lion in the wild lane, a
  moss-cloaked giant for Summit). The front-facing pose list (flex, cheer) does not fit
  four-legged bodies; taking these means a new pose list. White with a black outline cuts
  as well as black does, so the background is not what rules it out.
- John (11-10): the style is fine, low detail is right for the watch; no pick yet. He does
  not want the pet moved by squash and stretch ("an old Flash video"): poses are drawn
  frames, and the face is an overlay.

## Round 2 (2026-11-10): body sheets 2.1 to 2.5

Nub, Sprig, Dash, Chonk and Scamp, sent as follow-ups in the lineup chats. ChatGPT's five
are filed here as `2026-11-10_body-<name>-b.png`, with its lineup as `2026-11-10_lineup-b.png`.

- **ChatGPT: all five usable.** Every cell is its own pose, on black, with the one plain
  face and the same animal throughout; the lineup's design held without a crop attached.
  Measured cell against cell (each cut to its ink, scaled to 64 px): the closest pairs are
  idle and breathe, which are meant to be close, and nothing is a copy. The same twelve
  poses come back for every animal, which is what one animation table needs.
- **Gemini: dropped for body sheets.** John stopped after three: it began repeating itself,
  and on the Chonk sheet it changed the face from cell to cell and gave three cells another
  character's single leaf and pointed ears.
- 2.6 (Gale) was run but is not among the saved files.
- The Scamp sheet's clean belly ovals are where the belly emblem idea came from.

## Round 3 (2026-11-10): the emblems, and the first bake

- **Emblems (prompt 6): ChatGPT's sheet is the pick**, filed as `2026-11-10_emblems-b.png`.
  All sixteen came back in order, chunky and solid. Gemini's sheet is as clean but thinner in
  places (the leaf's veins, the dumbbell's plates), which would fill in at 30 px.
- **`scripts/bake_friend_sprites.py` turns the sheets into what the watch loads.** For each
  body sheet: find the twelve cells, cut each out of the black (the dimming along an outline
  becomes alpha), swap the hue of the blue body for each of the six colorways, shrink to the
  home size and the card size, and pack one strip per character, colorway and size. For each
  pose it records where the feet are and where the middle of the belly patch is. Emblems are
  cut by brightness and baked per colorway at three levels. 60 strips and 16 emblem strips,
  1.5 MB of PNG in all. `--check` proves the committed files still match the sheets;
  `--contact DIR` writes review sheets.
- **What had to be tuned against the real sheets:**
  - The painters put a fine texture on the flat areas. Flattening a whole strip to 64 colors
    turned it into blotches; a 3 px median first and 128 colors keeps the body smooth.
  - A colorway darker than the sheet's blue (mint, sun) dulled the belly with the body. The
    belly now takes less of the darkening than the solid body does.
  - The pink cheeks disappear on a pink or orange body, so on rose and peach they are
    deepened. Where a cheek fades into the body the sheet is violet; those pixels are rebuilt
    as pink over the new body color.
  - The emblem is 30 px at home size. A pose gets one only where its belly patch can hold
    it: not the crouch, not the hatchling (no patch), and by rule not the back view or asleep.
- **What the watch does with it** (`FriendSprites.mc`, Friend 0.9.0, never compiled): loads
  one strip, copies one pose per frame with `setClip` + `drawBitmap`, then the emblem the same
  way. No tint, no scaling, no blending. The emblem's level follows warmth and pulses during
  effort; every emblem can be picked for now, and the earning rules above are not built.
- **Not done, waiting on sheets:** the face layer (each pose keeps the plain face it was
  painted with, so there is no blink, no mood face and no closed eyes asleep), the gear, the
  egg, and the six later grown forms (each lane shows its first grown form at every tier).
