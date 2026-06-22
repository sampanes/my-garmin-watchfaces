# Power roster — the concrete unlockable-capability catalog

The menu behind `05-progression.md §"What 'power' means"`. `05` is the *philosophy*
(a power = a capability the pet can **sense / say / do**, never a stat multiplier;
functional = changes the loop, expressive = flavor only). **This doc is the actual
list of real Connect IQ capabilities** that can become earned powers, grounded in the
API surface (web research 2026-06-22, 3 parallel sweeps of developer.garmin.com +
forums). Each is a *candidate* — none is committed scope; pacing/gating still flows
through the `05` ladder + the evolution bands kicked can.

> **Confidence tags** (same convention as `open-questions.md §B`): **[OFFICIAL]** =
> developer.garmin.com API docs · **[FORUM]** = named forum confirmation · **[FOLKLORE]**
> = community estimate · **⚠️ VERIFY** = needs a hardware stub test → see `11-hardware-test-plan.md`.
>
> **Device legend:** ⚪ both · 🔵 FR265/265S only · 🟢 VA6 only. Always `has`-gate
> anything not ⚪, and anything above each device's CIQ floor (FR265 = 5.2.0, VA6 = 6.0.0).
>
> **Reminder — almost every "sense/do" power is FOREGROUND-ONLY.** Sensors, GPS, the
> accel listener, tones all stop when the app goes inactive. Background gets 64 KB, a
> ≥5-min floor, ~30 s/run, and can't drive UI/vibe/tones (it *can* call `makeWebRequest`,
> `showNotification`, `Storage`, and publish complications). This shapes which powers are
> live vs after-the-fact (`01 §"Live vs after-the-fact"`).

---

## 🧠 SENSE — the pet learns to perceive something new about you

The richest vein, and it pays straight into the "feed the pet with your body" +
daily check-in arc (`01`). The pattern: a new sense = a new branch in the pet's
reactions/dialogue (and the persona colors the wording, `07`).

| ⭐ | Power | API | Type | Dev | Conf | Notes / caveat |
|---|---|---|---|---|---|---|
| ⭐ | **Recovery refusal** ("coach's orders") | `ActivityMonitor.timeToRecovery` (3.3.0) · `COMPLICATION_TYPE_RECOVERY_TIME` (4.2.0) | FUNCTIONAL | ⚪ | [OFFICIAL] | Pet *refuses* to push a hard session when you're in recovery debt → gives the tough-love coach real **consequence**, not just lines. The most on-brand power you have. |
| ⭐ | **Stress sense** | `ActivityMonitor.stressScore` live (5.0.0) · `SensorHistory.getStressHistory()` (3.3.0) | FUNCTIONAL | ⚪ | [OFFICIAL] | Drives the "biometrics tell the story → it reacts, doesn't ask" evening beat (`01`). ⚠️ stress-history iterator's `getOldest/NewestSampleTime()` may return garbage (forum) — use `.next().data`. |
|   | **Energy reader** (Body Battery) | `COMPLICATION_TYPE_BODY_BATTERY` (4.2.0) live · `SensorHistory.getBodyBatteryHistory()` (3.3.0) | FUNCTIONAL | ⚪ | [OFFICIAL] | Morning hello branches on it (charged vs drained). ⚠️ VERIFY: returns no data in the simulator (device-only); and confirm a *device app* can read it (subscriber may be watchface-only — T7/T15). |
|   | **Breath sense** | `ActivityMonitor.respirationRate` live (3.3.0) | FUNCTIONAL | ⚪ | [OFFICIAL] | Pet notices breathing quicken; anchors a breathwork/calm beat. |
| ⭐ | **Morning readiness (DIY HRV)** | `Sensor.registerSensorDataListener` → `heartRateData.heartBeatIntervals` → compute RMSSD yourself | FUNCTIONAL | ⚪ | [FORUM] | An *earned ritual*: "sit still with me 2 min" → pet reads your nervous system. ⚠️ wrist optical interpolates at low HR (constant 1000 ms ≠ real variability) → frame as a vibe-check, not a number; real HRV wants an ANT+ strap. Garmin's polished **HRV Status label is NOT exposed** — this DIY path is the only way in. ⚠️ VERIFY intervals populate at rest + outside a recording (T11). |
|   | **Pulse-ox sense** (SpO2) | `Sensor.oxygenSaturation` live (3.2.0) · `SensorHistory.getOxygenSaturationHistory()` | FUNCTIONAL | ⚪ | [OFFICIAL] | Both watches have the sensor. ⚠️ intermittent unless all-day/sleep SpO2 is enabled by the user. |
|   | **Fitness-trajectory sense** | `UserProfile.vo2maxRunning/Cycling` (3.3.0) · `COMPLICATION_TYPE_TRAINING_STATUS` (4.2.0) | FUNCTIONAL | ⚪ | [OFFICIAL] | "Are you building or coasting?" + aerobic ceiling. ⚠️ training-status complication crashes on some devices (forum) — `has`-gate + try/catch (T13). |
|   | **Daily rhythm** (baseline) | `ActivityMonitor.getInfo()` steps/calories/activeMinutes + `getHistory()` 7-day | FUNCTIONAL | ⚪ | [OFFICIAL] | The always-on baseline sense (no permission). Daily aggregates only — no per-event timestamps (`01`/`open-questions §C`). |

