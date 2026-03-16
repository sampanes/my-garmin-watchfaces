[Home](MASTER_MAP.md) | [Overview](BIRDSEYE_VIEW.md)

You have bought your wife a VivoActive 6
 and yourself a Forerunner 265, I will notate this and keep it as a priority pair of watch-types for future documentation.

Since you are an embedded engineer, I will skip the fluff. You want to use Monkey C (Garmin’s OO language, ref-counted, compiles to bytecode for a VM) and the Connect IQ SDK. [1] 
Here is the engineering fast-track to building and sideloading your own watch faces.
1. The Stack (VS Code Based)
Garmin deprecated the Eclipse plugin. The standard environment is now:

* VS Code + Monkey C Extension (Official Garmin).
* Connect IQ SDK Manager: Use this to download the toolchain and specific device definitions (download the specific models you and your wife own).
* Developer Key: Required to sign binaries (.prg). Generate this via the VS Code extension command palette: Monkey C: Generate Developer Key. [1, 2, 3, 4] 

2. The Runtime Architecture
A watch face is a strictly power-constrained app. You subclass WatchUi.WatchFace. The system invokes your specific methods based on the power state.

* onUpdate(dc): The main draw loop.
* Low Power Mode: Runs once per minute. Most of the day, your watch is in this state.
   * High Power Mode: Runs 1Hz for ~10 seconds when the user raises their wrist ("gesture").
* onPartialUpdate(dc) (Optional):
* Runs 1Hz always (if supported/enabled) to draw seconds or heart rate.
   * Strict Power Budget: You have an execution time limit (typically ~30ms, varies by device). If your code exceeds this average over a minute, the OS kills your watch face and reverts to the default. You must use dc.setClip() to only redraw the pixels changing (e.g., the bounding box of the second hand).

3. Embedded Constraints & "Gotchas"

* Memory: You are working with a heap of ~64KB–128KB (device dependent).
* AMOLED vs. MIP:
* MIP (Fenix/Forerunner): straightforward bit-mapped reflex display.
   * AMOLED (Venu/Epix): You must implement burn-in protection. In "Always On" mode, you cannot light up more than ~10% of pixels, and you must shift static elements periodically. The SDK provides flags to detect this mode.
* Jungles (.jungle):
* This is the build configuration system (like a Makefile). Since you and your wife likely have different watches (different resolutions/shapes), you use Jungles to map different resource paths (layouts, fonts) to specific device compiler targets. [5] 

4. "Hello World" to Wrist (Sideloading)
You do not need to publish to the store to run code on your own devices.

   1. Create Project: Ctrl+Shift+P -> Monkey C: New Project -> Watch Face.
   2. Build: Ctrl+Shift+P -> Monkey C: Build for Device. Select the specific model.
   3. Output: This generates a .prg file in your bin/ folder.
   4. Install:
   * Plug the watch into your PC via USB (Mounts as Mass Storage / MTP).
      * Copy the .prg file into GARMIN/Apps/.
      * Disconnect. The watch face will be available in the selection menu immediately. [5] 
   
5. Code Snippet: The onUpdate Loop
Here is the basic structure you will be working in (source/YourView.mc):

using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;

