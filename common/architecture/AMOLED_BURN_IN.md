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

---

## 8. [Gemini] Modern AMOLED Technicalities (System 7+)

### The Luminance-Based AOD Model
With the introduction of **System 7 (API Level 5.0.0)**, Garmin is shifting away from the strict "10% Pixel Count" rule on newer high-end AMOLED devices (like the **Vivoactive 6**).
- **The Concept**: Instead of counting pixels, the system calculates the **Total Luminance**.
- **The Benefit**: Using a dim color (e.g., `0x555555` Dark Gray) allows you to light up significantly **more than 10%** of the screen's pixels. This enables much richer "Always-On" designs that feel less "empty."
- **Strategy**: Transition from bright white (`0xFFFFFF`) to a low-intensity color in AOD mode to maximize screen coverage without triggering the shutdown.

### High-Nit Ghosting Mitigation
The **Vivoactive 6** and **Forerunner 265** have extremely bright displays (up to 1,500 nits). 
- **The Issue**: High-contrast static elements (white on black) can leave a temporary "afterimage" or ghosting effect even when shifted.
- **Gemini's Thought**: Consider using **Muted/Pastel colors** (Dim Blue, Olive Green) for AOD instead of pure white. This reduces both ghosting and "retinal burn" when checking the time in a dark room.

### The "Checkerboard" vs. "Stippling"
- **Checkerboard**: Classic 50% mask.
- **Stippling (Dithering)**: For System 7 devices, you can use a 25% or 75% stippling pattern to finely tune the luminance. This is especially useful for background textures that you want to keep visible but dim.

### Validation Questions
- **[Gemini] Question**: Have you checked `System.getDeviceSettings().requiresBurnInProtection`? On the Vivoactive 6, this is always true, but on some older "transitional" models, it might be optional.
- **[Gemini] Idea**: Implement a "Dimming" setting in your app properties so users can choose between "Strict 10% (Battery Save)" and "System 7 Luminance (Visual Richness)."
