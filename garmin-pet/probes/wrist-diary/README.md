# Friend (formerly Wrist Diary)

> **For the home PC: 0.8.0 has never been compiled.** It was written on a machine with no SDK.
> Run `scripts/home-verify.ps1` (or `scripts/build-friend.ps1`) and expect compiler errors in the
> three new files (`FriendPet.mc`, `FriendArt.mc`, `FriendVoice.mc`) and the pet section at the
> end of `WristDiaryView.mc`; the sensing code above it is unchanged from 0.7.1. Then compare the
> simulator with the eight sheets in [preview/](preview/) (`python scripts/friend_preview.py`
> redraws them; `--check` holds the mock to the Monkey C). Unproven on a compiler: the
> `FriendLook` module constants, the three-deep `mLines` array cast, `Math.pow(...).toFloat()`,
> `onTap` in the behavior delegate, and whether a tap on the FR265 would otherwise arrive as
> START. Add what the compiler says to `common/language/COMPILER_FACTS.md`.
>
> **The drawn friend is a placeholder, on purpose.** It is shapes in code so the game can be
> played; no more effort goes into it. Real art is made by hand outside this repo and replaces it
> behind one seam, `FriendArt.draw` (see "Art slots" below).

A deliberately plain, local-only first friend. It reuses Wrist Diary's application UUID so
installing it replaces that prototype instead of adding another app slot.

## Versions

Friend uses `major.minor.patch` versions. The current version is `0.8.0`, shown beside `FRIEND`
at the top of the watch screen and included in every export marker. The earlier unlabelled first
dogfood build is treated as `0.1.0`. A `0.3.1` export may appear in old logs: it was a local
build that never reached git, and `0.4.0` was built on `0.3.0` instead. Increase the patch number for fixes, minor for compatible
data/features, and major if stored data or behavior is intentionally broken or replaced.

**0.5.0 — Walk with Friend:** the T19-proven foreground recorder is now an explicit Friend mode.
It creates a standard Walking FIT activity with GPS, HR and distance for Garmin Connect. Ending a
walk is an explicit foreground confirmation; a `CLOSED`/`onStop` save remains best-effort only,
because T20 returned success but produced no FIT file.

**0.5.1 — No trap on the walk result:** START and Back always leave the `WE WALKED` /
`WALK FAILED` card, even when the FIT session refuses to discard; the next walk retries that
cleanup and reports `CLEANUP ERR` if it still fails. Also two casts for the type checker.

**0.6.0 — Beat intervals (test plan T11):** the sensor listener also asks for beat-to-beat
intervals. Every session summary now tallies how many arrived, how many differed from the one
before (a constant 1000 ms means interpolated beats, not HRV), the min and max in ms, and the
same count/changes pair taken while a Friend Walk was recording. Export format 5. If the watch
refuses the option, Friend logs `FRIEND_RR_ERROR`, records `rr_count` −1 and falls back to the
motion-only listener 0.4.0 ran with.

**0.7.0 -- Export on every exit:** the watch firmware encrypts Connect IQ app storage
(`GARMIN/Apps/DATA/*.DAT` reads as random bytes over USB), so the log export is the only readable
copy. Friend now writes the same export the DEBUG DATA card does every time it exits, Back or
watch-closed, after the session summary is saved. A failed export logs `FRIEND_AUTO_EXPORT_ERROR`
and changes nothing stored. The DEBUG DATA card still works for an export mid-session.

**0.7.1 -- Hide/show timeline:** every `onShow` / `onHide` writes `FRIEND_SHOW,<elapsed s>` /
`FRIEND_HIDE,<elapsed s>,<hide count>` to the log beside `FRIEND_EXIT`, so a session the watch
closed can show whether the close followed a hide that never got its show back. The 2026-10-31
[field log](../../field-logs/2026-10-31_friend-export.md) counted 3 hides in each such session and
could say no more. No stored data or export format change.

**0.8.0 -- The friend becomes a pet (unbuilt):** designed against the
[2026-11-10 field log](../../field-logs/2026-11-10_friend-export.md). The effort chapters Friend
already senses now feed a pet that grows, following
[`12-pet-state-and-economy.md`](../../12-pet-state-and-economy.md):

- **First open is an egg.** Up/Down picks its colorway, START hatches it, then Up/Down picks one
  of four voices (Drill Sergeant, Hype Cheerleader, Deadpan, Zen), each shown with a sample line.
  The egg "heard it all": every chapter Friend still holds is credited at the hatch, so the pet is
  born with its history (about 370 XP, band 2, on the watch this was designed against).
- **Effort is XP.** A chapter earns effort minutes (x1, x1.25 or x1.5 by heart rate over the
  four-hour baseline, shown as one to three flames), tapered within a day, plus a daily-first
  bonus. While a chapter is open the home screen shows the flames and the XP it has earned so far,
  and the bar fills in gold.
