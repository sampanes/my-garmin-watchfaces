# Pet state and effort economy — a testable proposal

Status: **PROPOSAL (2026-10-22).** Every number in this doc is **PROPOSED** and remains a project decision. It
front-loads the progression numbers that `05-progression.md` left as a kicked can
(`05-progression.md:234-236`, `05-progression.md:292-301`, `open-questions.md:154-158`) so they can
be argued with concrete values instead of in the abstract.

What exists today: Friend (`probes/wrist-diary/`) only senses. It groups HR-vs-baseline and wrist
motion evidence into neutral effort chapters and keeps memory marks that never decay
(`probes/wrist-diary/README.md:22-28`). It has no pet state, XP, stages or momentum. This doc defines
the layer that would sit on top of Friend's chapter rows.

The numbers are pinned down by three host-side scripts (PowerShell, no SDK needed):

| Script | Purpose |
|---|---|
| `scripts/pet-model.ps1` | Pure functions: `Get-PetMood`, `Invoke-PetOpen`, `Get-ChapterCredit`, `Invoke-PetChapter`, `Get-Momentum`, `Update-Momentum`, `Get-Stage`. All constants live in one `$PetConfig` table that mirrors this doc. |
| `scripts/test-pet-model.ps1` | Property tests of the cozy guardrails. Prints one `[pass]` line. |
| `scripts/pet-pacing-sim.ps1` | 120-day pacing sim for three synthetic users (output in §7). |

If a number here changes, change `$PetConfig`, rerun both scripts, and paste the new sim table.

---

## 1. The stats question: 4 or 5? Proposed answer: neither, as stored bars

`01-solo-game.md` disagrees with itself and with later docs:

- `01-solo-game.md:25` lists **five** stats (hunger, happiness, energy, hygiene, health), and the
  save sketch at `01-solo-game.md:205` stores five.
- `01-solo-game.md:243` scopes the MVP to **four** stats with timestamp decay.
- `01-solo-game.md:20` says needs decay over real time, but `08-watch-interaction-model.md:42-43`
  says skipped days never "decay stats", and `04-activity-sensing.md:233` says no "stats decay"
  when the wearer skips a check-in.

**PROPOSED:** store **zero** decaying need bars. Show **three derived readouts**, each computed on
open from timestamps and the clock (`01-solo-game.md:99-115`, `08-watch-interaction-model.md:306`):

| Readout | Derived from | Range / labels | Replaces |
|---|---|---|---|
| **Mood** (weather) | stored mood + time since last settle + warmth (§3) | 35-100; misty / fair / sunny / radiant | happiness |
| **Fullness** (effort snack) | today's effort minutes in the day ledger (§4) | peckish (0) / snacked (<30 effort min) / full (30+); resets to peckish at day start, never "starving" | hunger |
| **Energy** | local clock only (drowsy at night, `01-solo-game.md:132-133`) | awake / winding down / asleep | energy/sleep |

Reasons:

1. **Hygiene is a pure chore.** No body signal feeds it, so it can only be a to-do item, which
   `08-watch-interaction-model.md:258` lists under "what to avoid". Clean stays as an optional care
   action (§3.4), not a bar.
2. **Health implies sickness, and sickness from absence is a neglect penalty.** The locked failure
   rule allows "sick/sad" only as gentle flavor (`01-solo-game.md:34-37`,
   `open-questions.md:147-148`); "sad" is already covered by mood weather. A health bar that drops
   when you skip days is the neglect spiral `05-progression.md:189-190` forbids.
3. **Decaying bars contradict the later, more specific rule.** `04-activity-sensing.md:233` and
   `08-watch-interaction-model.md:42-43` are newer and explicit: skipped days do not decay stats.
   Derived readouts satisfy both "the pet reacts to real time" and "nothing decays as punishment".
4. **Three readouts fit one card.** One full-screen pet status card (`08-watch-interaction-model.md:187-196`)
   carries three words more legibly than four or five bars on a round screen.

If the project keeps 4 for the MVP, the least harmful 4 are these three plus a care-flavor
"cozy" readout fed only by optional care actions, never by time.

---

## 2. Save-state blob (v1)

