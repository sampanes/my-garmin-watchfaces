[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Graphics Part 1: The Draw Context (DC) & Geometric Primitives

The `Toybox.Graphics.Dc` (Draw Context) is your canvas. For an embedded engineer, think of it as the abstraction layer over the frame buffer.

---

Next: [Part 2: Typography](DC_PART2_TYPOGRAPHY.md)

---

## 1. Coordinate System & Canvas Properties
Garmin devices use a top-left coordinate system `(0,0)`.

- **`getWidth()` / `getHeight()`**: Returns the pixel dimensions of the screen.
  - **Round Screens (FR 265 / VA 6)**: The width and height are equal (the diameter). The center is `(width/2, height/2)`.
- **`getFontHeight(font)`**: Essential for vertical alignment. Returns the height of a specific font (System or Custom).
- **`setClip(x, y, w, h)`**: **CRITICAL FOR POWER.** This restricts drawing to a specific rectangular region. Anything drawn outside this box is ignored by the GPU/CPU.
  - *Note*: Always `clearClip()` when finished with a partial update to avoid accidental clipping in the next frame.

---

## 2. Color Management & Transparency
AMOLED screens support full 24-bit color (`0xRRGGBB`), but many older MIP devices are limited to 16 or 64 colors.

- **`setColor(foreground, background)`**: The standard way to set "active" colors.
  - `dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);`
- **`setFill(color)` / `setStroke(color)`**: Advanced methods that support **Alpha Transparency** (`0xAARRGGBB`).
  - *Note*: Alpha blending is computationally expensive. Use it sparingly, especially in `onPartialUpdate`.
- **`setBlendMode(mode)`**: Controls how new pixels interact with existing ones.
  - `Graphics.BLEND_MODE_NORMAL`: Overwrites.
  - `Graphics.BLEND_MODE_ADD`: Adds color values (useful for glows/lighting effects).

---

## 3. Geometric Primitives (The "Bread and Butter")
Methods for drawing basic shapes. Most have a `draw` (outline) and `fill` (solid) version.

### Lines & Points
- **`drawLine(x1, y1, x2, y2)`**: Draws a line.
- **`drawPoint(x, y)`**: Sets a single pixel.
- **`setPenWidth(pixels)`**: Sets the thickness for all subsequent `draw` calls.

### Rectangles & Circles
- **`drawRectangle(x, y, w, h)`** / **`fillRectangle(x, y, w, h)`**
- **`drawRoundedRectangle(x, y, w, h, radius)`**
- **`drawCircle(x, y, radius)`** / **`fillCircle(x, y, radius)`**
- **`drawEllipse(x, y, a, b)`**: `a` and `b` are the x and y radii.

### Advanced Shapes
- **`drawArc(x, y, r, attr, start, end)`**:
  - `attr`: `Graphics.ARC_CLOCKWISE` or `Graphics.ARC_COUNTER_CLOCKWISE`.
  - `start`/`end`: Angles in degrees (0 is 3 o'clock, 90 is 12 o'clock).
- **`fillPolygon(arrayOfPoints)`**:
  - Takes an array of coordinate pairs: `[[x1,y1], [x2,y2], ...]`.
  - Max points: 64. Great for custom hands or complex UI elements.

---

## 4. Modern Rendering Features
### Anti-Aliasing
AMOLED screens (FR 265 / VA 6) look significantly better with anti-aliasing enabled.
- **`setAntiAlias(true)`**: Smoothens the edges of lines, circles, and polygons.
- **Cost**: Slightly higher CPU usage. Turn it OFF if you are struggling with the 30ms power budget.

### Drawing Context States
The DC maintains a "state" (current color, pen width, font, clip). If you are writing a complex watchface, it is often safer to set these explicitly at the start of `onUpdate` rather than assuming they persisted from the last call.

---

## 5. Engineering Tip: Round Screen Math
Since the FR 265 and VA 6 are round, you will frequently use trigonometry to place elements.
- **Center X**: `dc.getWidth() / 2`
- **Center Y**: `dc.getHeight() / 2`
- **Polar to Cartesian**:
  - `x = centerX + radius * Math.cos(angle_in_radians);`
  - `y = centerY - radius * Math.sin(angle_in_radians);`
- **Degree to Radian**: `rad = deg * (Math.PI / 180);`
