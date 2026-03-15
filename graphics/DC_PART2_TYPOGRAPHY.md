[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Graphics Part 2: Typography & Text Rendering

Text is the most important element of any watchface. In Garmin's Connect IQ, text rendering ranges from simple system fonts to complex vector-based radial text for round displays like the FR 265 and VA 6.

---

Prev: [Part 1: Primitives](DC_PART1_PRIMITIVES.md) | Next: [Part 3: Resources & Performance](DC_PART3_RESOURCES_AND_PERFORMANCE.md)

---

## 1. System Fonts
Garmin provides built-in fonts that are optimized for each device. Using these saves memory because they aren't bundled with your app's binary.

- **Proportionals**: `FONT_XTINY`, `FONT_TINY`, `FONT_SMALL`, `FONT_MEDIUM`, `FONT_LARGE`.
- **Numbers Only**: `FONT_NUMBER_MILD`, `FONT_NUMBER_MEDIUM`, `FONT_NUMBER_HOT`, `FONT_NUMBER_THAI_HOT` (Huge).
- **System Variations**: `FONT_SYSTEM_XTINY`, etc. (These are the actual fonts used by the watch's own menus).

---

## 2. Drawing Text: `drawText()`
The core method for rendering strings.
```monkeyc
dc.drawText(x, y, font, text, justification);
```

### Justification Flags (The Bitmask)
Justification is relative to the `(x, y)` coordinate you provide. You can combine horizontal and vertical flags using the OR (`|`) operator.

| Flag | Effect |
| :--- | :--- |
| `Graphics.TEXT_JUSTIFY_LEFT` | Anchor `x` is the left edge of text. |
| `Graphics.TEXT_JUSTIFY_RIGHT` | Anchor `x` is the right edge of text. |
| `Graphics.TEXT_JUSTIFY_CENTER` | Anchor `x` is the horizontal center. |
| `Graphics.TEXT_JUSTIFY_VCENTER` | Anchor `y` is the vertical center. |

**Common Example**: `Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER` perfectly centers text on your coordinate.

---

## 3. Measuring Text
To create dynamic layouts, you must know how big your text will be before you draw it.

- **`dc.getTextWidthInPixels(text, font)`**: Returns the width of a string.
- **`dc.getFontHeight(font)`**: Returns the total height (Ascent + Descent).
- **`dc.getFontAscent(font)`**: Distance from baseline to the top.
- **`dc.getFontDescent(font)`**: Distance from baseline to the bottom.

---

## 4. Custom Fonts (BMFont)
If system fonts don't fit your design, you can include custom `.fnt` (BMFont) files.

### Workflow:
1. **Generate**: Use a tool like *BMFont* or *ShoeBox* to create a `.fnt` file and a `.png` atlas.
2. **XML Declaration**: Add the font to your `resources/fonts.xml`.
   ```xml
   <fonts>
       <font id="MyCustomFont" filename="fonts/myfont.fnt" antialias="true" />
   </fonts>
   ```
3. **Load**: `var myFont = WatchUi.loadResource(Rez.Fonts.MyCustomFont);`
4. **Draw**: `dc.drawText(x, y, myFont, "Hello", ...);`

---

## 5. Advanced Text (API 4.2.2+)
For round screens (FR 265 / VA 6), Garmin introduced **Vector Fonts** and curved text rendering.

### Vector Fonts
Unlike bitmap fonts, these can be scaled at runtime without losing quality.
- `var vFont = Graphics.getVectorFont({:face => "sans-serif", :size => 48});`

### Radial Text (`drawRadialText`)
Draws text along the curve of the watch face.
```monkeyc
dc.drawRadialText(cx, cy, vFont, "GO GARMIN", justify, angle, radius, direction);
```
- **`angle`**: Degrees (0 = 3 o'clock).
- **`radius`**: Distance from center to text baseline.
- **`direction`**: `RADIAL_TEXT_DIRECTION_CLOCKWISE` (top of circle) or `COUNTER_CLOCKWISE` (bottom).

### Angled Text (`drawAngledText`)
Draws straight text that is rotated by a specific angle. Great for labels next to tick marks.

---

## 6. Engineering Gotchas
1. **Memory**: Custom fonts are huge memory hogs. Every character is a bitmap in your heap. **Optimization Tip**: Use `filter="0123456789:"` in your XML to only include the characters you actually need.
2. **Anti-Aliasing**: For custom fonts, set `antialias="true"` in the XML. For system fonts, use `dc.setAntiAlias(true)`.
3. **Vertical Centering**: `TEXT_JUSTIFY_VCENTER` is not perfect for all fonts. Sometimes you need to manually offset `y` using `getFontAscent() / 2` for pixel-perfect alignment.
