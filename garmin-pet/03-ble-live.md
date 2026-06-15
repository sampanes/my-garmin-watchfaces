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

### ANT / ANT+ (`Toybox.Ant`) — the more plausible native path
- Garmin's own low-power radio; supports **generic device-to-device channels**.
- More likely than BLE to allow two watches to exchange small messages without a
  phone or server.
- Caveats: tiny throughput, fiddly channel/pairing setup, both apps must implement
  the identical channel config, UX for "find each other" is non-trivial. **Verify**
  with a real two-device test.

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
2. Spike B — can two watches exchange bytes over an **ANT generic channel**
   (`Toybox.Ant` / `AntPlus` generic channel)? This is now the *only* path to true
   offline P2P. Test on the *actual* FR265 + VA6 pair (cross-device, not two identical
   units). If ANT generic D2D isn't exposed/usable either, true P2P is dead.
3. If ANT works: design a tiny in-person "playdate" (snapshot swap / co-op tap game).
4. If ANT fails: **phone-bridged pseudo-live** is the fallback — a short-lived server
   "room" two friends join by code or phone-proximity. Not offline, needs connectivity
   and the backend from Track 2, but it's the dependable way to get a "live-ish" visit.

Realistically, **plan for the phone-bridged fallback** and treat ANT as a bonus spike.
Do **not** let Track 3 block Tracks 1–2 — it's the bonus, not the spine.
