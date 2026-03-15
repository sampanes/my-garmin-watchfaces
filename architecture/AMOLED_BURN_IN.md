[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# AMOLED Burn-In Protection: The Engineering Guide

---

## 🔗 Related Documentation
- [WatchFace Lifecycle & Power Budgeting](APP_LIFECYCLE_AND_POWER.md)

---

## 1. The Core Hardware Rules
When in Low Power Mode (Sleep), your watchface must adhere to:

### The 10% Pixel Rule
- No more than **10% of total display pixels** can be lit (any color other than black).
- **Why?**: AMOLED pixels consume power individually. High luminance increases heat and battery drain.

### The 3-Minute Persistence Rule
- No single pixel can be "on" (non-black) for more than **3 consecutive minutes**.
- **Why?**: Long-term static illumination causes permanent degradation of the organic material (burn-in).

---

## 2. Detection: `requiresBurnInProtection`
Always check if the device requires these protections. Older MIP (Memory-in-Pixel) devices do not.

```monkeyc
var settings = System.getDeviceSettings();
var needsProtection = (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
```

---

## 3. Strategy 1: Pixel Shifting
The most common way to satisfy the 3-minute rule is to shift the entire UI every minute.

- **The Logic**: In `onUpdate()`, use the current minute to calculate a small offset (2-5 pixels).
- **Implementation**:
```monkeyc
function onUpdate(dc) {
    var clockTime = System.getClockTime();
    var xOffset = 0;
    var yOffset = 0;

    if (isLowPower && needsProtection) {
        // Shift in a 4x4 square pattern based on minute
        xOffset = (clockTime.min % 4) - 2; 
        yOffset = (clockTime.min / 4 % 4) - 2;
    }

    dc.drawText(centerX + xOffset, centerY + yOffset, font, timeStr, justify);
}
```

---

## 4. Strategy 2: Checkerboarding (The 50% Mask)
To satisfy the 10% rule while keeping large fonts visible, use a "checkerboard" mask.

- **The Logic**: Overlay a bitmap mask of alternating transparent and black pixels.
- **The Result**: You cut the lit-pixel count by 50% instantly.
- **Pro Tip**: Alternate the mask every minute (Shift by 1 pixel) to ensure no single pixel stays on for more than 1 minute.

---

## 5. UI Design Patterns for AMOLED
| Problem | Solution |
| :--- | :--- |
| **Solid Numbers** | Use "Outline" or "Stencil" font versions in Low Power Mode. |
| **Large Logos** | Hide them entirely in Low Power Mode. |
| **Tick Marks** | Shift them along with the time, or use a checkerboard mask. |
| **Colors** | Use Pure Black (`0x000000`) for the background to turn pixels OFF. |

---

## 6. The "Heat Map" Simulator Tool
This is the single most important tool for AMOLED engineering.

### How to use it:
1. Open your watchface in the **Connect IQ Simulator**.
2. Select **File > View Screen Heat Map**.
3. The simulator will run through a 24-hour cycle in a few seconds.
4. **Results**:
   - **Green/Yellow**: Safe.
   - **Red/Pink**: Danger! These pixels are staying on too long.
   - **Blank Screen**: Your code violated the rules and the system "killed" the display.

---

## 7. Implementation Checklist
- [ ] Is `isLowPower` flag toggled in `onEnterSleep` and `onExitSleep`?
- [ ] Are all static UI elements (tick marks, labels) shifted or masked?
- [ ] Have you verified your pixel count is <10% using the Heat Map?
- [ ] Are you using Pure Black for the background?
- [ ] Did you disable "Seconds" or other 1Hz updates in Low Power Mode?
