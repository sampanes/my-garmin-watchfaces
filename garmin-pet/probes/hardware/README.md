# Pet Hardware Probe Runner

This is the turnkey first pass for `11-hardware-test-plan.md`: one small watch app you build, sideload, run on the real watches, and record.

It currently covers:

- T0 device info: screen and burn-in flags
- T1 tone — also shows `SND YES/NO` (the system tones setting): `playTone` is
  silently suppressed when tones are off, so "no beep" alone is ambiguous
- T2 vibration pattern — also shows `VIB YES/NO` (`vibrateOn`)
- T7 Body Battery history — distinguishes `NO API` (module/method absent) /
  `NO ITER` (getter returned null) / `NULL` (no samples) / value
- T8 stress live/history — same guards, plus the newest sample's age in minutes
  (the timestamp-sanity half of T8)
- T14 VO2max profile values
- T17 barometer / floors split

The remaining rows in `11-hardware-test-plan.md` need specialized probes because they require background services, activity recording, ANT pairing, notifications, GPS walks, or web callbacks.

## VS Code Path

1. Open this repo in VS Code.
2. Open `garmin-pet/probes/hardware/monkey.jungle` and leave that file active before pressing `Ctrl+Shift+P`.
   This repo has multiple jungle files; if the root `monkey.jungle` is active, VS Code/Garmin commands can target the Japanese Ink watch face instead of this probe app.
3. Press `Ctrl+Shift+P`.
4. Run `Tasks: Run Task`.
5. Pick `Pet probe: build FR265` or `Pet probe: build VA6`.
6. The task writes a `.prg` under `bin/hardware-probes/` and opens that folder.
7. Plug in the watch. In File Explorer, open the watch, then `GARMIN/Apps/`.
8. Copy the `.prg` into `GARMIN/Apps/`.
9. Eject/disconnect the watch and launch `Pet HW Probe`.
10. Use up/down to choose a probe. Press Select to run it.
11. Record the result in `garmin-pet/11-hardware-test-plan.md`.

The app saves the last displayed result for each probe in `Application.Storage`,
so returning to a T-number shows the most recent value again. It does **not**
export a text log from the watch. For MAN probes like tone/vibration, you still
need to write down what you observed because the app cannot detect whether you
heard a beep or felt a distinct pattern.

On the FR265, those saved values show up over MTP as binary object-store files
under `GARMIN/Apps/DATA` (`pet-hardware-probe-*.DAT/.IDX/.IMT`). They are useful
to the app, but not useful as a human-readable log.

## Terminal Path

```powershell
.\scripts\build-pet-hardware-probe.ps1 -Device fr265 -OpenFolders
.\scripts\build-pet-hardware-probe.ps1 -Device vivoactive6 -OpenFolders
```

If the script cannot find your SDK or developer key, pass them explicitly:

```powershell
.\scripts\build-pet-hardware-probe.ps1 `
  -Device fr265 `
  -SdkPath "<Connect IQ SDK folder>" `
  -DeveloperKey "<developer key path>" `
  -OpenFolders
```

## Important Limit

Windows exposes modern Garmin watches over MTP, not as normal drive letters. The build script opens the output folder and `This PC`, but the final copy into `GARMIN/Apps/` is still a drag/drop step.
