[Home](../MASTER_MAP.md) | [Monkey C Guide](MONKEY_C_GUIDE.md)

# Compiler Facts (read before writing Monkey C without an SDK)

Facts checked against a real compiler, simulator or watch on the home PC.
Everything here is either a compile error a blind session actually hit, a
render bug the simulator exposed, or an API signature read from the
installed SDK (Connect IQ SDK 9.1.0) docs. A session with no SDK should
read this first and add to it whenever the home PC proves something new.

For what the current tree does when compiled (errors, warnings, PRG sizes,
simulator vs `compose_preview.py`), read the newest report in
[`common/home-verify/`](../home-verify/README.md).

---

## 1. Errors and bugs a blind session shipped

Each entry: what was written, what the compiler or simulator did, the fix.

### 1.1 `fillPolygon` needs `Graphics.Point2D`, not an open array (compile error, 2026-10-30)

Written:

```
var poly = [] as Lang.Array<Lang.Array<Lang.Numeric>>;
dc.fillPolygon(poly);
```

SDK 9.1 at `-l 2` refuses it: `Invalid 'Array<Array<...>>' passed as
parameter 1 of type 'Array<Array[Numeric, Numeric]>'`. `Point2D` is a
two-element tuple, `[Lang.Numeric, Lang.Numeric]`, and an open array is not
a tuple. Fix:

```
var poly = [] as Lang.Array<Graphics.Point2D>;
poly.add([x, y] as Graphics.Point2D);
```

### 1.2 `setFill` / `setStroke` take `0xAARRGGBB`; a bare `0xRRGGBB` is invisible (sim, 2026-10-30)

Written: `dc.setFill(0xA62C1E); dc.fillCircle(...)`. It compiles, but the
alpha byte is 0x00, so every fill after it draws fully transparent. The
crest dots of the ink face's HR overlay never appeared. `setColor` is the
odd one out: it takes plain `0xRRGGBB`. Fix: build fill colors with
`Graphics.createColor(alpha, r, g, b)`. Also note `setFill` takes precedence
over `setColor` for every fill until it is set again.

### 1.3 `Complications` is watch-face-only (compile error, 2026-10-30)

