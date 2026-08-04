# Wrist Diary

A deliberately plain, local-only data logger for validating which daily and
wrist signals are useful before building them into the pet game.

## What it does

- Automatically captures one snapshot each time the app launches.
- Pressing Select captures another snapshot; Up/Down changes pages.
- Keeps the newest 60 snapshots in `Application.Storage` (about 30 days when
  opened morning and evening).
- Prints the complete snapshot ring as CSV between `WRIST_DIARY_BEGIN` and
  `WRIST_DIARY_END` markers. On a physical watch this is written to
  `GARMIN/Apps/LOGS/wrist-diary-fr265.TXT` when that empty log file exists.
- Makes no web requests and sends nothing off the watch.

Each record contains epoch time, steps, calories, moderate/vigorous active
minutes, stress, latest and four-hour HR summary, Body Battery when available,
distance, and floors climbed. Missing values are stored as `-1` and displayed
as `--`; the app never invents a reading.

Daily counters reset at midnight. If a counter is lower than the previous
snapshot, the delta is intentionally left blank rather than pretending the
overnight interval is known.

## Build

```powershell
.\scripts\build-wrist-diary.ps1
```

The output is `bin/wrist-diary/wrist-diary-fr265.prg`. Copy it to
`GARMIN/Apps/`, and copy an empty `wrist-diary-fr265.txt` to
`GARMIN/Apps/LOGS/` before launching the app.

## Retrieve later

Reconnect the watch and run:

```powershell
.\scripts\read-wrist-diary.ps1
```

The script copies the log into a timestamped ignored directory under
`bin/wrist-diary/downloads/` and prints the newest complete exported block as
a table. The original device log and on-watch storage are left untouched.
