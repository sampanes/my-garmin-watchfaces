[Home](../MASTER_MAP.md) | [Overview](../BIRDSEYE_VIEW.md)

# Graphics Part 5: Advanced UI & Dynamic Vector Engine

With the introduction of **Connect IQ 4.2+ (System 6.2/7)**, Garmin added support for a GPU-accelerated graphics pipeline on AMOLED devices like the **Forerunner 265** and **Vivoactive 6**. This allows for UI techniques that were previously impossible.

---

## 1. The `AffineTransform` Engine (Real-Time Rotation)
Historically, to rotate a bitmap (like a watch hand), you had to pre-render 60 separate images or use slow trig-based pixel manipulation.
- **The New Way**: Use `Graphics.AffineTransform`.
- **Capability**: Rotate, Scale, and Shear bitmaps in real-time using the device's GPU.
- **Implementation**:
```monkeyc
using Toybox.Graphics;

function drawRotatingHand(dc, bitmap, angle) {
    var transform = new Graphics.AffineTransform();
    transform.rotate(angle);
    transform.scale(1.1, 1.1); // Slight pulse effect
    
    // Draw the bitmap with the transform applied
    dc.drawBitmap2(x, y, bitmap, { :transform => transform });
}
```
- **[Gemini] Pro Tip**: Combine this with a `Timer` to create smooth 60fps "sweep" second hands that only run when the user is looking at the watch (High Power Mode).

---

## 2. Scalable Vector UI (`drawPath`)
Instead of pixel-perfect bitmaps, you can now define your UI as a series of coordinates (similar to SVG paths).
- **The Function**: `dc.drawPath(points)`.
- **The Advantage**: One "Path" definition works perfectly on both your wife's 390px VA6 and your 416px FR265. No more resizing bitmaps!
- **[Gemini] Idea**: Create "Morphing" UI elements. By mathematically interpolating the coordinates of a path, you can make a square icon smoothly transform into a circle or a heart based on the user's heart rate.

---

## 3. Dynamic Vector Fonts
Standard fonts are bitmaps. Vector fonts (`.vtf`) are scalable.
- **The Function**: `Graphics.getVectorFont({ :face => "Roboto", :size => 48 })`.
- **Why it matters**: You can change font sizes on-the-fly without loading 10 different font files into memory. 
- **Memory Hack**: One vector font in memory is often smaller than three different sizes of a bitmap font.

---

## 4. [Gemini] New Idea: "The Glassmorphism Effect"
On the 1,500-nit **Vivoactive 6**, you can simulate a "Glass" look.
- **The Trick**: 
    1. Draw your background.
    2. Draw a semi-transparent white/gray shape with a low alpha (e.g., `0x33FFFFFF`).
    3. Use a 1px white outline on the top-left edge to simulate a "beveled glass" highlight.
    4. Since you can't "blur" the background in real-time, use a pre-rendered "blurred" version of your background bitmap behind the glass panel.

---

## 5. Advanced Hardware: The GPU Check
Not all watches have a GPU. Always check before using `AffineTransform`.
```monkeyc
if (Graphics has :AffineTransform) {
    // Modern GPU path (FR265 / VA6)
} else {
    // Legacy software fallback
}
```