### 🎁 The device-split senses — each watch awakens one the other can't
A genuinely cool cross-device beat: frame the hardware gap as *"your model unlocks a
sense the other can't feel."*

| Power | API | Dev | Conf | Notes |
|---|---|---|---|---|
| 🟢 **Sleep sense** | `COMPLICATION_TYPE_SLEEP_SCORE` (needs **API 6.0.2**) | 🟢 VA6 only | [OFFICIAL] | Pet wakes differently after a good vs rough night. FR265 (CIQ 5.2) **cannot** read it at all. ⚠️ VERIFY 6.0.2 on VA6 firmware (T16). Note: sleep *stages* (deep/REM) are exposed to **no one** — feature request open since 2022. |
| 🔵 **Thin-air / altitude sense** | barometer: `Sensor.altitude`/`pressure`, `SensorHistory.getElevation/PressureHistory`, `ActivityMonitor.floorsClimbed` | 🔵 FR265 only | [OFFICIAL] | "Feels the air thin as you climb"; floors-climbed mechanic. VA6 has no barometer → null/empty (GPS altitude only). |

---

## 🏃 DO — the pet acts on the world

| ⭐ | Power | API | Type | Dev | Conf | Notes / caveat |
|---|---|---|---|---|---|---|
| ⭐ | **Walk/Run with me** (locked, `01`) | `ActivityRecording.createSession` + `Position.enableLocationEvents` + `Sensor.setEnabledSensors([HR])`; `FitContributor` for custom fields | FUNCTIONAL | ⚪ | [OFFICIAL]+[FORUM] | Pet records a real FIT → syncs to Garmin Connect **with a map**, no backend (`01`). ⚠️ GPS+HR are **not** auto-recorded — must enable both; FG-only (track stops if app backgrounds, T19/T20). 77 SPORT_* / 98 SUB_SPORT_* types. |
| ⭐ | **Mark our spot / Take me home** | `PersistedContent.saveWaypoint(loc, {:name})` + `System.exitTo(waypoint.toIntent())` | FUNCTIONAL | ⚪ | [OFFICIAL]+[FORUM] | Stamp a named landmark ("Buddy's Oak") that **persists on the watch**, or save the walk's start + fire native turn-by-turn home. ⚠️ `exitTo` **quits the pet app**; same-SDK-gen coord bug seen on Fenix/Epix (T21). Can *read* courses (`getCourses`) but can't author new ones on-device. |
|   | **Rep counter** (`04`) | `Sensor.registerSensorDataListener({:accel,:sampleRate=>25})`; `SensorLogging` to embed raw accel in the FIT | FUNCTIONAL | ⚪ | [OFFICIAL]+[FORUM] | Pet watches you train and counts. Device-app FG-only; 25 Hz max; battery-heavy → session-scoped. The most interactive power. |
| 🔵 | **Plays you a tune** | `Attention.playTone` (19 named tones) + custom `ToneProfile` melody (freq+dur sequence) | EXPRESSIVE | 🔵 FR265 only | [OFFICIAL] | A little victory jingle on goal-hit. **VA6 lacks a tone generator** per docs → `playTone` likely no-ops there (inversion of the device-split, T1). |
|   | **Haptic emote / "morse"** | `Attention.vibrate([VibeProfile,…])` (≤8 profiles, duty% + ms) | EXPRESSIVE | ⚪ (rhythm 🟢-leaning) | [OFFICIAL] | Pet "speaks" in buzz patterns (double-tap = hi, long pulse = hungry). ⚠️ **FR265 = single duty cycle** (no rhythm/intensity) per docs; VA6/Venu-class likely honors patterns (T2). |
|   | **Bike buddy** | `AntPlus.PowerMeter` (and cadence/speed) | FUNCTIONAL | ⚪ | [OFFICIAL] | Reacts to FTP zones. Needs a paired sensor → niche/later. Note **HR/temp are NOT exposed via AntPlus** (read HR from optical via `Sensor`). |

---

## 📡 CONNECT / PRESENCE — the pet escapes the app

