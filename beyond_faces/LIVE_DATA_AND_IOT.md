[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Beyond Faces: Live Data & IoT (BLE/Web)

Since you are an embedded engineer, you might want your watch to do more than just show time. Here is how to turn your Garmin into an **IoT Controller**.

---

## 1. BLE Bonding ("Just Works")
System 7 introduced improved Bluetooth Low Energy (BLE) bonding. 
- **The New Feature**: "Just Works" pairing allows your watch to connect to local ESP32s, Heart Rate straps, or even smart home hubs without a complex PIN handshake.
- **[Gemini] Idea**: Build a "Garage Door Opener" watchface. A long-press on a specific part of the screen sends a BLE command to an ESP32 in your garage.

---

## 2. JSON-over-Web (The "Live" Face)
Use a **Service Delegate** (Background Process) to pull live data every 5 minutes.
- **[Gemini] Trends for 2025**:
    - **Crypto/Stock Tickers**: Keep a tiny "Price" field that updates in the background.
    - **Home Assistant**: Trigger lights or check temperatures via web requests.
    - **Weather Pro**: Instead of standard Garmin weather, pull specific data (like UV Index or Surf Swell) from specialized APIs.

---

## 3. Complications as Data Consumers
Don't write your own weather engine. Use the **Complications API**.
- **[Gemini] Strategy**: Subscribe to the "Weather" complication. The OS handles the update frequency, saving you massive battery life compared to manual `makeWebRequest` calls.

---

## 4. [Gemini] Innovative Idea: "Remote Telemetry"
Since the **Forerunner 265** has a Barometer, it is a highly accurate altitude sensor. 
- **The Concept**: Broadcast your watch's sensor data (Altitude, HR, GPS) via BLE to a nearby tablet or bike computer.
- **API**: Use `BluetoothLowEnergy.setTransmitState()` to act as a Peripheral.

---

## 5. Security & Permissions
- **Web**: Needs `Communications` and `Background` permissions.
- **BLE**: Needs `BluetoothLowEnergy` permission.
- **[Gemini] Warning**: Always use HTTPS. Garmin will block non-SSL web requests by default in newer firmware.
