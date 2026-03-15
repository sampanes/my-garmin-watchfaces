[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Beyond Faces: Bluetooth Low Energy (BLE)

Garmin watches can act as both a **Central** (controlling a smart light or bike sensor) and a **Peripheral** (broadcasting data to another device) using the `BluetoothLowEnergy` module.

---

Back: [Web & Background Tasks](WEB_AND_BACKGROUND.md)

---

## 1. BLE Central (Connecting to Other Devices)
You can scan for, connect to, and interact with non-Garmin Bluetooth devices.

### Scanning for a Peripheral:
```monkeyc
using Toybox.BluetoothLowEnergy;

function startScan() {
    BluetoothLowEnergy.setScanState(BluetoothLowEnergy.SCAN_STATE_ON);
}

function onScanResults(scanResults) {
    for (var result = scanResults.next(); result != null; result = scanResults.next()) {
        // Check if this is the device you want
        if (result.getDeviceName().equals("MySmartDevice")) {
            BluetoothLowEnergy.pairDevice(result);
        }
    }
}
```

---

## 2. Profile Definitions
Unlike standard BLE on a phone, Garmin requires you to pre-define the **GATT Profile** in your code using a `Dictionary`.

```monkeyc
var profile = {
    :uuid => BluetoothLowEnergy.stringToUuid("0000180D-0000-1000-8000-00805f9b34fb"), // Heart Rate Service
    :characteristics => [{
        :uuid => BluetoothLowEnergy.stringToUuid("00002a37-0000-1000-8000-00805f9b34fb"), // Measurement
        :descriptors => [BluetoothLowEnergy.cccdUuid()]
    }]
};
BluetoothLowEnergy.registerProfile(profile);
```

---

## 3. Reading/Writing Data
Once connected, you interact with the device's **Characteristics**.
- **Read**: `characteristic.requestRead()`
- **Write**: `characteristic.requestWrite(data, options)`
- **Notify**: Register a listener for the CCCD (Client Characteristic Configuration Descriptor).

---

## 4. BLE Peripheral (Broadcasting)
Some Garmin watches can broadcast their own data (like Heart Rate) to other devices.
- **Usage**: Use `BluetoothLowEnergy.setAdvertisingData()` and `BluetoothLowEnergy.setAdvertisingPayload()`.
- **Constraint**: This is very power-intensive and usually limited by watch model.

---

## 5. Engineering Gotchas
1. **Permissions**: You MUST add `<iq:permission id="BluetoothLowEnergy"/>` to your `manifest.xml`.
2. **Queued Operations**: BLE on Garmin is **Asynchronous**. You cannot send 10 write requests at once. You must wait for the `onCharacteristicWrite` callback before sending the next one.
3. **Handle Management**: You only have a limited number of "Handles" for BLE objects. Clean up unused `Device` and `Service` objects promptly.
4. **Android/iOS Bridge**: Garmin watches communicate with the internet *via* the Garmin Connect app. If you're building a companion app on the phone, the watch acts as a gateway.
5. **BLE Bonding**: Some devices require a secure bond (PIN code). Handling this in Connect IQ can be complex and model-dependent.
