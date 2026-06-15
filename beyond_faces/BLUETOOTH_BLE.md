[Home](../common/MASTER_MAP.md) | [Overview](../common/BIRDSEYE_VIEW.md)

# Beyond Faces: Bluetooth Low Energy (BLE)

Garmin watches can act as a BLE **Central** (scanning for and connecting to external peripherals like a smart light or bike sensor) using the `BluetoothLowEnergy` module. **They cannot act as a Peripheral / advertiser / GATT server** — see §4.

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

## 4. BLE Peripheral / Advertising — NOT SUPPORTED
**Connect IQ cannot act as a BLE peripheral, advertiser, or GATT server.** The
`BluetoothLowEnergy` module is **central/client only** (GATTC operations, since API
3.1.0). Methods like `setAdvertisingData()` / `setAdvertisingPayload()` /
`startAdvertising()` **do not exist** in the API. A watch can connect *to* a sensor;
it cannot *be* one — so it can't broadcast HR to Zwift, and **two watches cannot
connect to each other over BLE**.

> ⚠️ Corrected 2026-06-15. The previous version of this section (claiming
> `setAdvertisingData()`/`setAdvertisingPayload()` broadcasting) was an AI-research
> hallucination. Per Garmin dev Jim M: *"The BLE in CIQ is meant to connect to
> external sensors, but not act as one. I doubt that will change."*
> Sources: [BLE API docs](https://developer.garmin.com/connect-iq/api-docs/Toybox/BluetoothLowEnergy.html),
> [forum: broadcast HR by BLE](https://forums.garmin.com/developer/connect-iq/f/app-ideas/224447/broadcast-heart-rate-by-ble).

---

## 5. Engineering Gotchas
1. **Permissions**: You MUST add `<iq:permission id="BluetoothLowEnergy"/>` to your `manifest.xml`.
2. **Queued Operations**: BLE on Garmin is **Asynchronous**. You cannot send 10 write requests at once. You must wait for the `onCharacteristicWrite` callback before sending the next one.
3. **Handle Management**: You only have a limited number of "Handles" for BLE objects. Clean up unused `Device` and `Service` objects promptly.
4. **Android/iOS Bridge**: Garmin watches communicate with the internet *via* the Garmin Connect app. If you're building a companion app on the phone, the watch acts as a gateway.
5. **BLE Bonding**: Some devices require a secure bond (PIN code). Handling this in Connect IQ can be complex and model-dependent.
