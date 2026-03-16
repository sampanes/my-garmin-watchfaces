[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Pre-Build Discovery Findings + Idea Backlog

Purpose: turn research into actionable pre-implementation planning for **Forerunner 265** and **vívoactive 6**.

---

## A) Recommended Next Step Before Coding

## 1) Run a "Device Truth + Budget Baseline" sprint
Build a small validation artifact in the simulator (not a production app) that measures and records:

- **AOD behavior contract** on both targets (low-power draw rules, burn-in/luminance-safe layouts).
- **`onPartialUpdate()` budget safety** with strict clip regions and timing diagnostics.
- **Memory behavior** under realistic data fields (time + HR + battery + steps).
- **First-frame transition quality** when waking from sleep mode.

### Deliverables
- `docs/baselines/FR265_BASELINE.md`
- `docs/baselines/VIVOACTIVE6_BASELINE.md`

Each baseline file should include:
1. Build target + SDK/API version
2. Measured draw timings (`onUpdate`, `onPartialUpdate`)
3. Pixel/luminance strategy used in low power
4. Memory observations and failure thresholds
5. Reproduction steps and simulator settings

---

## B) Watchface Concepts (Capabilities + Limits)

## 1) Dual-Mode Pro Minimal
- **Capabilities:** Large time typography, optional compact data row (battery/HR/steps), tiny clipped seconds zone.
- **Limitations:** AOD mode only shows sparse essentials with black-first rendering.

## 2) Training Readiness Face
- **Capabilities:** Time-first layout with activity-centric glanceables (readiness/recovery proxy, next workout, battery).
- **Limitations:** Every-second effects must be aggressively clipped and may be disabled in low power.

## 3) Adaptive Round Layout Family
- **Capabilities:** Shared visual system with per-resolution layout tables (390 and 416).
- **Limitations:** Not truly one-layout-fits-all; spacing and text-fit must be tuned per target.

## 4) Night-Safe AMOLED
- **Capabilities:** Battery-friendly black-dominant design with deliberate minute-level pixel shift.
- **Limitations:** Reduced decorative graphics in low-power mode.

---

## C) Creative Non-Watchface Project Ideas

## 1) Run Session Companion (Widget/App)
- **What it does:** Pre-run checklist, quick controls, and post-run recap.
- **Engineering value:** Utility-focused and reusable logic for future training apps.

## 2) Sensor Health Console
- **What it does:** Device-level sensor availability/status diagnostics.
- **Engineering value:** Creates a reusable compatibility and troubleshooting toolkit.

## 3) BLE Utility Tool
- **What it does:** Accessory status/alert surface for selected BLE scenarios.
- **Engineering value:** Expands capability beyond watchface rendering.

## 4) Background Sync + Status Tile
- **What it does:** Lightweight fetch + cache + concise status presentation.
- **Engineering value:** Establishes robust patterns for background/web behavior.

## 5) Internal Draw/Power Benchmark Harness
- **What it does:** Controlled draw tests to compare clipping, buffering, and update patterns.
- **Engineering value:** Makes performance decisions measurable before shipping.

---

## D) Suggested Sequence
1. Baseline sprint (truth + budgets)
2. One flagship watchface prototype (Dual-Mode Pro Minimal)
3. One non-watchface utility (Sensor Health Console or Run Session Companion)
4. Iterate with benchmark data, then scale portfolio
