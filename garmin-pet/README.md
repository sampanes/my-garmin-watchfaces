# garmin-pet — design notes

Notes/research for a Tamagotchi-style virtual-pet **app** for Garmin wearables.
This is a notes folder (markdown), **not code yet** — snippets are illustrative only.

> **Grounded in repo research (2026-06-15).** The hardware/platform facts below
> were reconciled against this repo's own docs (`common/architecture/SPEC_*`,
> `beyond_faces/*`, `common/workflow/MULTI_DEVICE_STRATEGY.md`). ⚠️ That reconcile
> ran against the **cloned GitHub remote**, which trails your unpushed local work —
> re-check anything surprising against the local repo on your personal PC.

> **Where this lives:** a subfolder of `my-garmin-watchfaces`, peer to `watch-faces/`
> and `beyond_faces/`. It's a Connect IQ **device app** (interactive, launched from
> the app list), not a watch face — a different animal from the rest of the repo,
> but it reuses your device targets, tooling, and the research docs cross-linked below.

## The three tracks

| # | Track | Certainty | File |
|---|-------|-----------|------|
| 1 | **Solo game** — the pet itself, offline, single-device | High — clearly doable | [01-solo-game.md](01-solo-game.md) |
| 2 | **Async social** — ACNH-style visits, gifts, mailbox | Medium — doable, needs *your* backend + *your* friend graph | [02-async-social.md](02-async-social.md) |
| 3 | **Live co-presence** — pets "meet" when physically together | Low — **direct BLE ruled out**; ANT unproven; plan for phone-bridged | [03-ble-live.md](03-ble-live.md) |

Track 1 add-on capability: [04-activity-sensing.md](04-activity-sensing.md) — the pet
reacts to lifting / push-ups via accelerometer rep-counting (sidesteps Garmin's clunky
Strength activity).

**Cross-cutting spine:** [05-progression.md](05-progression.md) — the three-layer
progression/ownership model (how the pet "scales up" without becoming a paralyzing
skill-tree *or* an ownerless treadmill). Underpins both Track 1 and Track 2.

What's now confirmed vs still open: [open-questions.md](open-questions.md).

**Watch UX spine:** [08-watch-interaction-model.md](08-watch-interaction-model.md) —
the behavior-first, one-primary-action control model. This is the current answer to
"what can the user do on the watch?" and it supersedes older touch-first thinking.

**Appearance & transfer spine:** [09-appearance-and-transfer.md](09-appearance-and-transfer.md) —
the composable-sprite layer model (additive heap cost, multiplicative variety) and how a pet
— a tiny versioned integer blob, not image data — moves between watches: a personal/no-backend
export vs a deferrable paid backend.

**Power catalog:** [10-power-roster.md](10-power-roster.md) — the concrete menu of unlockable
*capabilities* (sense / do / connect) behind `05`'s power philosophy, grounded in the real CIQ
API surface, with device gating (🔵 FR265 / 🟢 VA6) and confidence tags.

**Hardware test plan:** [11-hardware-test-plan.md](11-hardware-test-plan.md) — a battery of tiny
stub-app probes to spam at a computer to resolve every ⚠️ VERIFY (does it beep / does Body Battery
read / does the walk hit Connect with a map / does ANT pair). Self-reporting or eyeball-and-record.

## Build stance (2026-06-16 sanity pass)

The watch-native core is the product: **Track 1 + the activity buddy**. Build the
offline pet first, then add the foreground rep-counting loop once the care loop is
pleasant on real hardware.

Use the other tracks as gated expansions:
- **Track 2 social** is a second product, not a feature. Only start it after the solo
  loop is sticky enough to justify backend/auth/privacy/ops.
- **Track 3 live co-presence** is a hardware spike. It must not block Tracks 1-2; if
  ANT fails on real watches, fall back to phone/server-brokered visits or drop it.
- **Companion app** is Tier 2. Its first real job is proactive nudging / QR friend-add /
  account management, not becoming the main pet home.

Tone guardrail: ship personas as **Drill Sergeant / Hype Cheerleader / Deadpan / Zen**.
"Asshole coach" is useful internal shorthand, but product copy should roast effort gaps,
not bodies, worth, or identity.

## Target hardware (two devices) — confirmed from repo SPEC docs

| Device | Display | Shape | Input | Notes |
|--------|---------|-------|-------|-------|
| Forerunner 265 | 416×416 AMOLED, 16-bit | round | touch + **5 buttons** | has barometer; System 7 |
| Forerunner 265S | 360×360 AMOLED, 16-bit | round | touch + **5 buttons** | smaller sibling; System 7 |
| Vivoactive 6 | 390×390 AMOLED (to 1500 nits) | round | touch + **2 buttons + Action Notch** | **no barometer**; System 8 |

**Design implications:**
- **Three resolutions** (416 / 360 / 390) → relative/scaled layouts, per-device resource sets. See `common/workflow/MULTI_DEVICE_STRATEGY.md` (jungle `resourcePath` + scale factor, or the JSON "configurator" layout pattern).
- **Two input profiles** → behavior-first; never *require* 5 buttons or tiny touch targets.
  Design for one primary action + Back + page navigation, with FR265's extra buttons as
  accelerators. See `08-watch-interaction-model.md`.
