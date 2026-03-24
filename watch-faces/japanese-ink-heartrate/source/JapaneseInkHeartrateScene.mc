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
        if (mBuffer == null) {
            return;
        }

        renderScene(mBuffer.getDc(), mBufferWidth, mBufferHeight, minuteKey);
        mLastMinuteKey = minuteKey;
    }

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, minuteKey as Lang.Number) as Void {
        drawPaperBackground(dc, width, height);
        drawSunWash(dc, width, height, minuteKey);

        var distantMasses = makeMasses(
            width,
            (height * 57) / 100,
            [0.32, 0.58],
            minuteKey + 7,
            42,
            82,
            24
        );
        var foregroundMasses = makeMasses(
            width,
            (height * 69) / 100,
            [0.78, 0.56],
            minuteKey + 23,
            76,
            146,
            28
        );

        drawRasterMountains(dc, distantMasses, minuteKey + 31, false);
        drawMistPass(dc, width, height, (height * 56) / 100, minuteKey + 37);

        drawRasterMountains(dc, foregroundMasses, minuteKey + 43, true);
        drawMistErase(dc, width, height, (height * 69) / 100, minuteKey + 53);
        drawAtmosphericVeil(dc, width, height, minuteKey + 59);
    }

    function drawPaperBackground(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, 0xEFE5D6);
        dc.clear();

        fillRectAlpha(dc, 0x0AD4C5AE, 0, 0, width, height / 3);
        fillRectAlpha(dc, 0x0EF9F2E8, 0, height / 2, width, height / 3);
        fillRectAlpha(dc, 0x08D7C7B2, 0, (height * 4) / 5, width, height / 8);
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

    function makeMasses(
        width as Lang.Number,
        baseY as Lang.Number,
        samples as Lang.Array,
        seed as Lang.Number,
        minRise as Lang.Number,
        maxRise as Lang.Number,
        baseSpread as Lang.Number
    ) as Lang.Array {
        var masses = [];
        var step = width / (samples.size() + 1);
        var i = 0;

        while (i < samples.size()) {
            var value = samples[i];
            var centerX = ((i + 1) * step) + getJitter(seed + (i * 3), 14);
            var rise = minRise + ((maxRise - minRise) * value).toNumber();
            var crestY = baseY - rise + getJitter(seed + (i * 5), 10);
            var bodyHeight = 72 + ((52 * value).toNumber()) + getJitter(seed + (i * 7), 10);
            var spread = baseSpread + ((18 * value).toNumber()) + getJitter(seed + (i * 11), 6);
            masses.add([centerX, crestY, bodyHeight, spread, value]);
            i += 1;
        }

        return masses;
    }

    function drawRasterMountains(dc as Graphics.Dc, masses as Lang.Array, seed as Lang.Number, isForeground as Lang.Boolean) as Void {
        var i = 0;
        while (i < masses.size()) {
            drawMassRaster(dc, masses[i], seed + (i * 97), isForeground, i);
            i += 1;
        }

        if (!isForeground) {
            return;
        }

        i = 0;
        while (i < masses.size() - 1) {
            if (((seed + i) % 2) == 0) {
                drawMassBridge(dc, masses[i], masses[i + 1], seed + (i * 41));
            }
            i += 1;
        }
    }

    function drawMassRaster(dc as Graphics.Dc, mass as Lang.Array, seed as Lang.Number, isForeground as Lang.Boolean, index as Lang.Number) as Void {
        var centerX = mass[0];
        var crestY = mass[1];
        var bodyHeight = mass[2];
        var spread = mass[3];

        drawCrestCap(dc, centerX, crestY, spread, seed, isForeground);

        var y = 0;
        while (y < bodyHeight) {
            var progress = y.toFloat() / bodyHeight.toFloat();
            var halfWidth = ((spread * 4) / 10) + ((spread * y) / (bodyHeight + 8));
            var localCenter = centerX + getJitter(seed + y, 5);
            var leftBound = localCenter - halfWidth;
            var rightBound = localCenter + halfWidth;
            var rowY = crestY + y;
            var x = leftBound;
            var rowSeed = seed + (y * 17);
            var density = pickDensity(progress, isForeground);

            while (x <= rightBound) {
                if (shouldInk(rowSeed + x, density)) {
                    drawInkPoint(dc, x, rowY + getJitter(rowSeed + x + 5, 2), pickWashColor(progress, isForeground));

                    if (shouldInk(rowSeed + x + 9, density + 4)) {
                        drawInkPoint(dc, x + 2, rowY + 1, pickLiftColor(progress));
                    }
                }
                x += 4;
            }

            if ((y % 16) == 0) {
                drawScratchDescents(dc, localCenter, rowY, spread, seed + (y * 13), isForeground);
            }

            y += 4;
        }

        if (isForeground && (index % 2) == 0) {
            drawBrokenFlank(dc, centerX - (spread / 3), crestY + 14, bodyHeight / 2, seed + 401);
        }
    }

    function drawCrestCap(dc as Graphics.Dc, centerX as Lang.Number, crestY as Lang.Number, spread as Lang.Number, seed as Lang.Number, isForeground as Lang.Boolean) as Void {
        var leftX = centerX - (spread / 2) + getJitter(seed, 6);
        var midX = centerX + getJitter(seed + 2, 4);
        var rightX = centerX + (spread / 2) + getJitter(seed + 4, 6);
        var color = 0x6E2A221D;

        if (isForeground) {
            color = 0x9A231C18;
        }

        strokeLineAlpha(dc, color, leftX, crestY + 2, midX, crestY - 2);
        strokeLineAlpha(dc, color, midX, crestY - 2, rightX, crestY + 4);

        if ((seed % 2) == 0) {
            strokeLineAlpha(dc, 0x582D241E, midX - 5, crestY + 4, midX + 12 + getJitter(seed + 6, 5), crestY + 8);
        }
    }

    function drawScratchDescents(dc as Graphics.Dc, centerX as Lang.Number, startY as Lang.Number, spread as Lang.Number, seed as Lang.Number, isForeground as Lang.Boolean) as Void {
        var scratchCount = 1;
        var i = 0;

        while (i < scratchCount) {
            var startX = centerX + getJitter(seed + i, spread / 3);
            var endX = startX + getJitter(seed + i + 5, 7);
            var endY = startY + 18 + getJitter(seed + i + 9, 10);
            var color = 0x30322923;

            if (isForeground) {
                color = 0x44312621;
            }

            strokeLineAlpha(dc, color, startX, startY, endX, endY);
            i += 1;
        }
    }

    function drawBrokenFlank(dc as Graphics.Dc, centerX as Lang.Number, startY as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var i = 0;
        while (i < 3) {
            var x = centerX + getJitter(seed + i, 6);
            var y1 = startY + (i * (height / 6));
            var y2 = y1 + 16 + getJitter(seed + i + 8, 8);
            strokeLineAlpha(dc, 0x42312822, x, y1, x + getJitter(seed + i + 11, 5), y2);
            i += 1;
        }
    }

    function drawMassBridge(dc as Graphics.Dc, leftMass as Lang.Array, rightMass as Lang.Array, seed as Lang.Number) as Void {
        var leftX = leftMass[0];
        var rightX = rightMass[0];
        var leftY = leftMass[1] + 18 + getJitter(seed, 4);
        var rightY = rightMass[1] + 20 + getJitter(seed + 2, 4);
        var steps = 10;
        var i = 0;

        while (i <= steps) {
            var t = i.toFloat() / steps.toFloat();
            var x = leftX + ((rightX - leftX) * t).toNumber();
            var y = leftY + ((rightY - leftY) * t).toNumber() + getJitter(seed + i, 3);

            if (shouldInk(seed + i + x, 9)) {
                drawInkPoint(dc, x, y, 0x16594F48);
            }
            i += 1;
        }
    }

    function drawMistPass(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, yBase as Lang.Number, seed as Lang.Number) as Void {
        drawMistRibbon(dc, width / 5, yBase + 6, 92, 16, seed + 1);
        drawMistRibbon(dc, width / 2, yBase + 16, 112, 20, seed + 3);
        drawMistRibbon(dc, (width * 4) / 5, yBase + 10, 86, 16, seed + 5);
    }

    function drawMistErase(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, yBase as Lang.Number, seed as Lang.Number) as Void {
        fillRectAlpha(dc, 0x08FBF7EF, 0, yBase + 34, width, height - (yBase + 34));
        drawMistRibbon(dc, width / 4, yBase + 26, 110, 20, seed + 1);
        drawMistRibbon(dc, (width * 5) / 8, yBase + 34, 132, 24, seed + 3);
        drawMistRibbon(dc, width - 74, yBase + 22, 86, 18, seed + 5);
    }

    function drawAtmosphericVeil(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        drawMistRibbon(dc, width / 2 - 22, (height * 58) / 100, 70, 14, seed + 1);
        drawMistRibbon(dc, width / 2 + 32, (height * 62) / 100, 60, 12, seed + 3);
    }

    function drawMistRibbon(dc as Graphics.Dc, centerX as Lang.Number, centerY as Lang.Number, ribbonWidth as Lang.Number, ribbonHeight as Lang.Number, seed as Lang.Number) as Void {
        var i = 0;
        while (i < 2) {
            var localWidth = ribbonWidth - (i * 12);
            var localHeight = ribbonHeight - (i * 2);
            var driftX = getJitter(seed + i, 12);
            var driftY = getJitter(seed + i + 5, 4);
            var leftX = centerX + driftX - (localWidth / 2);
            var rightX = centerX + driftX + (localWidth / 2);
            var topY = centerY + driftY;
            var bottomY = topY + localHeight;

            fillMistBand(dc, 0x0EFBF6EF, leftX, rightX, topY, bottomY, seed + (i * 19));
            i += 1;
        }

        fillMistBand(dc, 0x0EF1E8DB, centerX - (ribbonWidth / 3), centerX + (ribbonWidth / 3), centerY + 4, centerY + ribbonHeight, seed + 91);
    }

    function fillMistBand(dc as Graphics.Dc, color as Lang.Number, leftX as Lang.Number, rightX as Lang.Number, topY as Lang.Number, bottomY as Lang.Number, seed as Lang.Number) as Void {
        var y = topY;
        while (y <= bottomY) {
            var inset = ((y - topY) % 3) * 2;
            var x = leftX + inset + getJitter(seed + y, 4);

            while (x <= rightX - inset) {
                if (shouldInk(seed + x + y, 8)) {
                    drawInkPoint(dc, x, y, color);
                }
                x += 4;
            }
            y += 4;
        }
    }

    function drawInkPoint(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, color as Lang.Number) as Void {
        dc.setStroke(color);
        dc.drawPoint(x, y);
    }

    function pickDensity(progress as Lang.Float, isForeground as Lang.Boolean) as Lang.Number {
        if (progress < 0.12) {
            return isForeground ? 1 : 1;
        } else if (progress < 0.30) {
            return isForeground ? 1 : 2;
        } else if (progress < 0.58) {
            return isForeground ? 2 : 3;
        } else if (progress < 0.80) {
            return isForeground ? 3 : 4;
        }

        return isForeground ? 4 : 5;
    }

    function pickWashColor(progress as Lang.Float, isForeground as Lang.Boolean) as Lang.Number {
        if (progress < 0.14) {
            return isForeground ? 0x3A2C241F : 0x2A4A433D;
        } else if (progress < 0.34) {
            return isForeground ? 0x2A4A4039 : 0x1E75695F;
        } else if (progress < 0.60) {
            return isForeground ? 0x1E675D55 : 0x186F645A;
        } else if (progress < 0.84) {
            return isForeground ? 0x166C6158 : 0x106F655D;
        }

        return isForeground ? 0x0CF0E6D9 : 0x0AF5ECE0;
    }

    function pickLiftColor(progress as Lang.Float) as Lang.Number {
        if (progress < 0.45) {
            return 0x10F2E8DD;
        } else if (progress < 0.75) {
            return 0x0CF5ECE1;
        }

        return 0x08FBF5ED;
    }

    function shouldInk(seed as Lang.Number, density as Lang.Number) as Lang.Boolean {
        var value = (seed * 31) % 17;
        return value < density;
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
