# Track 1 — Solo game (the pet itself)

**Verdict: clearly doable, and a good fit for the platform.** This is the
foundation; build it fully standalone before any networking. The watch angle
(sensors) is what makes it more than a phone clone.

## App shape

- **Type:** Connect IQ **device app** (interactive, full input, foreground).
  - A *watch face* is the wrong type: ~1 update/sec (1/min in low power), tight
    memory, no rich input.
  - Optional companions: a **glance** ("pet is hungry 🍗") and/or a
    **complication** for at-a-glance mood without opening the app.
- **Min API level:** common floor is **API 5.2**; build with **SDK 8.1.1** and gate
  System-8 features with `has` (confirmed — see README + `SPEC_*` docs).

## Core loop

Needs decay over real time; the player tops them back up.

- **Stats:** hunger, happiness/affection, energy/sleep, hygiene, health.
- **Actions:** feed, play, clean, pet, put to sleep, medicine.
- **Progression:** life stages (egg → baby → child → adult) + **evolution branches**
  (the one "real fork"). Currency + simple inventory (food, toys, decor). The full
  scaling model — *how* the pet grows without becoming a paralyzing skill-tree or an
  ownerless treadmill — is its own doc: **`05-progression.md` (three-layer model)**.
  TL;DR for this loop: progression tracks are **additive** (you get everything
  eventually; order is the expression), daily choices are small/reversible, and a
  *few* permanent identity choices (name, species, evolution branch) carry ownership.
- **Failure states:** **LOCKED gentle** (sick/sad, never death/neglect-spiral) — per
  the cozy guardrails in `05-progression.md §Cozy guardrails`. Decay forgives missed
  days; effort always yields visible positive change. (For a glance-able wearable,
  punishing failure ages badly and kills the cozy loop.)

## The watch differentiator: feed the pet with *your* body

This is the reason to do it on Garmin specifically. Tie pet wellbeing to the
wearer's real activity. Available inputs (confirmed in `beyond_faces/SENSORS_AND_GPS.md`):

- **Steps** → food/energy. Use `ActivityMonitor.getInfo()`, or the **`Complications`
  STEPS** subscription (System 7+, battery-efficient — OS pushes updates).
- **Workouts / intensity minutes** → play & happiness (`ActivityMonitor`).
- **Sleep tracking** → pet sleeps when you do.
- **Heart rate** → mood: `Sensor.getInfo().heartRate` live, or `SensorHistory`
  (HR history ~last 4 h). Body Battery / stress where exposed.
- ⚠️ **Pressure/altitude is FR265-only** (VA6 has no barometer) — gate with `has`.

This turns "don't neglect the pet" into "don't neglect yourself," which is sticky.

## Live (mat reps) vs after-the-fact (walks/runs) — the foreground rule

A real constraint that shapes *which* activities the pet experiences live: **only one app
is foreground at a time.** When you start Garmin's **native** Run/Walk (for the GPS map),
the pet app isn't running — so there's **no live ride-along during a native-tracked cardio
session**, and no live IPC between the native activity and the pet.

- **Mat reps (lifting, push-ups, etc.) → LIVE.** They run *inside* the pet's own "workout
  buddy" foreground session (25 Hz accel, `04`), so the pet senses + roasts in real time.
  This is the live experience.
- **Walks / runs → AFTER THE FACT.** The pet reads the day's **aggregates** on next open
  (or a ≥5-min background poll): steps / distance / active-minutes via the `Complications`
  STEPS subscription (battery-cheap, OS-pushed) + `ActivityMonitor`. So *"you ran today —
  good shit"* works **retroactively**. No route, no live presence, but the cardio still
  feeds the pet.
- **Stretch — "Run with [pet]" mode (later):** to have the pet actually *present* during a
  run (live pace + a saved GPS map), the pet must **be the recorder** — its own
  `ActivityRecording` session with `Position`/GPS, which saves a real activity to Garmin
  Connect and hands the pet live `Activity.Info`. Cost: it **replaces** the native Run UI
  and burns GPS battery (`SENSORS_AND_GPS.md`: GPS drains an FR265 in hours) — you can't
  foreground both. Deliberately a **separate mode**, and it slots into the `05` power ladder
  as an *earned functional power*, not a rework.

**Default (MVP): mat = live, cardio = after-the-fact.** The "run with pet" GPS mode is a
clean later add, not day-one.

## Time model — compute decay from timestamps, do NOT tick

The single most important design decision for battery + correctness:

> Store a `lastUpdate` timestamp per stat. On app open (or glance refresh),
> compute the *current* value from elapsed real time. Never rely on a constant
> timer or frequent background runs to "drain" stats.

Pseudo:

```
// on open / refresh
elapsed = now - state.lastUpdate
hunger  = clamp(state.hunger - HUNGER_RATE * elapsed, 0, MAX)
// ...other stats...
state.lastUpdate = now
```

A background task (confirmed limits: ≥5 min interval, ~30 s run, **32 KB heap**) is
then only needed for *proactive* nudges (glance update, "you have mail"), not for the
simulation itself — which is good, because 32 KB can't hold the game anyway.

## Save state

Use `Application.Storage` (key→value, JSON-able dicts). Keep it small (per-device
storage caps — verify). Shape sketch:

```
{
  "species": 3, "stage": "child",
  "stats": { "hunger": 72, "happy": 60, "energy": 88, "hygiene": 40, "health": 95 },
  "ts": { "fed": <epoch>, "played": <epoch>, "update": <epoch> },
  "inv": { "food": 5, "toy": 2, "currency": 130 },
  "born": <epoch>, "careScore": 0.81
}
```

`Properties` for user prefs (notifications on/off, difficulty, sound/vibe).

## Rendering & input

- **Sprites:** frame bitmaps in resources; animate by swapping frames on a `Timer`.
  **Bitmaps eat app memory** — limited palette, reuse frames, lazy-load. **Design to
  the VA6 device-app heap of 256–512 KB**, not FR265's 1 MB (VA6 is the tighter
  target). ⚠️ *These heap figures are disputed — community `compiler.json` reads say
  768 KB uniform; verify against local SDK. See README + `open-questions.md §B2`.*
  See `common/memory/MEM_PART1..3` and `common/graphics/DC_PART3_RESOURCES_AND_PERFORMANCE.md`.
- **Three resolutions:** FR265 416×416, FR265S 360×360, VA6 390×390 → relative/scaled
  layouts + per-device resource sets. Strategy: `common/workflow/MULTI_DEVICE_STRATEGY.md`.
- **Two input profiles:** touch-first (tap zones for actions); VA6 has only **2 buttons
  + an Action Notch**, so never require 5. Button mappings are fallback, not primary.
- **Power / AMOLED:** foreground animation drains AMOLED; keep sessions short, throttle
  redraws, idle when no interaction. Burn-in guidance: `common/architecture/AMOLED_BURN_IN.md`,
  `APP_LIFECYCLE_AND_POWER.md`.

## MVP scope (Track 1 only)

1. One species, 3 stages, 4 stats with timestamp decay.
2. Feed / play / clean / sleep actions + save/restore via Storage.
3. Steps→food hook (the one sensor tie-in that proves the concept).
4. Runs on FR265 **and** VA6 in the simulator at both resolutions.

Ship/enjoy this before touching Tracks 2–3.
