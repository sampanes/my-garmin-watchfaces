using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastMinuteKey as Lang.Number = -1;

    // Procedural Stamps
    var mWashStamp as Graphics.BufferedBitmap?;
    var mBrushStamp as Graphics.BufferedBitmap?;
    const STAMP_SIZE = 24;

    function initialize() {
        createStamps();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        ensureBuffer(dc.getWidth(), dc.getHeight());
    }

    function draw(dc as Graphics.Dc) as Void {
        ensureBuffer(dc.getWidth(), dc.getHeight());

        if (mBuffer == null) {
            renderScene(dc, dc.getWidth(), dc.getHeight(), getMinuteKey());
            return;
        }

        var minuteKey = getMinuteKey();
        if (minuteKey != mLastMinuteKey) {
            renderBufferedScene(minuteKey);
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

        var options = {
            :width => width,
            :height => height
        };

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
        var options = {
            :width => STAMP_SIZE,
            :height => STAMP_SIZE
        };

        if (Graphics has :createBufferedBitmap) {
            mWashStamp = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
            mBrushStamp = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
        } else {
            return;
        }

        // Render Wash Stamp (Soft, feathered circle)
        var washDc = mWashStamp.getDc();
        washDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        washDc.clear();
        for (var i = 0; i < 8; i++) {
            var alpha = (10 - i) * 2; // Very faint accumulation
            var radius = (STAMP_SIZE / 2) - (i * 1.5).toNumber();
            if (radius > 0) {
                washDc.setFill(Graphics.createColor(alpha, 0, 0, 0));
                washDc.fillCircle(STAMP_SIZE / 2, STAMP_SIZE / 2, radius);
            }
        }

        // Render Brush Stamp (Gritty, "dry brush" structural fragment)
        var brushDc = mBrushStamp.getDc();
        brushDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        brushDc.clear();
        brushDc.setFill(Graphics.createColor(60, 0, 0, 0));
        // Asymmetric "shredded" brush tip
        brushDc.fillRectangle(10, 4, 4, 12);
        brushDc.fillRectangle(8, 8, 2, 8);
        brushDc.fillRectangle(14, 6, 2, 10);
        brushDc.setFill(Graphics.createColor(30, 0, 0, 0));
        brushDc.fillRectangle(6, 12, 12, 4);
    }

    function renderBufferedScene(minuteKey as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) {
            return;
        }

        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight, minuteKey);
        mLastMinuteKey = minuteKey;
    }

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        drawPaperBackground(dc, width, height);
        drawSunWash(dc, width, height, minuteKey);

        // Distant Ridge (Lighter, softer)
        drawDistantDescents(dc, width, height, minuteKey + 7);
        drawSoftMist(dc, width / 2, (height * 48) / 100, 200, 45, minuteKey + 11);

        // Foreground Ridge (Darker, more structural)
        drawForegroundDescents(dc, width, height, minuteKey + 17);
        
        // Add a lone pine tree for focal point
        drawLonePine(dc, (width * 78) / 100, (height * 72) / 100, 45, minuteKey + 31);
        
        drawSoftMist(dc, width / 3, (height * 73) / 100, 160, 60, minuteKey + 19);
        drawSoftMist(dc, (width * 2) / 3, (height * 80) / 100, 180, 50, minuteKey + 23);
    }

    function drawPaperBackground(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, 0xF4F1EA); // Classic washi paper tone
        dc.clear();

        // Subtle substrate variation
        fillRectAlpha(dc, 0x08A89F8F, 0, 0, width, height / 2);
        fillRectAlpha(dc, 0x058B8171, 0, height / 2, width, height / 2);
    }

    function drawSunWash(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        var progress = minuteKey.toFloat() / 1440.0;
        var sunX = 70 + ((width - 140) * progress).toNumber();
        var arc = progress - 0.5;
        var sunY = 80 + ((arc * arc) * 110).toNumber();

        // Soft solar glow using wash stamps
        for (var i = 0; i < 5; i++) {
            var drift = getJitter(minuteKey + i, 8);
            drawStamp(dc, mWashStamp, sunX + drift - 12, sunY + drift - 12, 0x0BD4C4A9);
        }
        
        fillCircleAlpha(dc, 0x25E3D3BF, sunX, sunY, 13);
        strokeCircleAlpha(dc, 0x1AC1A489, sunX, sunY, 11);
    }

    function drawDistantDescents(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var crest = [
            [width / 5, (height * 43) / 100, 26, 65],
            [(width * 60) / 100, (height * 40) / 100, 32, 75]
        ];
        drawDescentFamily(dc, crest, seed, 0x35514942, 0x1A5F5852, 7, 9, 5);
    }

    function drawForegroundDescents(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var crest = [
            [width / 4, (height * 54) / 100, 34, 120],
            [(width * 68) / 100, (height * 52) / 100, 40, 145]
        ];
        drawDescentFamily(dc, crest, seed, 0x8529211C, 0x302E2722, 12, 12, 7);
    }

    function drawDescentFamily(
        dc as Graphics.Dc,
        crest as Lang.Array,
        seed as Lang.Number,
        crestColor as Lang.Number,
        fadeColor as Lang.Number,
        countPerAnchor as Lang.Number,
        xStep as Lang.Number,
        yStep as Lang.Number
    ) as Void {
        for (var i = 0; i < crest.size(); i++) {
            var anchor = crest[i];
            var centerX = anchor[0];
            var crestY = anchor[1];
            var halfSpan = anchor[2];
            var maxLength = anchor[3];

            drawCrestAnchor(dc, centerX, crestY, halfSpan, seed + (i * 31), crestColor);

            for (var j = 0; j < countPerAnchor; j++) {
                var startX = centerX - halfSpan + (j * xStep) + getJitter(seed + (i * 41) + j, 7);
                var startY = crestY + getJitter(seed + (i * 43) + j, 5);
                var length = maxLength - (j * yStep) + getJitter(seed + (i * 47) + j, 20);
                drawVerticalStampDescent(dc, startX, startY, length, seed + (i * 59) + (j * 13), crestColor, fadeColor);
            }
        }
    }

    function drawCrestAnchor(dc as Graphics.Dc, centerX as Lang.Number, crestY as Lang.Number, halfSpan as Lang.Number, seed as Lang.Number, color as Lang.Number) as Void {
        var leftX = centerX - halfSpan + getJitter(seed, 8);
        var midX = centerX + getJitter(seed + 2, 7);
        var rightX = centerX + halfSpan + getJitter(seed + 4, 8);

        dc.setStroke(color);
        dc.setPenWidth(3);
        dc.drawLine(leftX, crestY + 5, midX, crestY - 4);
        dc.drawLine(midX, crestY - 4, rightX, crestY + 6);
        
        // Structural brush accents - stacking to create "sharpness"
        drawStamp(dc, mBrushStamp, midX - 12, crestY - 10, color);
        drawStamp(dc, mBrushStamp, midX - 10, crestY - 6, color);
        
        // Secondary "rib" line
        dc.setPenWidth(1);
        dc.drawLine(midX - 10, crestY + 8, midX + 15, crestY + 12);
    }

    function drawVerticalStampDescent(
        dc as Graphics.Dc,
        startX as Lang.Number,
        startY as Lang.Number,
        length as Lang.Number,
        seed as Lang.Number,
        topColor as Lang.Number,
        fadeColor as Lang.Number
    ) as Void {
        if (length < 20) { return; }

        var x = startX;
        for (var y = 0; y < length; y += 4) {
            var progress = y.toFloat() / length.toFloat();
            var color = fadeColor;
            var stamp = mWashStamp;

            if (y < 8) {
                color = topColor;
                stamp = mBrushStamp;
            } else if (progress > 0.75) {
                color = 0x0AF4F1EA; // Fades into paper
            }

            if (shouldDrop(seed + y, progress)) {
                drawStamp(dc, stamp, x - 12, startY + y - 12, color);
                // Occasionally add a second "bleed" stamp
                if ((seed + y) % 17 == 0) {
                   drawStamp(dc, mWashStamp, x - 10 + getJitter(seed + y, 4), startY + y - 10, 0x105F5852);
                }
            }

            if ((y % 8) == 0) {
                x += getJitter(seed + y, 4);
            }
        }
    }

    function drawLonePine(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, size as Lang.Number, seed as Lang.Number) as Void {
        var color = 0xD01A1A1B; // Deep sumi black
        dc.setStroke(color);
        dc.setPenWidth(3);
        
        // Trunk
        var trunkTopX = x + getJitter(seed, 5);
        var trunkTopY = y - size;
        dc.drawLine(x, y, trunkTopX, trunkTopY);
        
        // Branches
        for (var i = 0; i < 4; i++) {
            var bY = trunkTopY + (i * size / 4);
            var bX = trunkTopX + getJitter(seed + i, 10);
            var bLen = (size / 2) - (i * size / 10);
            
            // Left branch
            dc.setPenWidth(2);
            dc.drawLine(bX, bY, bX - bLen, bY + getJitter(seed + i + 1, 8));
            drawStamp(dc, mBrushStamp, bX - bLen - 8, bY - 4, color);
            
            // Right branch
            dc.drawLine(bX, bY, bX + bLen, bY + getJitter(seed + i + 2, 8));
            drawStamp(dc, mBrushStamp, bX + bLen - 4, bY - 4, color);
        }
    }

    function drawSoftMist(dc as Graphics.Dc, centerX as Lang.Number, centerY as Lang.Number, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var mistColor = 0x08F4F1EA; // Slightly more opaque
        for (var i = 0; i < 6; i++) {
            var driftX = getJitter(seed + i, 25);
            var driftY = getJitter(seed + i + 10, 15);
            var w = width + (i * 12);
            var h = height + (i * 6);
            fillRectAlpha(dc, mistColor, centerX + driftX - (w / 2), centerY + driftY - (h / 2), w, h);
            
            // Overlapping wash stamps for organic edges
            drawStamp(dc, mWashStamp, centerX + driftX - 50, centerY + driftY, 0x05F4F1EA);
            drawStamp(dc, mWashStamp, centerX + driftX + 30, centerY + driftY - 15, 0x05F4F1EA);
        }
    }

    function shouldDrop(seed as Lang.Number, progress as Lang.Float) as Lang.Boolean {
        var limit = 10;
        if (progress > 0.25) { limit = 8; }
        if (progress > 0.55) { limit = 5; }
        if (progress > 0.8) { limit = 3; }
        return (((seed * 23) + 7) % 11) < limit;
    }

    function drawStamp(dc as Graphics.Dc, stamp as Graphics.BufferedBitmap?, x as Lang.Number, y as Lang.Number, color as Lang.Number) as Void {
        if (stamp == null) { return; }
        dc.drawBitmap(x, y, stamp);
    }

    function fillRectAlpha(dc as Graphics.Dc, color as Lang.Number, x as Lang.Number, y as Lang.Number, width as Lang.Number, height as Lang.Number) as Void {
        if (width <= 0 || height <= 0) { return; }
        dc.setFill(color);
        dc.fillRectangle(x, y, width, height);
    }

    function fillCircleAlpha(dc as Graphics.Dc, color as Lang.Number, x as Lang.Number, y as Lang.Number, radius as Lang.Number) as Void {
        dc.setFill(color);
        dc.fillCircle(x, y, radius);
    }

    function strokeCircleAlpha(dc as Graphics.Dc, color as Lang.Number, x as Lang.Number, y as Lang.Number, radius as Lang.Number) as Void {
        dc.setStroke(color);
        dc.drawCircle(x, y, radius);
    }

    function getJitter(seed as Lang.Number, scale as Lang.Number) as Lang.Number {
        var pattern = [0, -2, 1, -1, 2, -3, 1, 0, -2, 2, -1, 3, -2];
        return pattern[seed % pattern.size()] * scale / 6;
    }

}
