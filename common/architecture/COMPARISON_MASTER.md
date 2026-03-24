[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Comparison Master: FR265 vs. VA6 vs. The World

This document breaks down the technical hierarchy between your two target devices and how they sit within the broader Garmin ecosystem.

---

## 1. Head-to-Head: FR265 vs. VA6
| Feature | Forerunner 265 | Vivoactive 6 | Winner/Winner Reason |
| :--- | :--- | :--- | :--- |
| **Heap (Watchface)** | 128 KB | 124 KB | **FR265** (Slight edge for assets) |
| **GPS Precision** | Multi-Band (L1+L5) | Multi-GNSS (L1) | **FR265** (Superior for city/forest) |
| **Altitude** | Barometric | GPS-Derived | **FR265** (Baro is 10x more accurate) |
| **Input** | 5 Buttons + Touch | 2 Buttons + Touch | **FR265** (Better for sweaty hands) |
| **Brightness** | ~1000 nits | **~1500 nits** | **VA6** (Better in direct sun) |
| **CIQ System** | System 7 | **System 8** | **VA6** (Supports newer UI APIs) |

---

## 2. vs. "The World" (Garmin Tiers)

### Tier 1: The "Beasts" (Fenix 8, Epix Gen 2, MARQ)
- **Difference**: These have **16MB+ Paged Code** and **Elevate Gen 5** sensors (ECG/Skin Temp).
- **Vs. Your Pair**: Your FR265 and VA6 are "Mid-Tier." They lack the raw processing power and the ECG hardware of the Tier 1 devices.

### Tier 2: The "Pure Sports" (Forerunner 955/965)
- **Difference**: These have full **Onboard Topo Maps**. 
- **Vs. Your Pair**: The FR265 has breadcrumb navigation; the VA6 has basic courses. Neither can render full vector maps like the 965.

### Tier 3: The "Entry Level" (Forerunner 55/165, Vivoactive 5)
- **Difference**: Older MIP screens or lower-resolution AMOLED.
- **Vs. Your Pair**: Your devices are significantly faster and have better AOD support than the Tier 3 pool.

---

## 3. Comparison with the "General Pool" (Apple/Samsung/Android)

### Battery Life (The Garmin Advantage)
- **Garmin (FR265/VA6)**: 10–14 Days (Smartwatch Mode).
- **General (Apple/Samsung)**: 1–2 Days.
- **Developer Impact**: You can afford more background polling on Garmin because the battery floor is much higher.

### Display Performance
- **Garmin**: Focuses on **Luminance Management** and power-sipping.
- **General**: Focuses on high-refresh (60Hz) and complex animations.
- **Developer Impact**: Do not try to port a 60FPS Apple Watch animation to CIQ. You will hit the **30ms power wall** instantly.

### App Ecosystem
- **Garmin**: Highly specialized (Fitness/Navigation).
- **General**: Broad (Social/Messaging/Utility).
- **Developer Impact**: Your CIQ app should solve a **specific data problem**, not try to be a mini-smartphone app.

---

## 4. [Gemini] Final Architectural Verdict
- **For your FR265**: Build a **High-Density Data Face**. You have the memory and the barometric sensor to show altitude trends and complex running metrics.
- **For your Wife's VA6**: Build a **Clean, High-Aesthetic Face**. Utilize the 1,500-nit screen for vibrant colors, but use the **System 8 Complications** to keep the logic light and the battery drain low.
