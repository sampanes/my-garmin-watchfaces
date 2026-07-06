# Track 1 add-on — Activity sensing: "the pet knows I'm lifting / doing push-ups"

Verbal-ideation capture (2026-06-15). Goal: our characters react to strength work
(weights, push-ups) **without** the clunky native Garmin "Strength" activity flow.
This feeds Track 1 (the pet eats your effort); it's a *capability*, not a 4th track.

## The honest "automatic vs told" spectrum

There are three levels, and only the middle one is both realistic and pleasant:

| Level | "Pet just knows, nothing running" | **"One-tap, then auto-count"** ⭐ | "Fully manual: I type reps" |
|-------|-----------------------------------|----------------------------------|------------------------------|
| Feasible? | ❌ Not really | ✅ Yes | ✅ Yes (but tedious) |
| Why | CIQ can't stream high-freq accel **in the background / all day** — battery + the 64 KB background heap kill it. Passive all-day movement classification isn't exposed to apps. | App is open in a "workout buddy" mode → reads 25 Hz accel → counts reps live. You only tell it *which* exercise (one tap); it counts the *reps* for you. | Watch text/number entry is miserable; defeats the point. |

So the design target is **Level 2**: one primary action starts a foreground buddy session
(or, if needed, a single full-screen card picks "Push-ups" / "Squats" / "Generic"), and
from then on the watch **counts reps automatically** off the accelerometer. That directly
fixes your complaint — the native Strength activity makes you fight the UI; here the only
input is a single coarse commitment. The control grammar lives in `08-watch-interaction-model.md`.

## The dream UX: "press GO, he figures it out" (and roasts you)

Spitball (2026-06-15) — the flow worth aiming for: you walk up to the pull-up bar, **press
your friend, he says "sup, let's go" and does NOT ask what you're doing.** Then he *watches
the signal and guesses out loud*, e.g.:
- "up-down... that's a **squat**. 12. keep moving."
- "**left-hand curl**... long pause... **right-hand curl?**... left again. make up your mind."
- "wrist barely moved but your **HR and breathing spiked** — good shit, bruh."

This is one notch more ambitious than Level 2: you don't even pick the move (still a
foreground "buddy" session — *not* the impossible fully-passive Level 1). The pet
**auto-classifies**. But §"Telling push-ups from curls" already warned auto-classification
is the finicky part — so here's the trick that makes it shippable instead of frustrating:

## ⭐ Confidence becomes character (the key insight)

The classifier *will* be uncertain a lot of the time. **Don't hide that behind an error or a
menu — let the pet's confidence drive its dialogue.** This converts a hard ML problem into the
product's whole personality:

| Classifier state | What he says |
|---|---|
| **High confidence** | "That's a squat. 12 reps. Don't you dare slow down." |
| **Low confidence** | "...the hell was that? A curl? Sure. I'll allow it." |
| **Motion unreadable, body working** | "Wrist barely moved but your heart's redlining — good shit, bruh." |

The asshole is *allowed* to guess wrong and cover with snark. **Misclassification stops being a
bug and becomes banter.** Fits the locked canned-vocabulary model perfectly — these are
pre-written lines keyed by `guess × confidence × performance`.

## What the wrist can actually see (feasibility, grounded)

Mapping the spitball's own examples to honest tiers (the watch is on **one** wrist):
- **Squat** — *medium.* Low cadence, big slow vertical component, stable wrist orientation. Guessable.
- **Curl on the WATCH arm** — *easy.* Forearm rotates through gravity → the gravity vector
  swings between axes (§ above already calls this "very recognizable").
