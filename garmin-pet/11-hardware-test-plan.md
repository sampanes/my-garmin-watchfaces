# Hardware test plan — stub-app probes for the open ⚠️ VERIFY items

**Purpose.** A battery of tiny throwaway probes you can **spam** the next time you're at
a computer with the watches. The goal is **NOT** to build the pet app and dogfood it — it's
to upload minimal stub apps that each answer **one** platform question, either by
**self-reporting** what the API returned (AUTO) or by producing an effect **you eyeball
and record** (MANUAL — "did it beep?"). Every ⚠️ VERIFY in `10-power-roster.md` and the
open items in `open-questions.md §B2` map to a row below.

> **Why stubs, not the app:** the simulator can't answer these (no real Body Battery, no
> two-watch ANT, no real notifications/haptics, GPS/Connect sync is faked). They're
> empirical hardware facts → one probe each, ~10 lines of Monkey C, sideload, observe, log.

---

## The harness (build once, reuse for every AUTO probe)

Turnkey first pass now lives at `garmin-pet/probes/hardware/`.

- In VS Code: open `garmin-pet/probes/hardware/monkey.jungle` first and leave it
  active, then `Ctrl+Shift+P` -> `Tasks: Run Task` -> `Pet probe: build FR265`
  or `Pet probe: build VA6`. The active jungle matters because this repo also has
  a root watch-face jungle.
- In a terminal: `.\scripts\build-pet-hardware-probe.ps1 -Device fr265 -OpenFolders`
  or `.\scripts\build-pet-hardware-probe.ps1 -Device vivoactive6 -OpenFolders`.
- It builds `bin/hardware-probes/pet-hardware-probe-<device>.prg`, then you copy
  that file into the watch's `GARMIN/Apps/` folder over MTP.

The runner currently covers the cheap first-pass probes: T0/T1/T2/T7/T8/T14/T17.
Rows that need background services, GPS walks, ANT pairing, web callbacks, or
Garmin Connect inspection still need specialized one-off probe bodies.

The runner saves the last displayed result for each probe in `Application.Storage`
and shows it again when you return to that T-number. It does not export a text
log over MTP; MAN probes still require you to write down what happened.

On real hardware there's **no `System.println` console** — so AUTO probes must surface their
result **on the watch screen** (and/or stash it in `Storage` to dump). Minimal skeleton:

```monkeyc
// ProbeApp.mc — one harness, swap the body of probe() per test
using Toybox.Application;
using Toybox.WatchUi;
using Toybox.Graphics;

class ProbeApp extends Application.AppBase {
    function getInitialView() { return [ new ProbeView(), new ProbeDelegate() ]; }
}
class ProbeView extends WatchUi.View {
    var line = "press SELECT";
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        dc.drawText(dc.getWidth()/2, dc.getHeight()/2,
            Graphics.FONT_SMALL, line, Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);
    }
    function report(s) { line = s; WatchUi.requestUpdate(); }   // AUTO probes call this
}
class ProbeDelegate extends WatchUi.BehaviorDelegate {
    function onSelect() { probe(); return true; }                // fire the probe on the primary button
}
```

- **AUTO probe** = inside `probe()`, call the API, `try/catch`, and `report(...)` the value /
  `"null"` / exception / error code. Read it off the watch face.
- **Accumulate** multiple readings by appending to `Application.Storage` under a probe key and
  rendering the last N lines — handy for sensors that update over time.
- **Background probes** (T5, T25-bg) need a `ServiceDelegate` with `onTemporalEvent()` +
  `Background.registerForTemporalEvent(...)`; then **close the app and wait** (≥5 min floor).
- **MANUAL probe** = `probe()` triggers the effect (tone/vibe/notification/exitTo); you watch
  the physical watch and record the outcome — `report()` just confirms the call didn't throw.
- **Kitchen-sink manifest:** give the harness ALL the permissions up front so you never
  re-edit the manifest between probes: `Fit FitContributor Positioning Sensor SensorHistory
  SensorLogging Communications Background Ant UserProfile Complications PersistedContent
  Notifications`. (Some need a paired phone in BT range — flagged per row.)
- Build/sideload: `monkeyc -d fr265 ...` / `-d vivoactive6 ...` → copy the `.prg`/`.iq` to
  `GARMIN/Apps/`. Run on each device as the row's "Dev" column says.

---

## Test battery

Priority: ⭐ = high-value (resolves a locked decision or a flagship power) · ▫ = nice-to-have.
Cap: **AUTO** = stub self-reports · **MAN** = you observe & record.

