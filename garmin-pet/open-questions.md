# Open questions & decisions

Status after reconciling against this repo's docs (2026-06-15). Three lists:
**(A) RESOLVED from repo research**, **(B) STILL OPEN — verify externally**, and
**(C) product decisions**. ⚠️ Resolved items came from the cloned GitHub remote,
which trails your unpushed local — re-confirm against the local repo.

## A. RESOLVED from repo research ✅

- [x] **Device specs** — FR265 416×416 / FR265S 360×360 / VA6 390×390, all AMOLED
      round, 16-bit. FR265 = 5 buttons + barometer; VA6 = 2 buttons + Action Notch,
      **no barometer**. → `common/architecture/SPEC_FORERUNNER_265.md`, `SPEC_VIVOACTIVE_6.md`
- [x] **App memory budget** — device-app heap: FR265/265S **1 MB**, VA6 **256–512 KB**
      (design to VA6). Background **32 KB** on all. Glance 64 KB (VA6). → same SPEC docs,
      `common/memory/MEM_PART1..3`
- [x] **API floor / SDK** — common floor API **5.2**; FR265 System 7 (API 5.0.0+),
      VA6 System 8 (API 5.2.0+). Build with **SDK 8.1.1**, gate System-8 features with
      `has`. → SPEC docs, `common/workflow/WEB_RESEARCH_BRIEF_FORERUNNER265_VIVOACTIVE6.md`
- [x] **Multi-resolution strategy** — jungle `resourcePath` per device + scale factor
      vs FR265's 416, or a JSON "configurator" layout. → `common/workflow/MULTI_DEVICE_STRATEGY.md`
- [x] **makeWebRequest basics** — **HTTPS mandatory** (newer firmware blocks non-SSL);
      **works in background**; needs phone BT connection; **battery-saver disables**
      background. → `beyond_faces/WEB_AND_BACKGROUND.md`, `LIVE_DATA_AND_IOT.md`
- [x] **Background limits** — min interval **5 min** (`registerForTemporalEvent`),
      **~30 s** max run (incl. web-request lag), **32 KB** heap; mark code `(:background)`;
      needs `Communications` + `Background` permissions. → `beyond_faces/WEB_AND_BACKGROUND.md`
- [x] **No real-time server→watch push** — confirmed; use store-and-forward + pull.
      → `beyond_faces/WEB_AND_BACKGROUND.md`
- [x] **CIQ Mobile SDK** — exists for **iOS + Android** (companion-app messaging).
      → `beyond_faces/BLUETOOTH_BLE.md`
- [x] **Sensor inputs for pet mechanics** — `Sensor.getInfo()` (HR, cadence, temp;
      pressure **FR265 only**); `SensorHistory` (HR last ~4 h, elevation, pressure);
      `Complications` STEPS subscription (battery-efficient). → `beyond_faces/SENSORS_AND_GPS.md`
