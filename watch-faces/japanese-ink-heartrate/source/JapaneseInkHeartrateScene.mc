using Toybox.ActivityMonitor;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

// 2026-06-10 rewrite — complete-painting asset grammar.
//
// Every prior procedural attempt failed because Garmin's Dc has no gradients
// or blur, so runtime composition of primitives always exposed the primitive.
// The fix: each mountain is authored OFFLINE as a finished sumi-e painting
// (facet shading, dry-brush streaks, flying-white ridge gaps, crowning pines,
// mist-dissolved base all baked into PNG alpha by scripts/gen_sumie_kit.py).
// This file only PLACES those paintings, driven by the HR peak descriptor.
//
// Layout numbers are ported 1:1 from scripts/compose_preview.py, which mocks
// this exact recipe at 416x416. Iterate there first; it is far faster.

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastSceneKey as Lang.Number = -1;

    var mHost;
    var mGuest;
    var mFarRange;
    var mMist;
    var mMistLite;
    var mShore;
    var mPaperGrain;

    // HR peak descriptor cache. Each element is [nx, h, s] — normalized x
    // position, normalized height, spread. Sorted descending by h so
    // index 0 = host (dominant), index 1 = guest.
    var mPeaks as Lang.Array<Lang.Array<Lang.Float>>?;

    const HR_MIN = 45.0;
    const HR_MAX = 160.0;

    // Asset native dimensions (must match gen_sumie_kit.py outputs).
    const HOST_W = 320.0;
    const HOST_H = 290.0;
    const HOST_APEX_FRAC = 0.49375;   // main tower x within host bitmap
    const GUEST_W = 250.0;
    const GUEST_H = 210.0;
    const GUEST_APEX_FRAC = 0.40;

    function initialize() {
        if (WatchUi has :loadResource) {
            mHost = WatchUi.loadResource(Rez.Drawables.HostMountainTuned);
            mGuest = WatchUi.loadResource(Rez.Drawables.GuestMountainTuned);
            mFarRange = WatchUi.loadResource(Rez.Drawables.FarRangeTuned);
            mMist = WatchUi.loadResource(Rez.Drawables.MistBandTuned);
            mMistLite = WatchUi.loadResource(Rez.Drawables.MistBandLiteTuned);
            mShore = WatchUi.loadResource(Rez.Drawables.ShoreForegroundTuned);
            mPaperGrain = WatchUi.loadResource(Rez.Drawables.PaperGrainTuned);
        }
        mPeaks = computePeaks();
    }

    // ------------------------------------------------------------- HR data

    // Deterministic 48-sample mock (~4h at 5-min spacing) used when the
    // device/simulator has no usable HR history.
    function generateMockHR() as Lang.Array<Lang.Float> {
        return [
            72.0, 74.0, 76.0, 78.0, 82.0, 88.0, 95.0, 105.0,
            112.0, 108.0, 100.0, 92.0, 85.0, 80.0, 77.0, 75.0,
            73.0, 72.0, 74.0, 78.0, 84.0, 92.0, 102.0, 115.0,
            128.0, 135.0, 130.0, 120.0, 108.0, 95.0, 85.0, 78.0,
            74.0, 72.0, 70.0, 71.0, 73.0, 76.0, 79.0, 82.0,
            85.0, 90.0, 96.0, 102.0, 108.0, 110.0, 105.0, 98.0
        ] as Lang.Array<Lang.Float>;
    }

    function smoothHR(data as Lang.Array<Lang.Float>, windowSize as Lang.Number) as Lang.Array<Lang.Float> {
        var out = [] as Lang.Array<Lang.Float>;
        var half = windowSize / 2;
        var n = data.size();
        for (var i = 0; i < n; i++) {
            var lo = i - half;
            if (lo < 0) { lo = 0; }
            var hi = i + half;
            if (hi >= n) { hi = n - 1; }
            var sum = 0.0;
            var count = 0;
            for (var j = lo; j <= hi; j++) {
                sum += data[j];
                count++;
            }
            out.add(sum / count.toFloat());
        }
        return out;
    }

    function hrToPeaks(data as Lang.Array<Lang.Float>, count as Lang.Number) as Lang.Array<Lang.Array<Lang.Float>> {
        var peaks = [] as Lang.Array<Lang.Array<Lang.Float>>;
        var size = data.size();
        for (var i = 0; i < count; i++) {
            var t = (i + 0.5) / count.toFloat();
            var idx = (t * (size - 1).toFloat()).toNumber();
            if (idx < 0) { idx = 0; }
            if (idx >= size) { idx = size - 1; }
            var raw = data[idx];
            if (raw < HR_MIN) { raw = HR_MIN; }
            if (raw > HR_MAX) { raw = HR_MAX; }
            var hrNorm = (raw - HR_MIN) / (HR_MAX - HR_MIN);
            var h = 0.35 + hrNorm * 0.65;
            peaks.add([t, h, 0.15] as Lang.Array<Lang.Float>);
        }
        return peaks;
    }

    function sortPeaksByHeight(peaks as Lang.Array<Lang.Array<Lang.Float>>) as Lang.Array<Lang.Array<Lang.Float>> {
        var out = [] as Lang.Array<Lang.Array<Lang.Float>>;
        for (var i = 0; i < peaks.size(); i++) { out.add(peaks[i]); }
        for (var i = 0; i < out.size() - 1; i++) {
            var maxIdx = i;
            for (var j = i + 1; j < out.size(); j++) {
                if (out[j][1] > out[maxIdx][1]) { maxIdx = j; }
            }
            if (maxIdx != i) {
                var tmp = out[i];
                out[i] = out[maxIdx];
                out[maxIdx] = tmp;
            }
        }
        return out;
    }

    function fetchRealHR() as Lang.Array<Lang.Float>? {
        if (!(Toybox has :ActivityMonitor)) {
            return null;
        }
        if (!(ActivityMonitor has :getHeartRateHistory)) {
            return null;
        }

        var period = new Time.Duration(4 * 3600);
        var iterator = null;
        try {
            iterator = ActivityMonitor.getHeartRateHistory(period, false);
        } catch (ex) {
            return null;
        }
        if (iterator == null) {
            return null;
        }

        var samples = [] as Lang.Array<Lang.Float>;
        var sample = iterator.next();
        while (sample != null) {
            var hr = sample.heartRate;
            if (hr != ActivityMonitor.INVALID_HR_SAMPLE && hr > 0) {
                samples.add(hr.toFloat());
            }
            sample = iterator.next();
        }
        if (samples.size() < 8) {
            return null;
        }
        return samples;
    }

    function computePeaks() as Lang.Array<Lang.Array<Lang.Float>> {
        var hr = fetchRealHR();
        if (hr == null) {
            hr = generateMockHR();
        }
        var smoothed = smoothHR(hr, 7);
        var raw = hrToPeaks(smoothed, 3);
        return sortPeaksByHeight(raw);
    }

    function peakX(nx as Lang.Float) as Lang.Float {
        var clamped = nx;
        if (clamped < 0.0) { clamped = 0.0; }
        if (clamped > 1.0) { clamped = 1.0; }
        return 0.20 + clamped * 0.60;
    }

    // ------------------------------------------------------ buffer plumbing

    function onLayout(dc as Graphics.Dc) as Void {
        ensureBuffer(dc.getWidth(), dc.getHeight());
    }

    function draw(dc as Graphics.Dc) as Void {
        ensureBuffer(dc.getWidth(), dc.getHeight());

        if (mBuffer == null) {
            renderScene(dc, dc.getWidth(), dc.getHeight());
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

    function renderBufferedScene(sceneKey as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) {
            return;
        }

        // Refresh the HR descriptor each scene rebuild (every 20 min) so the
        // landscape tracks the wearer's last 4 hours.
        mPeaks = computePeaks();
        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight);
        mLastSceneKey = sceneKey;
    }

    // -------------------------------------------------------- composition

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }

        var w = width.toFloat();
        var h = height.toFloat();

        // host x anchor stays mid-right so the upper-left void holds the
        // inscription; guest is pushed clear of the host massif.
        var peaks = mPeaks;
        var h0 = 0.6;
        var h1 = 0.5;
        var hostNx = 0.5;
        var guestNx = 0.25;
        if (peaks != null && peaks.size() >= 2) {
            hostNx = 0.36 + peakX(peaks[0][0]) * 0.40;
            guestNx = peakX(peaks[1][0]);
            h0 = peaks[0][1];
            h1 = peaks[1][1];
            var dxp = hostNx - guestNx;
            if (dxp < 0.0) { dxp = -dxp; }
            if (dxp < 0.30) {
                guestNx = (hostNx < 0.5) ? hostNx + 0.34 : hostNx - 0.34;
            }
            if (guestNx < 0.16) { guestNx = 0.16; }
            if (guestNx > 0.84) { guestNx = 0.84; }
        }

        drawPaper(dc);
        drawCelestial(dc, width, height);

        // 1. far range — pale atmosphere high on the paper
        if (mFarRange != null) {
            dc.drawScaledBitmap(-(w * 0.024), h * 0.308, w * 1.048, h * 0.269, mFarRange);
        }

        // 2. guest mountain — recessed beyond the mist
        if (mGuest != null) {
            var gH = h * 0.505 * (0.42 + 0.28 * h1);
            var gW = gH * (GUEST_W / GUEST_H);
            var gX = guestNx * w - GUEST_APEX_FRAC * gW;
            var gY = h * 0.7212 - gH;
            dc.drawScaledBitmap(gX, gY, gW, gH, mGuest);
        }

        // 3. light mist — separates guest plane from host plane
        if (mMistLite != null) {
            dc.drawScaledBitmap(-(w * 0.216), h * 0.543, w * 1.067, h * 0.231, mMistLite);
        }

        // 4. host mountain — the hero massif
        if (mHost != null) {
            var hH = h * 0.6971 * (0.86 + 0.38 * h0);
            var hW = hH * (HOST_W / HOST_H);
            var hX = hostNx * w - HOST_APEX_FRAC * hW;
            var hY = h * 0.8942 - hH;
            dc.drawScaledBitmap(hX, hY, hW, hH, mHost);
        }

        // 5. full mist — dissolves all bases
        if (mMist != null) {
            dc.drawScaledBitmap(-(w * 0.029), h * 0.7115, w * 1.072, h * 0.269, mMist);
        }

        // 6. shore — dark foreground anchor, bottom-left inside the circle
        if (mShore != null) {
            dc.drawScaledBitmap(-(w * 0.019), h * 0.6875, w * 0.798, h * 0.243, mShore);
        }

        // 7. paper grain over everything: converts "screen" to "paper"
        if (mPaperGrain != null) {
            dc.drawScaledBitmap(0, 0, width, height, mPaperGrain);
        }
    }

    function drawPaper(dc as Graphics.Dc) as Void {
        dc.setColor(0xF2EEE6, 0xF2EEE6);
        dc.clear();
    }

    // Sun arcs 06:00-18:00, moon 18:00-06:00, west-to-east sin parabola.
    function drawCelestial(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var clockTime = System.getClockTime();
        var minuteOfDay = (clockTime.hour * 60) + clockTime.min;
        var isNight = minuteOfDay < 360 || minuteOfDay >= 1080;

        var t;
        if (isNight) {
            var nightMin = (minuteOfDay >= 1080) ? minuteOfDay - 1080 : minuteOfDay + 360;
            t = nightMin.toFloat() / 720.0;
        } else {
            t = (minuteOfDay - 360).toFloat() / 720.0;
        }

        var x = (width * 20) / 100 + ((width * 60) / 100 * t).toNumber();
        var y = (height * 14) / 100 - (Math.sin(t * 3.14159) * (height * 6) / 100).toNumber();
        var rHalo = (width * 46) / 1000;
        var rCore = (width * 34) / 1000;

        if (isNight) {
            dc.setFill(Graphics.createColor(0x30, 240, 235, 220));
            dc.fillCircle(x, y, rHalo);
            dc.setFill(Graphics.createColor(0xC0, 248, 244, 232));
            dc.fillCircle(x, y, rCore);
        } else {
            dc.setFill(Graphics.createColor(0x40, 200, 70, 50));
            dc.fillCircle(x, y, rHalo);
            dc.setFill(Graphics.createColor(0xCC, 175, 38, 28));
            dc.fillCircle(x, y, rCore);
        }
    }

}
