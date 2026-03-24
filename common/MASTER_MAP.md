[Home](MASTER_MAP.md) | [Overview](BIRDSEYE_VIEW.md)

# Garmin Connect IQ: Master Knowledge Map (MOC)

Welcome to the linked knowledge tree for Garmin development. This map connects the shared references in `common/`, the broader capability notes in `beyond_faces/`, and the project-specific docs under `watch-faces/`.

---

## Core Knowledge Pillars

### 1. [The Language: Monkey C](language/MONKEY_C_GUIDE.md)
*The foundation of everything. Syntax, types, and the VM.*
- Related: [Memory Management](memory/MEM_PART1_ARC_AND_LEAKS.md)

### 2. [Architecture & Power](architecture/APP_LIFECYCLE_AND_POWER.md)
*How apps live, breathe, and sleep. Crucial for battery life.*
- Related: [AMOLED Burn-In Protection](architecture/AMOLED_BURN_IN.md)
- Related: [Future-Proofing: Connect IQ System 9 (2026)](architecture/FUTURE_PROOFING_2026.md)

### 3. [The Graphics Engine](graphics/DC_PART1_PRIMITIVES.md)
*Drawing everything from pixels to polished watch-face composition.*
- [Part 1: Primitives](graphics/DC_PART1_PRIMITIVES.md)
- [Part 2: Typography](graphics/DC_PART2_TYPOGRAPHY.md)
- [Part 3: Resources & Optimization](graphics/DC_PART3_RESOURCES_AND_PERFORMANCE.md)
- [Part 4: Pro Hacks](graphics/DC_PART4_PRO_HACKS.md)
- [Part 5: Advanced UI & Dynamic Vector Engine](graphics/DC_PART5_ADVANCED_UI.md)

### 4. [Memory Mastery](memory/MEM_PART1_ARC_AND_LEAKS.md)
*Fighting the memory wall and preventing crashes.*
- [Part 1: ARC & Leaks](memory/MEM_PART1_ARC_AND_LEAKS.md)
- [Part 2: Object Overhead](memory/MEM_PART2_OVERHEAD_AND_TYPES.md)
- [Part 3: Optimization Tools](memory/MEM_PART3_OPTIMIZATION_AND_TOOLS.md)

### 5. [Beyond Watch Faces](../beyond_faces/SENSORS_AND_GPS.md)
*Hardware access, connectivity, and background logic beyond standard watch-face scope.*
- [Sensors & GPS](../beyond_faces/SENSORS_AND_GPS.md)
- [Web & Background Tasks](../beyond_faces/WEB_AND_BACKGROUND.md)
- [Bluetooth BLE](../beyond_faces/BLUETOOTH_BLE.md)
- [Live Data & IoT (BLE/Web)](../beyond_faces/LIVE_DATA_AND_IOT.md)

### 6. Watch Face Projects
*Project-specific concept docs, feasibility notes, and build plans.*
- [Japanese Ink Heartrate](../watch-faces/japanese-ink-heartrate/JAPANESE_INK_HEARTRATE.md)
- [Japanese Ink Heartrate Feasibility](../watch-faces/japanese-ink-heartrate/FEASIBILITY_ASSESSMENT.md)

---

## Getting Started

- **Newcomer?** Start with the [Workflow & Sideloading Guide](workflow/BUILD_AND_SIDELOAD.md).
- **Tooling setup?** Read the [VS Code for Dummies Guide](workflow/VS_CODE_FOR_DUMMIES.md).
- **Pre-coding facts?** Read the [Web-Verified Research Brief](workflow/WEB_RESEARCH_BRIEF_FORERUNNER265_VIVOACTIVE6.md).
- **Planning next?** Use the [Pre-Build Discovery Findings + Idea Backlog](workflow/PREBUILD_DISCOVERY_AND_IDEA_BACKLOG.md).
- **Spec before build?** Fill the [CIQ Product Requirements Template](workflow/CIQ_PRODUCT_REQUIREMENTS_TEMPLATE.md).
- **Troubleshooting?** Check the [Debugging & Issues Guide](workflow/DEBUGGING_AND_TROUBLESHOOTING.md) and [Windows Quirks](workflow/WINDOWS_SPECIFIC_QUIRKS.md).
- **Multi-device planning?** See the [Multi-Device Strategy Guide](workflow/MULTI_DEVICE_STRATEGY.md).
- **High-level overview?** See the [Bird's Eye View](BIRDSEYE_VIEW.md).

---

## Tooling Recommendation

To view this as a true knowledge tree, open this folder in **Obsidian**.

1. Install [Obsidian](https://obsidian.md/).
2. Open this project directory as a vault.
3. Use Graph View to inspect the connections between `common/`, `beyond_faces/`, and `watch-faces/`.

**Note on links:** This project uses standard Markdown links for broad compatibility, but Obsidian wikilinks such as `[[MASTER_MAP]]` also work well for local navigation.