One `Application.Storage` value under the key `pet`, separate from Friend's existing keys. Identity
and appearance fields are taken unchanged from `09-appearance-and-transfer.md:28-60`; the schema
version field follows `09-appearance-and-transfer.md:59`.

| Key | Type | PROPOSED meaning | Est. bytes |
|---|---|---|---|
| `v` | int | Schema version, `1`. | 4 |
| `id` | dict | Layer A identity: name (12 chars max), species, persona, basePal, evo (append-only), per `09-appearance-and-transfer.md:33-40`. | ~60 |
| `owned`, `look`, `greet` | dict / array | Layer B bitsets and Layer C arrangement, per `09-appearance-and-transfer.md:42-56`. | ~60 |
| `born` | epoch | Birth time; drives the evolution age gate and birthdays. | 4 |
| `tz` | int | Last seen UTC offset in seconds (for the local day). | 4 |
| `mood` | int 35-100 | Mood as of `tsSettle`. | 4 |
| `tsSettle` | epoch | When `mood` was last settled. | 4 |
| `tsOpen` | epoch | Last open; the reunion test reads this. | 4 |
| `xp` | int | Lifetime effort credit. Only ever increases. | 4 |
| `evos` | int | Evolutions confirmed (equals `id.evo` length). | 4 |
| `tsEvo` | epoch | Time of the last confirmed evolution. | 4 |
| `warm` | int 20-100 | Warmth as of `lastActiveDay` (current value is derived, §5). | 4 |
| `shields` | int 0-2 | Shields as of `lastActiveDay`. | 4 |
| `lastActiveDay` | int | Local day index of the last credited chapter, `-1` for none. | 4 |
| `activeDays` | int | Lifetime count of active days (drives shield earning). | 4 |
| `dayIdx`, `dayMin`, `dayBonus` | int, float, bool | Today's ledger: day index, effort minutes so far, daily-first bonus paid. | 12 |
| `reunionOwed` | bool | A reunion happened and its catch-up bonus has not been paid. | 1 |
| `careDay`, `careMask` | int, int | Which optional care actions already gave today's mood bump (§3.4). Not in the host model. | 8 |
| `lastChEnd` | epoch | Watermark: newest chapter `end_epoch` already credited. Makes crediting idempotent. | 4 |
| `chTotal` | int | Lifetime chapters credited (birthday and anniversary lines). | 4 |

Total payload is roughly 200 bytes of values. **Unverified:** the serialized size Garmin's Storage
layer actually writes for a dictionary of this shape; measure it on hardware once. Either way it is
far under the 32 KB per-value cap (`README.md:126`).

Rules:

- **Versioning:** every reader checks `v`. A missing field takes its `New-PetState` default. A `v`
  newer than the app knows is kept untouched and never overwritten (so an older build cannot destroy
  a newer save).
- **What is not stored:** weather label, fullness, energy, current warmth, stage and band. All are
  derived on open, so there is nothing that can drift out of sync or tick.
- **Crediting:** on open and when a chapter closes, every Friend chapter row with
  `end_epoch > lastChEnd` is credited once, oldest first (§4). Friend's own chapter log stays the
  evidence; the pet blob only keeps the watermark.

---

## 3. Mood as weather

Mood changes expression and dialogue; it is not a punishment bar
(`08-watch-interaction-model.md:248`). It is settled from timestamps on open, never ticked
(`01-solo-game.md:99-115`), so a background task is never needed for it
(`01-solo-game.md:117-120`).

### 3.1 The settle function (PROPOSED numbers)

```
elapsed   = max(0, now - tsSettle)            # a backward clock is treated as no time
effective = min(elapsed, 48 h)                # PAUSE: time past 48 h away does not count
target    = 40 + warm / 5                     # resting point 40..60, from momentum (§5)
mood      = target + (mood - target) * 0.5 ^ (effective / 24 h)
mood      = clamp(mood, 35, 100)              # FLOOR 35
if now - tsOpen >= 48 h:                      # REUNION
    mood = max(mood, 70); reunionOwed = true
```