- **Curl on the OTHER arm** — *~invisible.* Curling the off arm barely moves the watch. **That's
  exactly why "right-hand curl?" deserves a question mark — he genuinely can't see it well and is
  guessing from body sway + timing.** Your phrasing nailed the physics; make that uncertainty
  *diegetic* (he's confident on the watch arm, hedging on the other).
- **Tempo / pauses / rest** — *easy.* Gaps between rep peaks. Prime roast material ("you paused.
  tired already?").
- **Pull-ups** — *hard on motion alone* (hand gripped to bar, wrist semi-fixed, weak/ambiguous
  bob) — which is the whole reason for the next section.

## Multi-signal fusion — when motion fails, read the body

The pet fuses **accelerometer + heart rate (+ maybe respiration)** and **degrades gracefully**:
- **HR** — solid, real-time (`Sensor.getInfo().heartRate`) + `SensorHistory`. A pull-up set
  spikes HR even when the wrist signal is mush. **This is the dependable fallback.**
- **Respiration / breathing** — ⚠️ *verify CIQ exposes real-time respiration*; if not, infer
  "breathing went up" from HR. (Don't promise breathing data until confirmed.)
- Net: even an **unclassifiable** movement still reads as **effort** via physiology → the pet
  rewards it ("can't tell what that was, but you're gassed — it counts"). This fusion *is* the
  graceful-degradation engine behind "confidence becomes character," and it reinforces the
  locked principle: **reward effort, not precision.**

## Sensing is *earned*, not dumped — the capability ladder

These detections are the **functional "powers"** from `05-progression.md §"What power means"`
— the pet's sensing repertoire is a **track you climb**, not a feature you get all at once:

- Start knowing **squats** → earn **push-up** detection → earn **watch-arm curls** → earn the
  **HR "you're gassed" fallback** → earn **tempo/pause callouts** → earn **run/distance**.
- Each unlock is a discrete, felt capability ("oh — he can tell I'm doing curls now"). **The pet
  literally perceives more of your workout the longer you train**, which is the perfect marriage
  of theme and mechanic *and* solves a real design problem: don't hand a day-one player a
  classifier that claims to read everything (it'll be wrong and feel broken). Open it up as it
  earns trust.

This is the **functional** half of "power." The other half is **expressive powers / emotes** —
zero-consequence animations the pet earns (burst into flames, flex, faceplant); same
earn-with-effort economy, no game-state effect. They're the raw material for the visitor-greeting
routine (`02`). Full split + quadrant: `05`.

## Personality model (the actual soul)

- The "asshole friend" is **canned dialogue with attitude**, keyed by
  `(exercise-guess × confidence × performance × streak × time-of-day)`. Cheap, watch-native,
  on-brand with the locked canned-messaging model (`02`).
- **He doesn't care what you're about to do** — no tiny menu, no setup maze. Press → "sup,
  let's go" → he reacts to whatever happens. *The absence of a setup screen IS the personality.*
- Tone scales with the relationship/streak: more roast when you slack, grudging respect when
  you deliver. **The lines above are the *Drill Sergeant* voice specifically** — temperament is
  now a **permanent identity trait** (asshole vs cheerleader vs deadpan vs zen), so every persona
  reacts to these same sensing events in its own voice. Full system: **`07-personality.md`**.

## The mechanism (confirmed feasible)

- **Sensor:** `Sensor.registerSensorDataListener` streams the **accelerometer up to
  25 Hz** (10 Hz on older devices). Source: repo `beyond_faces/SENSORS_AND_GPS.md §3`
  + Garmin SDK docs. Precedent: people have built motion rep-counters on exactly this
  (e.g. a juggling-catch counter streaming Garmin accel to a phone).
- **Rep counting = peak detection.** A rep is one cycle of the acceleration-magnitude
  signal. Smooth it (low-pass), then count peaks above a threshold with a refractory
  gap so you don't double-count. Cadence (reps/sec) falls out for free.
- Pseudo (illustrative only — not real code yet):

```
mag = sqrt(ax^2 + ay^2 + az^2)         // per sample, ~25 Hz
mag = lowpass(mag)                      // kill jitter
if (mag crosses peakThreshold upward) and (now - lastRep > minRepGap):
    reps += 1; lastRep = now
```

## Telling push-ups from curls from squats

Counting *any* rhythmic rep is easy. **Classifying** the exercise is the hard part —
do it later, and lean on the wrist's orientation + motion signature:

- **Push-ups:** wrist roughly horizontal/planted, whole-body vertical bob ~0.5–1.5 Hz;
  gravity vector fairly stable on one axis.
- **Bicep curls:** forearm rotates through gravity → the gravity component swings
  between axes each rep (a very recognizable signature).
- **Squats:** lower cadence, smaller wrist accel, big slow vertical component.
- Start **exercise-agnostic** (count reps, user picked the type) → add a heuristic
  classifier only if you want the pet to *guess* the move. Auto-classification is
  where Garmin's own feature gets clunky; don't over-promise it.

## Why we can be *better* than native Strength here

Garmin's Strength activity does accel-based auto rep + auto rest detection — and it's
finicky (miscounts, makes you confirm weight). The pet doesn't need clinical accuracy:

- **Reward effort, not precision.** "~12 reps → pet gets a protein snack / flexes /
  levels up STR." Approximate counts are fine and forgiving feels good.
- **The pet provides the motivation Garmin's UI doesn't** — it's cheering, not logging.

## Relative effort & baselines — the buddy reads *change*, not just absolutes

The pet doesn't need to name the exercise to know you're working. It needs to know you're
doing **more than your own normal**. Three cheap, watch-native signals make that possible —
and none of them require classification. This is the most robust sensing the pet has.

### 1. The rolling HR baseline (free from the watch)

`SensorHistory.getHeartRateHistory()` is the watch's own internal database of roughly the
**last ~4 hours** of heart rate (`beyond_faces/SENSORS_AND_GPS.md §4`). Iterate it, average it,
and you have the wearer's recent resting baseline for **zero storage cost** — the watch already
keeps it.

So when the user taps **"starting a light workout"** and live HR (`Sensor.getInfo().heartRate`)
reads **89** while the trailing ~4-hour baseline sat at **69**, the buddy *knows* — with no
accelerometer, no rep-counting, no idea what the move even is — that **effort is up ~20 bpm over
this person's own recent normal.** The declared intent ("light workout") plus the HR delta vs
baseline is enough to react honestly:

| Signal | What he says |
|---|---|
| HR ~20 over 4h baseline | "Eighty-nine. Twenty over where you've been sitting. I see you." |
| Declared "light," HR says otherwise | "You said *light*. Your heart disagrees — that's twenty up. Good." |
| HR ≈ baseline | "Heart says you haven't started yet. Whenever you're ready." |

This is **relative-effort detection**, and it's the dependable floor under everything in
"Multi-signal fusion" above: it works for pull-ups, a brisk walk, yoga, or a move the classifier
can't read — anything that moves HR. It reinforces the locked principle: **reward effort, not
precision.** The accelerometer rep-counter is the *upgrade*; the HR-vs-baseline delta is the
thing that always works.

### 2. Lifetime baseline (one stored number)

For "calmer/harder than *usual*" (not just the last 4h), keep a running mean — an exponential
moving average nudged on each reading — in `Storage`. One float. Now the pet can compare today
against the wearer's whole history: *"calmest morning you've had in a while."*

### 3. "Past X" beyond ~4 hours (a handful of buckets)

`SensorHistory` only reaches back ~4h. For "past day / past week" baselines, persist your own
**roll-ups**: e.g. one HR average per hour (24 floats ≈ last day) or per day (7 floats ≈ last
week). "Baseline for the past week" = mean of those buckets. Tiny storage, simple math.

### 4. The step *timeline* — reconstruct *when*, not just *how many*

`ActivityMonitor.getInfo().steps` is a **daily cumulative counter** with **no per-step
timestamps** — but you manufacture the timing by **snapshot-and-diff**: persist `{timestamp,
steps}` and subtract consecutive readings.

- Open at 11:00 → steps = 4000, store it.
- Open at 13:00 → steps = 5000 → **1000 steps happened in the 11:00–13:00 window.**

Each sample is two numbers (a few bytes). Sampling every ~5 min all day (~288 samples) is a
couple KB — trivially under the 32 KB-per-value Storage cap. Do the sampling in a **background
temporal event** (`registerForTemporalEvent`, ≥5 min, 64 KB heap, ~30 s, **no phone needed** —
`ActivityMonitor` is local) and you get a **~5-minute-resolution step timeline without the user
ever opening the app.** That turns "8k steps, no idea when" into *"still all morning, then you
crushed it 1–3pm."* Two caveats: handle the **midnight reset** (a negative delta = new day, not
negative steps), and background firing is **best-effort ≥5 min**, not exact.

### Why this matters for the pet

Together these give the buddy a sense of **rhythm and change** — not "you have 8000 steps" but
"you were still all morning and then moved"; not "your HR is 89" but "your HR is 20 over your own
baseline." That's the difference between a step counter and a companion that *notices*. None of
it requires classifying the exercise, and all of it is cheap. Cross-ref: the declared-intent
entry point ("starting a light workout") is a Buddy-Mode launch action — control grammar in
`08-watch-interaction-model.md §Buddy Mode`.

## Caveats / constraints

- **Foreground only.** 25 Hz accel is CPU- and memory-heavy (the repo doc literally
  says "massive amount of CPU and memory"). Run it only during an open "workout buddy"
  session; process samples immediately, don't hoard them (watch the 768 KB device-app heap —
  same on FR265 and VA6 per `compiler.json`, SDK 9.1.0).
- **No all-day passive detection for strength moves.** If you want "I did push-ups earlier,
  pet noticed," the only honest source is Garmin's *own* recorded activity history after the
  fact — and CIQ won't hand you "you did push-ups" as a labeled event. Set expectations.
- **Walks/steps ARE passively accumulated.** `ActivityMonitor.getInfo()` reads the OS pedometer
  ledger — always running, guaranteed, regardless of which app is foreground. Call it on open
  and the daily step total is there. Caveat: daily aggregate only, **no per-step timestamps**
  (you know *how many* steps today, not *when* they happened). This is the after-the-fact
  walk/run path for the pet; it's free and reliable. ("Complications STEPS" is watch-face
  terminology for the same underlying data source — device apps call `ActivityMonitor` directly.)
- **Tuning per move + per device** (FR265 vs VA6 wrist accel differ). Calibrate.

## MVP for this capability

1. "Workout buddy" mode in the pet app: pick **Push-ups / Squats / Generic**.
2. Live **rep count** via 25 Hz accel + peak detection (exercise-agnostic counter).
3. Reps feed the pet (STR/happiness); pet animates/cheers per set.
4. Stretch: heuristic auto-classify curls vs push-ups; auto start/stop of a set.

Cross-ref: `beyond_faces/SENSORS_AND_GPS.md` (sensor access), `01-solo-game.md`
(how reps feed the pet), `common/memory/MEM_PART3_OPTIMIZATION_AND_TOOLS.md` (keeping
the 25 Hz processing within heap).
