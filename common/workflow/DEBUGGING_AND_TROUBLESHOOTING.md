[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Debugging & Troubleshooting: The Engineering Guide

Garmin development is notorious for the "Simulator vs. Device" gap. A watchface that runs perfectly on your PC may crash instantly on your Forerunner 265 or Vivoactive 6.

---

## 1. The Dreaded "IQ!" Icon (Device Crashes)
When you see the **IQ!** icon on your watch, the app has crashed.

### How to Find the Root Cause:
1. Connect your watch to your PC via USB.
2. Navigate to `/GARMIN/Apps/LOGS/`.
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
3. Place this `.txt` file in `/GARMIN/Apps/LOGS/` on the watch.
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

## 5. Android Wireless Debugging / ADB Pairing
If a phone connected over Wi-Fi debugging earlier and then refuses later, the stable DHCP reservation helps but does not freeze Android's debugging ports. Android can rotate the pairing and debug ports after toggles, reboots, or network changes.

### Recovery Workflow:
1. Restart the phone, PC, and router if the network path seems stale. In one May 2026 failure, a router reset may have been necessary before pairing worked again.
2. On the phone, go to Developer options -> **Wireless debugging**, then turn wireless debugging off and back on.
3. Tap **Pair device with pairing code**.
4. On the PC:
   ```powershell
   adb kill-server
   adb start-server
   adb pair PHONE_IP:PAIRING_PORT
   adb connect PHONE_IP:DEBUG_PORT
   adb devices -l
   ```
5. Use the pairing-code screen's port only for `adb pair`. After pairing, use the IP/port shown on the main Wireless debugging screen for `adb connect`; these ports are usually different.

### Checks:
- Phone and PC must be on the same Wi-Fi network, not a guest network.
- Router AP/client isolation must be off.
- VPNs on either device can block discovery or connection.
- Windows firewall/network profile can block the ADB path if the network is treated too restrictively.
- If `adb` is not on `PATH`, try `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.

---

## 6. The ERA Tool (Error Reporting Archive)
Garmin provides a tool to see crashes from users in the "real world."
- **Access**: In VS Code, `Ctrl+Shift+P` -> **Monkey C: View Error Reports**.
- **Usage**: This pulls logs from the Garmin App Store servers, showing you exactly which line of code crashed on which device model for your published apps.