| ⭐ | Power | API | Type | Dev | Conf | Notes / caveat |
|---|---|---|---|---|---|---|
| ⭐ | **Proactive nag (no companion?)** | `Notifications.showNotification` (5.1.0) — **docs say background-callable** | FUNCTIONAL | ⚪ | [OFFICIAL] ⚠️ | **Potentially loosens `06`'s locked stance** that proactive nagging needs the phone. The watch may post "haven't moved in 2 hrs" from a ≥5-min background event with **no companion app**. ⚠️ VERIFY does it appear/buzz with the app closed (T5). Distinct from `requestApplicationWake` (always a confirm dialog) and from background vibrate (not allowed). |
|   | **Ambient presence** | `Complications.updateComplication` (publish ≤4, even from background; persists when app closed) | FUNCTIONAL | ⚪ | [OFFICIAL]+[FORUM] | Pet's mood ("HAPPY 87") leaks onto the watch face. ⚠️ needs a complication-aware watch face (most stock faces don't subscribe); device-app **publish** works, device-app **subscribe** may be watchface-only (T15). |
|   | **Peek** (glance) | `WatchUi.GlanceView` via `AppBase.getGlanceView()` (3.1.0) | FUNCTIONAL | ⚪ | [OFFICIAL] | Pet's face in the swipe-up glance loop without opening the app; reads cached state from `Storage`. Restricted draw context (no layers/full-screen dc). |
| ⭐ | **Encounter (in-person, no backend)** | `Ant.GenericChannel` master `CHANNEL_TYPE_TX_NOT_RX` on `NETWORK_PUBLIC`, 8-byte payload (avoid RF 57) | FUNCTIONAL | ⚪ | [FORUM] ⚠️ | Two pets detect each other over ANT (~3–5 m) → visit/gift/XP. The no-phone social layer (`03 §Spike B`, `02`). Ran clean on a Forerunner 745; "Chess! – Blind Knights" is a shipped FR↔FR proof. ⚠️ VERIFY TX on FR265+VA6 + payload arrival across two watches (T23/T24). **BLE watch-to-watch is impossible** (central-only) — ANT is the only path. |
| 🟢 | **QR friend code** | CIQ 9 barcode rendering (`Toybox.Barcodes`, 6.0.0) | FUNCTIONAL | 🟢 VA6 only | [FOLKLORE] ⚠️ | VA6 shows your friend code as a scannable QR for add-a-friend (`02`); FR265 (CIQ 8) falls back to a typed code. ⚠️ VERIFY module name + render (T18). |
|   | **Daily oracle** | `Communications.makeWebRequest` → a **static** JSON gist/CDN (no real backend) | FUNCTIONAL | ⚪ | [OFFICIAL] | Pet brings a daily fact/quote or holiday-aware line. HTTPS-only; **JSON object at root** (array root → -400); ≥5-min bg; exit payload ~8 KB cap; JSON parse inflates ~3× heap (T25). |
|   | **Weather sense** | `Toybox.Weather.getCurrentConditions/getDaily/Hourly/getSunrise/Sunset` (3.2.0/3.3.0) | FUNCTIONAL | ⚪ | [OFFICIAL] | **Free, cached, zero network cost** (Garmin pre-syncs it). Pet shelters in rain, sunscreens at high UV, howls at thunder; sunrise/sunset gates morning/night. Feeds the ACNH alive-clock (`01`). ⚠️ returns null if phone hasn't synced. |

---

## 🚫 Confirmed dead ends (don't chase these)

| Wanted | Verdict |
|---|---|
| Watch-to-watch **BLE** | ❌ CIQ BLE is central-only (no advertise/GATT server). ANT is the only in-person path. |
| **Silent** server→watch push | ❌ none; `requestApplicationWake` always shows a confirm dialog. |
| **Sleep stages** (deep/light/REM) | ❌ no CIQ API (feature-requested since 2022). Sleep *score* is VA6-only (above). |
| Garmin **HRV Status** label | ❌ firmware-only; not exposed. DIY RMSSD (above) is the workaround. |
| Arbitrary **audio / TTS** | ❌ device apps can't use `Toybox.Media`; only tone beeps. |
| **Training load / acute:chronic / body composition / race predictor** | ❌ not in CIQ at all. |
| Custom **vibration rhythm on FR265** | ❌ single duty cycle only (VA6 likely OK). |
| **Tones on VA6** | ❌ no tone generator. |
| `Communications.transmit` **without a companion app** | ❌ Garmin Connect Mobile won't relay it; needs a CIQ Mobile SDK companion (`06`). |

---

## How this feeds the `05` ladder

- **Functional powers** above = the paced-out capability ladder `05` describes (sensing
  roadmap, nag, challenges) — each has consequence and is *earned*.
- **Expressive powers** (tune, haptic emote) join emotes/greeting-routine vocabulary (`02`)
  — zero consequence, the visitor-greeting raw material.
- **Evolution signature power** (`05 §still-open`): a branch granting **one signature
  functional power + a look** could draw its signature from this roster (e.g. a "mountain"
  branch → thin-air sense 🔵; a "rest/zen" branch → recovery-refusal + HRV ritual).
- **Device-split senses** are a free differentiator, not a fork — the *same* app awakens
  whichever senses the hardware supports (`08 §"One app, not two"`); `has`-gate, never branch the codebase.

## Cross-refs
- `05-progression.md` — the power philosophy + functional/expressive split this catalog instantiates
- `01-solo-game.md` — sense powers feed the differentiator + daily check-in; Walk-with-me lives here
- `04-activity-sensing.md` — rep counter + HR/physiology fallback
- `03-ble-live.md §Spike B` — the ANT encounter protocol
- `06-companion-app.md` — proactive nag (and the `showNotification` finding that may change it)
- `11-hardware-test-plan.md` — the stub tests that resolve every ⚠️ VERIFY above
- `open-questions.md §B2` — platform unknowns these powers depend on
