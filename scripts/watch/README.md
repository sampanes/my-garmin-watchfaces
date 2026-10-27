# Watch setup tools

Two tools for keeping the FR265 setup reproducible, run through
`scripts\watch-tools.ps1`, which builds its own Python environment in
`.venv` at the repo root on first use (Python 3.12+ needed).

## Settings inventory

`backup-garmin-device.ps1` runs this automatically after every verified backup
(`-SkipSettingsInventory` turns it off). By hand:

```powershell
.\scripts\watch-tools.ps1 settings                 # newest backup vs the one before
.\scripts\watch-tools.ps1 settings <backup> --against <older-backup>
```

It decodes the settings, sport-profile, workout, goal and schedule FIT files in a
backup with Garmin's FIT SDK and writes, into that backup folder:

- `settings-inventory.txt`: one line per field, `file | message[n] | field = value`.
  Garmin documents only part of these messages; undocumented ones still appear,
  as `message_<n>` / `field_<n>`, so a change still shows up as a line.
- `settings-diff.txt`: `~` changed, `+` added, `-` removed since the previous backup.

Change one setting on the watch, back up, and the diff names the field that
setting lives in. That is the way to map the undocumented fields, and the
inventory is the checklist to rebuild from by hand if Garmin's own restore
ever fails again.

Read-only: nothing writes to the watch. Garmin documents no restore path for
these files besides its Device Backup, so they are a record, not a restore
source. The output holds personal data (weight, birth year, zones) and stays in
`bin\`, which Git ignores.

## Workouts as code

Each `workouts\*.toml` file is one strength workout (see `mat-basics.toml` for the
format). Names come from Garmin's 1,500-exercise catalog.

```powershell
.\scripts\watch-tools.ps1 find lunge               # catalog names
.\scripts\watch-tools.ps1 check                    # validate every file, offline
.\scripts\watch-tools.ps1 show "Mat basics"        # the JSON that would be sent
.\scripts\watch-tools.ps1 push                     # create/update all, send to the watch
.\scripts\watch-tools.ps1 push "Mat basics" --schedule 2026-10-27
```

`push` matches Garmin Connect workouts by name: an existing one is updated in
place (its id and calendar entries survive), a new one is created. Then the
workout is sent to the last-synced device, or put on the calendar with
`--schedule`; it reaches the watch on its next sync.

The first `push` asks for the Garmin account email, password and any MFA code,
and saves a login token in `~\.garminconnect` (the password is not saved). It
uses the unofficial `garminconnect` library, which talks to Garmin's private web
API, so a Garmin change can break it without warning; `check` and `show` work
offline either way.

## Setup as code (Garmin Connect)

Much of the setup lives in the Garmin Connect account, not only on the watch,
and survives a watch wipe: units, sleep window, user profile, heart-rate zones,
goals, and the device settings Garmin Connect can edit (activity tracking,
alarms, and whatever else `snapshot` shows). `connect_setup.py` reads it, digs
the pre-wipe values out of old activity files, and writes a desired state back.

```powershell
.\scripts\watch-tools.ps1 snapshot                     # read-only: bin\garmin-connect\snapshot-<time>\*.json
.\scripts\watch-tools.ps1 recover --wiped 2026-10-26   # settings inside the last activity before / first after
.\scripts\watch-tools.ps1 apply                        # diff bin\watch-setup.toml vs Garmin Connect, write nothing
.\scripts\watch-tools.ps1 apply --yes                  # write only the differences
```

`recover` works because Garmin embeds part of the setup (device settings, user
profile, zones, sport settings) in every activity file. The last activity
before the wipe is a record of the old setup; `wipe-diff.txt` lists what the
wipe changed.

`bin\watch-setup.toml` is the desired state, using Garmin Connect's own JSON key
names as TOML tables (take them from a snapshot). Only listed keys are compared
or written; everything else is left alone:

```toml
[user.userData]
measurementSystem = "statute_us"

[device.activityTracking]
moveAlertEnabled = true

[[hr_zones]]
sport = "DEFAULT"
maxHeartRateUsed = 186
```

Not reachable this way: most of the watch. On the FR265 (snapshot of
2026-10-27), Garmin Connect's device settings fill in only units, time and date
format, start of week, alarms, do-not-disturb, auto-sync thresholds, Connect IQ
auto-update and the intensity-minute zones. Watch face, glances, controls menu,
backlight, activity list and data screens all come back `null`, so they are set
on the watch or in the Connect phone app.

`recover` needs activities recorded on the watch and synced to Garmin Connect.
An account with none has nothing to recover from.

Run these in an interactive terminal: the first login asks for the Garmin
email, password and MFA code, which a non-interactive prompt cannot answer.

## Tests

`.\scripts\watch-tools.ps1 test` builds FIT files with the FIT SDK's encoder,
inventories and diffs two fake backups, and pushes the repo's workouts to a fake
Garmin client. No watch or network needed.
