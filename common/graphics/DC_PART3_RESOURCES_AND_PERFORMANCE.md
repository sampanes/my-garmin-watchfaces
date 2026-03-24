[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Graphics Part 3: Bitmaps, Resources & Optimization

For complex watchfaces on the FR 265 and VA 6, raw drawing isn't enough. You need to manage memory-heavy bitmaps and use off-screen buffers for peak performance.

---

Prev: [Part 2: Typography](DC_PART2_TYPOGRAPHY.md) | Next: [Part 4: Pro Hacks](DC_PART4_PRO_HACKS.md)

---

## 1. Bitmaps (Drawables)
Bitmaps are static images defined in XML and loaded into memory at runtime.

### XML Definition (`resources/drawables.xml`)
```xml
<drawables>
    <bitmap id="MyLogo" filename="images/logo.png" antialias="true" />
</drawables>
```

### Loading & Drawing
```monkeyc
var logo = WatchUi.loadResource(Rez.Drawables.MyLogo);
dc.drawBitmap(x, y, logo);
```

---

## 2. BufferedBitmap: The "Secret Weapon"
A `BufferedBitmap` is an off-screen canvas. You draw to it once, and then draw the result to the screen as a single fast operation.

### Why use it?
1. **Caching**: If your background has 50 tick marks and 3 gradients, don't redraw them every second. Draw them once to a buffer in `onLayout` and simply `drawBitmap` the buffer in `onUpdate`.
2. **Flicker Reduction**: Pre-renders complex layers to avoid visible "building" of the UI.

### Creation (CIQ 4.0+ Recommended)
```monkeyc
var bufferRef = Graphics.createBufferedBitmap({
    :width => 100,
    :height => 100,
    :palette => [Graphics.COLOR_RED, Graphics.COLOR_BLACK]
});
var myBuffer = bufferRef.get(); // Lock it in memory
```

### Drawing to the Buffer
```monkeyc
var bDc = myBuffer.getDc();
bDc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
bDc.clear();
bDc.fillCircle(50, 50, 40);
```

---

## 3. Palette Management (Memory Optimization)
Memory is your tightest constraint. AMOLED devices support 24-bit color, but your heap doesn't.

- **The Problem**: A full-color 416x416 buffer for the FR 265 would take ~500KB, exceeding the entire app's memory limit.
- **The Solution**: Use **Palettes**.
  - A 2-color (1-bit) palette uses 1/32nd the memory of a 24-bit buffer.
  - A 16-color (4-bit) palette is usually the "sweet spot" for icons and simple UI elements.

---

## 4. The XML Layout System (`Rez`)
Garmin provides an Android-like XML layout system.

### `resources/layouts/layout.xml`
```xml
<layout id="MainLayout">
    <label id="TimeLabel" x="center" y="center" font="Graphics.FONT_LARGE" color="Graphics.COLOR_WHITE" />
</layout>
```

### Usage in Monkey C
```monkeyc
function onLayout(dc) {
    setLayout(Rez.Layouts.MainLayout(dc));
}

function onUpdate(dc) {
    // Updates all elements defined in the XML automatically
    View.onUpdate(dc); 
    
    // You can still draw manually on top
    dc.drawCircle(centerX, centerY, 100);
}
```

---

## 5. Optimization: The 30ms Partial Update
When drawing seconds or heart rate at 1Hz in Low Power Mode, you MUST be fast.

- **`dc.setClip(x, y, w, h)`**: This is non-negotiable. Only update the pixels that changed.
- **Pre-calculate everything**: Do not perform `Math.sin()` or `loadResource` inside `onPartialUpdate`. Store results in class variables during the 1-minute `onUpdate`.
- **Avoid Transparency**: Alpha blending in `onPartialUpdate` is a quick way to blow your 30ms budget.

---

## 6. Engineering Gotchas
1. **Graphics Pool**: In CIQ 4.0+, `createBufferedBitmap` uses a shared system pool. If you don't call `.get()` on the reference, the system might reclaim the memory.
2. **Bitmap Scaling**: Garmin's `drawBitmap` does NOT support scaling. If you need a smaller image, you must resize it in Photoshop before importing, or use a `VectorFont`.
3. **Transparent Colors**: By default, the first color in a bitmap's palette is often treated as transparent. Check your `resources.xml` carefully if images look "cut out."