| Constant | PROPOSED | Why |
|---|---|---|
| Floor | **35** ("misty": calm, a little sleepy) | `05-progression.md:189-190`: no fail state, decay never a loss spiral. Nothing below 35 exists. |
| Resting target | **40-60** (40 + warm/5) | Mood drifts toward a calm middle, not toward zero. It cannot even reach the floor through drift; the floor is a hard clamp for corrupt or migrated saves. |
| Half-life toward target | **24 h** | Gentle: yesterday's good session still shows today. |
| Pause | **after 48 h away** | `05-progression.md:300` asks "does it pause when away?" Yes: after 2 days the pet naps, so 3 days away and 90 days away look the same. |
| Reunion | **gap of 48 h or more lifts mood to at least 70 (sunny)** | `01-solo-game.md:140-142` and `05-progression.md:225-227`: a warm reunion, never a guilt clock. |
| Effort bump | **+15 per credited chapter**, cap 100 | `05-progression.md:190`: effort always yields visible positive change. |
| Care bump | **+5 per care action, once per action per day** | Care feels best after effort, not as a chore (`08-watch-interaction-model.md:249`). Optional; skipping it costs nothing. |

Weather labels: 35-49 misty, 50-69 fair, 70-84 sunny, 85-100 radiant. None of them is a negative
state.

### 3.2 No death, no neglect spiral

There is no state that ends the pet, and no number that falls because time passed except mood
drifting toward a calm middle. A 90-day absence leaves XP, stage and evolutions untouched; mood
rests at its paused value, then the reunion lifts it to sunny. Tested in
`scripts/test-pet-model.ps1` ("no death at 90 days", "warm reunion", "48 h pause").

### 3.3 Reunion payoff

A reunion sets `reunionOwed`. The first chapter afterward that earns the daily-first bonus gets an
extra **+10** (§4). This is the "small catch-up payoff" of `05-progression.md:225-226`, paid for
coming back *and moving*, so absence alone is never what earns it. Persona lines for the gap are
flavor only (`07-personality.md:73`, `05-progression.md:226-227`).

### 3.4 Care actions

Feed / play / rest / clean (`08-watch-interaction-model.md:198-205`) stay as optional, expressive
actions with a small mood bump. They are never required, never decay, and never gate credit.

---

## 4. Chapter to effort credit (XP)

Credit is earned from Friend's chapter rows. Generic effort is the paying unit; naming or counting
the move is never required (`README.md:29-31`, `08-watch-interaction-model.md:261-262`,
`04-activity-sensing.md:176-181`).

### 4.1 Effort minutes

```
level = 1.5   if hr_avg - baseline_hr >= 20      # "hard"   (3 flames)
        1.25  if hr_avg - baseline_hr >= 10      # "steady" (2 flames)
        1.0   otherwise, or if HR is missing     # "easy"   (1 flame)
effort_minutes = duration_s / 60 * level
```

- The level is **shown** on the reward card as flames (`08-watch-interaction-model.md:174-183`), so
  it is a visible description of the session, not a hidden multiplier. It measures this session's
  effort against the wearer's own baseline (`04-activity-sensing.md:155-158`); nothing the wearer
  owns or unlocks changes it (`05-progression.md:118-123`).
- `reason` (motion / HR / both) does not change credit: an HR-only chapter earns exactly what a
  motion chapter earns at the same HR (reward effort, not precision, `04-activity-sensing.md:178-179`).
- A Back-ended (`partial`) chapter earns the same as a complete one.
- Missing HR (`-1`, `probes/wrist-diary/README.md:61`) gives level 1.0, never zero.

### 4.2 Daily-first taper (never zero)

Effort minutes accumulate per local day (the day runs **03:00 to 03:00**, so a late-night session
counts for the evening it started in). Points are the integral of a stepped rate over the day's
running total:

| Day's effort minutes | Rate (points per effort minute) |
|---|---|
| 0-30 | **1.0** |
| 30-60 | **0.5** |
| 60 and up | **0.25** (floor; never reaches zero) |

Plus a **daily-first bonus of +10**, paid on the first chapter of the day that has at least **5
effort minutes** (so a 20-second wave cannot claim it). Every chapter earns at least **1** point.

