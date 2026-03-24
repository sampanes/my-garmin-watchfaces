using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastMinuteKey as Lang.Number = -1;

    function initialize() {
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

        dc.drawBitmap(0, 0, mBuffer);
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

    function renderBufferedScene(minuteKey as Lang.Number) as Void {
        if (mBuffer == null) {
            return;
        }

        renderScene(mBuffer.getDc(), mBufferWidth, mBufferHeight, minuteKey);
        mLastMinuteKey = minuteKey;
    }

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        drawPaperBackground(dc, width, height);
        drawSunWash(dc, width, height, minuteKey);

        var distantSpines = makeSpines(
            width,
            (height * 3) / 5,
            [0.28, 0.48, 0.62, 0.44, 0.58],
            minuteKey + 9,
            54,
            86,
            12,
            18
        );
        var foregroundSpines = makeSpines(
            width,
            (height * 69) / 100,
            [0.74, 0.52, 0.88, 0.60, 0.78],
            minuteKey + 27,
            92,
            148,
            14,
            24
        );

        drawSpineFamily(dc, distantSpines, 0x3A9F9389, 0x229E9186, 0x188D7D71, 0x2A65594F, false, minuteKey + 4);
        drawMistErase(dc, width, height, (height * 53) / 100, 0x20F7F0E7, 0x18F1E8DB, minuteKey + 2);

        drawSpineFamily(dc, foregroundSpines, 0x5E6F645C, 0x3872665D, 0x22685A51, 0x8E241D19, true, minuteKey + 12);
        drawFootMist(dc, width, height, (height * 69) / 100, minuteKey + 15);
        drawDryBrushAccents(dc, foregroundSpines, minuteKey + 18);
        drawVeilMist(dc, width, height, minuteKey + 21);
    }

    function drawPaperBackground(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, 0xEFE5D6);
        dc.clear();

        fillRectAlpha(dc, 0x0CCFC0A9, 0, 0, width, height / 3);
        fillRectAlpha(dc, 0x10F9F2E8, 0, height / 2, width, height / 3);
        fillRectAlpha(dc, 0x0AD8C6B0, 0, (height * 3) / 4, width, height / 6);
    }

    function drawSunWash(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        var progress = minuteKey.toFloat() / 1440.0;
        var sunX = 52 + ((width - 100) * progress).toNumber();
        var arc = progress - 0.5;
        var sunY = 56 + ((arc * arc) * 82).toNumber();

        fillCircleAlpha(dc, 0x12FFF8F0, sunX - 3, sunY + 2, 15);
        fillCircleAlpha(dc, 0x20E7D8C5, sunX, sunY, 10);
        fillCircleAlpha(dc, 0x36D3B598, sunX + 1, sunY, 6);
        strokeCircleAlpha(dc, 0x34BA9C82, sunX + 1, sunY, 9);
    }

    function makeSpines(
        width as Lang.Number,
        baseY as Lang.Number,
        samples as Lang.Array,
        seed as Lang.Number,
        minRise as Lang.Number,
        maxRise as Lang.Number,
        minWidth as Lang.Number,
        maxWidth as Lang.Number
    ) as Lang.Array {
        var spines = [];
        var sampleCount = samples.size();
        var step = width / (sampleCount + 1);
        var i = 0;

        while (i < sampleCount) {
            var value = samples[i];
            var x = ((i + 1) * step) + getJitter(seed + (i * 3), 18);
            var rise = minRise + ((maxRise - minRise) * value).toNumber();
            var topY = baseY - rise + getJitter(seed + (i * 5), 10);
            var fade = rise + 54 + getJitter(seed + (i * 7), 14);
            var bodyWidth = minWidth + ((maxWidth - minWidth) * value).toNumber() + getJitter(seed + (i * 11), 4);

            if (bodyWidth < 10) {
                bodyWidth = 10;
            }

            if (fade < 48) {
                fade = 48;
            }

            spines.add([x, topY, fade, bodyWidth, value]);
            i += 1;
        }

        return spines;
    }

    function drawSpineFamily(
        dc as Graphics.Dc,
        spines as Lang.Array,
        washColor as Lang.Number,
        midColor as Lang.Number,
        footColor as Lang.Number,
        accentColor as Lang.Number,
        drawConnectors as Lang.Boolean,
        seed as Lang.Number
    ) as Void {
        var i = 0;

        while (i < spines.size()) {
            drawSingleSpine(dc, spines[i], washColor, midColor, footColor, accentColor, seed + (i * 13));
            i += 1;
        }

        if (!drawConnectors) {
            return;
        }

        i = 0;
        while (i < spines.size() - 1) {
            if (((seed + i) % 3) != 1) {
                connectSpines(dc, spines[i], spines[i + 1], 0x185C534C, 0x10F5EEE5, seed + (i * 17));
            }
            i += 1;
        }
    }

    function drawSingleSpine(
        dc as Graphics.Dc,
        spine as Lang.Array,
        washColor as Lang.Number,
        midColor as Lang.Number,
        footColor as Lang.Number,
        accentColor as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var x = spine[0];
        var topY = spine[1];
        var fade = spine[2];
        var bodyWidth = spine[3];

        var bodyHeight = fade / 2;
        var middleY = topY + bodyHeight / 2;
        var lowerY = topY + bodyHeight + 10;

        fillEllipseAlpha(dc, washColor, x - bodyWidth / 2, topY - 2, bodyWidth, bodyHeight);
        fillEllipseAlpha(dc, midColor, x - ((bodyWidth * 4) / 10), middleY - 4, (bodyWidth * 4) / 5, bodyHeight + 18);
        fillEllipseAlpha(dc, footColor, x - ((bodyWidth * 7) / 10), lowerY, (bodyWidth * 7) / 5, fade);

        var sideWisp = bodyWidth + 18 + getJitter(seed + 3, 8);
        fillEllipseAlpha(dc, 0x12F7EFE5, x - sideWisp / 2, topY + bodyHeight / 2, sideWisp, 26 + getJitter(seed + 5, 6));
        fillEllipseAlpha(dc, 0x16EFE5D7, x - (bodyWidth / 2) - 10 + getJitter(seed + 7, 6), topY + bodyHeight + 18, bodyWidth + 20, 30);

        var capWidth = (bodyWidth * 3) / 5;
        fillEllipseAlpha(dc, accentColor, x - capWidth / 2, topY - 3, capWidth, 10);
        fillEllipseAlpha(dc, 0x72322924, x - bodyWidth / 5, topY + 5, bodyWidth / 3 + 4, 16);

        drawSpineTail(dc, x, topY + 8, fade, bodyWidth, seed + 11);
    }

    function drawSpineTail(
        dc as Graphics.Dc,
        centerX as Lang.Number,
        startY as Lang.Number,
        fade as Lang.Number,
        bodyWidth as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var segments = 5;
        var i = 0;

        while (i < segments) {
            var progress = i.toFloat() / segments.toFloat();
            var segY = startY + (progress * fade).toNumber();
            var segWidth = bodyWidth - ((bodyWidth * i) / 8) + getJitter(seed + i, 6);
            var segHeight = 18 + ((fade / 7) - (i * 2));
            var drift = getJitter(seed + (i * 2), 8);
            var color = pickTailColor(i);

            if (segWidth < 10) {
                segWidth = 10;
            }

            if (segHeight < 10) {
                segHeight = 10;
            }

            fillEllipseAlpha(dc, color, centerX + drift - segWidth / 2, segY, segWidth, segHeight);
            i += 1;
        }
    }

    function pickTailColor(index as Lang.Number) as Lang.Number {
        var colors = [0x26463E39, 0x1E5D534C, 0x18685E56, 0x12A39589, 0x0EF7EFE6];
        return colors[index % colors.size()];
    }

    function connectSpines(
        dc as Graphics.Dc,
        leftSpine as Lang.Array,
        rightSpine as Lang.Array,
        color as Lang.Number,
        liftColor as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var leftX = leftSpine[0];
        var rightX = rightSpine[0];
        var leftY = leftSpine[1] + 12 + getJitter(seed, 4);
        var rightY = rightSpine[1] + 16 + getJitter(seed + 2, 4);
        var midX = (leftX + rightX) / 2;
        var topY = ((leftY + rightY) / 2) + getJitter(seed + 4, 8);
        var depth = 16 + getJitter(seed + 6, 6);

        dc.setFill(color);
        dc.fillPolygon([
            [leftX, leftY],
            [midX, topY],
            [rightX, rightY],
            [rightX, rightY + depth],
            [midX, topY + depth + 6],
            [leftX, leftY + depth]
        ]);

        fillEllipseAlpha(dc, liftColor, midX - 20, topY + 8, 40, depth + 12);
    }

    function drawMistErase(
        dc as Graphics.Dc,
        width as Lang.Number,
        height as Lang.Number,
        horizonY as Lang.Number,
        brightColor as Lang.Number,
        warmColor as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var bands = [
            [width / 7, horizonY + 6, 88],
            [width / 3, horizonY + 14, 102],
            [(width * 5) / 8, horizonY + 4, 116],
            [width - 72, horizonY + 12, 90]
        ];
        var i = 0;

        while (i < bands.size()) {
            var band = bands[i];
            var drift = getJitter(seed + (i * 3), 12);
            drawMistStamp(dc, band[0] + drift, band[1], band[2], brightColor, warmColor, seed + (i * 5));
            i += 1;
        }
    }

    function drawFootMist(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, baseY as Lang.Number, seed as Lang.Number) as Void {
        fillRectAlpha(dc, 0x10F6EFE6, 0, baseY + 40, width, height - (baseY + 40));

        drawMistStamp(dc, width / 5, baseY + 22, 76, 0x22FBF7F1, 0x14F0E7DA, seed + 1);
        drawMistStamp(dc, width / 2, baseY + 30, 96, 0x1EFBF6EE, 0x16EFE4D6, seed + 3);
        drawMistStamp(dc, (width * 4) / 5, baseY + 20, 82, 0x20FBF7F0, 0x14F3E9DD, seed + 5);
    }

    function drawVeilMist(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        drawMistStamp(dc, width / 2 - 28, (height * 57) / 100, 74, 0x18FBF7F0, 0x12EFE7DB, seed + 1);
        drawMistStamp(dc, width / 2 + 36, (height * 61) / 100, 62, 0x16FFF9F1, 0x10EFE6D8, seed + 3);
    }

    function drawMistStamp(
        dc as Graphics.Dc,
        centerX as Lang.Number,
        centerY as Lang.Number,
        radius as Lang.Number,
        brightColor as Lang.Number,
        warmColor as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var skew = getJitter(seed, 10);
        fillEllipseAlpha(dc, brightColor, centerX - radius, centerY - 7, radius * 2, 15);
        fillEllipseAlpha(dc, warmColor, centerX - (radius * 3) / 4 + skew, centerY - 1, (radius * 3) / 2, 18);
        fillEllipseAlpha(dc, 0x10FFFFFF, centerX - radius / 3, centerY + 4, (radius * 2) / 3, 10);
    }

    function drawDryBrushAccents(dc as Graphics.Dc, spines as Lang.Array, seed as Lang.Number) as Void {
        var i = 0;

        while (i < spines.size()) {
            if (((seed + i) % 2) == 0) {
                var spine = spines[i];
                var startX = spine[0] - (spine[3] / 4);
                var startY = spine[1] + 4;
                var endX = startX + 18 + getJitter(seed + i, 10);
                var endY = startY + 6 + getJitter(seed + i + 2, 8);

                strokeLineAlpha(dc, 0x88302822, startX, startY, endX, endY);
                strokeLineAlpha(dc, 0x54251D18, startX + 3, startY + 3, endX + 7, endY + 5);
            }
            i += 1;
        }
    }

    function fillRectAlpha(dc as Graphics.Dc, color as Lang.Number, x as Lang.Number, y as Lang.Number, width as Lang.Number, height as Lang.Number) as Void {
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

    function fillEllipseAlpha(dc as Graphics.Dc, color as Lang.Number, x as Lang.Number, y as Lang.Number, width as Lang.Number, height as Lang.Number) as Void {
        dc.setFill(color);
        dc.fillEllipse(x, y, width, height);
    }

    function strokeLineAlpha(dc as Graphics.Dc, color as Lang.Number, x1 as Lang.Number, y1 as Lang.Number, x2 as Lang.Number, y2 as Lang.Number) as Void {
        dc.setStroke(color);
        dc.drawLine(x1, y1, x2, y2);
    }

    function getJitter(seed as Lang.Number, scale as Lang.Number) as Lang.Number {
        var pattern = [0, -2, 1, -1, 2, -3, 1, 0, -2, 2, -1, 3, -2];
        return pattern[seed % pattern.size()] * scale / 6;
    }

}
