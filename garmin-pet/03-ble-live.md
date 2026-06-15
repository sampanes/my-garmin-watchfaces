# Track 3 — Live co-presence ("our pets meet when we're together")

**Verdict: speculative R&D. Lowest certainty of the three.** The dream is offline,
peer-to-peer: two watches near each other let their pets visit/play live with no
server. Whether Connect IQ actually lets two *watches* talk directly is the open
question — prove the radio channel exists on real FR265 ↔ VA6 hardware **before**
designing any UX.

> **Repo cross-refs:** `beyond_faces/BLUETOOTH_BLE.md` (BLE central vs peripheral,
> gotchas), `beyond_faces/LIVE_DATA_AND_IOT.md`. Both FR265 and VA6 list **ANT+**
> external-sensor support in their SPEC docs — so the *radio hardware* is present;
> what's unconfirmed is whether CIQ exposes **generic device-to-device** messaging.

## Candidate channels (and their problems)

### BLE (`Toybox.BluetoothLowEnergy`) — probably can't do watch↔watch directly
- The CIQ BLE API has historically let the watch act **only as BLE central
  (client)** — it scans for and connects to BLE **peripherals** (HR straps, sensors).
- Two watches both acting as central **cannot connect to each other**; you'd need one
  to **advertise as a peripheral**, which CIQ watches generally **could not do**.
- ⇒ Direct watch-to-watch over CIQ BLE is **doubtful**. **VERIFY against the current
  SDK** — peripheral/advertising support is exactly the kind of thing that may have
  changed; if it has, this whole track gets much easier.

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

1. Spike A — can a CIQ watch **advertise as a BLE peripheral** on current SDK?
   (Settles the BLE question.)
2. Spike B — can two watches exchange bytes over an **ANT generic channel**?
   Test on the *actual* FR265 + VA6 pair (cross-device, not two identical units).
3. Only if A or B succeeds: design the playdate UX.
4. If both fail: fall back to **phone-bridged pseudo-live** (server room joined by
   proximity or a code), and be clear it needs connectivity.

Do **not** let Track 3 block Tracks 1–2 — it's the bonus, not the spine.
