[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# WatchFace Lifecycle & Power Budgeting

---

## 🔗 Related Documentation
- [AMOLED Burn-In Protection](AMOLED_BURN_IN.md)

---

## 1. The Two Power States
Garmin watchfaces operate in two distinct modes to balance user experience with battery life.

### High Power Mode
- **Trigger**: Wrist gesture (raising the watch), button press, or screen tap.
- **`onExitSleep()`**: Called once when entering this mode.
- **`onUpdate()`**: Called **every second** (1Hz).
- **Duration**: Typically ~10 seconds before timeout.
- **Capability**: Full access to drawing commands and higher CPU usage.

### Low Power Mode (Sleep)
- **Trigger**: Inactivity timeout after High Power Mode.
- **`onEnterSleep()`**: Called once when entering this mode.
- **`onUpdate()`**: Called **once per minute** (at the start of the minute).
- **`onPartialUpdate()`**: Called every second (if supported and enabled) for specific 1Hz updates (e.g., seconds).

---

## 2. The 30ms Power Budget
To prevent battery drain, Garmin enforces a strict execution limit on `onPartialUpdate()`.

- **The Rule**: The average execution time of `onPartialUpdate()` must stay below **30 milliseconds (30,000 μs)**.
- **The Window**: Averaged over a rolling 1-minute period.
- **The Penalty**: If you exceed the budget, the system **kills partial updates**. Your watchface will "freeze" (no seconds/HR updates) until the next minute or next wake-up.
- **Optimization**: You **MUST** use `dc.setClip()` to redraw only the tiny bounding box of the element that changed.

---

## 3. AMOLED Always-On Display (AOD)
AMOLED displays require extra care to prevent hardware damage (burn-in).

### The 10% Pixel Rule
- No more than **10% of total screen pixels** can be illuminated at once in Low Power mode.
- **Strategy**: Use thin fonts, outlines, and minimalist designs. Turn off heavy background images.

### The 3-Minute Burn-in Rule
- No single pixel can be "on" (non-black) for more than **3 consecutive minutes**.
- **Strategy: Pixel Shifting**: Every minute (in `onUpdate`), shift the entire UI or critical elements (like the clock) by 2-5 pixels in a random or circular pattern.
- **Strategy: Checkerboarding**: Draw text using a 50% checkerboard mask and flip the mask every minute to toggle which pixels are active.

---

## 4. Implementation Checklist
| Method | Frequency | Primary Responsibility |
| :--- | :--- | :--- |
| `onLayout(dc)` | Once | Load resources, set up layouts. |
| `onShow()` | When visible | Initial state setup. |
| `onUpdate(dc)` | 1/min (Low) or 1Hz (High) | Full screen redraw. Apply pixel shifting in Low Power. |
| `onPartialUpdate(dc)` | 1Hz (Low) | Draw seconds/HR using `setClip()`. Watch the 30ms budget. |
| `onEnterSleep()` | On transition | Set a flag (e.g., `isAsleep = true`) to trigger AOD layouts. |
| `onExitSleep()` | On transition | Set flag (`isAsleep = false`) to restore full UI. |

---

## 5. Diagnostic Tools
- **Simulator > File > View Watchface Diagnostics**: Displays real-time execution time for `onPartialUpdate`.
- **Simulator > View > View Screen Heat Map**: Simulates 24 hours of pixel usage to detect burn-in risks.
- **Simulator > View > Low Power Mode**: Manually toggle sleep state to test your `onEnterSleep` logic.

---

## 6. Engineering Gotchas
1. **Clip Regions**: If your clipping region in `onPartialUpdate` is too large (e.g., a full-width bar), you will almost certainly blow the 30ms budget.
2. **System Variables**: Accessing `System.getSystemStats()` or `Sensor.getInfo()` in `onPartialUpdate` is expensive. Cache these in `onUpdate` or `onExitSleep` if possible.
3. **Transition Lag**: There is often a slight lag when switching from Low to High power. Ensure your `onUpdate` is efficient enough to draw the first "High Power" frame instantly.
