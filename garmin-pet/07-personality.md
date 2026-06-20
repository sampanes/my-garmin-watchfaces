# Personality — persona as a permanent identity trait ("voice pack")

**Verdict: the pet's *temperament* is a permanent identity choice (a 4th Layer-A trait in
`05-progression.md`), chosen at creation, orthogonal to species/look, re-pickable only at
evolution.** It's implemented as a **"voice pack"** — a table of canned lines + a few
behavior weights — so it's nearly free to add and tiny on the wire.

> Origin (2026-06-15): "make personality a lock-in trait too... another user might prefer a very
> cute supportive sycophant, unlike me." Two people, two opposite coaches, **one app**.

## Why permanent (and why this is the right call)

- **Commitment breeds attachment** — Gilbert & Ebert (`05 §Layer A`): a chosen-and-kept trait
  bonds you harder than an endlessly editable slider. "My pet is a jerk" *is* the relationship.
- **Real user diversity, zero app-fork.** Asshole-for-him / sycophant-for-her is the same
  build; persona is one integer in the save state. No separate "nice mode" codepath.
- **It diverges pets further** (the `05` "won't everyone be identical?" answer): same species
  can be a snarling drill sergeant or a gushing cheerleader. Persona is a whole expression axis.

**Re-pick valve:** like the evolution branch, persona is permanent *within a life* but the one
sanctioned moment to change it is **at evolution** (the "fig that regrows" — `05`). Commitment
with a release valve, internally consistent with how branches work.

**Telegraph at pick-time** (`05` principle — informed choice, not a blind gamble): the creation
screen shows a **sample line per persona** so you hear the voice *before* you commit.

## The persona model: two sliders → four starter archetypes

Don't go infinite (paralysis — `05`). Two legible axes:

```
                    INTENSE
                       │
      Drill Sergeant   │   Hype Cheerleader
      "the Asshole"    │   "the Sycophant"
   MEAN ───────────────┼─────────────── KIND
      Deadpan          │   Zen Buddy
      "the Snark"      │   "the Calm"
                       │
                     CHILL
```

| Persona | Warmth × Energy | Vibe | Behavior weights |
|---|---|---|---|
| **Drill Sergeant** (him) | mean + intense | tough love, sarcasm, withholds praise | high nag freq, high praise threshold, roast=on |
| **Hype Cheerleader** (her) | kind + intense | gushing, unconditional, soft | high nag freq (but sweet), praise=always, roast=off |
| **Deadpan** | mean + chill | dry, sardonic, low-key, unbothered | low nag, dry praise, roast=mild |
| **Zen Buddy** | kind + chill | calm, gentle, no pressure | low nag, gentle praise, roast=off |

## Implementation: one event bus, N line tables

The game fires the **same keyed events** regardless of persona:
`COLD_OPEN`, `SET_DONE{reps,exercise,confidence}`, `LOW_CONFIDENCE`, `MOTION_BLIND_GASSED`,
`STREAK_BROKEN{days}`, `GOAL_HIT`, `IDLE_NUDGE`, ...

A persona is just a **lookup**: `event-key → pool of canned lines` + a few numeric weights
(nag frequency, praise threshold, roast level). Pick a line from the pool, varying by index so
it doesn't repeat. **Adding or swapping a persona = swap the line table**, not new art or logic.
- **Cheap & watch-native** — rides the locked canned-vocabulary model (`02`).
- **Memory-friendly** — persona is dialogue + weights, *not* new sprites; the same art serves
  every temperament.
- **Tiny on the wire** — `state.id.persona` is one int; a visiting friend sees/hears *your*
  pet's persona (a friend visiting your jerk-pet = built-in comedy).

## Sample lines (original; same events, four voices)

| Event | Drill Sergeant | Hype Cheerleader | Deadpan | Zen Buddy |
|---|---|---|---|---|
| **Cold open** (press GO) | "Sup. Let's go." | "YES okay okay let's GO — you've got this!!" | "Oh. We're doing this. Fine." | "Hey. Whenever you're ready." |
| **Solid set (12 reps)** | "Twelve. Barely acceptable." | "TWELVE?! You're literally incredible!" | "Twelve. Didn't hate it." | "Twelve. Nicely done." |
| **Low-confidence guess** | "The hell was that. A curl? Sure." | "Ooh not sure what that was but you LOOKED amazing!" | "...Sure. We'll call it a curl." | "Not sure what that was — it counted." |
| **Motion-blind, gassed** (pull-ups) | "Wrist barely moved but you're gassed. Good shit." | "Your heart is POUNDING, you beast — so proud!" | "Can't see it. Heart says you tried. OK." | "Couldn't read the move, but your body worked. Good." |
| **Streak broken (3 days off)** | "Oh, look who remembered I exist. 0 for 3." | "I missed you!! No worries — fresh start today!" | "Three days. Bold." | "Welcome back. No guilt. Let's just start." |
| **Goal hit** | "...Fine. That was actually good. Don't let it go to your head." | "YOU DID IT!!! I'm so, so proud of you!!" | "Goal hit. Cool." | "You reached it. Breathe. Well done." |

## Content guardrail: tough-love, not abuse

The Drill Sergeant **roasts the slacking, never demeans the person.** No cruelty about
body/worth — sarcasm aimed at the *effort gap*, always with an implicit "now go." Keeps it
general-audience (store policy, `open-questions §B`) and, frankly, keeps it from being a
genuinely demotivating jerk. Mean *flavor*, supportive *function*.

Shipping-label rule: **Drill Sergeant / Hype Cheerleader / Deadpan / Zen** are the
user-facing labels. "Asshole" / "sycophant" can remain internal shorthand for ideation,
but should not appear in store copy, onboarding, or the picker UI. The joke is the
relationship dynamic, not edgelord labeling.

## Decision

- [x] **Persona = permanent Layer-A identity trait** (with evolution as the re-pick valve).
- [x] **Orthogonal to species/look**; implemented as a voice-pack (line table + weights).
- [x] **Telegraphed at creation** (sample line preview before commit).
- [x] **Shipping labels separated from internal shorthand** (market-safe labels in UI/store;
      sharper language can stay in design notes).
- [ ] Final persona roster (start with the 4 above? add more later?) — open.
- [ ] Per-persona behavior-weight tuning (nag cadence, praise thresholds) — open.

## Cross-refs
- `05-progression.md §Layer A` — persona is one of the few permanent identity choices
- `04-activity-sensing.md` — the roast/cheer dialogue is persona-parameterized (the lines there
  are the Drill Sergeant's voice; every persona reacts to the same sensing events)
- `02-async-social.md` — canned-vocabulary model these lines ride on
