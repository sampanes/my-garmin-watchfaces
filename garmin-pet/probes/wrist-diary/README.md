# Friend MVP (formerly Wrist Diary)

A deliberately plain, local-only first friend. It reuses Wrist Diary's application UUID so
installing it replaces that prototype instead of adding another app slot.

## Versions

Friend uses `major.minor.patch` versions. The current version is `0.3.0`, shown beside `FRIEND`
at the top of the watch screen and included in every export marker. The earlier unlabelled first
dogfood build is treated as `0.1.0`. Increase the patch number for fixes, minor for compatible
data/features, and major if stored data or behavior is intentionally broken or replaced.

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
  the activity: lifting, stress, chores, and bathroom heroics remain deliberately indistinguishable.
- During a chapter the friend says `WITH YOU`. Afterward it says `I SAW N MIN`, remembers the
  chapter at the next check-in, and adds a small persistent memory mark below its face. Memories
  never decay and skipped days carry no penalty.
- Back exits immediately after saving a compact session summary. Pressing Select performs the
  larger text export on demand; ordinary open/close use does not serialize the whole history.
- Makes no web requests and sends nothing off the watch.

The export contains four CSV sections: the 8 newest check-in snapshots, the 8 newest session
summaries, the 12 newest effort chapters, and up to 48 live records sampled evenly across the
retained four-hour window. This keeps one export inside Garmin's small rotating debug logs while
the chapter summaries preserve higher-value detail; all 20-second records remain in on-watch
storage. Each live record now includes the 20-second HR minimum/average/maximum instead of only
one final reading. Chapter summaries include duration, HR range and peak delta, motion, step
change, whether Back ended the chapter early, and a numeric evidence reason (`1` motion, `2` HR,
`3` both). Missing values are `-1`; Friend never invents a sensor result.

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

Before reconnecting, open Friend and press Select once so the newest complete export is in the
log. The reader copies both the live log and rotated backup, writes parsed CSV files under the
ignored `bin/friend/downloads/` directory, and leaves on-watch data untouched.
