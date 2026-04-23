using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastSceneKey as Lang.Number = -1;

    var mNoiseTable as Lang.Array<Lang.Float>;
    const TABLE_SIZE = 128;

    var mVerticalFadeDescent;
    var mPaperTile as Graphics.BufferedBitmap?;
    var mWashTile as Graphics.BufferedBitmap?;
    var mDryBrushStamp as Graphics.BufferedBitmap?;
    var mMistStamp as Graphics.BufferedBitmap?;
    var mCrestStamp as Graphics.BufferedBitmap?;

    var mPaperTexture as Graphics.BitmapTexture?;
    var mWashTexture as Graphics.BitmapTexture?;

    const PAPER_TILE_SIZE = 48;
    const WASH_TILE_SIZE = 48;
    const DRY_BRUSH_W = 34;
    const DRY_BRUSH_H = 18;
    const MIST_STAMP_W = 110;
    const MIST_STAMP_H = 54;
    const CREST_SIZE = 30;

    function initialize() {
        loadAssets();

        mNoiseTable = new [TABLE_SIZE] as Lang.Array<Lang.Float>;
        for (var i = 0; i < TABLE_SIZE; i++) {
            mNoiseTable[i] = (Math.rand() % 1000).toFloat() / 1000.0;
        }

        createMaterials();
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
            renderScene(dc, dc.getWidth(), dc.getHeight(), getSceneKey());
            return;
        }

        var sceneKey = getSceneKey();
        if (sceneKey != mLastSceneKey) {
            renderBufferedScene(sceneKey);
        }

        var buffer = mBuffer;
        if (buffer != null) {
            dc.drawBitmap(0, 0, buffer);
        }
    }

    function getSceneKey() as Lang.Number {
        var clockTime = System.getClockTime();
        var minuteOfDay = (clockTime.hour * 60) + clockTime.min;
        return minuteOfDay / 20;
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
        mLastSceneKey = -1;
    }

    function createMaterials() as Void {
        if (!(Graphics has :createBufferedBitmap)) {
            return;
        }

        mPaperTile = Graphics.createBufferedBitmap({ :width => PAPER_TILE_SIZE, :height => PAPER_TILE_SIZE }).get() as Graphics.BufferedBitmap;
        mWashTile = Graphics.createBufferedBitmap({ :width => WASH_TILE_SIZE, :height => WASH_TILE_SIZE }).get() as Graphics.BufferedBitmap;
        mDryBrushStamp = Graphics.createBufferedBitmap({ :width => DRY_BRUSH_W, :height => DRY_BRUSH_H }).get() as Graphics.BufferedBitmap;
        mMistStamp = Graphics.createBufferedBitmap({ :width => MIST_STAMP_W, :height => MIST_STAMP_H }).get() as Graphics.BufferedBitmap;
        mCrestStamp = Graphics.createBufferedBitmap({ :width => CREST_SIZE, :height => CREST_SIZE }).get() as Graphics.BufferedBitmap;

        drawPaperTile();
        drawWashTile();
        drawDryBrushStamp();
        drawMistStamp();
        drawCrestStamp();

        if (Graphics has :BitmapTexture) {
            if (mPaperTile != null) {
                mPaperTexture = new Graphics.BitmapTexture({
                    :bitmap => mPaperTile,
                    :offsetX => 0,
                    :offsetY => 0
                });
            }
            if (mWashTile != null) {
                mWashTexture = new Graphics.BitmapTexture({
                    :bitmap => mWashTile,
                    :offsetX => 0,
                    :offsetY => 0
                });
            }
        }
    }

    function drawPaperTile() as Void {
        var tile = mPaperTile;
        if (tile == null) {
            return;
        }

        var dc = tile.getDc();
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        for (var i = 0; i < 14; i++) {
            var t = i.toFloat() / 14.0;
            var x = (fastNoise((t * 5.4) + 0.3, 11) * PAPER_TILE_SIZE.toFloat()).toNumber();
            var y = (fastNoise((t * 7.1) + 0.7, 19) * PAPER_TILE_SIZE.toFloat()).toNumber();
            var radius = 1 + (fastNoise((t * 9.0) + 0.4, 29) * 1.0).toNumber();
            dc.setFill(Graphics.createColor(2 + (i % 2), 126, 115, 99));
            dc.fillCircle(x, y, radius);
        }
    }

    function drawWashTile() as Void {
        var tile = mWashTile;
        if (tile == null) {
            return;
        }

        var dc = tile.getDc();
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        for (var i = 0; i < 40; i++) {
            var t = i.toFloat() / 40.0;
            var x = (fastNoise((t * 7.1) + 0.2, 41) * WASH_TILE_SIZE.toFloat()).toNumber();
            var y = (fastNoise((t * 8.6) + 0.7, 53) * WASH_TILE_SIZE.toFloat()).toNumber();
            var density = (fastNoise((t * 6.0) + 0.4, 59) * 0.6) + (fastNoise((t * 10.0) + 1.1, 61) * 0.4);
            var alpha = 2 + (density * 6.0).toNumber();
            var tone = 78 + (density * 10.0).toNumber();
            dc.setFill(Graphics.createColor(alpha, tone, tone - 4, tone - 10));
            dc.fillCircle(x, y, 1);
        }
    }

    function drawDryBrushStamp() as Void {
        var stamp = mDryBrushStamp;
        if (stamp == null) {
            return;
        }

        var dc = stamp.getDc();
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        for (var i = 0; i < 24; i++) {
            var t = i.toFloat() / 24.0;
            var x = 3 + (t * (DRY_BRUSH_W - 7)).toNumber();
            var y = (DRY_BRUSH_H / 2) + (signedNoise((t * 6.2) + 0.7, 61) * 4.0).toNumber();
            var r = 1 + (fastNoise((t * 9.4) + 0.2, 67) * 3.0).toNumber();
            var alpha = 18 + (fastNoise((t * 8.1) + 1.1, 71) * 40.0).toNumber();
            dc.setFill(Graphics.createColor(alpha, 38, 33, 29));
            dc.fillCircle(x, y, r);

            if ((i % 5) != 0) {
                dc.setFill(Graphics.createColor(alpha / 2, 70, 62, 54));
                dc.fillCircle(x, y + 1, 1);
            }
        }
    }

    function drawMistStamp() as Void {
        var stamp = mMistStamp;
        if (stamp == null) {
            return;
        }

        var dc = stamp.getDc();
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        for (var i = 0; i < 15; i++) {
            var t = i.toFloat() / 15.0;
            var x = (MIST_STAMP_W * (0.1 + (t * 0.8))).toNumber();
            var y = (MIST_STAMP_H / 2) + (signedNoise((t * 5.9) + 0.5, 83) * 10.0).toNumber();
            var rx = 12 + (fastNoise((t * 8.4) + 0.4, 89) * 20.0).toNumber();
            var ry = 6 + (fastNoise((t * 7.7) + 1.3, 97) * 10.0).toNumber();
            var alpha = 14 + (fastNoise((t * 6.5) + 0.6, 101) * 16.0).toNumber();
            dc.setFill(Graphics.createColor(alpha, 244, 240, 232));
            dc.fillEllipse(x, y, rx, ry);
            dc.setFill(Graphics.createColor(maxNum(6, alpha - 8), 250, 247, 241));
            dc.fillEllipse(x + 3, y, rx / 2, maxNum(3, ry / 2));
        }
    }

    function drawCrestStamp() as Void {
        var stamp = mCrestStamp;
        if (stamp == null) {
            return;
        }

        var dc = stamp.getDc();
        dc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
        dc.clear();

        for (var i = 0; i < 10; i++) {
            var x = 4 + (i * 2);
            var y = 10 + (signedNoise(i.toFloat() * 1.4, 109) * 4.0).toNumber();
            var radius = 2 + (i % 3);
            dc.setFill(Graphics.createColor(24 + (i * 2), 30, 25, 22));
            dc.fillCircle(x, y, radius);
        }

        dc.setFill(Graphics.createColor(14, 92, 82, 70));
        dc.fillEllipse(17, 12, 8, 3);
    }

    function renderBufferedScene(sceneKey as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) {
            return;
        }

        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight, sceneKey);
        mLastSceneKey = sceneKey;
    }

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        drawPaper(dc, width, height, seed);
        drawCelestial(dc, width, height, seed);

        var baseField = generateField(72, seed);
        var ghostField = smoothField(baseField, 4);
        var farField = smoothField(baseField, 3);
        var mainField = smoothField(baseField, 1);

        drawRangeBody(dc, ghostField, width, height, (height * 37) / 100, (height * 9) / 100, 0x0B9EA2A5, 0x065C6165, seed + 13, 0);
        drawMistCuts(dc, width, height, (height * 44) / 100, 1, seed + 19, 0.82);

        drawRangeBody(dc, farField, width, height, (height * 49) / 100, (height * 13) / 100, 0x17676662, 0x084E4E49, seed + 37, 1);
        drawMistCuts(dc, width, height, (height * 58) / 100, 1, seed + 43, 0.68);

        drawRangeBody(dc, mainField, width, height, (height * 58) / 100, (height * 26) / 100, 0x2B433C35, 0x0F322D28, seed + 59, 2);

        var anchors = pickAnchors(mainField, 2);
        drawSharedMountainMass(dc, anchors, mainField, width, height, (height * 60) / 100, (height * 24) / 100, seed + 71);
        drawHostRidgeBone(dc, anchors, mainField, width, height, (height * 60) / 100, (height * 24) / 100, seed + 89);
        drawGuestCrest(dc, anchors, mainField, width, height, (height * 60) / 100, (height * 24) / 100, seed + 103);
        drawRidgeBlots(dc, mainField, width, height, (height * 58) / 100, (height * 26) / 100, seed + 131);

        drawMistCuts(dc, width, height, (height * 83) / 100, 1, seed + 191, 0.34);
        drawPaperOverlay(dc, width, height, seed + 211);
    }

    function drawPaper(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        dc.setColor(0xF2EEE6, 0xF2EEE6);
        dc.clear();

        dc.setFill(Graphics.createColor(10, 255, 250, 244));
        dc.fillCircle((width * 26) / 100, (height * 18) / 100, (width * 15) / 100);

        dc.setFill(Graphics.createColor(7, 236, 228, 214));
        dc.fillEllipse((width * 69) / 100, (height * 72) / 100, (width * 23) / 100, (height * 10) / 100);

        if (mPaperTexture != null) {
            mPaperTexture.setOffset(seed % PAPER_TILE_SIZE, (seed * 3) % PAPER_TILE_SIZE);
            dc.setFill(mPaperTexture);
            dc.fillRectangle(0, 0, width, height);
        }
    }

    function drawCelestial(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        var clockTime = System.getClockTime();
        var minuteOfDay = (clockTime.hour * 60) + clockTime.min;
        var orbitT = minuteOfDay.toFloat() / 1440.0;
        var x = (width * 22) / 100 + ((width * 46) / 100 * orbitT).toNumber();
        var y = (height * 18) / 100 - (Math.sin(orbitT * 6.28318) * (height * 5) / 100).toNumber();

        dc.setFill(Graphics.createColor(10, 210, 196, 176));
        dc.fillCircle(x, y, 16);
        dc.setFill(Graphics.createColor(16, 242, 235, 223));
        dc.fillCircle(x, y, 10);
    }

    function drawRangeBody(
        dc as Graphics.Dc,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        bodyColor as Lang.Number,
        washColor as Lang.Number,
        seed as Lang.Number,
        layerIndex as Lang.Number
    ) as Void {
        var body = buildRangePolygon(field, width, height, baseY, amplitude, seed, 1.0);
        var wash = buildRangePolygon(field, width, height, baseY + 12, amplitude + 12, seed + 7, 0.8);

        fillPolygonWithMaterial(dc, wash, washColor, seed + (layerIndex * 7));
        fillPolygonWithMaterial(dc, body, bodyColor, seed + 17 + (layerIndex * 9));

        dc.setFill(Graphics.createColor(3, 255, 251, 246));
        dc.fillEllipse((width * 60) / 100, baseY + (amplitude / 3), (width * 8) / 100, (height * 2) / 100);
    }

    function drawSharedMountainMass(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Number>,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var hostIdx = anchors[0];
        var guestIdx = anchors.size() > 1 ? anchors[1] : minNum(field.size() - 1, hostIdx + 8);
        if (guestIdx < hostIdx) {
            var tmp = hostIdx;
            hostIdx = guestIdx;
            guestIdx = tmp;
        }

        hostIdx = maxNum(0, hostIdx - 3);
        guestIdx = minNum(field.size() - 1, guestIdx + 3);

        var upper = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;
        var lower = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;
        var hostT = hostIdx.toFloat() / (field.size() - 1).toFloat();
        var guestT = guestIdx.toFloat() / (field.size() - 1).toFloat();
        var valleyT = (hostT + guestT) / 2.0;

        for (var i = hostIdx; i <= guestIdx; i++) {
            var t = i.toFloat() / (field.size() - 1).toFloat();
            var x = (width.toFloat() * t).toNumber();
            var y = ridgeY(field, i, height, baseY, amplitude, seed);
            var hostLift = gaussian(t, hostT, 0.09) * 10.0;
            var guestDrop = gaussian(t, guestT, 0.11) * 4.0;
            var valleyDrop = gaussian(t, valleyT, 0.08) * 12.0;
            y = y - hostLift.toNumber() + guestDrop.toNumber() + valleyDrop.toNumber();
            upper.add([x, y] as [Lang.Numeric, Lang.Numeric]);

            var dipBias = gaussian(t, valleyT, 0.11) * 32.0;
            var shoulderBias = gaussian(t, hostT, 0.12) * 10.0;
            var lowerY = y + 34 + dipBias.toNumber() - shoulderBias.toNumber() + (signedNoise((t * 5.0) + 0.9, seed + 13) * 6.0).toNumber();
            lower.add([x, lowerY] as [Lang.Numeric, Lang.Numeric]);
        }

        var poly = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;
        for (var u = 0; u < upper.size(); u++) {
            poly.add(upper[u]);
        }
        for (var l = lower.size() - 1; l >= 0; l--) {
            poly.add(lower[l]);
        }

        fillPolygonWithMaterial(dc, poly, 0x1646413A, seed + 5);

        var washPoly = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;
        for (var wu = 0; wu < upper.size(); wu++) {
            var p = upper[wu];
            washPoly.add([p[0], p[1] + 8] as [Lang.Numeric, Lang.Numeric]);
        }
        for (var wl = lower.size() - 1; wl >= 0; wl--) {
            var q = lower[wl];
            washPoly.add([q[0], q[1] + 12] as [Lang.Numeric, Lang.Numeric]);
        }

        fillPolygonWithMaterial(dc, washPoly, 0x0C66615A, seed + 17);
    }

    function drawRidgeBlots(
        dc as Graphics.Dc,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var hostIdx = pickAnchors(field, 2)[0];
        var startIdx = maxNum(3, hostIdx - 12);
        var endIdx = minNum(field.size() - 4, hostIdx + 14);

        for (var i = startIdx; i <= endIdx; i += 3) {
            var t = i.toFloat() / (field.size() - 1).toFloat();
            var x = (width.toFloat() * t).toNumber();
            var y = ridgeY(field, i, height, baseY, amplitude, seed) - 2;
            var edgeSize = 6 + ((i - startIdx) % 3);
            var innerSize = maxNum(3, edgeSize - 3);

            dc.setFill(Graphics.createColor(16, 42, 38, 33));
            dc.fillEllipse(x, y, edgeSize, maxNum(3, edgeSize - 2));

            dc.setFill(Graphics.createColor(9, 118, 108, 95));
            dc.fillEllipse(x + 1, y, innerSize, maxNum(2, innerSize - 1));

            if ((i % 2) == 0) {
                dc.setFill(Graphics.createColor(7, 255, 252, 247));
                dc.fillEllipse(x + 3, y + 1, maxNum(2, innerSize - 1), 2);
            }
        }
    }

    function drawHostRidgeBone(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Number>,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Void {
        var hostIdx = anchors[0];
        var startIdx = maxNum(0, hostIdx - 6);
        var endIdx = minNum(field.size() - 1, hostIdx + 3);

        if (dc has :setPenWidth) {
            dc.setPenWidth(2);
        }
        dc.setColor(Graphics.createColor(28, 33, 29, 25), Graphics.COLOR_TRANSPARENT);

        for (var i = startIdx; i < endIdx; i++) {
            var t1 = i.toFloat() / (field.size() - 1).toFloat();
            var t2 = (i + 1).toFloat() / (field.size() - 1).toFloat();
            var x1 = (width.toFloat() * t1).toNumber() - (width * 11) / 100;
            var x2 = (width.toFloat() * t2).toNumber() - (width * 11) / 100;
            var y1 = ridgeY(field, i, height, baseY, amplitude, seed) - 7 - (i - startIdx);
            var y2 = ridgeY(field, i + 1, height, baseY, amplitude, seed) - 7 - (i + 1 - startIdx);
            dc.drawLine(x1, y1, x2, y2);
        }

        var hostX = ((hostIdx.toFloat() / (field.size() - 1).toFloat()) * width.toFloat()).toNumber() - (width * 7) / 100;
        var hostY = ridgeY(field, hostIdx, height, baseY, amplitude, seed) - 12;

        stampBitmap(dc, mCrestStamp, hostX - 34, hostY - 14, 66, 26);
        stampBitmap(dc, mDryBrushStamp, hostX - 42, hostY - 11, 82, 13);
        stampBitmap(dc, mDryBrushStamp, hostX - 22, hostY - 19, 42, 7);

        if (dc has :setPenWidth) {
            dc.setPenWidth(1);
        }
        dc.setColor(Graphics.createColor(18, 52, 46, 40), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(hostX - 12, hostY + 2, hostX + 7, hostY + 16);
    }

    function drawGuestCrest(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Number>,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Void {
        if (anchors.size() < 2) {
            return;
        }

        var guestIdx = anchors[1];
        var guestX = ((guestIdx.toFloat() / (field.size() - 1).toFloat()) * width.toFloat()).toNumber() + (width * 1) / 100;
        var guestY = ridgeY(field, guestIdx, height, baseY, amplitude, seed) - 6;

        stampBitmap(dc, mCrestStamp, guestX - 10, guestY - 8, 18, 14);
        stampBitmap(dc, mDryBrushStamp, guestX - 10, guestY - 4, 20, 6);
    }

    function drawAnchorMasses(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Number>,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Void {
        for (var i = 0; i < anchors.size(); i++) {
            var idx = anchors[i];
            var x = ((idx.toFloat() / (field.size() - 1).toFloat()) * width.toFloat()).toNumber();
            var topY = ridgeY(field, idx, height, baseY, amplitude, seed);
            var isHost = (i == 0);
            if (isHost) {
                x -= (width * 10) / 100;
            }
            var bodyWidth = isHost ? 62 : 24;
            var depth = isHost ? 118 : 48;

            drawSpineMass(dc, x + (isHost ? -6 : 5), topY + 12, bodyWidth + (isHost ? 20 : 6), depth + (isHost ? 20 : 10), isHost ? 0x0E575049 : 0x094D4842, seed + (i * 11), isHost ? 0.52 : 0.42);
            drawSpineMass(dc, x, topY, bodyWidth, depth, isHost ? 0x32403A34 : 0x163E3832, seed + (i * 17), isHost ? 0.18 : 0.16);
        }
    }

    function drawCrestAccents(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Number>,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Void {
        for (var i = 0; i < anchors.size(); i++) {
            var idx = anchors[i];
            var x = ((idx.toFloat() / (field.size() - 1).toFloat()) * width.toFloat()).toNumber();
            var y = ridgeY(field, idx, height, baseY, amplitude, seed) - 2;
            var isHost = (i == 0);
            if (isHost) {
                x -= (width * 10) / 100;
                y -= 8;
            }

            stampBitmap(dc, mCrestStamp, x - ((isHost ? 62 : 20) / 2), y - ((isHost ? 32 : 18) / 2), isHost ? 62 : 20, isHost ? 32 : 18);
            stampBitmap(dc, mDryBrushStamp, x - (isHost ? 38 : 12), y - (isHost ? 10 : 4), isHost ? 74 : 22, isHost ? 14 : 8);
            if (isHost) {
                stampBitmap(dc, mDryBrushStamp, x - 24, y - 18, 46, 8);
                dc.setColor(Graphics.createColor(26, 32, 28, 24), Graphics.COLOR_TRANSPARENT);
                if (dc has :setPenWidth) {
                    dc.setPenWidth(2);
                }
                dc.drawLine(x - 22, y - 4, x + 24, y - 12);
                dc.drawLine(x - 12, y - 1, x + 12, y + 2);
            }

            dc.setFill(Graphics.createColor(isHost ? 20 : 7, 36, 32, 28));
            dc.fillEllipse(x + (isHost ? 10 : 4), y + (isHost ? 1 : 3), isHost ? 20 : 8, isHost ? 4 : 3);
        }
    }

    function drawDescents(
        dc as Graphics.Dc,
        anchors as Lang.Array<Lang.Number>,
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Void {
        for (var i = 0; i < anchors.size(); i++) {
            var idx = anchors[i];
            var x = ((idx.toFloat() / (field.size() - 1).toFloat()) * width.toFloat()).toNumber();
            var topY = ridgeY(field, idx, height, baseY, amplitude, seed) + 10;
            var descent = mVerticalFadeDescent;
            var isHost = (i == 0);
            if (isHost) {
                x -= (width * 10) / 100;
            }

            if (descent != null) {
                var widthScale = isHost ? 28 : 14;
                var heightScale = isHost ? 78 : 42;
                stampBitmap(dc, descent, x - (widthScale / 2), topY - 4, widthScale, heightScale);
            }

            var count = isHost ? 1 : 1;
            for (var j = 0; j < count; j++) {
                var dx = (signedNoise((j * 2.7) + 0.6, seed + (i * 19)) * (isHost ? 9.0 : 5.0)).toNumber();
                var dy = isHost ? 24 : 18;
                stampBitmap(dc, mDryBrushStamp, x - (isHost ? 10 : 8) + dx, topY + dy, isHost ? 18 : 12, isHost ? 8 : 6);
            }
        }
    }

    function drawFrameMass(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, isLeft as Lang.Boolean, seed as Lang.Number) as Void {
        var field = smoothField(generateField(18, seed), 3);
        var frameWidth = (width * 18) / 100;
        var xStart = isLeft ? -18 : width - frameWidth + 18;
        var xEnd = isLeft ? frameWidth : width + 18;
        var poly = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;

        for (var i = 0; i < field.size(); i++) {
            var t = i.toFloat() / (field.size() - 1).toFloat();
            var x = xStart + ((xEnd - xStart).toFloat() * t).toNumber();
            var yBase = (height * (isLeft ? 69 : 71)) / 100;
            var y = yBase - (field[i] * (height * 8) / 100).toNumber() + (signedNoise((t * 5.2) + 0.5, seed + 7) * 4.0).toNumber();
            poly.add([x, y] as [Lang.Numeric, Lang.Numeric]);
        }

        if (isLeft) {
            poly.add([frameWidth + 10, height] as [Lang.Numeric, Lang.Numeric]);
            poly.add([-22, height] as [Lang.Numeric, Lang.Numeric]);
        } else {
            poly.add([width + 22, height] as [Lang.Numeric, Lang.Numeric]);
            poly.add([width - frameWidth - 10, height] as [Lang.Numeric, Lang.Numeric]);
        }

        fillPolygonWithMaterial(dc, poly, 0x0E4B443D, seed + 17);
    }

    function drawMistCuts(
        dc as Graphics.Dc,
        width as Lang.Number,
        height as Lang.Number,
        yCenter as Lang.Number,
        bandCount as Lang.Number,
        seed as Lang.Number,
        scale as Lang.Float
    ) as Void {
        var stamp = mMistStamp;
        if (stamp == null) {
            return;
        }

        for (var band = 0; band < bandCount; band++) {
            for (var i = 0; i < 2; i++) {
                var t = (i + 1).toFloat() / 3.0;
                var x = ((width.toFloat() * (0.22 + (t * 0.46))) + (signedNoise((t * 8.0) + band, seed + 3) * width.toFloat() * 0.12)).toNumber();
                var y = yCenter + (signedNoise((t * 5.7) + 0.2 + band, seed + 11) * 16.0 * scale).toNumber() + (band * 10);
                var stampW = ((132 + (i * 28)) * scale).toNumber();
                var stampH = ((48 + (band * 10)) * scale).toNumber();
                stampBitmap(dc, stamp, x - (stampW / 2), y - (stampH / 2), stampW, stampH);
            }
        }
    }

    function drawPaperOverlay(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, seed as Lang.Number) as Void {
        if (mPaperTexture != null) {
            mPaperTexture.setOffset((seed * 2) % PAPER_TILE_SIZE, (seed * 5) % PAPER_TILE_SIZE);
            dc.setFill(mPaperTexture);
            dc.fillRectangle(0, 0, width, height);
        }
    }

    function buildRangePolygon(
        field as Lang.Array<Lang.Float>,
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number,
        roughness as Lang.Float
    ) as Lang.Array<[Lang.Numeric, Lang.Numeric]> {
        var poly = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;

        for (var i = 0; i < field.size(); i++) {
            var t = i.toFloat() / (field.size() - 1).toFloat();
            var x = (width.toFloat() * t).toNumber();
            var y = baseY - (field[i] * amplitude.toFloat()).toNumber();
            y += (signedNoise((t * 4.6) + 0.2, seed + 5) * 7.0 * roughness).toNumber();
            poly.add([x, y] as [Lang.Numeric, Lang.Numeric]);
        }

        poly.add([width, height] as [Lang.Numeric, Lang.Numeric]);
        poly.add([0, height] as [Lang.Numeric, Lang.Numeric]);
        return poly;
    }

    function fillPolygonWithMaterial(
        dc as Graphics.Dc,
        poly as Lang.Array<[Lang.Numeric, Lang.Numeric]>,
        color as Lang.Number,
        seed as Lang.Number
    ) as Void {
        dc.setFill(color);
        dc.fillPolygon(poly);

        if (mWashTexture != null) {
            mWashTexture.setOffset(seed % WASH_TILE_SIZE, (seed * 3) % WASH_TILE_SIZE);
            dc.setFill(mWashTexture);
            dc.fillPolygon(poly);
        }
    }

    function drawSpineMass(
        dc as Graphics.Dc,
        x as Lang.Number,
        topY as Lang.Number,
        baseWidth as Lang.Number,
        depth as Lang.Number,
        color as Lang.Number,
        seed as Lang.Number,
        dissolveStrength as Lang.Float
    ) as Void {
        var steps = 12;
        var total = (steps + 1) * 2;
        var poly = new [total] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;

        for (var i = 0; i <= steps; i++) {
            var t = i.toFloat() / steps.toFloat();
            var curve = 0.24 + (0.94 * t) - (0.34 * t * t);
            var dissolve = 1.0;
            if (t > 0.62) {
                dissolve = 1.0 - (((t - 0.62) / 0.38) * dissolveStrength);
            }

            var widthFactor = maxFloat(0.18, curve * dissolve);
            var leftNoise = signedNoise((t * 5.0) + 0.3, seed + 5);
            var rightNoise = signedNoise((t * 5.7) + 0.9, seed + 11);
            var spread = baseWidth.toFloat() * widthFactor;
            var y = topY + (depth.toFloat() * t).toNumber() + (leftNoise * 6.0 * (0.2 + t)).toNumber();
            var leftX = x - spread.toNumber() - (leftNoise * 6.0 * (1.0 - (t * 0.3))).toNumber();
            var rightX = x + spread.toNumber() + (rightNoise * 6.0 * (1.0 - (t * 0.3))).toNumber();

            poly[i] = [leftX, y] as [Lang.Numeric, Lang.Numeric];
            poly[total - 1 - i] = [rightX, y] as [Lang.Numeric, Lang.Numeric];
        }

        fillPolygonWithMaterial(dc, poly, color, seed + 23);
    }

    function stampBitmap(
        dc as Graphics.Dc,
        bitmap,
        x as Lang.Number,
        y as Lang.Number,
        width as Lang.Number,
        height as Lang.Number
    ) as Void {
        if (bitmap == null) {
            return;
        }

        if (width <= 0 || height <= 0) {
            return;
        }

        dc.drawScaledBitmap(x, y, width, height, bitmap);
    }

    function generateField(count as Lang.Number, seed as Lang.Number) as Lang.Array<Lang.Float> {
        var base = getBaseSeries();
        var normalized = normalizeSeries(base);
        var field = [] as Lang.Array<Lang.Float>;

        for (var i = 0; i < count; i++) {
            var t = i.toFloat() / (count - 1).toFloat();
            var source = sampleSeries(normalized, t);
            var low = signedNoise((t * 2.1) + 0.4, seed + 7) * 0.06;
            var mid = signedNoise((t * 5.0) + 1.1, seed + 13) * 0.04;
            var host = gaussian(t, 0.34 + (fastNoise(0.5, seed + 17) * 0.08), 0.10) * 0.24;
            var guest = gaussian(t, 0.63 + (signedNoise(0.8, seed + 19) * 0.06), 0.12) * 0.18;
            var value = clamp01((source * 0.68) + host + guest + low + mid);
            field.add(value);
        }

        return field;
    }

    function getBaseSeries() as Lang.Array<Lang.Float> {
        return [
            68.0, 70.0, 69.0, 71.0, 74.0, 78.0, 76.0, 73.0,
            72.0, 74.0, 77.0, 81.0, 84.0, 83.0, 80.0, 76.0,
            74.0, 75.0, 79.0, 85.0, 92.0, 96.0, 90.0, 82.0,
            78.0, 76.0, 79.0, 87.0, 93.0, 95.0, 88.0, 81.0,
            77.0, 75.0, 76.0, 80.0, 86.0, 90.0, 89.0, 84.0,
            78.0, 74.0, 72.0, 71.0, 70.0, 72.0, 74.0, 73.0
        ] as Lang.Array<Lang.Float>;
    }

    function normalizeSeries(series as Lang.Array<Lang.Float>) as Lang.Array<Lang.Float> {
        var low = 9999.0;
        var high = -9999.0;
        var normalized = [] as Lang.Array<Lang.Float>;

        for (var i = 0; i < series.size(); i++) {
            if (series[i] < low) {
                low = series[i];
            }
            if (series[i] > high) {
                high = series[i];
            }
        }

        var span = maxFloat(1.0, high - low);
        for (var j = 0; j < series.size(); j++) {
            normalized.add((series[j] - low) / span);
        }
        return normalized;
    }

    function sampleSeries(series as Lang.Array<Lang.Float>, t as Lang.Float) as Lang.Float {
        var pos = t * (series.size() - 1).toFloat();
        var idx = Math.floor(pos).toNumber();
        var next = minNum(series.size() - 1, idx + 1);
        var frac = pos - idx.toFloat();
        return series[idx] + ((series[next] - series[idx]) * frac);
    }

    function smoothField(field as Lang.Array<Lang.Float>, radius as Lang.Number) as Lang.Array<Lang.Float> {
        var out = [] as Lang.Array<Lang.Float>;

        for (var i = 0; i < field.size(); i++) {
            var total = 0.0;
            var weightTotal = 0.0;
            for (var j = -radius; j <= radius; j++) {
                var idx = clampIndex(i + j, field.size());
                var weight = (radius + 1 - j.abs()).toFloat();
                total += field[idx] * weight;
                weightTotal += weight;
            }
            out.add(total / maxFloat(1.0, weightTotal));
        }

        return out;
    }

    function pickAnchors(field as Lang.Array<Lang.Float>, desired as Lang.Number) as Lang.Array<Lang.Number> {
        var scores = [] as Lang.Array<Lang.Array<Lang.Float>>;

        for (var i = 2; i < field.size() - 2; i++) {
            var center = field[i];
            var t = i.toFloat() / (field.size() - 1).toFloat();
            var prominence = center - ((field[i - 2] + field[i + 2]) / 2.0);
            var bias = gaussian(t, 0.38, 0.18) * 0.18;
            scores.add([i.toFloat(), prominence + center + bias] as Lang.Array<Lang.Float>);
        }

        var selected = [] as Lang.Array<Lang.Number>;
        for (var pick = 0; pick < desired; pick++) {
            var bestIdx = -1;
            var bestScore = -999.0;
            for (var j = 0; j < scores.size(); j++) {
                var candidate = scores[j][0].toNumber();
                if (isTooClose(candidate, selected, 5)) {
                    continue;
                }
                if (scores[j][1] > bestScore) {
                    bestScore = scores[j][1];
                    bestIdx = candidate;
                }
            }

            if (bestIdx >= 0) {
                selected.add(bestIdx);
            }
        }

        if (selected.size() == 0) {
            selected.add(field.size() / 2);
        }

        return selected;
    }

    function ridgeY(
        field as Lang.Array<Lang.Float>,
        idx as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        seed as Lang.Number
    ) as Lang.Number {
        var t = idx.toFloat() / (field.size() - 1).toFloat();
        return baseY - (field[idx] * amplitude.toFloat()).toNumber() + (signedNoise((t * 4.6) + 0.2, seed + 5) * 7.0).toNumber();
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

    function gaussian(x as Lang.Float, mean as Lang.Float, sigma as Lang.Float) as Lang.Float {
        var d = x - mean;
        var scaled = (d * d) / maxFloat(0.0001, sigma * sigma);
        return 1.0 / (1.0 + (scaled * 2.6));
    }

    function clamp01(value as Lang.Float) as Lang.Float {
        if (value < 0.0) {
            return 0.0;
        }
        if (value > 1.0) {
            return 1.0;
        }
        return value;
    }

    function clampIndex(value as Lang.Number, size as Lang.Number) as Lang.Number {
        if (value < 0) {
            return 0;
        }
        if (value >= size) {
            return size - 1;
        }
        return value;
    }

    function isTooClose(candidate as Lang.Number, selected as Lang.Array<Lang.Number>, spacing as Lang.Number) as Lang.Boolean {
        for (var i = 0; i < selected.size(); i++) {
            if ((candidate - selected[i]).abs() < spacing) {
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

    function maxNum(a as Lang.Number, b as Lang.Number) as Lang.Number {
        if (a > b) {
            return a;
        }
        return b;
    }

    function minNum(a as Lang.Number, b as Lang.Number) as Lang.Number {
        if (a < b) {
            return a;
        }
        return b;
    }
}
