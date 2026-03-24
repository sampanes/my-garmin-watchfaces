[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Windows 10 & VS Code: Specific Quirks

Building Garmin apps on Windows 10 requires specific environment tuning. If the "Play" button in VS Code isn't working, it's likely one of these three things.

---

## 1. Java: The #1 Source of Failure
The Monkey C compiler is a Java application.
- **Requirement**: You **MUST** have **Java 8 (JRE 1.8)**. 
- **The Quirk**: Newer versions (Java 11, 17, 21) often cause the compiler to hang or throw "Unsupported Class Version" errors.
- **The Fix**: 
    1. Install JRE 1.8.
    2. In VS Code Settings, search for `Monkey C: Java Path`.
    3. Set it explicitly to your `java.exe` (e.g., `C:\Program Files\Java\jre1.8.0_361\bin\java.exe`).

---

## 2. Developer Key Permissions
If you get an error saying "Unable to sign PRG" or "Private Key not found":
- **The Quirk**: Windows sometimes restricts access to the `.der` file if it's in a protected folder (like `System32` or `Program Files`).
- **The Fix**: Keep your `developer_key.der` in your user Documents or a dedicated `C:\Dev\Garmin\` folder. 
- **VS Code Setting**: Ensure `Monkey C: Developer Key Path` is an **absolute path**, not a relative one.

---

## 3. MTP & USB Sideloading
Windows 10 handles the Forerunner 265 and Vivoactive 6 as "Media Devices" (MTP), not "USB Drives."
- **The Quirk**: You cannot "Drag and Drop" to a drive letter like `D:\`. You must navigate to `This PC > Forerunner 265 > Internal Storage > Garmin > Apps`.
- **Driver Issue**: If the watch doesn't show up in Explorer, open **Device Manager**, find the "MTP Device" with the yellow triangle, right-click -> **Update Driver** -> **Browse my computer** -> **Let me pick from a list** -> Select **"MTP USB Device"**.

---

## 4. Simulator Port Conflicts
The Garmin Simulator uses local ports **1234** and **1235**.
- **The Quirk**: If you have a web server (like Node.js or IIS) or a corporate VPN running, these ports might be blocked.
- **The Symptom**: The simulator window opens but stays "Black" or "Connecting..." forever.
- **The Fix**: Close other dev servers or add an exclusion to your Windows Firewall for `simulator.exe`.

---

## 5. Project Naming (The Hyphen Bug)
- **The Quirk**: Do **NOT** use hyphens (`-`) in your project folder name or App Name (e.g., `my-watch-face`). 
- **The Result**: The Monkey C resource compiler will throw a cryptic "mismatched input" error because it treats the hyphen as a subtraction operator in the generated `Rez` module.
- **The Fix**: Use **CamelCase** (`MyWatchFace`) or **Underscores** (`My_Watch_Face`).
