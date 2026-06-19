# Track 1 add-on — Activity sensing: "the pet knows I'm lifting / doing push-ups"

Verbal-ideation capture (2026-06-15). Goal: our characters react to strength work
(weights, push-ups) **without** the clunky native Garmin "Strength" activity flow.
This feeds Track 1 (the pet eats your effort); it's a *capability*, not a 4th track.

## The honest "automatic vs told" spectrum

There are three levels, and only the middle one is both realistic and pleasant:

| Level | "Pet just knows, nothing running" | **"One-tap, then auto-count"** ⭐ | "Fully manual: I type reps" |
|-------|-----------------------------------|----------------------------------|------------------------------|
| Feasible? | ❌ Not really | ✅ Yes | ✅ Yes (but tedious) |
| Why | CIQ can't stream high-freq accel **in the background / all day** — battery + the 32 KB background heap kill it. Passive all-day movement classification isn't exposed to apps. | App is open in a "workout buddy" mode → reads 25 Hz accel → counts reps live. You only tell it *which* exercise (one tap); it counts the *reps* for you. | Watch text/number entry is miserable; defeats the point. |

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

## Caveats / constraints

- **Foreground only.** 25 Hz accel is CPU- and memory-heavy (the repo doc literally
  says "massive amount of CPU and memory"). Run it only during an open "workout buddy"
  session; process samples immediately, don't hoard them (watch the VA6 256–512 KB heap).
- **No all-day passive detection.** If you want "I did push-ups earlier, pet noticed,"
  the only honest source is Garmin's *own* recorded activity history after the
  fact — and CIQ won't hand you "you did push-ups" as a labeled event. Set expectations.
- **Tuning per move + per device** (FR265 vs VA6 wrist accel differ). Calibrate.

## MVP for this capability

1. "Workout buddy" mode in the pet app: pick **Push-ups / Squats / Generic**.
2. Live **rep count** via 25 Hz accel + peak detection (exercise-agnostic counter).
3. Reps feed the pet (STR/happiness); pet animates/cheers per set.
4. Stretch: heuristic auto-classify curls vs push-ups; auto start/stop of a set.

Cross-ref: `beyond_faces/SENSORS_AND_GPS.md` (sensor access), `01-solo-game.md`
(how reps feed the pet), `common/memory/MEM_PART3_OPTIMIZATION_AND_TOOLS.md` (keeping
the 25 Hz processing within heap).
