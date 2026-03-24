[Home](MASTER_MAP.md) | [Overview](BIRDSEYE_VIEW.md)

# Garmin Connect IQ: Master Knowledge Map (MOC)

Welcome to the **Linked Knowledge Tree** for Garmin development. This map connects all the specialized documentation we've built, focused on the **Forerunner 265** and **Vivoactive 6**.

---

## 🗺️ Core Knowledge Pillars

### 1. [The Language: Monkey C](language/MONKEY_C_GUIDE.md)
*The foundation of everything. Syntax, Types, and the Virtual Machine.*
- 🔗 Related: [Memory Management](memory/MEM_PART1_ARC_AND_LEAKS.md)

### 2. [Architecture & Power](architecture/APP_LIFECYCLE_AND_POWER.md)
*How apps live, breathe, and sleep. Crucial for battery life.*
- 🔗 Related: [AMOLED Burn-In Protection](architecture/AMOLED_BURN_IN.md)
- 🔗 Related: [Future-Proofing: Connect IQ System 9 (2026)](architecture/FUTURE_PROOFING_2026.md)

### 3. [The Graphics Engine (5 Parts)](graphics/DC_PART1_PRIMITIVES.md)
*Drawing everything from pixels to neon glows.*
- [Part 1: Primitives](graphics/DC_PART1_PRIMITIVES.md)
- [Part 2: Typography](graphics/DC_PART2_TYPOGRAPHY.md)
- [Part 3: Resources & Optimization](graphics/DC_PART3_RESOURCES_AND_PERFORMANCE.md)
- [Part 4: Pro Hacks](graphics/DC_PART4_PRO_HACKS.md)
- [Part 5: Advanced UI & Dynamic Vector Engine](graphics/DC_PART5_ADVANCED_UI.md)

### 4. [Memory Mastery (3 Parts)](memory/MEM_PART1_ARC_AND_LEAKS.md)
*Fighting the 128KB wall and preventing crashes.*
- [Part 1: ARC & Leaks](memory/MEM_PART1_ARC_AND_LEAKS.md)
- [Part 2: Object Overhead](memory/MEM_PART2_OVERHEAD_AND_TYPES.md)
- [Part 3: Optimization Tools](memory/MEM_PART3_OPTIMIZATION_AND_TOOLS.md)

### 5. [Beyond Watchfaces](beyond_faces/SENSORS_AND_GPS.md)
*Hardware access, connectivity, and background logic.*
- [Sensors & GPS](beyond_faces/SENSORS_AND_GPS.md)
- [Web & Background Tasks](beyond_faces/WEB_AND_BACKGROUND.md)
- [Bluetooth BLE](beyond_faces/BLUETOOTH_BLE.md)
- [Live Data & IoT (BLE/Web)](beyond_faces/LIVE_DATA_AND_IOT.md)

---

## 🚀 Getting Started
<<<<<<< HEAD
- **Newcomer?** Start with the [Workflow & Sideloading Guide](workflow/BUILD_AND_SIDELOAD.md).
- **Pre-coding facts?** Read the [Web-Verified Research Brief](workflow/WEB_RESEARCH_BRIEF_FORERUNNER265_VIVOACTIVE6.md).
- **Planning next?** Use the [Pre-Build Discovery Findings + Idea Backlog](workflow/PREBUILD_DISCOVERY_AND_IDEA_BACKLOG.md).
- **Spec before build?** Fill the [CIQ Product Requirements Template](workflow/CIQ_PRODUCT_REQUIREMENTS_TEMPLATE.md).
=======
- **Newcomer?** Start with the [VS Code for Dummies Guide](workflow/VS_CODE_FOR_DUMMIES.md).
- **Workflow?** See the [Standard Build & Sideload Guide](workflow/BUILD_AND_SIDELOAD.md).
- **Troubleshooting?** Check the [Debugging & Issues Guide](workflow/DEBUGGING_AND_TROUBLESHOOTING.md) and [Windows Quirks](workflow/WINDOWS_SPECIFIC_QUIRKS.md).
- **Multi-Device Expert?** See the [Multi-Device Strategy Guide](workflow/MULTI_DEVICE_STRATEGY.md).
>>>>>>> f612df9 (Gemini Additions)
- **High-Level Overview?** See the [Bird's Eye View](BIRDSEYE_VIEW.md).

---

## 🛠️ Tooling Recommendation
To view this as a true "Knowledge Tree," open this folder in **Obsidian**.
1. Install [Obsidian](https://obsidian.md/).
2. "Open folder as vault" -> Select this project directory.
3. Click the **Graph View** icon on the left to see the visual web of connections.

**Note on Links:** While this project uses standard Markdown links for broad compatibility, Obsidian also supports **wikilinks** like `[[MASTER_MAP]]`. You can use either style to navigate between files.