- [x] **BLE peripheral / watch↔watch** — ❌ **NOT POSSIBLE.** CIQ BLE is central-only
      (GATTC since API 3.1.0); no advertising / GATT server. Two watches **cannot**
      connect directly over BLE. → [BLE API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/BluetoothLowEnergy.html),
      [forum 224447](https://forums.garmin.com/developer/connect-iq/f/app-ideas/224447/broadcast-heart-rate-by-ble) (verified 2026-06-15)
- [x] **Accelerometer rep-counting** — ✅ **feasible.** 25 Hz accel via
      `registerSensorDataListener`; peak-detection rep counting is proven. Foreground
      session only (CPU/heap heavy). → `beyond_faces/SENSORS_AND_GPS.md §3`, see `04-activity-sensing.md`

## B. RESOLVED from web research (2026-06-15) ✅

Confidence tags: **[OFFICIAL]** = developer.garmin.com API docs; **[SEMI]** = named Garmin
staff on forums but not in docs; **[FOLKLORE]** = community estimate only.

- [x] **Storage size** — **32 KB per value [OFFICIAL]** (`Storage.setValue` throws
      `StorageFullException` past it). Per-app **total** "varies by device" (official) but
      no number published; **~100–128 KB total [FOLKLORE]**. → use Storage for anything
      beyond tiny settings.
- [x] **Properties size** — **~8 KB total [SEMI]** (Travis Vitek), and the whole dict is
      **RAM-resident the entire session** (loaded at app start), unlike Storage which is
      lazy-loaded from disk [SEMI, Brian.ConnectIQ]. → prefer **Storage**, not Properties,
      for save state; Properties only for small user settings.
- [x] **makeWebRequest size/throttle** — **no documented byte cap; it's heap-bound
      [OFFICIAL]**. Fails *gracefully*, never silently truncates: `NETWORK_RESPONSE_TOO_LARGE`
      = **-402**, `NETWORK_RESPONSE_OUT_OF_MEMORY` = **-403**, `BLE_QUEUE_FULL` = **-101**
      (too many parallel requests), `BLE_REQUEST_TOO_LARGE` = **-102**. **JSON parser inflates
      ~2.5–3× over wire bytes [FOLKLORE]** — the real ceiling; request `text/plain` + parse
      manually when tight. Concurrency is limited but unquantified → **serialize** (await each
      callback). Background: hard **5-min** floor, ~30 s lifetime [OFFICIAL/FOLKLORE].
- [x] **makeOAuthRequest flow** — `makeOAuthRequest(requestUrl, params, resultUrl,
      OAUTH_RESULT_TYPE_URL, resultKeys)` + `registerForOAuthMessages(cb)`. Watch never opens
      a browser: it hands the URL to **Garmin Connect Mobile**, which shows a phone web view and
      scrapes the redirect for your keys. **PKCE is hand-rolled** via `Toybox.Cryptography`
      (`randomBytes` + `Hash(HASH_SHA256)`, URL-safe base64) — no native PKCE. Foreground only,
      BLE-connected phone required. Gotcha: a `redirect_uri`-caching bug if you call
      `makeWebRequest` right after. → see decision in §C.
- [x] **App-wake / push** — **poll-only, confirmed [OFFICIAL].** No server→watch push.
      `Background.requestApplicationWake` *always* shows a "Start App" prompt (can't silently
      launch). Only inbound nudge is `registerForPhoneAppMessageEvent` (phone→watch over BLE,
      needs your own companion app). `registerForTemporalEvent` (≥5 min) is the only time
      scheduler; no new SDK 7/8 mechanism found. → "you have mail" = poll on open + bg ≥5 min,
      or phone-companion relay.
- [x] **ANT generic channel** — **de-risked.** Master/TX is blocked only on `NETWORK_ANTPLUS`,
      **not on wrist devices** — it ran clean on a **Forerunner** profile on `NETWORK_PUBLIC`.
      The `BurstPayload` "Symbol not found" bug is **simulator-only (works on real devices)**.
      Shipped existence proof: **"Chess! – Blind Knights"** does watch-to-watch over ANT.
      → remaining unknowns + protocol in `03-ble-live.md` (Spike B), now narrowed to real-HW TX
      + channel availability when sensors are paired.
- [x] **Store / dev-agreement / COPPA** — custom backend **allowed**, but you **must publish
      your own privacy policy + minimize/limit data retention** the moment user data leaves the
      device. **Canned/enumerated messages dodge the §1(g) UGC moderation/reporting/DMCA
      regime** that free text triggers (big lever → see §C). **Under-13-directed apps are banned
      outright** (no parental-consent path) → market **general-audience**. **Paid-upfront via
      Garmin Pay** exists ($4.99+, since Aug 2024; annual fee + revenue cut). True **in-app
      purchase is UNCONFIRMED** — verify with Garmin if gift-currency-style IAP is needed.

## B2. Genuinely still open ⏳

- [ ] **Memory budgets — RESOLVE THE CONFLICT.** Community `compiler.json` reads report **768 KB
      device-app / 64 KB background, identical across FR265/265S/VA6** — contradicting the SPEC-doc
      figures in README (1 MB / 256–512 KB / 32 KB bg). Source is second-hand. **Check
      `compiler.json` in the installed SDK on your personal PC** to settle it; it loosens the
      tightest design constraint if true. (Also: VA6 may be **API 6.0**, not 5.2 — doesn't move
      the build floor, which stays FR265's 5.2.)
- [ ] **Per-device Storage total** — exact cap for FR265 / VA6 (only "varies by device" is official).
- [ ] **In-app purchase** — does CIQ support true IAP/consumables beyond paid-upfront? (unconfirmed)
- [ ] **Re-confirm against local unpushed repo** (see Reconcile TODO below).

## C. Product decisions

- [x] **Build order: LOCKED.** Ship the solo watch pet first, then the foreground
      activity-buddy loop. Treat social, ANT co-presence, and phone companion work as
      gated expansions only after the core loop is fun on real hardware.
- [x] **Messaging: LOCKED canned** vocabulary/stickers (no free text). Reinforced twice:
      watch text entry is bad, *and* canned/enumerated content dodges the §1(g) UGC
      moderation/reporting/DMCA regime (store-policy research, §B). Free text → companion app only.
- [ ] **Companion phone app:** build one, or watch-only `makeWebRequest`?
      *(Recommend launch without; add later if it has legs.)* Gates push + QR-add.
- [x] **Persona tone: LOCKED guardrail.** User-facing labels are Drill Sergeant /
      Hype Cheerleader / Deadpan / Zen. Internal "asshole coach" shorthand is fine
      for ideation, but shipped lines roast the effort gap, never body/worth/identity.
- [x] **Failure mechanic: LOCKED gentle** (sick/sad, never death/neglect-spiral) — cozy
      guardrails, `05-progression.md`. Decay forgives missed days.
- [~] **Species/evolution: structure decided in `05-progression.md`** — evolution is *the one
      real fork* + the meta-track (infinite height), branches sampled across lives so none
      "rot". Still open: # of evolution bands, gates, and whether branches differ by
      power/verb vs cosmetic-only (lean: a signature verb + a look — horizontal, not vertical).
      MVP still starts single-species (see `01` MVP scope).
- [x] **Activity sensing — live vs after-the-fact RESOLVED.** Only one app is foreground, so
      the pet **can't ride along during Garmin's *native* Run/Walk** (and no live IPC between
      them). Mat reps run **live** in the pet's own session (`04`); walks/runs feed it **after
      the fact** via the `Complications` STEPS subscription + `ActivityMonitor` aggregates (no
      route). A live "Run with pet" GPS mode is possible **only if the pet itself records**
      (`Position`/`ActivityRecording`, saves to Garmin Connect) — a later *earned power*, not
      MVP. → `01-solo-game.md §"Live (mat reps) vs after-the-fact"`.
- [ ] **Sensor tie-ins:** which to ship first (recommend steps→food as the proof).
- [ ] **Device priority:** target FR265 + VA6 day one, or FR265 first then port?
- [ ] **Monetization:** hobby/free vs anything paid (affects store + ops appetite).
- [ ] **Backend ownership:** are you actually willing to run/maintain a service
      (Track 2)? If not, Track 2/3 social is off the table — be honest early.

## Reconcile-with-real-code TODO
- [x] First pass done vs the **cloned GitHub remote** (this folder's parent repo).
- [ ] Re-reconcile against the **local unpushed** `my-garmin-watchfaces` on your
      personal PC — confirm specs/SDK haven't moved, and salvage any sprite/animation
      or layout-helper code worth reusing.