### A — Haptics & tones (MAN)
| ID | Resolves | Stub calls | Observe / record | Dev |
|----|----------|-----------|------------------|-----|
| ⭐ T1 | VA6 "no tone generator"; FR265 melody works | `Attention.playTone(Attention.TONE_SUCCESS)`; then a `ToneProfile` freq+dur sequence | Beep on FR265? Custom melody plays? Silent on VA6? | 🔵🟢 |
| ⭐ T2 | FR265 "single duty cycle"; VA6 honors patterns | `Attention.vibrate([new VibeProfile(25,200), new VibeProfile(100,200), new VibeProfile(25,200)])` | Distinct rhythm/intensity, or one flat buzz? Per device. | 🔵🟢 |
| ▫ T3 | Backlight control | `Attention.backlight(true)` | Screen brightens? | 🔵🟢 |

### B — Proactive notification / nag (MAN + AUTO) — the `06` finding
| ID | Resolves | Stub | Observe / record | Dev |
|----|----------|------|------------------|-----|
| ▫ T4 | Foreground notification works + actions | `Notifications.showNotification("Buddy","hi",{:actions=>…})` on SELECT | Banner appears? Action buttons fire callback? | 🔵🟢 |
| ⭐ T5 | **Does showNotification fire from BACKGROUND with the app closed?** (loosens `06`) | `ServiceDelegate.onTemporalEvent()` calls `showNotification`; register 5-min temporal; **close app** | After ≥5 min, app closed: does a notification appear? Does it **buzz**? How intrusive? Record timing. | 🔵🟢 |
| ▫ T6 | `requestApplicationWake` is prompt-only | call it from `onTemporalEvent` | Confirm it shows "open app?" dialog (expected), not silent launch | 🔵🟢 |

### C — Biometrics / sensors (AUTO — render value or "null")
| ID | Resolves | Stub calls | Observe / record | Dev |
|----|----------|-----------|------------------|-----|
| ⭐ T7 | Body Battery readable by a **device app** (not just sim/watchface) | `SensorHistory.getBodyBatteryHistory({})` → `.next().data`; also try `Complications` subscribe | Real 0–100 value, or null/empty? | 🔵🟢 |
| ⭐ T8 | Stress value + the iterator timestamp bug | `ActivityMonitor.getInfo().stressScore`; `SensorHistory.getStressHistory({})` → `.next().data`, and print `getOldest/NewestSampleTime()` | Live value present? Are the history timestamps sane or garbage? | 🔵🟢 |
| ▫ T9 | Respiration live | `ActivityMonitor.getInfo().respirationRate` | breaths/min or null? | 🔵🟢 |
| ▫ T10 | SpO2 live + history | `Sensor.getInfo().oxygenSaturation`; `SensorHistory.getOxygenSaturationHistory({})` | value or null (note if intermittent)? | 🔵🟢 |
| ⭐ T11 | **DIY HRV feasibility** — do beat intervals populate & vary at rest? | `Sensor.registerSensorDataListener({:heartBeatIntervals=>true,...})`; render count + first few R-R ms | Varying ms (real) or constant 1000 ms (interpolated)? Do they appear **outside** a recording? Inside one? | 🔵🟢 |
| ▫ T12 | Recovery time | `ActivityMonitor.getInfo().timeToRecovery` | hours or null? | 🔵🟢 |
| ▫ T13 | Training-status complication (crash-prone) | `try { Complications.getComplication(TRAINING_STATUS) }` | string returned, or crash/null? (wrap in try/catch) | 🔵🟢 |
| ▫ T14 | VO2max | `UserProfile.getProfile().vo2maxRunning` | number or null? | 🔵🟢 |
| ⭐ T15 | **Can a device app SUBSCRIBE to complications** (BB/stress/etc.), or watchface-only? | `Complications.subscribeToUpdates(id)` + `registerComplicationChangeCallback` in the device app | Do callbacks fire with data, or nothing? (decides whether to use Complications vs `ActivityMonitor`/`SensorHistory`) | 🔵🟢 |

### D — Device-split capabilities (AUTO + `has`-gate)
| ID | Resolves | Stub | Observe / record | Dev |
|----|----------|------|------------------|-----|
| ⭐ T16 | 🟢 Sleep score (API 6.0.2) | `Complications.getComplication(SLEEP_SCORE)` | VA6: 0–100? FR265: `has` false / unavailable? | 🔵🟢 |
| ⭐ T17 | 🔵 Barometer split | `Sensor.getInfo().pressure`/`.altitude`; `ActivityMonitor.getInfo().floorsClimbed` | FR265 non-null; VA6 null/zero? | 🔵🟢 |
| ▫ T18 | 🟢 QR / `Barcodes` module | `if (Toybox has :Barcodes) render QR` | VA6 renders scannable QR? FR265 module absent? Confirm real module name. | 🔵🟢 |

