[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Workflow: From Zero to Watch (For Dummies)

Setting up Garmin development can feel like a "death by a thousand tools" process. This guide breaks it down into plain English steps specifically for the Forerunner 265 and Vivoactive 6.

---

> Before coding, review the [Web-Verified Research Brief](WEB_RESEARCH_BRIEF_FORERUNNER265_VIVOACTIVE6.md) to lock down device/API facts and AMOLED constraints from Garmin docs.

> Before implementation, fill the [CIQ Product Requirements Template](CIQ_PRODUCT_REQUIREMENTS_TEMPLATE.md) and review the [Pre-Build Discovery Findings + Idea Backlog](PREBUILD_DISCOVERY_AND_IDEA_BACKLOG.md).

## 1. The Pre-Requisites (The "Don't Skip" Part)
Before you even touch Garmin's tools, you need two things:
1. **Java 8 (JRE 1.8)**: While newer versions (11+) *might* work, **Java 8** is the "Gold Standard" for stability with the Monkey C compiler and simulator.
   - *Recommendation*: Download the standard Oracle JRE 1.8 or OpenJDK 8.
2. **VS Code**: Your primary code editor.

---

## 2. The Garmin Setup (The "Install" Part)
### Step A: The SDK Manager
1. Download the **Connect IQ SDK Manager** from the Garmin Developer site.
2. Open it and sign in with your Garmin account.
3. **Devices**: Find the **Forerunner 265** and **Vivoactive 6** in the list and click "Download." You must do this to get the specific resolutions and memory limits for your watches.
4. **SDK**: Download the latest SDK version (e.g., 8.x.x).

### Step B: The VS Code Extension
1. Open VS Code.
2. Go to the Extensions view (`Ctrl+Shift+X`) and search for **"Monkey C"** (by Garmin). Install it.
3. Open the Command Palette (`Ctrl+Shift+P`) and type: `Monkey C: Verify Installation`. If it complains about a path, point it to the SDKs folder you just downloaded.

---

## 3. The Developer Key (The "Security" Part)
You cannot run code on a real watch without a "Developer Key." It's an RSA file used to sign your app.
1. `Ctrl+Shift+P` -> `Monkey C: Generate Developer Key`.
2. Save this file somewhere safe (e.g., `Documents/Garmin/my_key.der`).
3. **NEVER DELETE THIS.** If you lose it, you can't update any apps you publish to the store.

---

## 4. Your First Build (The "Code" Part)
1. `Ctrl+Shift+P` -> `Monkey C: New Project`.
2. Choose "Watch Face" and name it.
3. **To Run in the Simulator**:
   - `F5` (or Debug > Start Debugging).
   - Select your device (e.g., FR 265).
   - The simulator will pop up. You can test gestures, low power mode, and "Heat Maps" here.

---

## 5. Sideloading (The "Real Watch" Part)
The simulator is great, but AMOLED screens are hard to judge until they are on your wrist.

### Step A: Generate the `.prg` file
1. `Ctrl+Shift+P` -> `Monkey C: Build for Device`.
2. Select your device (e.g., Vivoactive 6).
3. VS Code will create a `bin/` folder in your project. Inside is your file: `YourApp.prg`.

### Step B: Connect the Watch
1. Plug the watch into your USB port.
2. **Windows 10/11**: The watch uses **MTP (Media Transfer Protocol)**. It appears in File Explorer under "This PC," but does NOT get a drive letter.
3. **macOS**: Modern Garmins (FR265/VA6) **will not mount** as a drive on Mac. You **MUST** use a tool like **Android File Transfer** or **OpenMTP** to see the watch's file system.

### Step C: Copy and Run
1. Navigate to the `GARMIN/Apps/` folder on the watch.
2. **Copy** your `YourApp.prg` file into that folder.
3. Safely disconnect. The watch face will appear in your "Watch Face" selection menu immediately.

---

## 6. Troubleshooting: "Why didn't it work?"
- **"Symbol Not Found" on the watch**: Usually means your watch ran out of memory. Check the `memory/` guide.
- **Watch doesn't show up on PC**: Try a different USB cable (some are "charge only") or a different port.
- **App doesn't appear on the menu**: Ensure the `.prg` is in `GARMIN/Apps/` and NOT `GARMIN/Apps/Data/`.
- **The "Kill" Log**: If your watch crashes, plug it back into the PC and look for `GARMIN/Debug/CIQ_LOG.yml`. This file contains the exact line number where your code failed.
