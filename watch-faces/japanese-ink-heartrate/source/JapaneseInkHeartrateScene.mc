using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.Math;

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastMinuteKey as Lang.Number = -1;

    // Procedural Stamps for depth and texture
    var mInkStamp as Graphics.BufferedBitmap?;
    var mMistStamp as Graphics.BufferedBitmap?;
    const STAMP_SIZE = 32;

    function initialize() {
        createStamps();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        ensureBuffer(dc.getWidth(), dc.getHeight());
    }

    function draw(dc as Graphics.Dc) as Void {
        ensureBuffer(dc.getWidth(), dc.getHeight());

        if (mBuffer == null) {
            renderTornScene(dc, dc.getWidth(), dc.getHeight(), getMinuteKey());
            return;
        }

        var minuteKey = getMinuteKey();
        if (minuteKey != mLastMinuteKey) {
            renderBufferedTornScene(minuteKey);
        }

        var buffer = mBuffer;
        if (buffer != null) {
            dc.drawBitmap(0, 0, buffer);
        }
    }

    function getMinuteKey() as Lang.Number {
        var clockTime = System.getClockTime();
        return (clockTime.hour * 60) + clockTime.min;
    }

    function ensureBuffer(width as Lang.Number, height as Lang.Number) as Void {
        if (mBuffer != null && mBufferWidth == width && mBufferHeight == height) {
            return;
        }

        var options = { :width => width, :height => height };
        if (Graphics has :createBufferedBitmap) {
            mBuffer = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
        } else if (Graphics has :BufferedBitmap) {
            mBuffer = new Graphics.BufferedBitmap(options);
        } else {
            mBuffer = null;
        }

        mBufferWidth = width;
        mBufferHeight = height;
        mLastMinuteKey = -1;
    }

    function createStamps() as Void {
        var options = { :width => STAMP_SIZE, :height => STAMP_SIZE };
        if (!(Graphics has :createBufferedBitmap)) { return; }

        // Ink Stamp: Dark structural core
        mInkStamp = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
        if (mInkStamp != null) {
            var inkDc = mInkStamp.getDc();
            inkDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            inkDc.clear();
            inkDc.setFill(Graphics.createColor(45, 26, 26, 27)); // Sumi Black
            inkDc.fillCircle(16, 16, 10);
            inkDc.setFill(Graphics.createColor(25, 26, 26, 27));
            inkDc.fillCircle(16, 16, 14);
        }

        // Mist Stamp: Very soft, large wash
        mMistStamp = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
        if (mMistStamp != null) {
            var mistDc = mMistStamp.getDc();
            mistDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            mistDc.clear();
            for (var i = 0; i < 5; i++) {
                var alpha = (6 - i) * 3;
                mistDc.setFill(Graphics.createColor(alpha, 244, 241, 234));
                mistDc.fillCircle(16, 16, 16 - (i * 2));
            }
        }
    }

    function renderBufferedTornScene(minuteKey as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) { return; }
        renderTornScene(buffer.getDc(), mBufferWidth, mBufferHeight, minuteKey);
        mLastMinuteKey = minuteKey;
    }

    function renderTornScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        // 1. CLEAR WITH DARK INK (The Underworld base)
        dc.setColor(0x1A1A1B, 0x1A1A1B);
        dc.clear();

        // 2. DRAW UNDERWORLD LANDSCAPE (Hidden behind paper)
        drawInkMountains(dc, width, height, seed);

        // 3. DRAW TORN PAPER MASK (The Top Layer)
        drawJaggedPaperMask(dc, width, height, seed);
    }

    function drawInkMountains(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        // Draw deep ink pillars visible in the tear
        for (var i = 1; i <= 3; i++) {
            var x = (width * i) / 4;
            var startY = height / 3;
            for (var j = 0; j < 12; j++) {
                var dX = getJitter(seed + i + j, 30);
                var dY = j * 12 + getJitter(seed * 2 + j, 10);
                if (mInkStamp != null) {
                    dc.drawBitmap(x + dX - 16, startY + dY - 16, mInkStamp);
                }
                
                if ((seed + j) % 4 == 0) {
                    if (mMistStamp != null) {
                        dc.drawBitmap(x + dX - 30, startY + dY, mMistStamp);
                    }
                }
            }
        }
    }

    function drawJaggedPaperMask(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var paperColor = 0xF4F1EA;
        
        // We draw per-pixel columns for a truly jagged "torn" edge
        for (var x = 0; x < width; x++) {
            // Heart-rate-like jitter for the tear boundary
            var tearY = height / 2 + getJitter(seed + x, 50);
            var gap = 60 + getJitter(seed * 3 + x, 30);
            
            var topBoundary = tearY - (gap / 2);
            var bottomBoundary = tearY + (gap / 2);

            // --- Draw Top Paper Piece ---
            dc.setColor(paperColor, paperColor);
            dc.drawLine(x, 0, x, topBoundary);
            
            // --- Draw Bottom Paper Piece ---
            dc.drawLine(x, bottomBoundary, x, height);

            // --- Torn Edge Details ---
            // Shadow depth inside the tear
            dc.setColor(0x50000000, Graphics.COLOR_TRANSPARENT);
            dc.drawPoint(x, topBoundary + 1);
            dc.drawPoint(x, bottomBoundary - 1);
            
            // Fiber highlight on the paper edge
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawPoint(x, topBoundary);
            dc.drawPoint(x, bottomBoundary);
            
            // Random paper "fibers" jutting out
            if ((Math.rand() % 20) == 0) {
                dc.drawLine(x, topBoundary, x, topBoundary + 3);
            }
            if ((Math.rand() % 20) == 0) {
                dc.drawLine(x, bottomBoundary, x, bottomBoundary - 3);
            }
        }
    }

    function getJitter(seed as Lang.Number, scale as Lang.Number) as Lang.Number {
        // High-contrast jitter pattern for jagged edges
        var pattern = [0, -3, 5, -2, 4, -6, 2, -1, 3, -4, 6, -3, 1];
        var s = seed;
        if (s < 0) { s = -s; }
        var idx = s % pattern.size();
        return (pattern[idx] * scale) / 6;
    }

}
