[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Graphics Part 4: Pro Hacks & Obscure Techniques

To build "above average" watchfaces, you need to think like an embedded engineer. Garmin's VM is slow, memory is tight, and AMOLED rules are strict. These hacks will give you the edge.

---

Prev: [Part 3: Resources & Optimization](DC_PART3_RESOURCES_AND_PERFORMANCE.md)

---

## 1. The "Font-as-Sprites" Hack (High Performance)
`drawBitmap()` is slow and only supports one transparent color. **Fonts are faster.**
- **The Trick**: Use a tool like `BMFont` to pack your animation frames or icons into a `.fnt` file.
- **Why?**:
  - Fonts support **native anti-aliasing** and **alpha blending**.
  - Drawing a character with `dc.drawText()` is significantly faster than `dc.drawBitmap()`.
  - It handles multiple levels of transparency (alpha channels) perfectly.
- **Usage**: Map each frame to a character (e.g., 'A', 'B', 'C') and draw the one you need for the current animation state.

---

## 2. The AMOLED "Checkerboard Hack"
AMOLED devices (FR 265 / VA 6) will kill your watchface if more than 10% of pixels are lit in AOD mode.
- **The Trick**: Create a 2x2 "checkerboard" pattern where every other pixel is transparent.
- **The Result**: You can draw a "solid" hand or a bold font that *appears* solid but only uses 50% of the pixels.
- **Pro Tip**: If you shift this mask by 1 pixel every minute, you also satisfy the "3-minute burn-in rule" because no single pixel stays on for more than 1 minute.

---

## 3. Fake Gradients & Glows
Monkey C doesn't have a `blur()` or `gradient()` method. You have to fake it.
- **Glow Effect**: Draw the same circle/shape 4-5 times, increasing the radius by 2px each time and decreasing the alpha color (e.g., 80%, 40%, 20%, 5%).
- **Smooth Gradients**: Use a `for` loop to draw 1px high lines across an area, incrementing the color value slightly for each line.
  - **Optimization**: Do this **ONCE** in `onLayout` and save it to a `BufferedBitmap`. Drawing a gradient line-by-line in `onUpdate` will kill your frame rate.

---

## 4. Local Variable Speed Boost
Accessing a class member (`self.myValue`) is roughly **8-10x slower** than accessing a local variable.
- **The Hack**: In your `onUpdate` loop, copy any frequently used class variables to local variables at the top of the function.
```monkeyc
function onUpdate(dc) {
    var x = mPositionX; // Cache class member to local
    var color = mMainColor;
    
    for (var i = 0; i < 100; i++) {
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawPoint(x + i, 50); // Using 'x' is 8x faster than 'mPositionX'
    }
}
```

---

## 5. Pre-calculated LUTs (Look-Up Tables)
Don't do math in your draw loop.
- **The Hack**: If your watchface has a rotating hand, pre-calculate the `sin()` and `cos()` values for all 60 positions into an `Array` during `initialize()`.
- **Usage**: In `onUpdate`, just look up the index: `var x = centerX + mSinLUT[seconds] * radius;`.

---

## 6. Dirty Rectangles (The `setClip` Strategy)
Never redraw the whole screen if you don't have to.
- **The Hack**: If only the heart rate number changed, use `dc.setClip()` to surround just that number. Then draw your background (which will only render in that box) and the new text.
- **Why?**: This is the single biggest battery saver. The less the GPU has to "touch," the more power you save.

---

## 7. Custom Icons via "Filter"
Memory is tight. If you use a custom font for icons, don't include the whole alphabet.
- **The Trick**: Use the `filter` attribute in your `fonts.xml`.
```xml
<font id="IconFont" filename="icons.fnt" filter="ABC" />
```
- This ensures only the characters 'A', 'B', and 'C' are compiled into the PRG, saving tens of kilobytes of heap.
