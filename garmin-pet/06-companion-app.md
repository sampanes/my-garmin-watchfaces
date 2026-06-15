# Companion phone app — watch-first, phone as optional megaphone

**Verdict: the game lives on the WRIST. A phone app is NOT the home/backdrop — it's an
optional Tier-2 amplifier, and the one thing it uniquely unlocks is the *proactive nag*.**
Do not build a "whole Android backdrop"; it's overkill *and* it buries the best feature.

> Spitball origin (2026-06-15): "would a whole Android app for the backdrop be overkill?"
> Goal: a little asshole friend on the watch that makes you do 5 pull-ups / run a mile /
> squat your max.

## Possible? Yes.

The **Connect IQ Mobile SDK** (Android **and** iOS) exists exactly for this: a native
companion app that exchanges messages with your watch app over the Garmin Connect BLE
bridge. Same mechanism described in `02-async-social.md`. So feasibility is not the question
— *role* is.

## Why the phone must NOT be the home

- **Proximity is the whole feature.** The accountability gremlin works because he's strapped
  to your body all day. Move the real game into a phone app and he becomes another icon you
  swipe past in the other room. **The watch isn't the cheap version of the phone app — the
  watch IS the killer app.** You can't out-nag something physically attached to a wrist.
- **The sensors are on the wrist anyway** (rep-counting `04`, GPS mile, HR). A phone would
  just be a viewer of data the watch already owns.
- **Scope.** A full Android app is a second product: Play Store listing, review, updates, a
  second codebase, the Mobile-SDK glue. Massive for a hobby; halves your focus.

## The three architectures

| Architecture | Verdict |
|---|---|
| **Watch-only** (Garmin Connect = just the internet pipe) | ⭐ **Start here.** Strongest accountability, smallest scope. |
| **Watch-first + thin phone companion** | The eventual "if it has legs" upgrade. Add the nag first, visuals later. |
| **Phone-as-backdrop / home** (the spitball) | Overkill **and** dilutes the point. **Skip.** |

## The ONE real reason a companion earns its keep: the proactive nag

This is non-cosmetic and serves the goal directly. From the platform research
(`open-questions.md §B`):

- **No server→watch push exists**, and the watch **can't reliably buzz you on a schedule
  when the app is closed** (`Background.requestApplicationWake` only shows a "start app?"
  prompt — not a silent nag).
- On-wrist, the gremlin can only roast you **reactively** — when you open the app or log a
  set. To make him interrupt your day **unbidden** (*"IT'S 6PM. ZERO PULL-UPS."*), the nudge
  realistically originates on the **phone**: a scheduled local notification (or backend →
  phone push), optionally relayed to the watch via `registerForPhoneAppMessageEvent`.

So if/when a companion is built, **its first job is the scheduled nag**, not graphics.

## Tier-2 perks (nice, not the soul)

- The gorgeous big-screen **diorama / social hub** (the rich visuals from the look talk —
  cramped on a watch, lovely on a phone).
- **QR friend-add**, account management, richer onboarding.
- Heavier text entry (free-text stays phone-only; watch stays canned — `02`).

## Decision

- [x] **Watch-only MVP.** No companion app at launch.
- [x] **Companion deferred** to Tier 2; when added, **nag first, hub second.**
- [x] Reactive roasting (on-open / on-log) is watch-native and ships day one; proactive
      scheduled roasting waits for the companion.

## Cross-refs
- `02-async-social.md` — the Mobile SDK / BLE bridge, canned-vs-free-text
- `04-activity-sensing.md` — what the gremlin senses and how he narrates it
- `open-questions.md §B` — no server→watch push; app-wake is prompt-only
