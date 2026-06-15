# Track 3 — Live co-presence ("our pets meet when we're together")

**Verdict: the dream P2P version is mostly closed off. BLE is confirmed impossible;
ANT is the only remaining direct hope (unproven); the realistic path is a
phone-bridged "pseudo-live" session.** The dream was offline peer-to-peer — two
watches near each other letting their pets visit/play with no server. Connect IQ
does not allow direct watch↔watch BLE (verified below), so this track narrows to:
prove ANT generic channels work, or accept a server-brokered "live-ish" room.

> **Repo cross-refs:** `beyond_faces/BLUETOOTH_BLE.md` (BLE central vs peripheral,
> gotchas), `beyond_faces/LIVE_DATA_AND_IOT.md`. Both FR265 and VA6 list **ANT+**
> external-sensor support in their SPEC docs — so the *radio hardware* is present;
> what's unconfirmed is whether CIQ exposes **generic device-to-device** messaging.

## Candidate channels (and their problems)

### BLE (`Toybox.BluetoothLowEnergy`) — ❌ CONFIRMED IMPOSSIBLE for watch↔watch
**Verified 2026-06-15 against Garmin's API docs + dev forum.** CIQ BLE is
**central/client only** (GATTC operations, since API 3.1.0). There is **no
advertising, no GATT server, no peripheral role** — no `setAdvertisingData`, no
`startAdvertising`. A watch can connect *to* sensors; it cannot *be* one.
- Garmin dev (Jim M): *"The BLE in CIQ is meant to connect to external sensors, but
  not act as one. I doubt that will change."*
- Consequence: both watches can only be centrals, neither can advertise → **two
  watches cannot connect directly over CIQ BLE. Full stop.**
- ⚠️ **Repo doc error:** `beyond_faces/BLUETOOTH_BLE.md §4` claims watches can
  broadcast via `setAdvertisingData()`/`setAdvertisingPayload()`. **Those methods do
  not exist** — it's an AI-research artifact (Gemini-attempt lineage). Should be fixed.
