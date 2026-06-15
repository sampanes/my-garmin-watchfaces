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

So the design target is **Level 2**: you tap "Push-ups" (or the pet asks "what are we
doing?"), and from then on the watch **counts reps automatically** off the
accelerometer. That directly fixes your complaint — the native Strength activity makes
you fight the UI; here the only input is picking the move.

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
