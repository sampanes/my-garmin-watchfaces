[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Garmin VS Code for Dummies (Windows 10)

This guide walks you through the entire development lifecycle, assuming you've never touched a Garmin SDK before.

---

## 🚀 The "Golden Key" Hotkey
In VS Code, almost everything happens through the **Command Palette**.
- **`Ctrl + Shift + P`**: Memorize this. It is how you talk to the Garmin SDK.

---

## 1. Setup (The "One-Time" Stuff)
1. **Install Java**: Download and install **Java 8 (JRE 1.8)**. 
2. **Install Extension**: Go to the Extensions view (`Ctrl + Shift + X`), search for **"Monkey C"** (by Garmin), and install it.
3. **SDK Manager**: 
    - Press `Ctrl + Shift + P` -> **"Monkey C: SDK Manager"**.
    - Download the latest SDK and the **Forerunner 265** and **Vivoactive 6** device files.
4. **Developer Key**:
    - Press `Ctrl + Shift + P` -> **"Monkey C: Generate Developer Key"**.
    - Save the `.der` file in your Documents folder.
    - Go to Settings (`Ctrl + ,`), search for `Developer Key Path`, and paste the absolute path to your file.

---

## 2. Starting a New Project
1. Press `Ctrl + Shift + P` -> **"Monkey C: New Project"**.
2. **Name**: Use CamelCase (e.g., `MyCoolWatch`). *No hyphens!*
3. **Type**: Select **"Watch Face"**.
4. **Templates**: Select **"Simple"** (Complex ones can be overwhelming).
5. **Devices**: Check the boxes for **Forerunner 265** and **Vivoactive 6**.

---

## 3. The Development Loop (The "Daily" Stuff)

### Writing Code
- Open `source/MyCoolWatchView.mc`. This is where the magic happens.
- Use `Ctrl + P` to quickly jump between files in your project.

### Testing in the Simulator
1. **Press `F5`**. This starts the "Debugger."
2. **Select Device**: Choose **Forerunner 265** (or whichever you want to test).
3. **Result**: The Garmin Simulator window will pop up.
4. **Debug Console**: Press `Ctrl + Shift + Y` to see your `System.println()` messages.

### Making Changes
- Save your file (`Ctrl + S`).
- Press **`Ctrl + F5`** to "Run without Debugging" (this is often faster for quick UI tweaks).

---

## 4. Getting it onto the Watch (Sideloading)
1. Press `Ctrl + Shift + P` -> **"Monkey C: Build for Device"**.
2. **Device**: Select your watch model.
3. **Output**: Select your project's `bin/` folder.
4. **The File**: This creates a file named `MyCoolWatch.prg`.
5. **The Transfer**:
    - Plug your watch into the USB port.
    - Open Windows File Explorer.
    - Go to: `This PC > [Watch Name] > Internal Storage > Garmin > Apps`.
    - **Copy** your `.prg` file into that folder.
6. **The Result**: Unplug the watch. Your new watchface will appear in the "Watch Face" selection menu automatically.

---

## 5. Keyboard Shortcut Cheat Sheet
| Action | Hotkey |
| :--- | :--- |
| **Command Palette** | `Ctrl + Shift + P` |
| **Run / Debug** | `F5` |
| **Stop Debugging** | `Shift + F5` |
| **Toggle Console** | `Ctrl + Shift + Y` |
| **Search Files** | `Ctrl + P` |
| **Save All** | `Ctrl + K` then `S` |
| **Find in Files** | `Ctrl + Shift + F` |
| **Comment Line** | `Ctrl + /` |

---

## 6. Pro "Dummy" Tips
- **The Simulator is Black**: It probably crashed. Look at the **Debug Console** for an error message.
- **The Watch isn't showing up**: Try a different USB port or the original Garmin cable.
- **"Symbol Not Found"**: You probably tried to use a feature (like a Barometer) on a watch that doesn't have it (like the VA6). Use `has` checks!