This is the visible, cadence-based "daily counts for more" of `05-progression.md:218-221`. Because
the taper reads the day's running total, not the chapter count, splitting one workout into several
chapters (a long rest closes a chapter) earns the same as one chapter (tested: "split-invariant
credit").

Example, 40-minute chapters at level 1.25 (50 effort minutes each):

| | Chapter 1 | Chapter 2 | Chapter 3 | Per chapter |
|---|---|---|---|---|
| Same day | 50 | 15 | 13 | 26 |
| Three different days | 50 | 50 | 50 | 50 |

### 4.3 Scale

A daily 25-minute session at level 1.25 earns about 41 XP; the sim's daily user averages 41 XP per
day. Stage thresholds (§6) are sized from that.

---

## 5. Momentum (warmth) and shields — expression, not a multiplier

Momentum is a visible state that never multiplies effort (`05-progression.md:208-210`,
`05-progression.md:214-217`). `Get-ChapterCredit` takes no momentum input at all, and a test
asserts that warmth 20 and warmth 100 earn identical credit.

| Rule | PROPOSED | Doc it honors |
|---|---|---|
| Warmth range | **20-100**; 20-39 "rusty but fine", 40-69 "loose", 70-89 "warmed up", 90-100 "in the zone" | Floor, never a guilt bar (`05-progression.md:214-217`) |
| Start | **20** | |
| Gain | **+15** on the first credited chapter of a day; **+25** if 3 or more days were missed (comeback) | Comeback warmth (`05-progression.md:225-226`) |
| Grace | **the first missed day after an active day is free**, always, for everyone | One miss never shatters momentum (`05-progression.md:222-223`) |
| Shields | earn **1 per 5 active days**, hold at most **2**; each covers one further missed day | Earned shield (`05-progression.md:223-224`) |
| Drift | **-8 per uncovered missed day**, down to the floor of 20 | Gentle decay to a floor |
| Effect | posture, emote frequency, banter sharpness, and the mood resting target (40 + warm/5) | Expression + pacing, not a % (`05-progression.md:216-217`) |

Pacing still rewards consistency, but through the visible daily-first bonus (§4.2), not through
warmth. Warmth and shields are stored as of the last active day and the current values are derived
from the count of missed days, so reading them never changes state.

---

## 6. Growth stages and gates (infinite height)

Lifetime XP maps to bands. Bands **1-9** follow `60n² + 40n`; after band 9 each band costs a flat
**1100** more, forever (infinite height, `05-progression.md:155-156`). Every **3rd band** is an
evolution: the one real fork (`05-progression.md:148-149`), behind gates.

| Band | Name (placeholder) | XP | Life stage | Unlock (re-based ladder, §8) |
|---|---|---|---|---|
| 0 | Hatchling | 0 | baby | The floor: generic effort chapters, HR "you're gassed" lines, memory marks, step snack on open |
| 1 | Sprout | 100 | child | Emote: flex (expressive) |
| 2 | Trainee | 320 | child | Names squats (functional) |
| 3* | Athlete | 660 | adult | **Evolution 1** (branch pick, signature power per `05-progression.md:295-299`) + names push-ups |
| 4 | Veteran | 1120 | adult | Rep counts for named moves, confidence-gated |
| 5 | Ace | 1700 | adult | Tempo / pause callouts (`04-activity-sensing.md:62-63`) |
| 6* | Legend | 2400 | adult | **Evolution 2** + names watch-arm curls |
| 7 | Hero | 3220 | adult | Set boundaries |
| 8 | Mythic | 4160 | adult | Richer run / walk recaps from daily aggregates |
| 9* | Mythic 2 | 5220 | adult | **Evolution 3** |
| n > 9 | Mythic n-7 | 5220 + 1100 (n - 9) | adult | One roster item per band from `10-power-roster.md`, alternating functional and expressive; evolution every 3rd band |

Gates on an evolution band (PROPOSED):

- **Age:** the first evolution needs the pet to be at least **7 days** old; each later one needs **30
  days** since the previous evolution. Calendar days, not active days, so a gap never delays it.
  This keeps Layer A choices spaced so only one faces you at a time (`05-progression.md:64-65`) and
  stops a binge week from rushing an identity choice.
- **Deliberate confirm:** the evolution waits as "ready" until the wearer confirms it in the sit-down
  flow (`05-progression.md:265-266`, `08-watch-interaction-model.md:44-45`). It never expires (no
  FOMO, `05-progression.md:191-192`). XP keeps banking while it waits, and confirming opens every
  band the banked XP already covers.
- **Never a loss:** the displayed band never drops as XP rises (tested), and XP never decreases.

Week 1 (`05-progression.md:178-179`, loud positive feedback): the sim's users reach Sprout on day 3
(daily, 3x/week) or day 7 (weekend).

---

## 7. Pacing sim (120 days)

`scripts/pet-pacing-sim.ps1`, deterministic. Users: **Daily** (one chapter a day, 20-30 min, 18:00),
**3x/week** (Mon/Wed/Fri, 45 min), **Weekend** (Sat + Sun, 3 chapters of 35-45 min). HR delta over
baseline is drawn from 8-24 bpm for all three, so the comparison is cadence only. Each session is
an open followed by one chapter; the sim confirms a ready evolution at the next open.

```
| Band | Name      | XP needed | Daily     | 3x/week   | Weekend   |
|------|-----------|-----------|-----------|-----------|-----------|
|    1 | Sprout    |       100 | day 3     | day 3     | day 7     |
|    2 | Trainee   |       320 | day 9     | day 12    | day 14    |
|    3 | Athlete*  |       660 | day 17    | day 24    | day 28    |
|    4 | Veteran   |      1120 | day 28    | day 40    | day 49    |
|    5 | Ace       |      1700 | day 43    | day 61    | day 76    |
|    6 | Legend*   |      2400 | day 59    | day 87    | day 104   |
|    7 | Hero      |      3220 | day 78    | day 117   | -         |
|    8 | Mythic    |      4160 | day 101   | -         | -         |
|    9 | Mythic 2* |      5220 | -         | -         | -         |

| After 120 days | XP | Chapters | Active min | XP per active min | Stage |
|----------------|----|----------|------------|-------------------|-------|
| Daily | 4946 | 120 | 3018 | 1.64 | 8 Mythic |
| 3x/week | 3295 | 52 | 2340 | 1.41 | 7 Hero |
| Weekend | 2890 | 102 | 4106 | 0.70 | 6 Legend |
```

Weekly mood at a noon look (avg/min), warmth and shields at week end:

```
| Week | Daily mood warm sh     | 3x/week mood warm sh   | Weekend mood warm sh   |
|------|------------------------|------------------------|------------------------|
|    1 |  67/58   100  1        |  63/54    65  0        |  71/51    50  0        |
|    2 |  78/77   100  2        |  70/64   100  1        |  76/65    60  0        |
|    3 |  78/78   100  2        |  71/68   100  0        |  76/66    68  1        |
|    4 |  78/78   100  2        |  71/68   100  1        |  76/67    84  0        |
|    5 |  78/78   100  2        |  71/68   100  1        |  77/70    92  1        |
|    6 |  78/78   100  2        |  71/68   100  0        |  78/70   100  0        |
|  ... (weeks 7-17 repeat week 6 within 1 point; shields cycle 0/1 for 3x/week and Weekend)
|  18* |  78/78   100  2        |  70/70   100  0        |  84/84   100  0        |
```

What the sim says:

- **Everyone reaches the first evolution inside a month** (day 17 / 24 / 28) and keeps growing; no
  pattern stalls.
- **Mood never dips below 51** for any user in 120 days; the floor of 35 is never touched in normal
  play. The weekend user sees a reunion every Saturday and the 3x/week user every Monday, which
  reads as sunny returns, not lapses.
- **The taper is strong.** The weekend user trains the most minutes (4106) but earns the least per
  minute (0.70 vs 1.64). That is `05-progression.md:220-221` working as written ("daily beats
  binge"), but the project still needs to decide whether the 0.25 floor rate is too steep (§9).
- **Warmth saturates.** All three patterns reach "in the zone" (100) within six weeks, because
  gains outrun the gentle drift. That is gain-framed, but it means warmth stops distinguishing
  patterns. Tune in the sandbox if it should.

---

## 8. Reconciliation: generic effort is the floor, so the earned ladder is naming, reps and tempo

The docs disagree about whether generic effort is earned:

- **Gated:** `playgrounds/pet-sandbox/progression.js:29` unlocks "Senses generic effort" as a power at
  280 XP; `04-activity-sensing.md:79-80` frames sensing as functional powers you climb, and
  `04-activity-sensing.md:85` makes the HR "you're gassed" fallback an earned rung.
- **Required floor, ungated:** `README.md:29-31` ("generic effort is the required result"),
  `08-watch-interaction-model.md:261-262` ("Generic effort recognition is the required floor"),
  `01-solo-game.md:91-92`, `04-activity-sensing.md:14` and `04-activity-sensing.md:176-181` ("the
  dependable floor under everything", "the thing that always works"). Friend ships it with no gate:
  HR-only chapters (`reason` 2) are credited on day one (`probes/wrist-diary/README.md:22-25`).

**PROPOSED:** generic effort (motion, HR, or both) and its HR "you're gassed" dialogue are the
day-one floor, forever ungated. The earned functional ladder is re-based onto what genuinely
improves with trust: **naming** (squats, then push-ups, then watch-arm curls), **rep counts**,
**tempo / pause callouts**, **set boundaries**, and **run / walk recaps** (§6 table). This keeps
`04-activity-sensing.md:86-90`'s point (do not hand a day-one player a classifier that claims to read
everything) while honoring the floor. `04-activity-sensing.md:85` would then read "start knowing
effort, earn squats, ...".

Caveat: each naming or counting unlock can ship only once its classifier works on real wrists.
None is validated yet (**unverified, needs hardware**). If a band's sensing unlock is not ready, the
band delivers an expressive unlock and the sensing unlock moves later; no band is ever empty.

**`progression.js` was left unchanged.** Aligning it is not a constant swap: its thresholds
(0 / 120 / 280 / 380 / 500 / 700 / 900, `progression.js:27-33`) assume `XP_MAX = 1000`
(`progression.js:22`), the slider max is hard-coded to 1000 in `playgrounds/pet-sandbox/index.html:65`,
and the 280 XP label is the generic-effort gate this section removes. A sandbox update needs new
thresholds, a new `XP_MAX` (about 5000 to show bands 0-8), the slider max, and relabeled unlocks.

---

## 9. Decisions still open

| # | Decision | Proposed default | Alternative |
|---|---|---|---|
| 1 | Stats: 4 or 5 bars? | Neither: 0 stored bars, 3 derived readouts (§1) | 4 for the MVP: the 3 readouts + a care-only "cozy" readout |
| 2 | Generic effort gated? | Ungated floor; ladder = naming / reps / tempo (§8) | Keep `04`'s squats-first order and the `progression.js` gate (conflicts with README and 08) |
| 3 | Shields: a power or built in? | Grace day built in for everyone; shields earned by active days, not by an XP band | `05-progression.md:128` and `progression.js:33` treat streak shields as a functional power unlocked at a band (900 XP in the sandbox) |
| 4 | Taper strength | 1.0 / 0.5 / 0.25 at 30 / 60 effort min | A gentler floor (0.4) so weekend users are not at 0.70 XP per minute |
| 5 | Effort level flames | 1.0 / 1.25 / 1.5 by HR delta, shown on the card | Pure minutes, no level (simplest; loses "that was hard" recognition) |
| 6 | Pause and reunion threshold | 48 h for both | 72 h, so a normal weekend off is not a "reunion" |
| 7 | Evolution spacing | every 3rd band; 7-day / 30-day age gates | every 4th band (fewer Layer A choices) |
| 8 | Warmth saturation | everyone reaches 100 in about 6 weeks | lower gain (+10) so warmth tracks recency more |

## 10. Unverified (needs hardware)

- Serialized byte size of the `pet` Storage dictionary (§2).
- How the watch reports the UTC offset after travel, and whether the epoch clock can step backward
  after a sync. The model treats a backward clock as zero elapsed time and never moves timestamps
  back.
- Every naming / counting classifier in the §6 ladder.
- Whether `baseline_hr` is available often enough for the effort level to matter; when it is
  missing the chapter earns level 1.0.

## Cross-refs

- `05-progression.md` — the principles these numbers implement (§Momentum, §Cozy guardrails, still-open list)
- `08-watch-interaction-model.md` — mood as weather, the reward card, care actions
- `09-appearance-and-transfer.md` — identity and appearance blob reused in §2
- `probes/wrist-diary/README.md` — the chapter rows this economy consumes
- `scripts/pet-model.ps1`, `scripts/test-pet-model.ps1`, `scripts/pet-pacing-sim.ps1`
