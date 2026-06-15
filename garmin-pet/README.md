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

## Target hardware (yours + wife's) — confirmed from repo SPEC docs

| Device | Display | Shape | Input | Notes |
|--------|---------|-------|-------|-------|
| Forerunner 265 | 416×416 AMOLED, 16-bit | round | touch + **5 buttons** | has barometer; System 7 |
| Forerunner 265S | 360×360 AMOLED, 16-bit | round | touch + **5 buttons** | smaller sibling; System 7 |
| Vivoactive 6 | 390×390 AMOLED (to 1500 nits) | round | touch + **2 buttons + Action Notch** | **no barometer**; System 8 |

**Design implications:**
- **Three resolutions** (416 / 360 / 390) → relative/scaled layouts, per-device resource sets. See `common/workflow/MULTI_DEVICE_STRATEGY.md` (jungle `resourcePath` + scale factor, or the JSON "configurator" layout pattern).
- **Two input profiles** → touch-first; never *require* 5 buttons (VA6 has 2 + Action Notch).
- **No barometer on VA6** → gate barometric/altitude features with `has`.

## Memory budget (the real design constraint) — from SPEC docs

| Heap tier | FR265 / 265S | Vivoactive 6 |
|-----------|--------------|--------------|
| **Device app / widget** (our type) | **1024 KB (1 MB)** | **256–512 KB** (varies by firmware) |
| Background process | **32 KB** | **32 KB** |
| Glance | — | 64 KB |
| Watch face (not our type) | 128 KB | ~124 KB |

> **Design to the VA6 ceiling (256–512 KB), not FR265's 1 MB** — VA6 is the tighter
> target. And **background sync gets only 32 KB everywhere**: the JSON parser can
> crash on a large response, so social payloads must be tiny. Memory deep-dive:
> `common/memory/MEM_PART1..3`.
>
> ⚠️ **CONFLICT to resolve (flagged 2026-06-15, web research).** Community reads of
> Garmin's own `compiler.json` report a **uniform 768 KB device-app heap and 64 KB
> background across all three** (FR265 / 265S / VA6) — contradicting the table above
> (which came from this repo's SPEC docs). The web source is **second-hand**, so the
> table is left as-is pending **a direct check of `compiler.json` in your installed SDK**.
> If 768 KB is right, the tightest constraint loosens a lot — design conservatively to
> ~256 KB until confirmed. (Background sync being 64 KB rather than 32 KB would also ease
> social-payload limits.) See `open-questions.md §B2`.

## SDK / API target — from SPEC docs

- **Common API floor: 5.2** (VA6 needs API ≥ 5.2.0 / System 8; FR265 is API ≥ 5.0.0 / System 7).
- **Build with Connect IQ SDK 8.1.1** (VA6's minimum) and **gate System-8-only features with the `has` operator** so FR265 still builds/runs.

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