- Sources: [BLE API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/BluetoothLowEnergy.html),
  [forum: broadcast HR by BLE](https://forums.garmin.com/developer/connect-iq/f/app-ideas/224447/broadcast-heart-rate-by-ble).

### ANT generic channel (`Toybox.Ant` / `Ant.GenericChannel`) — the only remaining P2P path
**This CAN do device-to-device** (unlike BLE). An app extends `Ant.GenericChannel`,
opens one watch as **master** (transmit) and the other as **slave** (receive), and they
exchange messages directly over Garmin's own radio — **no phone, no server**.

How it's wired (from API docs + forum examples):
- **Channel type:** master = `CHANNEL_TYPE_TX_NOT_RX`, slave = `CHANNEL_TYPE_RX_NOT_TX`
  (a bidirectional type exists for two-way).
- **Network:** `NETWORK_PUBLIC` — **not** `NETWORK_ANTPLUS` (master mode on the ANT+
  network throws a runtime error).
- **RF frequency:** 2–80 (2402–2480 MHz); **avoid 57** (reserved for ANT+). Both apps
  hard-code the same custom freq.
- **Device number** ≠ 0 for the master; **transmission type** (forums: use `1`, not `5`);
  **message period** sets the rate (generic can run far faster than ANT+'s 4 Hz).
- Send via `sendBroadcast(payload)` / `sendAcknowledge(payload)`; bigger transfers via
  **burst** (`Ant.BurstPayload`). Permission: `<iq:permission id="Ant"/>` (verify exact id on 8.1.x).

Hard limits / landmines (why this is a *spike*, not a plan):
- **8 bytes per message.** A pet snapshot must be packed into a few 8-byte frames or
  sent as a burst (burst ≈ up to 8192 B / 1024 msgs, device-varying).
- **Best-effort, lossy.** Devs report dropped messages (e.g. losing ~5 s of a 2 Hz
  stream) and a slave that stops receiving after the app is backgrounded → need acks/retries.
- **Simulator won't prove it.** `GenericChannel` has had sim regressions and there's
  nothing to pair with in the sim — inherently a **two-real-device** test.
- **Watch master-mode: likely OK (de-risked 2026-06-15).** The only documented block on
  master/TX is the **ANT+ network** (`NETWORK_ANTPLUS` throws "Master channels on the ANT+
  network are not allowed" — anti-spoofing). On `NETWORK_PUBLIC` a master channel **ran
  without error on a Forerunner profile** (FR745) per the forums; no source blocks master
  mode by form factor. Garmin's `GenericChannelBurst` *sample* is Edge-only, but that's a
  sample target, not an API restriction. So the unknown narrowed from "can a watch master at
  all?" to **"does master-on-public actually transmit on FR265/VA6 silicon?"**
- **`Ant.BurstPayload` bug is SIMULATOR-ONLY.** The "Symbol not found" regression (SDK ≥4.1.6,
  still "Acknowledged") is reproduced **only in the sim**; the bug reporter states *"the code
  DOES work on devices."* → burst-based designs aren't dead; just can't be proven in the sim
  (which is true of all ANT here anyway). Debug burst on real hardware.
- **Channel availability is the other real risk.** The ~8 ANT channels are **shared with the
  system's own HR/sensor use**; on older Vivoactives, just having many sensors *paired* (not
  even connected) could starve `open()`. Keep the paired-sensor list minimal; if `open()`
  returns true but `onMessage` never fires in 1–2 s, **release and recreate the channel**
  (reported workaround).
- **Existence proof:** the shipped app **"Chess! – Blind Knights"** advertises watch-to-watch
  play over ANT — the best lead that two watches *can* link. Confirming its compatible-device
  list would cheaply validate cross-model pairing before you build anything.

Sources: [ANT/ANT+ core topic](https://developer.garmin.com/connect-iq/core-topics/ant-and-ant-plus/),
[Custom ANT Broadcast w/ GenericChannel](https://forums.garmin.com/developer/connect-iq/f/discussion/411246/custom-ant-broadcast-using-genericchannel),
[Ant.BurstPayload docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/Ant/BurstPayload.html).

### Phone-bridged "proximity" — not true P2P, but a fallback
- Companion phone apps detect proximity (phone↔phone BLE, or both reporting
  "we're together" to your backend) and broker a **short-lived live session** via
  the server. Needs connectivity; isn't offline. Essentially Track 2 + a realtime
  room, not radio P2P.

## What "live" would buy you (if a channel exists)

Keep it tiny — latency + throughput are brutal on these radios:
- In-person **snapshot exchange** (richer than the async version: instant).
- A short **co-op minigame** / "playdate" that boosts both pets.
- **Gift handoff** with live confirmation ("trade accepted").

## Honest recommendation

Treat this as a **feasibility spike**, isolated from Tracks 1–2:

1. ~~Spike A — BLE peripheral?~~ **DONE: answered NO** (BLE is central-only; see above).
2. Spike B — **ANT generic channel** is now the *only* path to true offline P2P.
   Full test protocol + the hardware-only "maybe"s are at the bottom of this file.
3. If ANT works: design a tiny in-person "playdate" (snapshot swap / co-op tap game).
4. If ANT fails: **phone-bridged pseudo-live** is the fallback — a short-lived server
   "room" two friends join by code or phone-proximity. Not offline, needs connectivity
   and the backend from Track 2, but it's the dependable way to get a "live-ish" visit.

Realistically, **plan for the phone-bridged fallback** and treat ANT as a bonus spike.
Do **not** let Track 3 block Tracks 1–2 — it's the bonus, not the spine.

---

## Spike B — ANT generic-channel feasibility (real hardware only)

**Question it answers:** can a FR265 and a VA6 exchange a few bytes app-to-app over a
generic ANT channel, reliably enough for an in-person "playdate," with **no phone/server**?

**Why hardware-only:** the simulator can't pair two devices over ANT and has had
`GenericChannel` regressions — you need both watches in hand. Budget it as a throwaway
test app, not production code.

**Minimal test app** (one app with a master/slave role toggle, or two build flavors):

| Param | Master watch | Slave watch |
|-------|--------------|-------------|
| Channel type | `TX_NOT_RX` | `RX_NOT_TX` |
| Network | `NETWORK_PUBLIC` | `NETWORK_PUBLIC` |
| RF frequency | fixed, e.g. **66** (≠57) | same (66) |
| Device number | fixed non-zero, e.g. `0xBEEF` | same |
| Device type / trans type | e.g. `1` / `1` | match |
| Message period | start ~4–8 Hz | match |
| Action | `sendBroadcast()` an incrementing counter each tick | log received counter |

**Steps:**
1. Build & sideload to both watches (master→FR265, slave→VA6; then **swap roles** to test both directions).
2. Master broadcasts an incrementing counter in an 8-byte payload.
3. Slave logs received counters → compute **received ÷ expected** over 60 s at ~1 m.
4. Repeat at ~5 m, and with a body/wrist between the watches (real blockage).
5. Try `sendAcknowledge()` for a round-trip, then a small **burst** for a bigger blob.

**Success ⇒ design the playdate UX:** ≥ ~90% of broadcasts received at 1–3 m **and** an
acknowledged round-trip works → build a tiny snapshot-swap / co-op tap minigame.

**Kill ⇒ fall back to phone-bridged pseudo-live:** if the watches won't open a master
channel, won't pair cross-model, burst is broken on 8.1.x, or loss is too high.

### The "maybe"s only real hardware can settle (checklist)
*Updated 2026-06-15 — several de-risked by web research; the live unknowns are now the
hardware-physics ones, not API-permission ones.*

- [ ] **(top risk)** Master-on-`NETWORK_PUBLIC` actually **transmits** on FR265/VA6 silicon
      (compiles/opens clean per forums; on-air TX from these watches is unverified).
- [ ] Two **different models** (FR265 ↔ VA6) actually pair on a shared custom channel.
      *(Cheaper first step: check the "Chess! – Blind Knights" store listing's device support.)*
- [ ] A **free ANT channel** exists while the watch's HR/sensors use ANT — keep paired sensors
      minimal; expect to use the release-and-recreate workaround if `onMessage` stalls.
- [ ] Delivery is reliable enough at realistic range/blockage (the loss numbers above).
- [ ] Truly works **offline** (airplane mode / no phone) — expected, but confirm.
- [ ] Channel stays alive for a whole foreground session (no silent stop after a minute).
- [x] ~~`Ant.BurstPayload` works on SDK 8.x~~ — bug is **simulator-only; works on devices**
      (per the bug reporter). Still verify your burst on real HW, but it's not a blocker.
