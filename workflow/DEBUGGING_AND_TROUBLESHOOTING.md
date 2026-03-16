[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Debugging & Troubleshooting: The Engineering Guide

Garmin development is notorious for the "Simulator vs. Device" gap. A watchface that runs perfectly on your PC may crash instantly on your Forerunner 265 or Vivoactive 6.

---

## 1. The Dreaded "IQ!" Icon (Device Crashes)
When you see the **IQ!** icon on your watch, the app has crashed.

### How to Find the Root Cause:
1. Connect your watch to your PC via USB.
2. Navigate to `/GARMIN/APPS/LOGS/`.
3. Open **`CIQ_LOG.yml`** (or `.txt`).
4. **Common Error Codes**:
   - `Symbol Not Found Error`: You called a function or variable that doesn't exist on this specific firmware. (Check your `has` capability checks!)
   - `Out Of Memory Error`: You exceeded the heap (128KB).
   - `Stack Underflow/Overflow`: Usually caused by infinite recursion or too many nested function calls.
   - `Unexpected Type Error`: You tried to perform math on a `null` or a `String`.

---

## 2. On-Device Logging (`println`)
`System.println()` works in the simulator console, but it can also work on the physical device.

### The "Text File" Trick:
1. Find your app's filename (e.g., `MYFACE.PRG`).
2. Create an empty text file with the **exact same name**: `MYFACE.TXT`.
3. Place this `.txt` file in `/GARMIN/APPS/LOGS/` on the watch.
4. Run your watchface. Now, all `println` statements will be written to that text file for you to read later.

---

## 3. The "Object Limit" Wall
This is a "hidden" constraint. Even if you have 50KB of free memory, the device may crash if you have too many **Objects**.
- **The Limit**: Most watches limit you to **256 or 512 total objects** (strings, arrays, class instances).
- **The Fix**: 
    - Use `Parallel Arrays` instead of an `Array of Objects`.
    - Avoid creating temporary strings in your `onUpdate` loop.
    - Use `Tuples` (System 7+) which count as a single object.

---

## 4. Simulator vs. Device Discrepancies
| Feature | Simulator Behavior | Physical Device Reality |
| :--- | :--- | :--- |
| **Fonts** | Uses Windows system fonts (Smooth). | Uses hardware-specific bitmaps (Chunkier). |
| **Speed** | 3.0GHz+ PC CPU (Instant). | ~10-30MHz Embedded CPU (Slow). |
| **Network** | Uses PC Wi-Fi/Ethernet. | Uses BLE through a phone (High latency/Failure rate). |
| **Float Math** | Highly precise. | Can have slight rounding errors on older hardware. |

---

## 5. The ERA Tool (Error Reporting Archive)
Garmin provides a tool to see crashes from users in the "real world."
- **Access**: In VS Code, `Ctrl+Shift+P` -> **Monkey C: View Error Reports**.
- **Usage**: This pulls logs from the Garmin App Store servers, showing you exactly which line of code crashed on which device model for your published apps.
