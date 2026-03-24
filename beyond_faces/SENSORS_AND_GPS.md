[Home](../common/MASTER_MAP.md) | [Overview](../common/BIRDSEYE_VIEW.md)

# Beyond Faces: Sensors & GPS

If you're moving beyond watchfaces into **Widgets**, **Data Fields**, or **Apps**, you gain access to the watch's raw hardware sensors. This is where you can build fitness trackers, navigation tools, and environmental monitors.

---

## 1. Accessing Real-Time Sensors (`Toybox.Sensor`)
The `Sensor` module is your primary gateway to the watch's "biological" and "physical" data.

### Standard Sensors
- **Heart Rate**: `Sensor.getInfo().heartRate`
- **Cadence**: `Sensor.getInfo().cadence`
- **Temperature**: `Sensor.getInfo().temperature`
- **Pressure**: `Sensor.getInfo().pressure`

### How to use it:
```monkeyc
using Toybox.Sensor;

function onUpdate(dc) {
    var info = Sensor.getInfo();
    if (info.heartRate != null) {
        dc.drawText(x, y, font, "HR: " + info.heartRate, justify);
    }
}
```

---

## 2. Positioning & GPS (`Toybox.Position`)
To get latitude, longitude, and speed, you use the `Position` module. This is heavily power-intensive and usually disabled for watchfaces.

### Enabling GPS:
```monkeyc
using Toybox.Position;

function startGps() {
    Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
}

function onPosition(info) {
    var latLon = info.position.toDegrees();
    var speed = info.speed; // meters per second
}
```

---

## 3. High-Frequency Data: Accelerometer & Gyro
For elite engineering (like swing analysis or gesture detection), you can access the **High-Frequency Accelerometer** (up to 25Hz).

- **Module**: `Toybox.Sensor.registerSensorDataListener`
- **Constraint**: This consumes a massive amount of CPU and memory. You must process this data quickly or store it for later analysis.

---

## 4. Sensor History (`Toybox.SensorHistory`)
Want to show a graph of the last 4 hours of heart rate or elevation? Use `SensorHistory`.

- **Capabilities**: Accesses the watch's internal database of historical sensor readings.
- **Methods**: `getHeartRateHistory()`, `getElevationHistory()`, `getPressureHistory()`.
- **Note**: This returns an **Iterator**. You must loop through it to get the values.

---

## 5. Engineering Gotchas
1. **Permissions**: You MUST add `<iq:permission id="Sensor"/>` and `<iq:permission id="Positioning"/>` to your `manifest.xml`.
2. **Null Checks**: Sensors can return `null` (e.g., if the watch isn't on a wrist or hasn't locked GPS). **Always check for null.**
3. **Power Consumption**: GPS will drain a Forerunner 265 in hours. Only enable it when absolutely necessary (e.g., during an active workout app).
4. **Platform Support**: Not all sensors are on all watches. The Vivoactive 6 might have a barometer while an older model might not. Use the `has` operator: `if (Toybox has :SensorHistory) { ... }`.

---

[Next: Web & Background Tasks](WEB_AND_BACKGROUND.md)