- **Back pays out.** After the session is saved, a reward card shows the XP, the flames, one line
  in the pet's voice and the bar moving; START or Back leaves, or it leaves by itself after 20
  seconds. If nobody pressed, or the watch closed Friend, the card opens the next visit instead
  (`LAST TIME`). A band gained adds a `GREW UP!` card.
- **Bands change the pet:** Hatchling (in its shell), Sprout (a leaf, the flex emote), Trainee
  (a headband, the spin emote), then the first **evolution** at 660 XP: the GROWING card offers
  it, Up/Down previews three forms (sleek, round, wild) and a second START makes it permanent.
  Later bands add flames, a cape and an aura. The pet waits one band below an evolution until
  the wearer chooses.
- **Mood is weather**, drawn in the sky and on the face (misty, fair, sunny, radiant). It drifts
  to a calm middle, stops drifting after 48 hours away and greets a return warmly. Nothing decays
  as a punishment and there is no fail state.
- **Up/Down is a card stack:** TODAY (weather, today's effort snack out of 30 minutes, warmth and
  rest-day shields), GROWING (band, XP to the next, what it unlocks), OUR TRAIL (distance walked
  with Friend, toward landmarks at 1, 5, 10, 21.1 and 42.2 km) and DEBUG DATA.
- **A tap pets it** (an emote, a line, +5 mood once a day). A tap is never START, so a sleeve on
  the touchscreen cannot start or save a walk.
- **A stray walk is not saved.** Ending a walk under a minute and under 50 m offers
  `START drop it` instead of `START save`.
- The pet is one array of 32 numbers under the Storage key `pet`; every exit exports it as a
  `FRIEND_PET` line (export format 6) and `read-friend.ps1` prints it, so the watch's XP can be
  held against `pet-model.ps1`. `scripts/test-friend-pet.ps1` holds the watch's integer math and
  every tuning constant to the model.
- On the DEBUG DATA card, MENU reopens the colorway and voice choice (a dogfood escape hatch;
  nothing else resets).

Where 0.8.0 departs from doc 12 as written: flames at +15 / +30 bpm instead of +10 / +20 (the
field log shows why); the displayed band waits below an evolution instead of showing it early;
the only care action is petting; every band's unlock is expressive, because no classifier for
naming moves or counting reps exists yet.

## Art slots

Everything the pet shows is drawn by `FriendArt` from five numbers the game sets
(`setLook`, `setPose`): **stage** (egg, baby, child, adult), **band** (accessories: shell 0,
leaf 1-2, headband 2+, cape 5+), **form** (sleek, round, wild; adult only), **colorway** (6) and
**face/pose** (faces: misty, fair, sunny, radiant, effort, joy, sleep; poses: idle, run, hop,
flex, spin, flames, sleep), plus a frame counter at 5 frames a second. Hand-made art replaces
the body of `FriendArt.draw` and `drawEgg`; nothing else in the game knows how the pet is drawn.
The sky, the flame, heart, shield and sparkle icons are separate small functions in the same
class. The app uses 31 KB of its 768 KB at its peak, so there is room for bitmaps.

## What it does

- Opening Friend captures a daily/wrist snapshot and immediately starts observing. There is no
  workout chooser or start confirmation; leave the app open and ignore it.
- While open it reads live HR, compares it with the trailing four-hour baseline, and processes
  25 Hz accelerometer samples. Every 20 seconds it saves compact motion and HR evidence.
- Keeps a rolling 700 live records (about 3 h 53 m), plus 60 launch snapshots and 60 session
  summaries. A session summary preserves the shape of older workouts after detailed data rolls.
- Automatically groups sustained HR and/or wrist-motion evidence into neutral **effort chapters**.
  Two positive buckets within one minute open a chapter; six quiet buckets among the latest eight
  close it at the last strong evidence, excluding a forgotten-at-the-desk tail. Friend never names
  the activity: lifting, stress, chores, and other everyday movement remain deliberately indistinguishable.
- During a chapter the friend speaks in its voice (`With you.` is one of the lines). Afterward it
  says `I saw N min.` and remembers the chapter at the next check-in. Memories never decay and
  skipped days carry no penalty.
- From the companion screen, START enters `FRIEND WALK` and begins warming GPS; START again begins
  the activity even if a fix is still settling. While walking, START or Back opens `END WALK?`;
  START explicitly stops and saves, while Back resumes without a route gap. A successful result
  says `WE WALKED` and the activity syncs through Garmin normally.
- Up/Down pages through the cards to the debug-data card. START there performs the larger text export on demand and
  shows `EXPORTED`; ordinary open/close use does not serialize the whole history. The card also
  shows the T11 tally at a glance: `RR 812  93% VARY` (intervals this session and the share that
  differed from the previous one), `RR NONE YET`, or `RR OFF` when the watch refused the option.
