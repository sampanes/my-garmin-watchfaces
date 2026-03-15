[Home](MASTER_MAP.md) | [Overview](BIRDSEYE_VIEW.md)

# Bird's Eye View: Garmin Watchface Development

This document serves as the master roadmap for documenting the Garmin Connect IQ ecosystem, focusing on engineering watchfaces for the **Forerunner 265** and **Vivoactive 6**.

---

## 1. Project Objectives
- **Centralize Knowledge**: Convert fragmented online documentation into a structured, searchable local Markdown repository.
- **Engineering Focus**: Skip high-level "fluff" and focus on memory management, power constraints, and hardware-specific optimizations.
- **Device Specialization**: Deep-dive into AMOLED-specific requirements (burn-in, power budgets) for our target devices.

---

## 2. Target Hardware Profiles
| Feature | Forerunner 265 | Vivoactive 6 |
| :--- | :--- | :--- |
| **Display Type** | AMOLED | AMOLED |
| **Resolution** | 416 x 416 px | 390 x 390 px |
| **Input** | 5 Buttons + Touch | 2 Buttons + Touch |
| **Memory (Heap)** | ~128 KB (Est.) | ~64-128 KB (Est.) |
| **Always-On Support** | Yes (Requires Burn-in Protection) | Yes (Requires Burn-in Protection) |

---

## 3. Core Technical Stack
- **Language**: Monkey C (Object-oriented, reference-counted, bytecode-compiled).
- **Runtime**: Connect IQ Virtual Machine.
- **IDE**: VS Code + Monkey C Extension.
- **Tooling**:
  - `Connect IQ SDK Manager`: For toolchain and device definition updates.
  - `Manifest.xml`: App properties and permissions.
  - `Jungles (.jungle)`: Build configuration and resource mapping.

---

## 4. Documentation Roadmap (The "Spin-off" Plan)
We will systematically fetch and decompose the following resources into specific sub-folders and documents:

### Folder: `/language`
- [x] `MONKEY_C_GUIDE.md`: Syntax, Types, Objects, and Annotations.
- [ ] `MEMORY_MANAGEMENT.md`: Reference counting, weak pointers, and heap optimization.

### Folder: `/architecture`
- [x] `APP_LIFECYCLE_AND_POWER.md`: `WatchUi.WatchFace` states, AMOLED constraints, and 30ms budget.
- [ ] `AMOLED_BURN_IN.md`: Pixel-shifting, 10% brightness rules, and recovery techniques.

### Folder: `/graphics`
- [x] `DC_PART1_PRIMITIVES.md`: Coordinates, Colors, Lines, and Shapes.
- [x] `DC_PART2_TYPOGRAPHY.md`: Fonts, Justification, and Radial Text.
- [x] `DC_PART3_RESOURCES_AND_PERFORMANCE.md`: Bitmaps, Buffers, and XML Layouts.

### Folder: `/workflow`
- [ ] `BUILD_AND_SIDELOAD.md`: `.prg` generation and manual device deployment.
- [ ] `DEBUGGING_TOOLS.md`: Using the Simulator, ERA (Error Reporting), and console logging.

---

## 5. Primary External Sources
These are the URLs we will be "harvesting" in the next steps:
- **Language**: [Monkey C Language Guide](https://developer.garmin.com/connect-iq/monkey-c/)
- **API Reference**: [Connect IQ Toybox API Docs](https://developer.garmin.com/connect-iq/sdk/)
- **Basics**: [Connect IQ Programmer's Guide](https://developer.garmin.com/connect-iq/connect-iq-basics/)
- **Examples**: [Official Garmin GitHub Samples](https://github.com/garmin/connectiq-apps)
- **Community**: [Garmin Developer Forums](https://forums.garmin.com/developer/connect-iq/)

---

## 6. Known "Gotchas" & Critical Constraints
1. **The 30ms Wall**: If `onPartialUpdate` exceeds ~30ms average, the OS kills the watchface. Redrawing *only* changed pixels is mandatory.
2. **AMOLED Strictness**: Static elements must move every minute in AOD mode. No more than 10% of pixels can be lit.
3. **Reference Counting**: Circular references will cause memory leaks; understand `WeakPointer` early.
4. **MTP Limitations**: On Windows, the watch must be handled as a media device for sideloading `.prg` files.
