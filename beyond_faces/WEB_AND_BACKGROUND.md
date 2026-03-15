[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Beyond Faces: Web & Background Tasks

---

## 🔗 Related Documentation
- [Bluetooth Low Energy (BLE)](BLUETOOTH_BLE.md)

---

## 1. Web Requests (`Toybox.Communications`)
You can fetch JSON, text, or even small images over the internet.

### Basic GET Request:
```monkeyc
using Toybox.Communications;

function makeRequest() {
    var url = "https://api.example.com/data";
    var params = { "format" => "json" };
    var options = {
        :method => Communications.HTTP_REQUEST_METHOD_GET,
        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
    };

    Communications.makeWebRequest(url, params, options, method(:onReceive));
}

function onReceive(responseCode, data) {
    if (responseCode == 200) {
        // 'data' is a Monkey C Dictionary representing the JSON
        System.println("Received: " + data["key"]);
    }
}
```

---

## 2. Background Processes
A background process (also called a "Service Delegate") can run even if your watchface is asleep or the user is in another app.

### How it Works:
- **Temporal Event**: You can schedule the background process to wake up every 5 minutes (the minimum interval).
- **Service Delegate**: This is a separate class marked with the `(:background)` annotation.

### The Background Lifecycle:
1. **Schedule**: `Background.registerForTemporalEvent(new Time.Duration(300));` (300 seconds = 5 minutes).
2. **Wake Up**: The system instantiates your `ServiceDelegate`.
3. **Execute**: `onTemporalEvent()` is called. You can do a web request here.
4. **Exit**: `Background.exit(data);` kills the background process and passes data back to the main app.
5. **Handle**: The main app class's `onBackgroundData(data)` is called.

---

## 3. The 32 KB Memory Wall
This is the single biggest hurdle in Garmin development.
- **The Constraint**: Background processes are limited to a **tiny 32 KB heap**.
- **The Consequence**: If you try to fetch a large JSON file (e.g., a 100-item list), the JSON parser will consume all 32 KB and crash your process with a `-400` error.
- **The Hack**: Ensure your server-side API only returns the absolute bare minimum data required.

---

## 4. Engineering Gotchas
1. **Permissions**: You MUST add `<iq:permission id="Communications"/>` and `<iq:permission id="Background"/>` to your `manifest.xml`.
2. **Annotations**: Every class, variable, and module used by the background process must be marked with `(:background)`. If you forget this, the background process will crash immediately because it can't "find" the code.
3. **30-Second Timeout**: If your background process takes more than 30 seconds to finish (including web request lag), the OS will kill it.
4. **Phone Connection**: Web requests fail if the watch isn't connected to the phone via Bluetooth. Always check `System.getDeviceSettings().phoneConnected`.
5. **Battery Saver**: Background tasks are often disabled when the watch is in Battery Saver mode.
