[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Technical Specification: Forerunner 265 / 265S

The Forerunner 265 is a high-performance, multi-sport AMOLED wearable. For developers, it represents the "Gold Standard" for mid-to-high-tier Garmin devices, offering a robust sensor suite and generous memory for a watchface.

---

## 1. Display & Graphics Specs
| Attribute | Forerunner 265 (Standard) | Forerunner 265S (Small) |
| :--- | :--- | :--- |
| **Resolution** | **416 x 416 px** | **360 x 360 px** |
| **Shape** | Round | Round |
| **Technology** | AMOLED (High Brightness) | AMOLED (High Brightness) |
| **Color Depth** | 16-bit (64k colors) | 16-bit (64k colors) |
| **Always-On (AOD)** | Supported (System 7 Luminance) | Supported (System 7 Luminance) |

---

## 2. Memory Tiers (Heap Limits)
*These values are estimates based on firmware v18.xx and Connect IQ 5.x.*
- **Watch Faces**: **128 KB** (Generous for complex animations).
- **Data Fields**: **128 KB** (Simple) / **256 KB** (Full Screen/Complex).
- **Device Apps / Widgets**: **1024 KB (1 MB)**.
- **Background Processes**: **32 KB** (The universal constraint).
- **Audio Content**: **1024 KB (1 MB)**.

---

## 3. Sensor Array (The "Full" Suite)
The 265 includes the **Barometric Altimeter**, which is a critical differentiator from the Vivoactive line.

### Internal Sensors
- **GNSS**: Multi-Band / Dual-Frequency (L1 + L5). Supports **SatIQ** (Auto-select).
- **Heart Rate**: Garmin Elevate **Gen 4**.
- **Barometer**: **Yes** (Provides `ambientPressure` and `floorClimbing` data).
- **Pulse Ox**: Yes.
- **Motion**: 3-axis Accelerometer + Gyroscope + Compass.
- **Environment**: Thermometer (Ambient) + Ambient Light Sensor (ALS).

### External Sensor Support (ANT+ / BLE)
- Heart Rate Straps (HRM-Pro / Swim).
- Cycling Sensors (Power, Cadence, Speed).
- Foot Pods & Running Dynamics Pods.

---

## 4. Input & Interaction
- **5 Physical Buttons**: (Light, Up, Down, Start/Stop, Back).
- **Touchscreen**: Capacitive (supports multi-touch gestures).
- **Haptics**: Linear resonant actuator (standard vibration).

---

## 5. Software Context
- **CIQ System**: **System 7** (API Level 5.0.0+).
- **Min. SDK**: Connect IQ SDK 6.2.x.
- **On-Device Music**: 8 GB Storage.
- **Key APIs**: 
  - Supports **Running Dynamics** (GCT, Vertical Oscillation).
  - Supports **Training Readiness** (Glanceable data).
  - Supports **Complications API** (Provider and Consumer).

---

## 6. Engineering Quirks
1. **Saturation Risk**: The 416px AMOLED is very dense. Small text (<12pt) can "bleed" at high brightness. Use high-contrast anti-aliasing.
2. **Gesture Sensitivity**: The 265 is known for a very sensitive "wrist-flip" gesture; avoid logic that triggers complex calculations on every `onExitSleep` unless necessary.
3. **MTP Only**: Windows users MUST use MTP to sideload. Mac users need "Android File Transfer."
