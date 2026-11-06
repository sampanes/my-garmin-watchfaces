[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Technical Specification: Vivoactive 6 (Released April 2025)

The Vivoactive 6 is a "Lifestyle" AMOLED smartwatch. While it shares the screen tech of the Forerunner 265, it has significant hardware omissions (no barometer) and a unique UI paradigm (The Action Notch).

---

## 1. Display & Graphics Specs
| Attribute | Specification |
| :--- | :--- |
| **Resolution** | **390 x 390 px** |
| **Shape** | Round |
| **Technology** | Ultra-Bright AMOLED (up to 1,500 nits) |
| **Color Depth** | 16-bit (64k colors) |
| **Always-On (AOD)** | Supported (System 8 Luminance) |

---

## 2. Memory Tiers (Heap Limits)
*Updated 2026-11-06 from Garmin's published device reference (https://developer.garmin.com/connect-iq/device-reference/vivoactive6/): the VA6 limits are the same as the FR265's, not tighter.*
- **Watch Faces**: **128 KB** (131072 B). Was "~124 KB".
- **Data Fields**: **256 KB** (262144 B). Was "~32 KB".
- **Device Apps / Widgets**: **768 KB** (786432 B). Was "256 KB - 512 KB".
- **Glances**: **64 KB** (65536 B).
- **Background Processes**: **64 KB** (65536 B). Was 32 KB.
- **Audio Content**: **512 KB** (524288 B).

---

## 3. Sensor Array (The "Lite" Suite)
**CRITICAL**: The Vivoactive 6 **lacks a Barometric Altimeter**. 

### Internal Sensors
- **GNSS**: Standard Multi-GNSS (GPS, GLONASS, Galileo, Beidou, QZSS). **No Multi-Band L1+L5**.
- **Heart Rate**: Garmin Elevate **Gen 4**.
- **Barometer**: **NONE**. Elevation is derived strictly from GPS/Maps.
- **Motion**: 3-axis Accelerometer + **Gyroscope (New to VA6)** + Compass.
- **Environment**: Ambient Light Sensor (ALS).

### External Sensor Support
- Heart Rate Straps (BLE/ANT+).
- Basic Speed/Cadence (Cycling).
- **Note**: Generally does not support advanced Cycling Power Meters or high-end Running Dynamics Pods natively in the OS, though CIQ apps may bypass this.

---

## 4. Input & Interaction
- **2 Physical Buttons**: (Top-Right: Action/Menu, Bottom-Right: Back/Lap).
- **Touchscreen**: Highly optimized for swipe-heavy navigation.
- **The "Action Notch"**: A hardware/software notch on the right side. Users swipe from the notch to trigger `onActionView()`.

---

## 5. Software Context
- **CIQ System**: **System 8** (API Level **6.0**; was "5.2.0+". Garmin Compatible Devices page, checked 2026-11-06: https://developer.garmin.com/connect-iq/compatible-devices/. The System label was not rechecked.)
- **Min. SDK**: **Connect IQ SDK 8.1.1**.
- **On-Device Music**: 8 GB Storage.
- **Key APIs**:
  - **Action View Pattern**: Required for menu triggers (`BehaviorDelegate.onActionView()`).
  - **Course Following**: Now supported natively (new to VA6).
  - **Running Power**: Calculated via wrist-based accelerometer (no pod needed).

---

## 6. Engineering Quirks
1. **The 32KB Data Field Wall** (superseded 2026-11-06: Garmin's device reference lists 256 KB for VA6 data fields, see section 2): With only 32KB for data fields, you must avoid Dictionaries entirely. Use Tuples or Parallel Arrays.
2. **Elevation `null`**: Any call to `Sensor.Info.ambientPressure` will return `null`. Apps relying on floor-climb counts will fail.
3. **Brightness (Burn-in)**: The 1,500-nit peak is significantly higher than the FR265. Aggressive checkerboarding or luminance-dimming in AOD is **mandatory** to prevent ghosting.
4. **Notch Interaction**: Traditional "Swipe Up" for menus is replaced by the notch interaction. If you don't implement `onActionView()`, your app may feel "broken" to VA6 users.
