using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastMinuteKey as Lang.Number = -1;

    var mNoiseTable as Lang.Array<Lang.Float>;
    const TABLE_SIZE = 64;

    var mCrestStamp as Graphics.BufferedBitmap?;
    var mVerticalFadeDescent;

    const CREST_SIZE = 26;

    function initialize() {
        loadAssets();
        createStamps();

        mNoiseTable = new [TABLE_SIZE] as Lang.Array<Lang.Float>;
        for (var i = 0; i < TABLE_SIZE; i++) {
            mNoiseTable[i] = (Math.rand() % 1000).toFloat() / 1000.0;
        }
    }

    function loadAssets() as Void {
        if (WatchUi has :loadResource) {
            mVerticalFadeDescent = WatchUi.loadResource(Rez.Drawables.VerticalFadeDescentTuned);
        }
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
        if (!(Graphics has :createBufferedBitmap)) {
            return;
        }

        var options = { :width => CREST_SIZE, :height => CREST_SIZE };
        mCrestStamp = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;

        var crestStamp = mCrestStamp;
        if (crestStamp == null) {
            return;
        }

        var stampDc = crestStamp.getDc();
        stampDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        stampDc.clear();

        stampDc.setFill(Graphics.createColor(32, 24, 22, 20));
        stampDc.fillEllipse(4, 10, 16, 8);
        stampDc.fillEllipse(9, 6, 10, 5);
        stampDc.fillEllipse(13, 12, 8, 6);

        stampDc.setFill(Graphics.createColor(14, 58, 49, 41));
        stampDc.fillEllipse(6, 11, 10, 5);
    }

    function renderBufferedScene(minuteKey as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) {
            return;
        }

        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight, minuteKey);
        mLastMinuteKey = minuteKey;
    }

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        drawPaper(dc, width, height, seed);
        drawCelestial(dc, width, height, seed);

        // Background / Ghost Range: Very soft, many anchors for a distant horizon feel
        var ghostAnchors = buildAnchors(4, width, 40, width - 40, (height * 34) / 100, (height * 7) / 100, 12, 48, seed + 41);
        drawRangeWash(dc, ghostAnchors, height, 11, 132, 137, 144, seed + 49);
        drawInkLayer(dc, ghostAnchors, 102, 108, 116, 9, false, 0, seed + 55);

        drawMistErasure(dc, width, (height * 44) / 100, 8, 58, 20, 24, seed + 81);

        // Far Range: More defined, fewer anchors to start building hierarchy
        var farAnchors = buildAnchors(3, width, 32, width - 32, (height * 45) / 100, (height * 10) / 100, 14, 78, seed + 101);
        drawRangeWash(dc, farAnchors, height, 14, 106, 110, 116, seed + 111);
        drawInkLayer(dc, farAnchors, 86, 89, 94, 13, false, 1, seed + 121);

        drawMistErasure(dc, width, (height * 55) / 100, 9, 66, 22, 32, seed + 161);

        // Main Range: The core subject. Large variance, selective crest budget.
        var mainAnchors = buildAnchors(3, width, 45, width - 45, (height * 49) / 100, (height * 14) / 100, 18, 122, seed + 201);
        drawRangeWash(dc, mainAnchors, height, 20, 94, 86, 74, seed + 211);
        drawInkLayer(dc, mainAnchors, 58, 51, 43, 19, true, 1, seed + 221);

        // Heavy mist to clear the base of the main range and keep time window open
        drawMistErasure(dc, width, (height * 68) / 100, 9, 74, 25, 42, seed + 281);
        drawMistErasure(dc, width, (height * 76) / 100, 7, 56, 21, 32, seed + 321);

        // Framing: Selective, quiet masses on the edges
        var leftFrame = buildAnchors(2, width, -30, (width * 32) / 100, (height * 64) / 100, (height * 8) / 100, 24, 158, seed + 401);
        drawRangeWash(dc, leftFrame, height, 18, 78, 70, 62, seed + 421);
        drawInkLayer(dc, leftFrame, 33, 27, 22, 22, true, 1, seed + 431);

        var rightFrame = buildAnchors(2, width, (width * 68) / 100, width + 30, (height * 67) / 100, (height * 7) / 100, 22, 146, seed + 461);
        drawRangeWash(dc, rightFrame, height, 16, 76, 68, 60, seed + 481);
        drawInkLayer(dc, rightFrame, 33, 27, 22, 20, true, 1, seed + 491);

        drawMistErasure(dc, width, (height * 82) / 100, 6, 50, 17, 24, seed + 551);
        drawPaperGrain(dc, width, height, seed + 701);
    }

    function drawPaper(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        dc.setColor(0xF4F1EA, 0xF4F1EA);
        dc.clear();

        dc.setFill(Graphics.createColor(18, 250, 245, 236));
        dc.fillEllipse(-20, -12, (width * 3) / 4, (height * 2) / 5);

        dc.setFill(Graphics.createColor(10, 233, 226, 214));
        dc.fillEllipse((width * 34) / 100, (height * 68) / 100, (width * 3) / 4, (height * 22) / 100);

        dc.setFill(Graphics.createColor(6, 214, 200, 176));
        dc.fillEllipse((width * 4) / 100, (height * 6) / 100, (width * 84) / 100, (height * 12) / 100);
    }

    function drawCelestial(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var clockTime = System.getClockTime();
        var minuteOfDay = (clockTime.hour * 60) + clockTime.min;
        var orbitX = (width * 18) / 100 + ((minuteOfDay * (width * 62)) / 1440);
        var orbitT = minuteOfDay.toFloat() / 1440.0;
        var arcOffset = Math.sin(orbitT * 6.28318);
        var orbitY = (height * 15) / 100 - (arcOffset * (height * 6) / 100).toNumber();

        dc.setFill(Graphics.createColor(12, 220, 201, 174));
        dc.fillEllipse(orbitX - 12, orbitY - 12, 24, 24);

        dc.setFill(Graphics.createColor(22, 244, 239, 231));
        dc.fillEllipse(orbitX - 8, orbitY - 8, 16, 16);
    }

    function buildAnchors(
        count as Lang.Number,
        width as Lang.Number,
        xMin as Lang.Number,
        xMax as Lang.Number,
        topBase as Lang.Number,
        topVariance as Lang.Number,
        widthBase as Lang.Number,
        depthBase as Lang.Number,
        seed as Lang.Number
    ) as Lang.Array<Lang.Array<Lang.Float>> {
        var anchors = [] as Lang.Array<Lang.Array<Lang.Float>>;
        var span = (xMax - xMin).toFloat();

        for (var i = 0; i < count; i++) {
            var t = (i + 1).toFloat() / (count + 1).toFloat();
            var x = xMin.toFloat() + (span * t) + (signedNoise((t * 6.1) + 0.3, seed + 5) * span * 0.08);
            var topY = topBase.toFloat() + (signedNoise((t * 8.4) + 0.7, seed + 13) * topVariance.toFloat());
            var baseWidth = widthBase.toFloat() * (0.82 + (fastNoise((t * 5.0) + 1.1, seed + 21) * 0.72));
            var depth = depthBase.toFloat() * (0.84 + (fastNoise((t * 4.4) + 0.9, seed + 29) * 0.72));
            var emphasis = 0.35 + (fastNoise((t * 7.3) + 1.9, seed + 37) * 0.65);
            anchors.add([x, topY, baseWidth, depth, emphasis] as Lang.Array<Lang.Float>);
        }

        return anchors;
    }

    function drawInkLayer(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Array<Lang.Float>>,
        r as Lang.Number,
        g as Lang.Number,
        b as Lang.Number,
        alphaMax as Lang.Number,
        useDescents as Lang.Boolean,
        crestBudget as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var accentIndices = getAccentIndices(anchors, crestBudget);

        for (var i = 0; i < anchors.size(); i++) {
            var anchor = anchors[i];
            var x = anchor[0].toNumber();
            var topY = anchor[1].toNumber();
            var baseWidth = anchor[2].toNumber();
            var depth = anchor[3].toNumber();
            var emphasis = anchor[4];
            var isAccent = isIndexSelected(accentIndices, i);

            // Subordinate non-accent anchors more heavily
            var weight = isAccent ? 1.0 : 0.65;
            var bodyAlpha = (alphaMax.toFloat() * weight).toNumber() + ((emphasis * 4.0).toNumber());
            var washAlpha = maxNum(4, bodyAlpha - 11);

            // Slightly wider, softer secondary wash for body integration
            drawSpineShape(dc, x, topY + 6, baseWidth + 12, depth + 22, washAlpha, clampColor(r + 36), clampColor(g + 36), clampColor(b + 38), seed + (i * 17), 0.75);
            drawSpineShape(dc, x, topY, baseWidth, depth, bodyAlpha, r, g, b, seed + (i * 23), 0.45);

            if (isAccent) {
                drawCrestAccent(dc, x, topY - 3, seed + (i * 31), clampColor(r - 12), clampColor(g - 12), clampColor(b - 11));
            }

            // Only use descents on the most dominant anchors
            if (useDescents && isAccent && emphasis > 0.7) {
                drawDescentTrail(dc, x, topY + 8, depth, seed + (i * 41), emphasis);
            }

            if (isAccent || emphasis > 0.85) {
                drawInkBleed(dc, x, topY + 2, baseWidth, seed + (i * 43), clampColor(r - 8), clampColor(g - 8), clampColor(b - 8));
            }
        }
    }

    function drawRangeWash(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Array<Lang.Float>>,
        height as Lang.Number,
        alphaBase as Lang.Number,
        r as Lang.Number,
        g as Lang.Number,
        b as Lang.Number,
        seed as Lang.Number
    ) as Void {
        if (anchors.size() == 0) {
            return;
        }

        for (var layer = 0; layer < 3; layer++) {
            var alpha = maxNum(4, alphaBase - (layer * 6));
            var yOffset = layer * 12;
            var poly = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;
            
            var first = anchors[0];
            var last = anchors[anchors.size() - 1];
            
            // Asymmetrical shoulder starts
            var firstShoulderX = first[0].toNumber() - (first[2].toNumber() * (22 + layer)) / 10;
            var firstShoulderY = first[1].toNumber() + (first[3].toNumber() * (55 + (layer * 4))) / 100 + yOffset;
            poly.add([firstShoulderX, firstShoulderY] as [Lang.Numeric, Lang.Numeric]);

            for (var i = 0; i < anchors.size(); i++) {
                var anchor = anchors[i];
                var peakX = anchor[0].toNumber();
                var peakY = anchor[1].toNumber() + (anchor[3].toNumber() * (15 + (layer * 5))) / 100 + yOffset;
                
                // Add a "shoulder" before the peak for more ridge-like shape
                if (i > 0) {
                    var prev = anchors[i-1];
                    var sX = (prev[0].toNumber() * 3 + peakX) / 4;
                    var sY = (prev[1].toNumber() + peakY) / 2 + 5;
                    poly.add([sX, sY] as [Lang.Numeric, Lang.Numeric]);
                }

                poly.add([peakX, peakY] as [Lang.Numeric, Lang.Numeric]);

                if (i < anchors.size() - 1) {
                    var next = anchors[i + 1];
                    var midX = (peakX + next[0].toNumber()) / 2;
                    var midY = (peakY + next[1].toNumber() + (next[3].toNumber() * (20 + (layer * 5))) / 100 + yOffset) / 2;
                    
                    // Deeper, more organic sag between peaks
                    var sagMult = 12 + (layer * 4);
                    var sag = (sagMult.toFloat() * (1.2 + signedNoise((i * 2.1) + layer + 0.5, seed + 17))).toNumber();
                    poly.add([midX, midY + sag] as [Lang.Numeric, Lang.Numeric]);
                }
            }

            var lastShoulderX = last[0].toNumber() + (last[2].toNumber() * (22 + layer)) / 10;
            var lastShoulderY = last[1].toNumber() + (last[3].toNumber() * (55 + (layer * 4))) / 100 + yOffset;
            poly.add([lastShoulderX, lastShoulderY] as [Lang.Numeric, Lang.Numeric]);
            
            // Ground the polygon
            poly.add([lastShoulderX, height] as [Lang.Numeric, Lang.Numeric]);
            poly.add([firstShoulderX, height] as [Lang.Numeric, Lang.Numeric]);

            dc.setFill(Graphics.createColor(alpha, r, g, b));
            dc.fillPolygon(poly);
        }
    }

    function drawSpineShape(
        dc as Graphics.Dc,
        x as Lang.Number,
        topY as Lang.Number,
        baseWidth as Lang.Number,
        depth as Lang.Number,
        alpha as Lang.Number,
        r as Lang.Number,
        g as Lang.Number,
        b as Lang.Number,
        seed as Lang.Number,
        dissolveStrength as Lang.Float
    ) as Void {
        var steps = 11;
        var total = (steps + 1) * 2;
        var poly = new [total] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;

        for (var i = 0; i <= steps; i++) {
            var t = i.toFloat() / steps.toFloat();
            var curve = 0.26 + (1.02 * t) - (0.40 * t * t);
            var dissolve = 1.0;
            if (t > 0.68) {
                dissolve = 1.0 - (((t - 0.68) / 0.32) * dissolveStrength);
            }
            var widthFactor = maxFloat(0.22, curve * dissolve);
            var leftNoise = signedNoise((t * 4.9) + (x.toFloat() * 0.011), seed + 5);
            var rightNoise = signedNoise((t * 5.6) + (x.toFloat() * 0.013), seed + 11);
            var spread = baseWidth.toFloat() * widthFactor;
            var y = topY + ((depth.toFloat() * t) + (leftNoise * 6.0 * (0.28 + t))).toNumber();
            var leftX = x - spread.toNumber() - (leftNoise * 5.0 * (1.0 - (t * 0.35))).toNumber();
            var rightX = x + spread.toNumber() + (rightNoise * 5.0 * (1.0 - (t * 0.35))).toNumber();

            poly[i] = [leftX, y] as [Lang.Numeric, Lang.Numeric];
            poly[total - 1 - i] = [rightX, y] as [Lang.Numeric, Lang.Numeric];
        }

        dc.setFill(Graphics.createColor(alpha, r, g, b));
        dc.fillPolygon(poly);
    }

    function drawCrestAccent(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, seed as Lang.Number, r as Lang.Number, g as Lang.Number, b as Lang.Number) as Void {
        var crestStamp = mCrestStamp;
        if (crestStamp != null) {
            dc.drawBitmap(x - (CREST_SIZE / 2), y - (CREST_SIZE / 2), crestStamp);
        }

        dc.setFill(Graphics.createColor(18, r, g, b));
        dc.fillEllipse(x - 7, y - 1, 14, 5);
        dc.fillEllipse(x - 4, y - 4, 9, 4);
    }

    function drawDescentTrail(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, depth as Lang.Number, seed as Lang.Number, emphasis as Lang.Float) as Void {
        var descent = mVerticalFadeDescent;
        if (descent != null) {
            var halfWidth = 16;
            if (descent has :getWidth) {
                halfWidth = descent.getWidth() / 2;
            }

            var copies = 1 + ((emphasis * 2.0).toNumber());
            for (var i = 0; i < copies; i++) {
                var dx = (signedNoise((i * 1.9) + 0.7, seed + 7) * 11.0).toNumber();
                var dy = (i * 12) + (fastNoise((i * 1.7) + 0.5, seed + 13) * 8.0).toNumber();
                dc.drawBitmap(x - halfWidth + dx, y + dy, descent);
            }
        }

        dc.setFill(Graphics.createColor(10, 88, 79, 68));
        for (var j = 0; j < 3; j++) {
            var blobY = y + (depth / 4) + (j * 12) + (fastNoise((j * 2.2) + 0.4, seed + 21) * 8.0).toNumber();
            var blobX = x + (signedNoise((j * 2.8) + 0.9, seed + 27) * 9.0).toNumber();
            dc.fillEllipse(blobX - 6, blobY - 4, 12, 8);
        }
    }

    function drawInkBleed(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, width as Lang.Number, seed as Lang.Number, r as Lang.Number, g as Lang.Number, b as Lang.Number) as Void {
        dc.setFill(Graphics.createColor(8, r, g, b));
        for (var i = 0; i < 4; i++) {
            var dx = (signedNoise((i * 2.7) + 0.3, seed + 5) * width.toFloat() * 0.35).toNumber();
            var dy = (fastNoise((i * 1.9) + 0.4, seed + 17) * 8.0).toNumber();
            var rw = 3 + (fastNoise((i * 1.3) + 0.8, seed + 29) * 4.0).toNumber();
            var rh = 4 + (fastNoise((i * 1.7) + 1.2, seed + 41) * 6.0).toNumber();
            dc.fillEllipse(x + dx - rw, y + dy - rh, rw * 2, rh * 2);
        }
    }

    function drawMistErasure(
        dc as Graphics.Dc,
        width as Lang.Number,
        yCenter as Lang.Number,
        puffCount as Lang.Number,
        radiusXBase as Lang.Number,
        radiusYBase as Lang.Number,
        alphaBase as Lang.Number,
        seed as Lang.Number
    ) as Void {
        for (var i = 0; i < puffCount; i++) {
            var t = (i + 1).toFloat() / (puffCount + 1).toFloat();
            var x = ((width.toFloat() * t) + (signedNoise((t * 8.2) + 0.9, seed + 5) * width.toFloat() * 0.09)).toNumber();
            var y = yCenter + (signedNoise((t * 6.7) + 0.4, seed + 13) * radiusYBase.toFloat() * 0.8).toNumber();
            var rw = (radiusXBase.toFloat() * (0.64 + (fastNoise((t * 9.0) + 0.7, seed + 21) * 1.08))).toNumber();
            var rh = (radiusYBase.toFloat() * (0.56 + (fastNoise((t * 7.3) + 1.1, seed + 29) * 0.84))).toNumber();
            var alpha = alphaBase + (fastNoise((t * 5.8) + 1.7, seed + 37) * 10.0).toNumber();

            dc.setFill(Graphics.createColor(alpha, 244, 241, 234));
            dc.fillEllipse(x - rw, y - rh, rw * 2, rh * 2);

            dc.setFill(Graphics.createColor(maxNum(8, alpha - 8), 248, 245, 239));
            dc.fillEllipse(x - (rw / 2), y - (rh / 2), rw, rh);
        }
    }

    function drawPaperGrain(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        dc.setColor(Graphics.createColor(10, 166, 152, 126), Graphics.COLOR_TRANSPARENT);

        for (var i = 0; i < 30; i++) {
            var t = i.toFloat() / 30.0;
            var x = (fastNoise((t * 7.0) + 0.3, seed + 5) * width.toFloat()).toNumber();
            var y = (fastNoise((t * 9.0) + 0.6, seed + 11) * height.toFloat()).toNumber();
            var len = 3 + (fastNoise((t * 11.0) + 1.0, seed + 17) * 10.0).toNumber();
            var dy = (signedNoise((t * 8.0) + 1.4, seed + 23) * 2.0).toNumber();
            dc.drawLine(x, y, x + len, y + dy);
        }
    }

    function fastNoise(x as Lang.Float, seed as Lang.Number) as Lang.Float {
        var i = Math.floor(x).toNumber();
        var f = x - i.toFloat();
        var idx1 = (i + seed).abs() % TABLE_SIZE;
        var idx2 = (idx1 + 1) % TABLE_SIZE;
        var a = mNoiseTable[idx1];
        var b = mNoiseTable[idx2];
        return a + ((b - a) * (f * f * (3.0 - (2.0 * f))));
    }

    function signedNoise(x as Lang.Float, seed as Lang.Number) as Lang.Float {
        return (fastNoise(x, seed) * 2.0) - 1.0;
    }

    function clampColor(value as Lang.Number) as Lang.Number {
        if (value < 0) {
            return 0;
        }
        if (value > 255) {
            return 255;
        }
        return value;
    }

    function maxNum(a as Lang.Number, b as Lang.Number) as Lang.Number {
        if (a > b) {
            return a;
        }
        return b;
    }

    function getAccentIndices(anchors as Lang.Array<Lang.Array<Lang.Float>>, crestBudget as Lang.Number) as Lang.Array<Lang.Number> {
        var selected = [] as Lang.Array<Lang.Number>;
        if (crestBudget <= 0) {
            return selected;
        }

        for (var pick = 0; pick < crestBudget; pick++) {
            var bestIndex = -1;
            var bestScore = -1.0;

            for (var i = 0; i < anchors.size(); i++) {
                if (isIndexSelected(selected, i)) {
                    continue;
                }

                var anchor = anchors[i];
                var score = anchor[4] - (anchor[1] / 1000.0);
                if (score > bestScore) {
                    bestScore = score;
                    bestIndex = i;
                }
            }

            if (bestIndex >= 0) {
                selected.add(bestIndex);
            }
        }

        return selected;
    }

    function isIndexSelected(indices as Lang.Array<Lang.Number>, target as Lang.Number) as Lang.Boolean {
        for (var i = 0; i < indices.size(); i++) {
            if (indices[i] == target) {
                return true;
            }
        }
        return false;
    }

    function maxFloat(a as Lang.Float, b as Lang.Float) as Lang.Float {
        if (a > b) {
            return a;
        }
        return b;
    }

}
