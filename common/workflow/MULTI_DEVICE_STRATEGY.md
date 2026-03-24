[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Workflow: Multi-Device Strategy (The "Jungle" Way)

You have a **Forerunner 265** (416px, 5-button) and your wife has a **Vivoactive 6** (390px, 2-button). Managing one codebase for both is an engineering challenge.

---

## 1. The `monkey.jungle` Power Move
The Jungle file is the "Makefile" of the Garmin world. Use it to swap resources and code based on the device.

```jungle
# Base paths
base.sourcePath = source
base.resourcePath = resources

# Special resources for the wife's VA6
vivoactive6.resourcePath = $(base.resourcePath);resources-va6
vivoactive6.excludeAnnotations = Buttons;Barometer

# Special resources for your FR265
fr265.resourcePath = $(base.resourcePath);resources-fr265
fr265.excludeAnnotations = TouchOnly;NoBaro
```

---

## 2. Conditional Compilation (Annotations)
Use annotations to completely strip code for the device that doesn't need it.
- **Example**:
```monkeyc
(:Barometer)
function getAltitudeTrend() {
    return Sensor.getInfo().ambientPressure; // Only compiled for FR265
}

(:NoBaro)
function getAltitudeTrend() {
    return Activity.getActivityInfo().altitude; // Only compiled for VA6 (GPS fallback)
}
```

---

## 3. UI Abstraction Layer
Don't hardcode `dc.drawText(208, 208, ...)`. 
- **The Strategy**: Use a "Layout Scale" constant.
```monkeyc
var centerX = dc.getWidth() / 2;
var centerY = dc.getHeight() / 2;
var scale = dc.getWidth() / 416.0; // Scale factor relative to FR265
```

---

## 4. [Gemini] New Idea: "The Configurator Pattern"
Instead of two different layouts, use a **JSON-based layout engine**.
1. Load a JSON file from `resources/` that defines where the Time, Heart Rate, and Steps should go.
2. Provide a different JSON for the VA6 vs. FR265.
3. This allows you to "re-skin" the watchface for your wife without touching a single line of Monkey C code.

---

## 5. Testing with "Device Families"
In the VS Code extension, you can "Build for All Devices in Project."
- **[Gemini] Tip**: Use the **"Prettier Monkey C"** extension's "Live Linting" to catch device-specific errors (like calling a Barometer function on a VA6) before you even hit the Compile button.
