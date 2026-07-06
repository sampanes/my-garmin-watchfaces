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
- **Min API level:** FR265 min CIQ **5.2.0**, VA6 min CIQ **6.0.0** — gate
  System-8-only features with `has`; build with **SDK 9.1.0** (reconciled — see
  README §"SDK / API target"; the earlier "common floor 5.2 / SDK 8.1.1" is superseded).

## Core loop

Needs decay over real time; the player tops them back up. The care loop exists, but it
must not become a tiny-button chore board. On-watch interaction follows
`08-watch-interaction-model.md`: one primary action, full-screen cards, and behavior
events before raw touch.

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
- **Stretch — "Walk/Run with [pet]" mode (an *unlock*, later):** to have the pet actually
  *present* during a walk/run (live pace + a saved GPS map), the pet must **be the recorder** —
  its own `ActivityRecording` session with `Position`/GPS, which hands the pet live
  `Activity.Info`. Cost: it **replaces** the native Run UI and burns GPS battery
  (`SENSORS_AND_GPS.md`: GPS drains an FR265 in hours) — you can't foreground both. Deliberately
  a **separate mode**, framed as an **earned functional power** in the `05` power ladder, not a
  rework.
  - ⭐ **The payoff (2026-06-22): the recorded walk lands in Garmin Connect with a full map —
    indistinguishable from a native activity — with NO backend and NO partner API.** This is the
    clean inversion of the "we can't ride Garmin's pipeline" limitation (§above, `09`/`06`): we
    can't *read* native activities, but because the pet wrote the **FIT** itself, Garmin's
    **ordinary first-party BLE sync** uploads it and renders the map for free. The "data ready to
    view" + map experience the native walking app gives you is suddenly *ours* — earned, pet-
    branded, and it even shows up in your Connect activity feed. The Garmin **Health/Activity
    partner API is explicitly NOT used** (rejected — too heavy / approval-gated); this gets the
    same result purely on-device.

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

A background task (confirmed limits: ≥5 min interval, ~30 s run, **64 KB heap** —
README §Memory budget) is then only needed for *proactive* nudges (glance update,
"you have mail"), not for the simulation itself — which is good, because 64 KB can't
hold the game anyway.

## The watch knows the real day — lean on it (the ACNH "alive" feeling)

**John's idea (via *Animal Crossing: New Horizons*):** ACNH feels *alive* because it runs on the
**real-world calendar** — real time of day, real seasons, holidays on their actual dates, and a
town that kept living while you were gone. A watch pet gets this more intimately than any phone
game, because **the watch *is* the clock on your wrist** — it already knows the true date and time
for free, with no sensor and no battery cost (`Toybox.Time` / `System.getClockTime()`).

Time isn't only the decay input (§Time model) — it's the cheapest source of *world texture*:

- **Time of day.** Morning greeting → midday → evening wind-down; lighting/energy follow real local
  time (the `pet-sandbox` already tints the scene by hour). The pet gets drowsy at night.
- **Day of week.** Weekend energy vs Monday; rhythms like "leg day." A **Wednesday**
  "halfway through the week" nod fits here too — but **sprinkled, not scripted** (see the
  moderation guardrail below): the charm dies the moment every day has a forced line.
