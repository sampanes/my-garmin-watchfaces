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

## B. STILL OPEN — verify against Garmin developer docs ⏳

- [ ] **Storage** size cap per device + `Properties` size limits (not in repo).
- [ ] **makeWebRequest** exact request/response **size limits** + any **throttling**.
- [ ] **makeOAuthRequest** concrete flow for a custom backend (named only).
- [ ] **App-wake API** — does `Background.requestApplicationWake` / a Notifications API
      exist for a "you have mail" nudge? (Real-time push already ruled out.)
- [ ] **ANT generic channel** watch↔watch — supported? throughput? (Both devices have
      ANT+ per SPEC docs, but generic device-to-device messaging is unconfirmed.) **Now
      the only candidate for true P2P** since BLE is ruled out — test on the actual
      FR265 + VA6 pair (not two identical units).
- [ ] **Store review** rules for apps calling external servers + handling messaging.
- [ ] **Dev agreement** restrictions on social/messaging apps + **COPPA/kids** data.

## C. Product decisions

- [ ] **Messaging:** canned vocabulary/stickers only vs free text. *(Recommend
      canned — watch text entry is bad + moderation burden.)*
- [ ] **Companion phone app:** build one, or watch-only `makeWebRequest`?
      *(Recommend launch without; add later if it has legs.)* Gates push + QR-add.
- [ ] **Failure mechanic:** punishing (death) vs gentle (sick/sad). *(Gentle ages
      better for a glanceable wearable.)*
- [ ] **Species/evolution:** single species first vs branching tree.
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