class MyEngineerFaceView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources (fonts, images) here to avoid I/O in onUpdate
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called once a minute (low power) or 1Hz (high power)
    function onUpdate(dc) {
        // 1. Clear screen
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();

        // 2. Get Time
        var clockTime = System.getClockTime();
        var timeString = Lang.format("$1$:$2$", [clockTime.hour, clockTime.min.format("%02d")]);

        // 3. Draw (Direct DC calls are faster than Layouts for complex logic)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth()/2, dc.getHeight()/2, Graphics.FONT_LARGE, timeString, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}


[1] [https://www.youtube.com](https://www.youtube.com/shorts/ricDJ-kt9bQ)
[2] [https://github.com](https://github.com/AndrewKhassapov/connect-iq)
[3] [https://medium.com](https://medium.com/@ericbt/design-your-own-garmin-watch-face-21d004d38f99)
[4] [https://packagecontrol.io](https://packagecontrol.io/packages/MonkeyC#:~:text=If%20you%20don%27t%20have%20a%20key%20and,and%20update%20your%20key%20path%20for%20you.)
[5] [https://github.com](https://github.com/AndrewKhassapov/connect-iq)

---

Yes, Garmin provides a comprehensive, public developer portal specifically for Connect IQ and Monkey C. Given your background, you’ll find the documentation is structured similarly to most modern SDKs, though with a heavy focus on the unique power and memory constraints of wearable hardware. [1] 
Official Documentation Hubs

* Monkey C Language Guide: This is the core reference for the language itself. It covers object-oriented principles, memory management (reference counting), and Monkey C-specific features like "annotations" for code stripping.
* [Connect IQ API Reference](https://developer.garmin.com/connect-iq/sdk/): The "Toybox" (Garmin's standard library). You’ll spend most of your time in Toybox.Graphics, Toybox.System, and Toybox.WatchUi.
* [Programmer's Guide](https://developer.garmin.com/connect-iq/connect-iq-basics/): A high-level manual covering the app lifecycle, the resource compiler (XML-based layouts/images), and "Jungles" (the build configuration system). [2, 3, 4, 5, 6] 

Engineering-Specific Resources

* Connect IQ Developer Forum: This is the most active part of the community. Since some edge-case hardware behaviors aren't always in the docs, searching the forums is often necessary for advanced troubleshooting.
* [Sample Code Library](https://github.com/garmin/connectiq-apps): Garmin maintains a GitHub repository with official samples (e.g., analog watch faces, complex data fields) which are excellent for seeing how to handle specific sensors or display types.
* [Reference Guides](https://developer.garmin.com/connect-iq/app-review-guidelines/): Detailed docs for secondary tools like Monkey Motion (for animations) and the ERA (Error Reporting Tool) for viewing crash logs from devices in the field. [4, 7, 8, 9, 10] 

Common Feedback for Pros
Experienced developers often find the official documentation a bit sparse on complex examples, noting that while the API reference is solid, the "how-to" for advanced tasks sometimes requires trial and error or digging through the [Developer FAQ](https://developer.garmin.com/connect-iq/connect-iq-faq/). However, for an embedded engineer already familiar with Garmin's internal ecosystem, the public SDK will likely feel very accessible. [11, 12] 

[1] [https://medium.com](https://medium.com/@earel329/garmin-iq-and-monkey-c-fundamentals-ffe83eebb3fc)
[2] [https://developer.garmin.com](https://developer.garmin.com/connect-iq/monkey-c/)
[3] [https://developer.garmin.com](https://developer.garmin.com/connect-iq/monkey-c/annotations/#:~:text=Monkey%20C%20allows%20associating%20symbols%20with%20class,%28:test%29%20static%20function%20testThisClass%28%20x%20%29%20%7D)
[4] [https://github.com](https://github.com/garmin/connectiq-apps)
[5] [https://developer.garmin.com](https://developer.garmin.com/connect-iq/api-docs/Toybox/Test.html)
[6] [https://developer.garmin.com](https://developer.garmin.com/connect-iq/connect-iq-basics/)
[7] [https://marketplace.visualstudio.com](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)
[8] [https://forums.garmin.com](https://forums.garmin.com/developer/connect-iq/w/wiki/3/connect-iq-faq#:~:text=The%20best%20place%20to%20start%20is%20on,to%20download%20the%20software%20development%20kit%20%28SDK%29.)
[9] [https://forums.garmin.com](https://forums.garmin.com/developer/connect-iq/w/wiki/3/connect-iq-faq)
[10] [https://developer.garmin.com](https://developer.garmin.com/connect-iq/reference-guides/monkey-motion-reference/)
[11] [https://forums.garmin.com](https://forums.garmin.com/developer/connect-iq/f/discussion/404843/connect-iq-sdk-documentation)
[12] [https://www.reddit.com](https://www.reddit.com/r/Garmin/comments/1eqgd5t/repeat_or_not_to_repeat_monkey_c_path/)

---

---

## 🛠️ Post-Session Engineering Summary (v1.2)

We have completed a comprehensive deep-dive documentation project for the **Forerunner 265** and **Vivoactive 6**. The following core pillars are now established in the local knowledge base, including the latest **System 7 (API 5.0.0+)** updates:

### 1. The Language (Monkey C)
- **Paradigm**: Object-oriented, bytecode-compiled for a specialized VM.
- **Typing**: Gradual Type System. Use `as` for strictness.
- **System 7 Updates**: New `Tuple` type for memory-efficient data structures. Paged code support (System 8) up to 16MB.

### 2. AMOLED Hardware Constraints
- **10% Pixel Rule**: Traditional rule for burn-in protection.
- **Luminance Model (System 7)**: Newer devices (Vivoactive 6) use total brightness instead of pixel count. Allows more pixels if they are dimmed.
- **Heat Map Validation**: Mandatory simulator tool to prevent firmware "killing" your watchface.

### 3. Graphics & Performance
- **The DC**: (0,0) top-left. Polar-to-Cartesian for round screens.
- **Complications API**: System 7 standardized data subscriptions (Weather, Steps) for battery efficiency.
- **Native Editor**: Users can customize settings directly on the watch via `<watchface-config>`.

### 4. Memory Management
- **Heap Limits**: ~128KB. Use `Parallel Arrays` or `Tuples` over `Dictionaries`.
- **Background Tasks**: Still limited to a **32KB wall**. Use annotations strictly.

### 5. Deployment & Monetization
- **Sideload**: `.prg` to `GARMIN/Apps/` via MTP.
- **Native Payments**: Official store monetization now supported; no more 3rd-party unlock code hacks.
- **Policy**: Original designs only (2025 Store Policy).

**Full documentation is available via the [[MASTER_MAP.md]] Knowledge Tree.**
