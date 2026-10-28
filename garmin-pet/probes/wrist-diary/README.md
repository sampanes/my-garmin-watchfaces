# Friend MVP (formerly Wrist Diary)

A deliberately plain, local-only first friend. It reuses Wrist Diary's application UUID so
installing it replaces that prototype instead of adding another app slot.

## Versions

Friend uses `major.minor.patch` versions. The current version is `0.5.1`, shown beside `FRIEND`
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
- During a chapter the friend says `WITH YOU`. Afterward it says `I SAW N MIN`, remembers the
  chapter at the next check-in, and adds a small persistent memory mark below its face. Memories
  never decay and skipped days carry no penalty.
- From the companion screen, START enters `FRIEND WALK` and begins warming GPS; START again begins
  the activity even if a fix is still settling. While walking, START or Back opens `END WALK?`;
  START explicitly stops and saves, while Back resumes without a route gap. A successful result
  says `WE WALKED` and the activity syncs through Garmin normally.
- Up/Down opens the debug-data card. START there performs the larger text export on demand and
  shows `EXPORTED`; ordinary open/close use does not serialize the whole history.
- Back from the companion screen exits immediately after saving a compact session summary, even
  if that save fails. Back from preparation cancels it, and Back from a walk result returns home.
- The face has three moods: calm (green, small smile), effort (orange, open mouth) and remember
  (gold, happy closed eyes). Every text line is sized to fit the round screen at its height.
- Every session summary records how it ended (`exit_reason` `1` Back, `2` the watch closed the
  app), the elapsed second of the last button press (`last_input_s`, `-1` for none) and the
  number of presses (`inputs`). Each exit also prints one `FRIEND_EXIT,reason,elapsed,last_input,
  inputs` log line. A launch with no session summary at all means Friend crashed; the reader
  copies Garmin's `CIQ_LOG.YML`/`.BAK` crash log next to the export to confirm it.
- Makes no web requests and sends nothing off the watch.

Garmin rotates the app log at about 5 KB and keeps one older file (measured on the FR265:
`.BAK` files of 5150 and 5160 bytes), so only an export under 5 KB is always retrieved whole; a
7.3 KB export on 2026-10-22 lost its start. Export format 4 is therefore host-tested below 4.8 KB
with conservative high-width values even when every detailed row came from a separate short session:

- `FRIEND_DEVICE`: part number, firmware, Connect IQ version, and whether tones and vibration
  are switched on (`1`/`0`).
- CSV rows without header lines (the column names live in `scripts/friend-export.ps1`): the 4
  newest check-in snapshots, the 8 newest session summaries and the 10 newest effort chapters.
- The 35 newest 20-second live records (the last 11 minutes 40 seconds Friend was open) in a compact
  fixed-width base-36 form, 22 characters a row instead of about 65.

Each check-in snapshot also answers open hardware questions: respiration rate, time to recovery
(hours), SpO2, barometric pressure (Pa) and the age of the newest stress-history sample (s).
There `-1` means the watch answered null, `-2` that this firmware lacks the field, and `-3` that
the call threw. Session summaries also carry battery % at start and end (`battery_start`, `battery_end`), peak
app memory in KB (`mem_peak_kb`) and how many times the screen went away (`hides`; a close by the
watch usually adds one). Chapter summaries include duration, HR range and peak delta, motion, step
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

Before reconnecting, open Friend, use Up/Down to reach `DEBUG DATA`, then press START so the newest
complete export is in the log. The reader copies both the live log and rotated backup, writes parsed CSV files under the
ignored `bin/friend/downloads/` directory, and leaves on-watch data untouched. Every read also
merges its rows into `bin/friend/archive/` (no duplicates), so reading after each session builds
the full history that no single export can carry. `scripts/test-friend-export.ps1` checks the
compact format and the size budget on the host.
