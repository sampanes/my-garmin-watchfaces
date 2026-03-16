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

---

## 5. [Gemini] Modern Data & Monetization (System 7+)

### The Complications API (`Toybox.Complications`)
System 7 introduces a standardized way for watchfaces to receive data from other apps or the system (Weather, Steps, Solar Intensity, etc.).
- **The Old Way**: You manually queried `Toybox.SensorHistory` or `Toybox.Weather`.
- **The New Way**: You "subscribe" to a specific complication ID.
- **[Gemini] Advantage**: This is much more battery-efficient because the system handles the data updates and only pushes them to your watchface when necessary.
- **Implementation**:
```monkeyc
using Toybox.Complications;

function subscribeToSteps() {
    var stepComplicationId = new Complications.Id(Complications.COMPLICATION_TYPE_STEPS);
    Complications.registerComplicationChangeCallback(method(:onComplicationUpdate), [stepComplicationId]);
}

function onComplicationUpdate(complicationId) {
    var data = Complications.getComplication(complicationId);
    System.println("Steps: " + data.value);
}
```

### Native Store Payments
Historically, Garmin developers had to use 3rd-party services (like KiezelPay) to charge for their work, requiring a clunky "Unlock Code" UI.
- **Native Payments**: Garmin now supports official monetization through the Connect IQ Store.
- **[Gemini] Thought**: This reduces your code overhead significantly. You no longer need complex background tasks to verify licenses via 3rd-party APIs. The system handles the "Entitlement" check for you.
- **API**: Check `Toybox.Application.getAppEntitlements()` to see if the user has a valid license.

### [Gemini] Engineering Question:
With the **Vivoactive 6** being a more "lifestyle" oriented device, have you considered using the **Complications API** to allow users to swap out data fields (e.g., swapping "Steps" for "Hydration")? This aligns with the new **Native Watch Face Editor** mentioned in the language guide.
