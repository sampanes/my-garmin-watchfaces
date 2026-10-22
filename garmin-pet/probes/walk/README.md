# Walk Probe (T19 / T20)

A single-purpose watch app for `11-hardware-test-plan.md` rows **T19** and **T20**: does a walk
recorded by our own app land in Garmin Connect the way the pet's "Walk with me" power needs
(`10-power-roster.md`), with a route map, an HR graph and a custom field, and what happens to the
track when the app leaves the screen mid-walk?

It records a real FIT activity with `ActivityRecording` (sport walking), turns on continuous
location events and the HR sensor explicitly (neither is recorded unless the app enables it), and
adds one custom FIT field, `pet_mood`. Nothing goes off the watch except the normal activity sync.

## What it proves

| Question | Where the answer shows |
|---|---|
| An app-recorded walk syncs to Connect at all | Connect activity list |
| The activity has a **route map** (GPS was recorded) | Connect activity page |
| The activity has an **HR graph** (HR was recorded) | Connect activity page |
| A custom FIT field reaches Connect | "Connect IQ" section / charts, or the raw FIT |
| The activity type is Walking | Connect activity page |
| The walk counts toward daily totals | Connect daily summary |
| T20: the track stops when the app leaves the screen | Route shape, `HID` counts, `CLOSED` result |

## Controls

| Action | FR265 / FR265S | vivoactive 6 (expected, verify on the watch) |
|---|---|---|
| Start recording | START (top right, marked by a green arc) | top button or tap |
| Stop and save | START again | top button or tap |
| Stop and save | BACK while recording (stays on the SAVED screen) | bottom button / swipe right |
| Discard the recording | hold UP (menu) while recording | hold bottom button |
| Exit | BACK while not recording | bottom button / swipe right |

Back while recording does not ask anything: it stops, saves, and leaves the result on screen.
A second Back exits. If the watch itself closes the app while it is recording, the app saves the
activity on the way out and remembers that the walk ended as `CLOSED`.

## Screen

```
WALK PROBE
RECORDING            READY / WAITING FIX / RECORDING / REC NO FIX / SAVED / DISCARDED / error
GPS GOOD             GOOD / USABLE / POOR / LAST KNOWN / NONE (last accuracy reported)
12:04                elapsed (wall clock, so it stays right across hides)
HR 96   FIX 712      live HR, location events received while recording
START saves ...      hint, or T20 detail once the screen has gone away
```

- `WAITING FIX` before START means the watch has no usable fix yet. START still works; the route
  simply begins at the first fix. While recording, `REC NO FIX` means the fix dropped below usable.
- `FIX` counts location events during the recording. On a continuous fix it climbs about once a
  second.
- After a save the footer alternates between the hint and a detail line,
  `FIX 712 HID 1x 34s +0`: fixes, times the screen went away, total seconds away, and fixes that
  arrived while it was away.
- On the idle screen the footer alternates between `LAST SAVED 12:04 START` (result, elapsed, how
  it ended: `START`, `BACK`, `CLOSED` or `MENU`) and the same detail line. Both survive closing
  and reopening the app.
- Error words: `NO GPS` (location events refused), `NO REC API`, `START ERR` (session or field
  creation threw), `SAVE ERR` (`save()` returned false or threw).

The `pet_mood` field is a staircase: 0 for the first minute, 1 for the second, up to 4, then back
to 0. It is written every 5 seconds and holds its value between writes, so a correct chart shows
clean one-minute steps.

## Build and install

VS Code: open `garmin-pet/probes/walk/monkey.jungle` (leave it active, as the hardware probe README
explains), then `Tasks: Run Task` and pick `Walk probe: build FR265` or `Walk probe: build VA6`.

Terminal:

```powershell
.\scripts\build-walk-probe.ps1 -OpenFolders                       # fr265
.\scripts\build-walk-probe.ps1 -Device fr265s -OpenFolders
.\scripts\build-walk-probe.ps1 -Device vivoactive6 -OpenFolders
```

The build is `bin/walk/walk-probe-<device>.prg`. Copy it into `GARMIN/Apps/` over MTP, then use the
watch's own control to leave USB mode and let it finish processing the app.

Before the first build:

- The manifest declares `Fit`, `Positioning` and `Sensor`. Garmin's permission table lists `Fit` as
  covering both `ActivityRecording` and `FitContributor`; if the compiler or the watch complains
  about a FitContributor permission, add `<iq:uses-permission id="FitContributor"/>` to
  `manifest.xml`.
- A store install asks the wearer to approve permissions; a USB sideload is expected to apply them
  without a prompt. If the watch does ask, accept.
