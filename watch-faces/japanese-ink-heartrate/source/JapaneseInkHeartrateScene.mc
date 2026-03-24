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

    function renderBufferedScene(minuteKey as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) {
            return;
        }

        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight, minuteKey);
        mLastMinuteKey = minuteKey;
    }

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        drawPaperBackground(dc, width, height);
        drawSunWash(dc, width, height, minuteKey);

        drawDistantDescents(dc, width, height, minuteKey + 7);
        drawMistBand(dc, width / 2, (height * 29) / 50, 130, 18, minuteKey + 11, 0x10FBF6EF, 0x0CF1E8DB);

        drawForegroundDescents(dc, width, height, minuteKey + 17);
        drawMistBand(dc, width / 4, (height * 73) / 100, 100, 20, minuteKey + 19, 0x10FBF6EF, 0x0EF2EADD);
        drawMistBand(dc, (width * 3) / 4, (height * 19) / 25, 114, 24, minuteKey + 23, 0x12FBF7F0, 0x0EF0E6D9);
    }

    function drawPaperBackground(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, 0xEFE5D6);
        dc.clear();

        fillRectAlpha(dc, 0x0AD3C3AC, 0, 0, width, height / 3);
        fillRectAlpha(dc, 0x0EF9F2E8, 0, height / 2, width, height / 3);
        fillRectAlpha(dc, 0x08D8C8B1, 0, (height * 4) / 5, width, height / 8);
    }

    function drawSunWash(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        var progress = minuteKey.toFloat() / 1440.0;
        var sunX = 50 + ((width - 96) * progress).toNumber();
        var arc = progress - 0.5;
        var sunY = 54 + ((arc * arc) * 82).toNumber();

        fillCircleAlpha(dc, 0x10FFF9EF, sunX - 2, sunY + 1, 14);
        fillCircleAlpha(dc, 0x18E3D3BF, sunX, sunY, 10);
        strokeCircleAlpha(dc, 0x26C1A489, sunX + 1, sunY, 8);
    }

    function drawDistantDescents(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var crest = [
            [width / 4, (height * 11) / 25, 22, 46],
            [(width * 11) / 20, (height * 43) / 100, 26, 56]
        ];

        drawDescentFamily(dc, crest, seed, 0x6A514942, 0x245F5852, 5, 6, 4);
    }

    function drawForegroundDescents(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var crest = [
            [width / 3, (height * 53) / 100, 26, 84],
            [(width * 5) / 8, (height * 51) / 100, 30, 104]
        ];

        drawDescentFamily(dc, crest, seed, 0xA129211C, 0x342E2722, 8, 8, 5);
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
        var i = 0;
        while (i < crest.size()) {
            var anchor = crest[i];
            var centerX = anchor[0];
            var crestY = anchor[1];
            var halfSpan = anchor[2];
            var maxLength = anchor[3];

            drawCrestAnchor(dc, centerX, crestY, halfSpan, seed + (i * 31), crestColor);

            var j = 0;
            while (j < countPerAnchor) {
                var startX = centerX - halfSpan + (j * xStep) + getJitter(seed + (i * 41) + j, 5);
                var startY = crestY + getJitter(seed + (i * 43) + j, 3);
                var length = maxLength - (j * yStep) + getJitter(seed + (i * 47) + j, 10);
                drawVerticalFadeDescent(dc, startX, startY, length, seed + (i * 59) + (j * 13), crestColor, fadeColor);
                j += 1;
            }

            i += 1;
        }
    }

    function drawCrestAnchor(dc as Graphics.Dc, centerX as Lang.Number, crestY as Lang.Number, halfSpan as Lang.Number, seed as Lang.Number, color as Lang.Number) as Void {
        var leftX = centerX - halfSpan + getJitter(seed, 4);
        var midX = centerX + getJitter(seed + 2, 3);
        var rightX = centerX + halfSpan + getJitter(seed + 4, 4);

        strokeLineAlpha(dc, color, leftX, crestY + 3, midX, crestY - 2);
        strokeLineAlpha(dc, color, midX, crestY - 2, rightX, crestY + 4);

        if ((seed % 2) == 0) {
            strokeLineAlpha(dc, 0x62322924, midX - 4, crestY + 5, midX + 10 + getJitter(seed + 6, 4), crestY + 8);
        }
    }

    function drawVerticalFadeDescent(
        dc as Graphics.Dc,
        startX as Lang.Number,
        startY as Lang.Number,
        length as Lang.Number,
        seed as Lang.Number,
        topColor as Lang.Number,
        fadeColor as Lang.Number
    ) as Void {
        if (length < 12) {
            return;
        }

        var x = startX;
        var y = 0;

        while (y < length) {
            var progress = y.toFloat() / length.toFloat();
            var color = fadeColor;

            if (y < 3) {
                color = topColor;
            } else if (progress > 0.72) {
                color = 0x12F1E8DB;
            } else if (progress > 0.52) {
                color = 0x22574F49;
            }

            if (shouldDrop(seed + y, progress)) {
                drawInkPoint(dc, x, startY + y, color);

                if ((y % 7) == 0 && progress < 0.55) {
                    drawInkPoint(dc, x + 1, startY + y, 0x182E2722);
                }
            }

            if ((y % 6) == 0) {
                x += getJitter(seed + y + 5, 2);
            }

            y += 2;
        }
    }

    function shouldDrop(seed as Lang.Number, progress as Lang.Float) as Lang.Boolean {
        var limit = 8;

        if (progress > 0.2) {
            limit = 6;
        }
        if (progress > 0.45) {
            limit = 4;
        }
        if (progress > 0.7) {
            limit = 2;
        }

        return (((seed * 17) + 3) % 11) < limit;
    }

    function drawMistBand(
        dc as Graphics.Dc,
        centerX as Lang.Number,
        centerY as Lang.Number,
        width as Lang.Number,
        height as Lang.Number,
        seed as Lang.Number,
        lightColor as Lang.Number,
        warmColor as Lang.Number
    ) as Void {
        var i = 0;
        while (i < 2) {
            var localWidth = width - (i * 14);
            var localHeight = height - (i * 3);
            var driftX = getJitter(seed + i, 10);
            var driftY = getJitter(seed + i + 5, 3);
            fillRectAlpha(dc, lightColor, centerX + driftX - (localWidth / 2), centerY + driftY, localWidth, localHeight);
            i += 1;
        }

        fillRectAlpha(dc, warmColor, centerX - (width / 3), centerY + 4, (width * 2) / 3, height - 4);
    }

    function drawInkPoint(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, color as Lang.Number) as Void {
        dc.setStroke(color);
        dc.drawPoint(x, y);
    }

    function fillRectAlpha(dc as Graphics.Dc, color as Lang.Number, x as Lang.Number, y as Lang.Number, width as Lang.Number, height as Lang.Number) as Void {
        if (width <= 0 || height <= 0) {
            return;
        }

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

    function strokeLineAlpha(dc as Graphics.Dc, color as Lang.Number, x1 as Lang.Number, y1 as Lang.Number, x2 as Lang.Number, y2 as Lang.Number) as Void {
        dc.setStroke(color);
        dc.drawLine(x1, y1, x2, y2);
    }

    function getJitter(seed as Lang.Number, scale as Lang.Number) as Lang.Number {
        var pattern = [0, -2, 1, -1, 2, -3, 1, 0, -2, 2, -1, 3, -2];
        return pattern[seed % pattern.size()] * scale / 6;
    }

}
