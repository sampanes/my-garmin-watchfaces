using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastMinuteKey as Lang.Number = -1;

    var mBrushStamp as Graphics.BufferedBitmap?;
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

        mBrushStamp = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
        if (mBrushStamp != null) {
            var brushDc = mBrushStamp.getDc();
            brushDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            brushDc.clear();
            brushDc.setFill(Graphics.createColor(34, 28, 24, 20));
            brushDc.fillEllipse(7, 11, 18, 7);
            brushDc.fillEllipse(10, 7, 10, 5);
            brushDc.fillEllipse(15, 15, 10, 6);
        }

        mMistStamp = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
        if (mMistStamp != null) {
            var mistDc = mMistStamp.getDc();
            mistDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
            mistDc.clear();
            for (var i = 0; i < 6; i++) {
                var alpha = (7 - i) * 3;
                mistDc.setFill(Graphics.createColor(alpha, 244, 241, 234));
                mistDc.fillCircle(16, 16, 15 - (i * 2));
            }
        }
    }

    function renderBufferedScene(minuteKey as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) { return; }
        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight, minuteKey);
        mLastMinuteKey = minuteKey;
    }

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        drawPaper(dc, width, height);
        drawSun(dc, width, height, seed);

        var farPeaks = [
            [0.18, 0.22, 0.18],
            [0.48, 0.18, 0.22],
            [0.78, 0.26, 0.18]
        ];
        var midPeaks = [
            [0.16, 0.44, 0.12],
            [0.41, 0.62, 0.11],
            [0.68, 0.58, 0.10],
            [0.89, 0.40, 0.11]
        ];
        var nearPeaks = [
            [0.06, 0.48, 0.09],
            [0.25, 0.78, 0.08],
            [0.50, 0.92, 0.09],
            [0.75, 0.74, 0.08],
            [0.95, 0.54, 0.09]
        ];

        var farProfile = buildProfile(width, farPeaks, (height * 58) / 100, (height * 18) / 100, 0.05, seed + 101);
        drawMountainMass(dc, farProfile, width, height, 18, 7, seed + 121);

        drawMistBand(dc, width, (height * 45) / 100, 96, 0.24, seed + 201);

        var midProfile = buildProfile(width, midPeaks, (height * 70) / 100, (height * 34) / 100, 0.10, seed + 301);
        drawMountainMass(dc, midProfile, width, height, 44, 11, seed + 321);
        drawCrestMarks(dc, midProfile, width, seed + 341, 3);

        drawMistBand(dc, width, (height * 63) / 100, 84, 0.28, seed + 401);

        var nearProfile = buildProfile(width, nearPeaks, (height * 83) / 100, (height * 45) / 100, 0.13, seed + 501);
        drawMountainMass(dc, nearProfile, width, height, 86, 16, seed + 521);
        drawCrestMarks(dc, nearProfile, width, seed + 541, 4);

        drawMistBand(dc, width, (height * 78) / 100, 70, 0.18, seed + 601);
        drawWaterLines(dc, width, height, seed + 701);
        drawPaperGrain(dc, width, height, seed + 801);
    }

    function drawPaper(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(0xF4F1EA, 0xF4F1EA);
        dc.clear();
        dc.setFill(Graphics.createColor(10, 255, 250, 240));
        dc.fillRectangle(0, 0, width, height / 2);
    }

    function drawSun(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var x = (width * 78) / 100;
        var y = (height * 15) / 100 + getJitter(seed, 6);
        dc.setFill(Graphics.createColor(34, 220, 200, 172));
        dc.fillCircle(x, y, 13);
        dc.setStroke(Graphics.createColor(24, 186, 156, 126));
        dc.drawCircle(x, y, 10);
    }

    function buildProfile(width as Lang.Number, peaks as Lang.Array, yBase as Lang.Number, amp as Lang.Number, rough as Lang.Float, seed as Lang.Number) as Lang.Array {
        var points = [];
        var steps = 52;
        var stepWidth = width.toFloat() / steps.toFloat();

        for (var i = 0; i <= steps; i++) {
            var nx = i.toFloat() / steps.toFloat();
            var v = 0.0;

            for (var p = 0; p < peaks.size(); p++) {
                var peak = peaks[p];
                var dx = nx - peak[0];
                var spread = peak[2];
                var denom = 2.0 * spread * spread;
                var value = peak[1] * Math.pow(Math.E, -(dx * dx) / denom);
                if (value > v) { v = value; }
            }

            v += (getJitter(seed + i, 100).toFloat() / 100.0) * rough;

            var x = (i.toFloat() * stepWidth).toNumber();
            var y = yBase - (v * amp.toFloat()).toNumber();
            points.add([x, y]);
        }

        return points;
    }

    function drawMountainMass(dc as Graphics.Dc, profile as Lang.Array, width as Lang.Number, height as Lang.Number, maxAlpha as Lang.Number, dark as Lang.Number, seed as Lang.Number) as Void {
        for (var layer = 0; layer < 6; layer++) {
            var offset = layer * 9;
            var alpha = maxAlpha - (layer * (maxAlpha / 7));
            if (alpha < 2) { alpha = 2; }

            var poly = [];
            poly.add([0, height]);
            poly.add([width, height]);

            for (var i = profile.size() - 1; i >= 0; i--) {
                var pt = profile[i];
                poly.add([pt[0], pt[1] + offset]);
            }

            dc.setFill(Graphics.createColor(alpha, dark, dark - 2, dark - 4));
            dc.fillPolygon(poly);
        }

        bleedEdge(dc, profile, maxAlpha / 2, seed + 23);
    }

    function drawCrestMarks(dc as Graphics.Dc, profile as Lang.Array, width as Lang.Number, seed as Lang.Number, marks as Lang.Number) as Void {
        var chosen = [];

        for (var m = 0; m < marks; m++) {
            var bestIndex = -1;
            var bestY = 9999;

            for (var i = 2; i < profile.size() - 2; i++) {
                var pt = profile[i];
                var valid = true;
                for (var j = 0; j < chosen.size(); j++) {
                    var prev = chosen[j];
                    var delta = pt[0] - prev[0];
                    if (delta < 0) { delta = -delta; }
                    if (delta < (width / 8)) {
                        valid = false;
                    }
                }
                if (valid && pt[1] < bestY) {
                    bestY = pt[1];
                    bestIndex = i;
                }
            }

            if (bestIndex >= 0) {
                chosen.add(profile[bestIndex]);
                profile[bestIndex] = [profile[bestIndex][0], 9999];
            }
        }

        dc.setStroke(Graphics.createColor(52, 24, 20, 18));
        dc.setPenWidth(2);

        for (var k = 0; k < chosen.size(); k++) {
            var mark = chosen[k];
            var x1 = mark[0] - 12 + getJitter(seed + k, 4);
            var y1 = mark[1] + 2;
            var x2 = mark[0] + 16 + getJitter(seed + k + 11, 4);
            var y2 = mark[1] - 3 + getJitter(seed + k + 17, 3);
            dc.drawLine(x1, y1, x2, y2);

            if (mBrushStamp != null) {
                dc.drawBitmap(mark[0] - 12, mark[1] - 6, mBrushStamp);
            }
        }
    }

    function bleedEdge(dc as Graphics.Dc, profile as Lang.Array, alpha as Lang.Number, seed as Lang.Number) as Void {
        if (mBrushStamp == null) { return; }

        for (var i = 0; i < profile.size(); i += 3) {
            if (((seed + i) % 4) != 0) { continue; }
            var pt = profile[i];
            dc.drawBitmap(pt[0] - 10 + getJitter(seed + i, 4), pt[1] - 3 + getJitter(seed + i + 9, 4), mBrushStamp);
        }
    }

    function drawMistBand(dc as Graphics.Dc, width as Lang.Number, yCenter as Lang.Number, thickness as Lang.Number, alpha as Lang.Float, seed as Lang.Number) as Void {
        var a = (alpha * 255).toNumber();
        for (var i = 0; i < 9; i++) {
            var x = ((width * i) / 8) + getJitter(seed + i, 18) - 40;
            var y = yCenter + getJitter(seed + i + 11, 12);
            var w = 80 + ((i % 3) * 22);
            var h = thickness - ((i % 4) * 7);
            dc.setFill(Graphics.createColor(a / 3, 244, 241, 234));
            dc.fillEllipse(x, y - (h / 2), w, h);

            if (mMistStamp != null) {
                dc.drawBitmap(x + (w / 3), y - 16, mMistStamp);
            }
        }
    }

    function drawWaterLines(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        dc.setStroke(Graphics.createColor(22, 34, 28, 22));
        dc.setPenWidth(1);
        for (var i = 0; i < 10; i++) {
            var y = (height * 79) / 100 + (i * 6) + getJitter(seed + i, 2);
            var x1 = (width / 5) + getJitter(seed + i + 7, 18);
            var x2 = (width * 4) / 5 + getJitter(seed + i + 13, 18);
            dc.drawLine(x1, y, x2, y);
        }
    }

    function drawPaperGrain(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        dc.setStroke(Graphics.createColor(8, 140, 120, 90));
        dc.setPenWidth(1);
        for (var i = 0; i < 34; i++) {
            var x = ((seed * (i + 3) * 13) % width);
            var y = ((seed * (i + 5) * 17) % height);
            var len = 5 + (((seed + i) * 7) % 9);
            dc.drawLine(x, y, x + len, y + getJitter(seed + i + 21, 2));
        }
    }

    function getJitter(seed as Lang.Number, scale as Lang.Number) as Lang.Number {
        var pattern = [0, -3, 5, -2, 4, -6, 2, -1, 3, -4, 6, -3, 1];
        var s = seed;
        if (s < 0) { s = -s; }
        return (pattern[s % pattern.size()] * scale) / 6;
    }

}
