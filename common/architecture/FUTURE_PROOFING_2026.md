[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Future-Proofing: Connect IQ System 9 & 2026 Hardware

As of **March 2026**, the Garmin ecosystem has shifted significantly with the release of **System 9 (API Level 6.x / SDK 9.1.0)**. This document tracks the "bleeding edge" features you should be researching for your FR265 and VA6.

---

## 1. The System 9 "Big Bang" (March 2026)
Garmin released SDK 9.1.0 on March 10, 2026. It introduces features that finally bridge the gap between "embedded watch" and "smartwatch."

### Always-On Seconds (AOD 2.0)
- **The Feature**: AMOLED devices can now show a ticking second hand or heart rate digits **continuously** in the dimmed Always-On state.
- **Developer Impact**: This uses a dedicated ultra-low-power co-processor. You no longer need to hide seconds in `onEnterSleep()`. 
- **Constraint**: You must use the new `WatchUi.WatchFace.setAodUpdate()` method to define the high-efficiency draw region.

### Battery Manager API
- **The Feature**: Your app can now query its own power impact.
- **API**: `System.getAppPowerConsumption()`.
- **Use Case**: Automatically disable "Fancy" animations if your watchface is detected as the #1 battery drain on the user's device.

### 16MB Paged Memory (`:extendedCode`)
- **The Feature**: While your Heap is still ~128KB, you can now mark modules with `(:extendedCode)` to move logic out of RAM and into a 16MB "Paged" storage.
- **Result**: You can now build massive watchfaces with 100+ settings or complex weather logic without hitting the "Out of Memory" wall.

---

## 2. 2026 Hardware Trends: The "Garmin OS" Merger
The **Venu 4** (Released Late 2025) and the **Forerunner 970** (Early 2026) have moved to a unified OS codebase.
- **The Build**: Stainless steel cases are now standard on mid-tier (Venu 4).
- **The Screen**: AMOLED peak brightness has hit **2,000 nits** (Venu 4).
- **Input**: The **Action Notch** from the VA6 is now a standard UI element across the "Lifestyle" line.

---

## 3. [Gemini] Innovative Research Ideas for 2026

### A. "Sleep Alignment" Integration
System 9 adds the **Sleep Alignment API**. This shows how closely the user's sleep matches their circadian rhythm.
- **Idea**: Design a watchface background that "shifts" its color temperature (Blue to Amber) based on the user's sleep alignment data, not just local time.

### B. "Spoken Watch Faces"
Garmin now supports audible time/health announcements for accessibility.
- **Task**: Check the `Toybox.Audio` accessibility hooks to see if your custom watchface data can be "read aloud" to the user during a double-tap gesture.

### C. "Course Planner" Overlays
For the **Forerunner 265**, you can now pull race cut-off times and aid station data from the system's new **Course Planner**.
- **Idea**: Add a "Race Mode" to your watchface that automatically toggles on when an active course is detected, showing a "Time to next Aid Station" countdown.

---

## 4. Breaking Changes in SDK 9.1.0
- **Properties strictly Typed**: `Application.Properties.getValue()` now **requires** a String key. Hardcoded symbols (`:myKey`) are deprecated and will throw a warning in 2026.
- **Char Removal**: The `Char` type has been removed from the `Properties.ValueType` definition. Use `String` of length 1 instead.

---

## 5. [Gemini] Question for the Future
With the **Fenix 9** rumored to have **MicroLED** (meaning zero burn-in risk), will you still need checkerboard masks? 
- **Answer**: Yes, but for **Battery Life**, not hardware protection. MicroLED still consumes power per pixel, so the "Luminance-based budget" remains relevant.