### E — Activity recording → Garmin Connect map (AUTO + MAN-in-Connect) — the flagship
| ID | Resolves | Stub | Observe / record | Dev |
|----|----------|------|------------------|-----|
| ⭐ T19 | **"Walk with me" lands in Connect with a map + HR** | `createSession({:sport=>SPORT_WALKING})`; `Position.enableLocationEvents(LOCATION_CONTINUOUS,cb)`; `Sensor.setEnabledSensors([SENSOR_HEARTRATE])`; add a `FitContributor` field; walk ~3 min; `save()` | After sync: activity in Garmin Connect **with a route map**? HR graph present? Custom field visible? | 🔵🟢 |
| ▫ T20 | GPS track stops when app backgrounds | start T19, then background the app mid-walk | Straight-line gap in the route where it backgrounded? (confirms FG-only) | 🔵🟢 |

### F — Navigation (MAN — app exits)
| ID | Resolves | Stub | Observe / record | Dev |
|----|----------|------|------------------|-----|
| ⭐ T21 | `exitTo` launches native nav to the right coords | `var w = PersistedContent.saveWaypoint(loc,{:name=>"Test"}); System.exitTo(w.toIntent())` | Native turn-by-turn launches? Coords correct (watch the Fenix-gen bug)? App exited? | 🔵🟢 |
| ▫ T22 | Waypoint persists after app exit | run T21, then browse the watch's saved locations | "Test" waypoint present in saved locations? | 🔵🟢 |

### G — ANT encounter (MAN — needs BOTH watches) — see `03 §Spike B` for full protocol
| ID | Resolves | Stub | Observe / record | Dev |
|----|----------|------|------------------|-----|
| ⭐ T23 | ANT master TX runs on wrist devices | open `GenericChannel` `CHANNEL_TYPE_TX_NOT_RX`, `NETWORK_PUBLIC`, RF≠57, device# ≠0; `sendBroadcast(8 bytes)` | Channel opens without error on FR265? on VA6? (ran clean on FR745) | 🔵🟢 |
| ⭐ T24 | Two watches actually exchange a payload | one build master, one slave (`RX_NOT_TX`), same params | Slave receives the 8-byte payload? Latency? Range in a room? (BurstPayload bug is sim-only — confirm) | 🔵+🟢 |

### H — Web & weather (AUTO — render value / error code)
| ID | Resolves | Stub | Observe / record | Dev |
|----|----------|------|------------------|-----|
| ▫ T25 | `makeWebRequest` to a **static** JSON gist (no backend), incl. background | GET a `{"q":"…"}` gist over HTTPS; render payload or error code; then a background variant | Success + value? Error code (-400 array-root / -402 / -403 / -104 no-phone)? Background round-trip < 30 s? | 🔵🟢 |
| ▫ T26 | Weather cache availability | `Weather.getCurrentConditions()`; `Weather.getSunrise(loc,now)` | fields populated or null (needs recent phone sync)? | 🔵🟢 |

---

## Results log (fill in as you go — then fold conclusions back into the docs)

Record: **date · firmware/CIQ version · device · PASS/FAIL/value · surprises.** When a row
resolves, update the matching ⚠️ VERIFY in `10-power-roster.md` and/or `open-questions.md §B2`
(promote to ✅ or move to a dead end), and bump any locked decision it affects (esp. T5 → `06`).

| ID | Date | Device / fw | Result | Notes |
|----|------|-------------|--------|-------|
| _e.g. T1_ | _2026-0x-xx_ | _FR265 / 19.xx_ | _PASS — beeped_ | _melody played fine_ |
| T1 | 2026-06-25 | FR265 / SW 28.05 / CIQ VM 5.2.0 | FAIL — no audible beep | `Attention.playTone(Attention.TONE_SUCCESS)` produced no audible tone on hardware. Custom `ToneProfile` not yet separately tested. |
| T2 | 2026-06-25 | FR265 / SW 28.05 / CIQ VM 5.2.0 | CONFIRMED — flat buzz, no pattern | 25/100/25 `VibeProfile` sequence collapsed to one flat vibration. |
|  |  |  |  |  |

### Priority order if time is short
1. **T19** (Walk-with-me → Connect map) — the flagship power's core proof.
2. **T5** (background notification) — could rewrite `06`'s proactive-nag stance.
3. **T23/T24** (ANT encounter) — the only no-backend in-person social path (`03`).
4. **T7/T11/T15** (Body Battery / DIY HRV / complication-subscribe) — unlock the richest sense powers.
5. **T1/T2** (tones/haptics device-split) + **T16/T17** (sleep/baro split) — cheap, fast, confirm the cross-device beat.

## Cross-refs
- `10-power-roster.md` — every ⚠️ VERIFY tag here maps to a power there
- `open-questions.md §B2` — the platform unknowns; promote items as probes resolve them
- `03-ble-live.md §Spike B` — the full ANT FR265↔VA6 channel protocol (T23/T24 detail)
- `06-companion-app.md` — T5 may loosen the locked "proactive nag needs the phone" stance
- `01-solo-game.md` — T19/T20 (recording), the sense probes feed the differentiator