- **No barometer on VA6** → gate barometric/altitude features with `has`.

## Memory budget (the real design constraint) — from installed SDK `compiler.json`

Read directly from `compiler.json` in the active **SDK 9.1.0** (`Devices/fr265/` and
`Devices/vivoactive6/`). The two targets are **identical**:

| Heap tier | FR265 / 265S | Vivoactive 6 |
|-----------|--------------|--------------|
| **Device app / `watchApp`** (our type) | **768 KB** | **768 KB** |
| Background process | **64 KB** | **64 KB** |
| Glance | 64 KB | 64 KB |
| Data field | 256 KB | 256 KB |
| Watch face (not our type) | 128 KB | 128 KB |

> **Design both watches to 768 KB.** There is no tighter VA6 ceiling — the old
> "256–512 KB VA6" figure was wrong. **Background sync gets 64 KB** (not 32 KB), which
> roughly doubles the social-payload headroom, though the JSON parser can still crash on
> a large response so keep payloads tiny. Memory deep-dive: `common/memory/MEM_PART1..3`.
>
> ✅ **CONFLICT RESOLVED (2026-06-19).** The community read of Garmin's `compiler.json`
> (uniform **768 KB device-app / 64 KB background** across FR265 / 265S / VA6) was
> **correct**; the prior SPEC-doc figures here (1 MB FR265 / 256–512 KB VA6 / 32 KB bg)
> were **wrong** and have been replaced with the values read from the installed SDK.
> Note: this is the **heap** budget. Persistent **Storage (disk)** is separate and now also
> settled — `simulator.json` reports `appStorageCapacity` = **10 MB on both** devices (total
> app-data). The only tight Storage limit is **32 KB per `Storage` value** (`StorageFullException`
> past it), so save-state headroom is effectively a non-issue — design to the 768 KB *runtime
> heap*, not disk. See `open-questions.md §B2`.

## SDK / API target — from SPEC docs + installed SDK

- **Device API floors (from `compiler.json`):** FR265 min CIQ **5.2.0**, VA6 min CIQ **6.0.0**.
  A single binary targeting both must not call APIs above what either device's firmware provides
  — **gate newer/System-8-only features with the `has` operator** so FR265 still builds/runs.
- **Active installed SDK: 9.1.0** (2026-03-09); 8.1.1 also installed. (Earlier notes said "build
  with 8.1.1" — superseded.)

## Connectivity model (shapes every social idea)

The watch has **no independent internet** — only via the paired phone:

```
 [Watch app] --BT/CIQ--> [Garmin Connect Mobile] --HTTPS--> [YOUR backend]
                          (no phone / no signal / battery-saver = no sync)

 optional companion route:
 [Watch app] <--CIQ Mobile SDK--> [YOUR phone app] --internet--> [YOUR backend]
```

Two hard truths that recur below:
1. **No Connect IQ API to your Garmin Connect friends.** Any "friends" feature is
   *your own* network (friend codes, your accounts, your server). Garmin = device + pipe.
2. **No real-time server→watch push.** You poll (on open, or background ≥5 min, 32 KB,
   30 s). Social = asynchronous. Track 3 explores the one exception: direct radio in person.

## Reference docs in this repo (cross-links)

| Theme | Best file(s) |
|-------|--------------|
| Device specs | `common/architecture/SPEC_FORERUNNER_265.md`, `SPEC_VIVOACTIVE_6.md`, `COMPARISON_MASTER.md` |
| Memory | `common/memory/MEM_PART1_ARC_AND_LEAKS.md`, `MEM_PART2_OVERHEAD_AND_TYPES.md`, `MEM_PART3_OPTIMIZATION_AND_TOOLS.md` |
| Lifecycle / power / AMOLED | `common/architecture/APP_LIFECYCLE_AND_POWER.md`, `AMOLED_BURN_IN.md` |
| Graphics / rendering | `common/graphics/DC_PART1_PRIMITIVES.md` … `DC_PART5_ADVANCED_UI.md` |
| Web + background | `beyond_faces/WEB_AND_BACKGROUND.md`, `beyond_faces/LIVE_DATA_AND_IOT.md` |
| Sensors / GPS | `beyond_faces/SENSORS_AND_GPS.md` |
| BLE / radio | `beyond_faces/BLUETOOTH_BLE.md` |
| Multi-device / language | `common/workflow/MULTI_DEVICE_STRATEGY.md`, `common/language/MONKEY_C_GUIDE.md` |
| Index | `common/MASTER_MAP.md` |

## Glossary

- **CIQ / Connect IQ** — Garmin's app platform; **Monkey C** — the language.
- **Device app** — full-screen interactive app from the app list (what we're building).
- **Glance / Complication** — at-a-glance surfaces; candidates for "pet mood" peek.
- **Background service** (`Toybox.Background`) — throttled periodic code (sync); 32 KB, 5 min, 30 s.
- **`Communications.makeWebRequest` / `makeOAuthRequest`** — HTTP / OAuth via the phone bridge.
- **`Application.Storage` / `Properties`** — persistent save state / settings.
- **`Toybox.Sensor` / `SensorHistory` / `ActivityMonitor` / `Complications`** — body-data inputs.
- **`Toybox.BluetoothLowEnergy` / `Toybox.Ant`** — radio APIs (Track 3).