- **Seasons & holidays.** Seasonal palette/mood; holidays land on their **real** dates. **Cozy
  guardrail:** all seasonal content **recurs** — never miss-it-forever (no FOMO; Stardew's "next
  year"). → `05-progression.md §Cozy guardrails`.
- **"It lived while you were away."** The real-timestamp gap powers the **idle-return story** and
  gentle decay (already the §Time model spine): "you've been gone since Tuesday" is true, felt, and
  framed as a warm reunion — never a guilt clock (→ `05-progression.md §Momentum`, comeback warmth).
- **Anchored moments.** Birthday (from `born` epoch), care-streak anniversaries.

### Daily check-in arc — *morning hello → evening recap* (let biometrics do the talking)

John's framing: the pet **bookends the day.** **Morning** — a warm, forward-looking hello on the
first open after wake (or past a local-morning threshold): *"morning — gonna be a good one."*
**Evening/night** — a reflective beat: *"how'd today go?"*

The twist that keeps this *alive* rather than scripted: **the pet usually already knows.** It has
been on your wrist all day, so before it *asks* how the day went it checks what it can already
sense — steps, active minutes, HR / stress trend, Body Battery, goals hit (all free, already
feeding the pet per §differentiator). So the evening beat **branches on biometrics**:

- **Biometrics tell the story → it reacts, it doesn't ask.** *"rough one, huh — stress was up all
  afternoon. let's wind down."* / *"you crushed it today, I felt it."* **Knowing without being
  told is the alive feeling** — this is the §differentiator ("feed the pet with your body") and the
  real-day texture closing into one loop.
- **Biometrics are quiet / ambiguous → then it asks.** *"quiet day on my end — how'd it actually
  go?"* The literal question is the **fallback**, not the default.

Persona colors the wording (`07`): Drill Sergeant *"good shit, I felt that"* vs Zen Buddy *"you
carried a lot today — rest."*

**Moderation guardrail (important):** these beats are **occasional and earned**, never a daily
checklist of forced chatter. Morning hello + an evening reaction *when there's something real to
react to*; the Wednesday / holiday / anniversary lines are **rare seasoning**, not a script.
Over-talking turns texture into nagging and trips the cozy guardrails (no guilt clock, no
chore-board → `05-progression.md §Cozy guardrails`). Exact cadence / frequency = **kicked can**
(feel it out in `pet-sandbox`), consistent with the §Momentum and `open-questions.md §C` deferrals.

### The readiness ritual is a *care* moment, not a data grab

When the pet invites a stillness ritual — *"lie down with me two minutes"* (the DIY-HRV / stress
capture, `10-power-roster.md`) — the **biometrics it gathers can override the ritual's own
purpose.** If the signal says she's too stressed / depleted, the pet **abandons the measurement
and pivots to care**: the number stops mattering, the point becomes *her*. It fires
`HIGH_STRESS` (`07-personality.md`), persona-flavored:

- **Hype Cheerleader (her):** the **empty-cup analogy** ("you can't pour from empty — fill your
  cup first"), gentle permission that **some things on the list just aren't important today**,
  and **self-care-as-science** framing (rest is maintenance, not indulgence). Warm, not preachy.
- **Drill Sergeant:** same truth as *strategy* — "can't pour from an empty canteen; that's
  logistics, sit down." **Zen:** rest as system maintenance. **Deadpan:** "do less, world survives."

**Cozy-guardrail tie:** this is the no-guilt / no-punishment-clock principle made literal — *the
pet that sometimes asks you to perform will also tell you to stop.* "Knowing without being told"
(§above) here becomes **knowing when to let you off the hook.** Guardrail: never clinical, never
alarmist (no "your stress is dangerously high") — it's a friend reading the room, not a readout.

**Guardrail:** real time makes the world feel *alive* (warmth, texture, rhythm) — it is **never a
punishment clock.** No missable-forever events, no "you're late." Recurrence + comeback warmth keep
it cozy. This is the most natural superpower a *watch* pet has over a phone pet, and nearly free to
build.

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

The full identity/appearance schema (Layers A/B/C as a **composable-sprite vector** — species
+ palette + equipped slots) lives in `09-appearance-and-transfer.md`; that same tiny versioned
blob is also what **transfers between watches**.

## Rendering & input

- **Sprites:** frame bitmaps in resources; animate by swapping frames on a `Timer`.
  **Bitmaps eat app memory** — limited palette, reuse frames, lazy-load. The device-app heap is
  **768 KB on all three targets** (FR265 / FR265S / VA6) — confirmed from the installed SDK 9.1.0
  `compiler.json`; there is **no** FR265 heap advantage (the old "256–512 KB VA6 / 1 MB FR265"
  figure was wrong). So the sprite/animation budget is **uniform**: size the frame catalog to
  768 KB shared across the whole game, and let the *resolution* differences below (not a smaller
  VA6 heap) drive per-device resource sets. Background services remain the tight box at **64 KB**.
  Resolved in `open-questions.md §B2`; see also `common/memory/MEM_PART1..3` and
  `common/graphics/DC_PART3_RESOURCES_AND_PERFORMANCE.md`. **Composable layers** (parts ×
  palette swap — additive heap, multiplicative variety) are specced in `09-appearance-and-transfer.md`.
- **Three resolutions:** FR265 416×416, FR265S 360×360, VA6 390×390 → relative/scaled
  layouts + per-device resource sets. Strategy: `common/workflow/MULTI_DEVICE_STRATEGY.md`.
- **Input stance:** behavior-first, not touch-first. Use `WatchUi.BehaviorDelegate` for
  Select / Back / NextPage / PreviousPage / ActionMenu. Select is the one primary action;
  Back is sacred; up/down pages through big cards; any touch target must be whole-screen
  or large-row. VA6 has only **2 buttons + an Action Notch**, so never require 5 buttons
  or four distinct swipe directions. Full model: `08-watch-interaction-model.md`.
- **Power / AMOLED:** foreground animation drains AMOLED; keep sessions short, throttle
  redraws, idle when no interaction. Burn-in guidance: `common/architecture/AMOLED_BURN_IN.md`,
  `APP_LIFECYCLE_AND_POWER.md`.

## MVP scope (Track 1 only)

1. One species, 3 stages, 4 stats with timestamp decay.
2. Feed / play / clean / sleep actions + save/restore via Storage.
3. Steps→food hook (the one sensor tie-in that proves the concept).
4. Runs on FR265 **and** VA6 in the simulator at both resolutions.

Ship/enjoy this before touching Tracks 2–3.
