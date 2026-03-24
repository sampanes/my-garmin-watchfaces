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
        drawMistField(dc, width, height, minuteKey);
        drawRidgeWash(dc, width, height, (height * 29) / 50, 18, [0.56, 0.51, 0.48, 0.45, 0.49, 0.43, 0.46], minuteKey + 3, [0x30B5A899, 0x4CC9BAA7, 0x6ADFD4C6]);
        drawRidgeWash(dc, width, height, (height * 17) / 25, 32, [0.72, 0.68, 0.49, 0.58, 0.62, 0.57, 0.40, 0.50, 0.44], minuteKey, [0x388B7A6A, 0x5C62554B, 0x88433830]);
        drawCrestInk(dc, width, height, (height * 17) / 25, 32, [0.72, 0.68, 0.49, 0.58, 0.62, 0.57, 0.40, 0.50, 0.44], minuteKey, 0xCC241C17);
    }

    function drawPaperBackground(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, 0xEFE5D6);
        dc.clear();

        fillRectAlpha(dc, 0x12D6C5AF, 0, height / 8, width, height / 4);
        fillRectAlpha(dc, 0x10FFFFFF, 0, (height * 3) / 5, width, height / 3);
        fillRectAlpha(dc, 0x08C9B8A2, 0, 0, width, height / 2);
    }

    function drawSunWash(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        var progress = minuteKey.toFloat() / 1440.0;
        var sunX = 44 + ((width - 88) * progress).toNumber();
        var sunY = 58 + (((progress - 0.5) * (progress - 0.5)) * 84).toNumber();

        fillCircleAlpha(dc, 0x18FFFFFF, sunX - 3, sunY + 1, 16);
        fillCircleAlpha(dc, 0x28E6D6C3, sunX, sunY, 11);
        fillCircleAlpha(dc, 0x55D0B395, sunX + 1, sunY, 7);
        strokeCircleAlpha(dc, 0x4AAE9278, sunX + 1, sunY, 10);
    }

    function drawMistField(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var yBase = (height * 3) / 5;
        var positions = [20, width / 4, (width * 7) / 16, (width * 5) / 8, width - 58];
        var i = 0;

        while (i < positions.size()) {
            var drift = getJitter(seed + i, 10);
            drawMistStamp(dc, positions[i] + drift, yBase + ((i + 1) % 3) * 10, 40 + (i % 2) * 12);
            i += 1;
        }
    }

    function drawMistStamp(dc as Graphics.Dc, centerX as Lang.Number, centerY as Lang.Number, radius as Lang.Number) as Void {
        fillEllipseAlpha(dc, 0x1AFFFFFF, centerX - radius, centerY - 7, radius * 2, 12);
        fillEllipseAlpha(dc, 0x20F5EDE3, centerX - (radius * 3) / 5, centerY - 1, (radius * 6) / 5, 16);
        fillEllipseAlpha(dc, 0x18EFE6DA, centerX - radius / 4, centerY + 3, radius, 10);
        fillEllipseAlpha(dc, 0x14FFFFFF, centerX + radius / 5, centerY + 1, (radius * 3) / 5, 8);
    }

    function drawRidgeWash(
        dc as Graphics.Dc,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        samples as Lang.Array,
        seed as Lang.Number,
        colors as Lang.Array
    ) as Void {
        var crest = makeRidgePoints(width, baseY, amplitude, samples, seed);
        var i = 0;

        while (i < crest.size()) {
            var point = crest[i];
            stampHorizontalWash(dc, point[0], point[1] + 16, colors[0], 42, 16, seed + i);
            stampHorizontalWash(dc, point[0] + getJitter(seed + i, 7), point[1] + 10, colors[1], 28, 10, seed + i + 5);
            stampHorizontalWash(dc, point[0] + getJitter(seed + i + 5, 5), point[1] + 5, colors[2], 14, 6, seed + i + 9);
            i += 1;
        }

        i = 0;
        while (i < crest.size() - 1) {
            var p1 = crest[i];
            var p2 = crest[i + 1];
            smearConnector(dc, 0x1E8D7C6E, p1[0], p1[1] + 14, p2[0], p2[1] + 14, 14);
            i += 1;
        }
    }

    function drawCrestInk(
        dc as Graphics.Dc,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        samples as Lang.Array,
        seed as Lang.Number,
        color as Lang.Number
    ) as Void {
        var crest = makeRidgePoints(width, baseY, amplitude, samples, seed);
        var i = 0;

        while (i < crest.size() - 1) {
            if ((i % 2) == 0) {
                var p1 = crest[i];
                var p2 = crest[i + 1];
                strokeLineAlpha(dc, color, p1[0], p1[1], p2[0], p2[1]);
                strokeLineAlpha(dc, 0x663A2D26, p1[0] + 3, p1[1] + 2, p2[0] + 2, p2[1] + 3);
            }

            i += 1;
        }
    }

    function makeRidgePoints(
        width as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        samples as Lang.Array,
        seed as Lang.Number
    ) as Lang.Array {
        var points = [];
        var sampleCount = samples.size();
        var step = width / (sampleCount - 1);
        var i = 0;

        while (i < sampleCount) {
            var shaped = samples[i] * samples[i];
            var x = (i * step);
            var y = baseY - (shaped * amplitude) + getJitter(seed + i, 4);
            points.add([x, y]);
            i += 1;
        }

        return points;
    }

    function fillConnector(
        dc as Graphics.Dc,
        color as Lang.Number,
        x1 as Lang.Number,
        y1 as Lang.Number,
        x2 as Lang.Number,
        y2 as Lang.Number,
        depth as Lang.Number
    ) as Void {
        dc.setFill(color);
        dc.fillPolygon([
            [x1, y1],
            [x2, y2],
            [x2, y2 + depth],
            [x1, y1 + depth]
        ]);
    }

    function smearConnector(
        dc as Graphics.Dc,
        color as Lang.Number,
        x1 as Lang.Number,
        y1 as Lang.Number,
        x2 as Lang.Number,
        y2 as Lang.Number,
        depth as Lang.Number
    ) as Void {
        fillConnector(dc, color, x1, y1, x2, y2, depth);
        fillEllipseAlpha(dc, 0x18877567, (x1 + x2) / 2 - 18, ((y1 + y2) / 2) + 2, 36, depth + 6);
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

    function stampHorizontalWash(
        dc as Graphics.Dc,
        centerX as Lang.Number,
        centerY as Lang.Number,
        color as Lang.Number,
        width as Lang.Number,
        height as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var skew = getJitter(seed, 8);
        fillEllipseAlpha(dc, color, centerX - width / 2, centerY - height / 2, width, height);
        fillEllipseAlpha(dc, color - 0x08000000, centerX - width / 3 + skew, centerY - height / 3, (width * 2) / 3, height / 2 + 2);
        fillEllipseAlpha(dc, 0x10FFFFFF, centerX - width / 4, centerY - 1, width / 2, height / 3 + 2);
    }

    function getJitter(seed as Lang.Number, scale as Lang.Number) as Lang.Number {
        var pattern = [0, -2, 1, -1, 2, -3, 1, 0, -2, 2, -1, 3, -2];
        return pattern[seed % pattern.size()] * scale / 6;
    }

}