The pet hardware probe (a `watch-app`) declared `ComplicationSubscriber`.
The manifest reader refuses it: "The following permission is invalid for
app type 'watch-app'". Without the permission, every `Toybox.Complications`
reference, reads and type constants included, is an error ("Permission
'ComplicationPublisher' or 'ComplicationSubscriber' required"). Device apps
read body battery, stress and HR through `ActivityMonitor` and
`SensorHistory` instead. Check an app type's permissions before using a
module: the SDK's "Manifest and Permissions" page has the table.

### 1.4 Null checks narrow locals, not members (warning at `-l 2`)

`if (info.pressure != null) { info.pressure.format(...) }` builds, but with
"Cannot find symbol ':format' on type 'Null'" as a warning: the checker
does not narrow a member or field after a null test. Copy it into a local,
test the local, use the local. At `-l 2` it is a warning, not an error,
and the runtime null check still protects the call.

---

## 2. Build facts

- Device id from the CLI is `fr265` (and `vivoactive6`). `fr265_sim` is a
  VS Code F5 target only; from the CLI it pops "unable to load device".
- `fr265s` is listed in some manifests but its device files are not
  installed on the home PC, so it is never compiled there.
- Build like the scripts do: `monkeyc -f <jungle> -d fr265 -o <prg> -y <key> -w -l 2`.
- In PowerShell, piping `monkeyc` through `Select-Object -First N` makes
  `$LASTEXITCODE` read `-1` even when the build succeeded. Read the
  `BUILD SUCCESSFUL` line or run it without truncating.
- Tuple types work in casts and declarations: `[x, y] as [Lang.Number, Lang.Number]`.

## 3. Device limits (from the SDK device files)

| Device | API level | Screen | Watch face memory | Watch app memory | Background |
|---|---|---|---|---|---|
| fr265 | 5.2.0 | 416x416 AMOLED | 131072 B | 786432 B | 65536 B |
| vivoactive6 | 6.0.0 | 390x390 AMOLED | 131072 B | 786432 B | 65536 B |

## 4. Signatures of every API this repo calls (SDK 9.1.0 docs)

"Since" is the API level the call first appeared in. Anything above the
device's API level (section 3) needs a `has` check.

### Toybox.Graphics.Dc

| Call | Since |
|---|---|
| `clear() as Void` | 1.0.0 |
| `clearClip() as Void` | 2.3.0 |
| `drawArc(x, y, r as Numeric, attr as Graphics.ArcDirection, degreeStart, degreeEnd as Numeric) as Void` | 1.2.0 |
| `drawBitmap(x, y as Numeric, bitmap as Graphics.BitmapType) as Void` | 1.0.0 |
| `drawBitmap2(x, y as Numeric, bitmap as Graphics.BitmapType, options as {:bitmapX, :bitmapY, :bitmapWidth, :bitmapHeight as Number, :tintColor as Graphics.ColorType, :filterMode as Graphics.FilterMode, :transform as Graphics.AffineTransform} or Null) as Void` | 4.2.1 |
| `drawCircle(x, y, radius as Numeric) as Void` | 1.0.0 |
| `drawLine(x1, y1, x2, y2 as Numeric) as Void` | 1.0.0 |
| `drawRectangle(x, y, width, height as Numeric) as Void` | 1.0.0 |
| `drawScaledBitmap(x, y, width, height as Numeric, bitmap as Graphics.BitmapType) as Void` | 4.0.0 |
| `drawText(x, y as Numeric, font as Graphics.FontType, text as Object or Null, justification as Graphics.TextJustification or Number) as Void` | 1.0.0 |
| `fillCircle(x, y, radius as Numeric) as Void` | 1.0.0 |
| `fillEllipse(x, y, a, b as Numeric) as Void` | 1.0.0 |
| `fillPolygon(pts as Array<Graphics.Point2D>) as Void` (64 points max) | 1.0.0 |
| `fillRectangle(x, y, width, height as Numeric) as Void` | 1.0.0 |
| `fillRoundedRectangle(x, y, width, height, radius as Numeric) as Void` | 1.0.0 |
| `getFontHeight(font as Graphics.FontType) as Number` | 1.0.0 |
| `getTextWidthInPixels(text as String, font as Graphics.FontType) as Number` | 1.0.0 |
| `setAntiAlias(enabled as Boolean) as Void` | 3.2.0 |
| `setBlendMode(mode as Graphics.BlendMode) as Void` | 4.0.0 |
| `setClip(x, y, width, height as Numeric) as Void` | 2.3.0 |
| `setColor(foreground, background as Graphics.ColorType) as Void` (plain 0xRRGGBB) | 1.0.0 |
| `setFill(fill as Number or Graphics.BitmapTexture) as Void` (0xAARRGGBB) | 4.0.0 |
| `setStroke(stroke as Number or Graphics.BitmapTexture) as Void` (0xAARRGGBB) | 4.0.0 |
| `setPenWidth(width as Numeric) as Void` | 1.0.0 |

### Toybox.Graphics (module) and AffineTransform

| Call | Since |
|---|---|
| `createColor(alpha, red, green, blue as Number) as Number` | 4.0.0 |
| `createBufferedBitmap(options as {:width, :height as Number, :palette as Array<Graphics.ColorType>, :colorDepth as Number, :bitmapResource as WatchUi.BitmapResource or Graphics.BitmapReference, :alphaBlending as Graphics.AlphaBlending}) as Graphics.BufferedBitmapReference` | 4.0.0 |
| `AffineTransform.scale(sx, sy as Float) as Void` | 4.2.0 |
| `AffineTransform.translate(tx, ty as Float) as Void` | 4.2.0 |
| `AffineTransform.rotate(theta as Float) as Void` | 4.2.0 |

Type aliases: `Point2D` is `[Numeric, Numeric]`; `ColorType` is a `Number`
(including the `COLOR_*` constants); `BitmapType` covers `WatchUi.BitmapResource`
and the `Graphics` bitmap references; `FontType` covers `WatchUi.FontResource`
and the built-in `FONT_*` values.

### Sensors and history

| Call | Since |
|---|---|
| `ActivityMonitor.getHeartRateHistory(period as Time.Duration or Number or Null, newestFirst as Boolean) as ActivityMonitor.HeartRateIterator` | 1.2.1 |
| `ActivityMonitor.getInfo() as ActivityMonitor.Info` | 1.0.0 |
| `SensorHistory.getHeartRateHistory(options as {:period as Number or Time.Duration, :order as SensorHistory.Order or Null} or Null) as SensorHistory.SensorHistoryIterator` | 2.1.0 |
| `SensorHistory.getBodyBatteryHistory(options as {:period, :order} or Null) as SensorHistory.SensorHistoryIterator` | (not stated) |
| `SensorHistory.getStressHistory(options as {:period, :order} or Null) as SensorHistory.SensorHistoryIterator` | (not stated) |
| `Sensor.getInfo() as Sensor.Info` | 1.0.0 |
| `Sensor.setEnabledSensors(sensors as Array<Sensor.SensorType>) as Array<Sensor.SensorType>` | 1.0.0 |
| `Sensor.registerSensorDataListener(listener as Method(data as Sensor.SensorData) as Void, options as {:period as Number, :accelerometer, :gyroscope, :magnetometer as {...}, :heartBeatIntervals as {:enabled as Boolean}, :synchronous as Boolean}) as Void` | (not stated) |
| `Sensor.unregisterSensorDataListener() as Void` | 2.3.0 |
| `Activity.getActivityInfo() as Activity.Info or Null` | 1.0.0 |
| `Position.enableLocationEvents(options as {...} or Position.LocationAcquisitionType, listener as Null or Method(loc as Position.Info) as Void) as Void` | (not stated) |
| `Position.getInfo() as Position.Info` | (not stated) |
| `UserProfile.getProfile() as UserProfile.Profile` | 1.0.0 |

### App, UI and system

| Call | Since |
|---|---|
| `Application.Properties.getValue(key as String) as Properties.ValueType` | 2.4.0 |
| `Application.Properties.setValue(key as String, value as Properties.ValueType) as Void` | 2.4.0 |
| `Application.Storage.getValue(key as Storage.KeyType) as Storage.ValueType` | 2.4.0 |
| `Application.Storage.setValue(key as Storage.KeyType, value as Storage.ValueType) as Void` | 2.4.0 |
| `Application.Storage.deleteValue(key as Storage.KeyType) as Void` | 2.4.0 |
| `WatchUi.loadResource(resource as ResourceId) as WatchUi.Resource` | 1.0.0 |
| `WatchUi.requestUpdate() as Void` | 1.0.0 |
| `WatchUi.pushView(view as WatchUi.Views, delegate as WatchUi.InputDelegates or Null, transition as WatchUi.SlideType) as Void` | 1.0.0 |
| `WatchUi.popView(transition as WatchUi.SlideType) as Void` | 1.0.0 |
| `System.getClockTime() as System.ClockTime` | 1.0.0 |
| `System.getDeviceSettings() as System.DeviceSettings` | 1.0.0 |
| `System.getSystemStats() as System.Stats` | 1.0.0 |
| `System.getTimer() as Number` | 1.0.0 |
| `System.println(output as Object or Null) as Void` | 1.0.0 |
| `Complications.getComplication(id as Complications.Id) as Complications.Complication` | 4.2.0 |
| `Complications.registerComplicationChangeCallback(callback as Complications.ComplicationChangedCallback or Null) as Void` | 4.2.0 |
| `Complications.subscribeToUpdates(id as Complications.Id) as Boolean` | 4.2.0 |
| `Complications.unsubscribeFromAllUpdates() as Void` | 4.2.0 |
| `Attention.playTone(options as Attention.Tone or {:toneProfile as Array<Attention.ToneProfile>, :repeatCount as Number}) as Void` | 1.0.0 |
| `Attention.vibrate(vibeProfiles as Array<Attention.VibeProfile>) as Void` | 1.0.0 |

`Properties.ValueType` is a union (`Number or Float or Long or Double or
String or Boolean or Array<ValueType>` among others). Cast what `getValue`
returns before using it as one of those.