- Back from the companion screen exits immediately after saving a compact session summary, even
  if that save fails. Back from preparation cancels it, and Back from a walk result returns home.
- Every text line is sized to fit the round screen at its height.
- Every session summary records how it ended (`exit_reason` `1` Back, `2` the watch closed the
  app), the elapsed second of the last button press (`last_input_s`, `-1` for none) and the
  number of presses (`inputs`). Each exit also prints one `FRIEND_EXIT,reason,elapsed,last_input,
  inputs` log line. A launch with no session summary at all means Friend crashed; the reader
  copies Garmin's `CIQ_LOG.YML`/`.BAK` crash log next to the export to confirm it.
- Makes no web requests and sends nothing off the watch.

Garmin rotates the app log at about 5 KB and keeps one older file (measured on the FR265:
`.BAK` files of 5150 and 5160 bytes), so only an export under 5 KB is always retrieved whole; a
7.3 KB export on 2026-10-22 lost its start. Export format 6 is therefore host-tested below 4.8 KB
with conservative high-width values even when every detailed row came from a separate short session:

- `FRIEND_DEVICE`: part number, firmware, Connect IQ version, and whether tones and vibration
  are switched on (`1`/`0`).
- CSV rows without header lines (the column names live in `scripts/friend-export.ps1`): the 4
  newest check-in snapshots, the 8 newest session summaries and the 10 newest effort chapters.
- Since 0.8.0, one `FRIEND_PET` line: the pet's 32 saved numbers.
- The 30 newest 20-second live records (the last 10 minutes Friend was open) in a compact
  fixed-width base-36 form, 22 characters a row instead of about 65.

Each check-in snapshot also answers open hardware questions: respiration rate, time to recovery
(hours), SpO2, barometric pressure (Pa) and the age of the newest stress-history sample (s).
There `-1` means the watch answered null, `-2` that this firmware lacks the field, and `-3` that
the call threw. Session summaries also carry battery % at start and end (`battery_start`, `battery_end`), peak
app memory in KB (`mem_peak_kb`) and how many times the screen went away (`hides`; a close by the
watch usually adds one). Since 0.6.0 they end with the T11 beat-interval tally: `rr_count`,
`rr_changes` (intervals unlike the previous one), `rr_min_ms`, `rr_max_ms`, and `rr_walk_count` /
`rr_walk_changes` for the part of the session a Friend Walk was recording; `rr_count` −1 means the
watch refused the option. Session rows stored by an older build are shorter and the reader leaves
their `rr_*` fields blank. Chapter summaries include duration, HR range and peak delta, motion, step
change, whether Back ended the chapter early, and a numeric evidence reason (`1` motion, `2` HR,
`3` both). Missing values are `-1`; Friend never invents a sensor result. All 700 live records
stay in on-watch storage.

## Bounce 2 inspiration

Bounce 2 includes a simple Tamagotchi-style digital pet that rewards returning but requires
manual daily care. Garmin Jr. separately turns daily activity goals into collectible gems and
revealed adventure memories. Friend borrows the persistent character and visible memory, but
automates the credit and rejects pet death, decay, and streak punishment. The chapter is earned
from sensed evidence without a workout chooser or care chore.

- [Garmin Bounce 2 product features](https://www.garmin.com/en-GB/p/pn/010-03399-02/)
- [Garmin collectible-gem thresholds](https://support.garmin.com/en-GB/?faq=z6f6hx0uDc7rd7QjOLPx97)
- [Hands-on description of the Bounce 2 digital pet](https://www.todaysparent.com/family/garmin-bounce-2-review/)

## Build

```powershell
.\scripts\build-friend.ps1
.\scripts\install-friend.ps1
```

The build is `bin/friend/friend-fr265.prg`. The installer copies it and the required empty
`wrist-diary-fr265.txt` log through the watch's MTP interface. Garmin retains that original log
basename because Friend intentionally reuses Wrist Diary's app identity.

After installation, **safely disconnect** means using the button/control on the Forerunner itself
to leave its USB connection mode, then letting the watch finish its on-watch app sync/update step.
Do not interpret it as merely pulling the cable immediately. Wait until the watch finishes
processing the staged app; then open Friend and confirm the version shown at the top of its screen.

## Retrieve later

Reconnect the watch and run:

```powershell
.\scripts\read-friend.ps1
```

Since 0.7.0 every exit already left the newest export in the log; on older builds, open Friend,
use Up/Down to reach `DEBUG DATA` and press START before reconnecting. The reader copies both the live log and rotated backup, writes parsed CSV files under the
ignored `bin/friend/downloads/` directory, and leaves on-watch data untouched. Every read also
merges its rows into `bin/friend/archive/` (no duplicates), so reading after each session builds
the full history that no single export can carry. `scripts/test-friend-export.ps1` checks the
compact format and the size budget on the host.