- Because it has the `Fit` permission, the app may be listed under **Activities** rather than
  **Apps** on the watch (Garmin's manifest docs say so). Look in both lists.
- Optional log: put an empty `walk-probe-fr265.txt` (match the `.prg` name) in
  `GARMIN/Apps/LOGS/` before the walk. The app then logs `WALK_START`, `WALK_HIDE`, `WALK_SHOW` and
  `WALK_END,reason,state,elapsed,fixes,hides,hidden_s,hidden_fixes` lines there.

## Outdoor procedure (T19)

1. Charge the watch and make sure it has synced with the phone recently (fresh satellite data
   helps the first fix).
2. Go outside with a clear view of the sky. Open **Walk Probe**.
3. Stand still and wait for `READY` and `GPS GOOD` (or at least `USABLE`). Note how long it took.
4. Press START. The state becomes `RECORDING` and the timer starts.
5. Walk for about 10 minutes on a route with at least one turn, so a real map is easy to tell from
   a straight line. Glance at the screen now and then: `FIX` should climb and `HR` should show a
   number.
6. Press START to stop and save. Confirm `SAVED` and write down the elapsed time and `FIX` count.
7. Sync: open Garmin Connect on the phone and pull to refresh (or wait for the automatic sync).
8. Fill in the checklist below for that activity.

Repeat on the vivoactive 6 with its own build.

## T20 variant: leave the screen mid-walk

1. Do steps 1 to 4 above and walk for about 3 minutes.
2. While still walking, make the app leave the screen without pressing BACK. Try one at a time and
   note which you used: open an incoming notification, open the controls menu (hold LIGHT) and
   choose something, or start another app or activity from the controls.
3. Keep walking for about 2 minutes, then come back to Walk Probe if the watch allows it.
4. Read the screen:
   - Still `RECORDING` with `HID 1x 120s +0`: the app survived but got no fixes while away. Expect
     a straight-line gap in the route.
   - Still `RECORDING` with `+N` close to the seconds away: fixes kept arriving. Expect no gap.
   - The app had closed: reopen it. `LAST SAVED ... CLOSED` means the watch shut it and the walk
     was saved at that moment. Expect the activity to end where you left the screen.
5. Finish with START, sync, and compare the route with where you actually walked.

The close itself usually adds one hide to `HID`, so a walk that ended `CLOSED` shows at least
`HID 1x`.

## What to look for in Garmin Connect

- [ ] Activity appears after sync, named "Walk Probe"
- [ ] Activity type shows as **Walking**
- [ ] **Route map** present and follows the real path
- [ ] **HR graph** present, values plausible
- [ ] Distance and pace present and plausible
- [ ] **Custom field** present: look for a "Connect IQ" section near the bottom of the activity
      page, on the phone and on the website, and for a "Pet mood" chart
- [ ] Walk counts toward the day's **steps** (steps come from the wrist anyway; check the activity's
      own step count too)
- [ ] Walk counts toward **intensity minutes** for that day
- [ ] Shows up in weekly activity totals / training load like a native walk
- [ ] T20: gap, early end, or unbroken route where the app left the screen

If the custom field is missing from Connect, do not mark the probe failed yet. Connect gets a
field's labels and chart settings from the app's store package, and forum reports disagree on
whether a sideloaded `.prg`'s fields are shown. Use **Export Original** on the Connect website,
convert the `.fit` with the FIT SDK's `FitCSVTool`, and look for a developer field named
`pet_mood` stepping 0 to 4. Present in the file but absent in Connect is a real finding: the data
reaches Connect, and showing it needs a store or beta build.

## Results

| Check | FR265 | VA6 |
|---|---|---|
| Date / firmware / CIQ version | | |
| Time to first `READY` | | |
| Activity synced, name | | |
| Activity type | | |
| Route map | | |
| HR graph | | |
| `pet_mood` in Connect (where) | | |
| `pet_mood` in the raw FIT | | |
| Counts toward steps | | |
| Counts toward intensity minutes | | |
| Elapsed / `FIX` count at save | | |
| T20: how the app left the screen | | |
| T20: `HID` detail / `LAST` result | | |
| T20: route shape in Connect | | |
| Surprises | | |

Fold conclusions back into `11-hardware-test-plan.md` (results log) and the Walk/Run with me row of
`10-power-roster.md`.

## API notes

Every call was checked against Garmin's API docs; nothing here has been compiled on this machine.

- `ActivityRecording.createSession({:name, :sport})`, `Session.start/stop/save/discard/isRecording`
  and `Session.createField(name, id, type, {:mesgType, :units})`. `Activity.SPORT_WALKING` is used
  because the `ActivityRecording.SPORT_*` copies are deprecated.
- `Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method)` in its original form, with
  no GNSS `:configuration` chosen.
- `Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE])`, which the docs say enables connected ANT+
  and system sensors "if possible".
- The `resources/fit/fitcontributions.xml` wrapper element (`<resources>`) and folder are the usual
  resource layout; Garmin's article shows only the inner `<fitContributions>` block.
