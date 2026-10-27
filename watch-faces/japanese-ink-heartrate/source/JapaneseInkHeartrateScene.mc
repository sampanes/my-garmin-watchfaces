using Toybox.ActivityMonitor;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

// 2026-10-27 rewrite — baked benchmark planes.
//
// Garmin's Dc has no gradients or blur, so runtime composition of primitives
// always exposed the primitive. The look that works is the browser benchmark
// (playgrounds/ink-sandbox/main.js): gradient-filled ridges with cun strokes,
// dry brush, ink bleed and small trees, separated by organic mist. The script
// scripts/gen_ink_layers.py ports those primitives and bakes each PLANE as one
// PNG; this file only places the planes, driven by the four-hour HR history:
// the two strongest hour-separated landmarks become the mid-plane peaks, the
// oldest and newest buckets set the two dark foreground masses.
//
// Layout numbers are ported 1:1 from scripts/compose_preview.py, which mocks
// this exact recipe at 416x416. Iterate there first; it is far faster.

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastSceneKey as Lang.Number = -1;

    var mFar;
    var mHost;
    var mGuest;
    var mMist;
    var mMistLite;
    var mFgLeft;
    var mFgRight;
    var mPaperGrain;

    // HR peak descriptor cache. Each element is [nx, h, s] — normalized x
    // position, normalized height, spread. Sorted descending by h so
    // index 0 = host (dominant), index 1 = guest.
    var mPeaks as Lang.Array<Lang.Array<Lang.Float>>?;
    // Sixteen 15-minute averages, oldest to newest. Zero means that portion
    // of the four-hour window was unavailable (for example after a reboot).
    var mHistory as Lang.Array<Lang.Float>?;
    var mLatestHr as Lang.Number?;

    const HR_MIN = 45.0;
    const HR_MAX = 160.0;
    const HISTORY_BUCKETS = 16;
    const HISTORY_SECONDS = 4 * 3600;

    // Asset native dimensions (must match gen_ink_layers.py outputs).
    const HOST_W = 340.0;
    const HOST_H = 260.0;
    const HOST_APEX_FRAC = 0.47;      // main peak x within the host bitmap
    const GUEST_W = 260.0;
    const GUEST_H = 190.0;
    const GUEST_APEX_FRAC = 0.42;

    function initialize() {
        if (WatchUi has :loadResource) {
            mFar = WatchUi.loadResource(Rez.Drawables.FarRangeTuned);
            mHost = WatchUi.loadResource(Rez.Drawables.HostMountainTuned);
            mGuest = WatchUi.loadResource(Rez.Drawables.GuestMountainTuned);
            mMist = WatchUi.loadResource(Rez.Drawables.MistBandTuned);
            mMistLite = WatchUi.loadResource(Rez.Drawables.MistBandLiteTuned);
            mFgLeft = WatchUi.loadResource(Rez.Drawables.FgLeftTuned);
            mFgRight = WatchUi.loadResource(Rez.Drawables.FgRightTuned);
            mPaperGrain = WatchUi.loadResource(Rez.Drawables.PaperGrainTuned);
        }
        refreshHistory();
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

    function emptyBuckets() as Lang.Array<Lang.Float> {
        var out = [] as Lang.Array<Lang.Float>;
        for (var i = 0; i < HISTORY_BUCKETS; i++) { out.add(0.0); }
        return out;
    }

    // The fallback uses the same 16-bin contract as real history. It keeps
    // the simulator attractive but never supplies a fake number to the seal.
    function mockBuckets() as Lang.Array<Lang.Float> {
        var source = generateMockHR();
        var out = [] as Lang.Array<Lang.Float>;
        var perBucket = source.size() / HISTORY_BUCKETS;
        for (var i = 0; i < HISTORY_BUCKETS; i++) {
            var sum = 0.0;
            for (var j = 0; j < perBucket; j++) {
                sum += source[i * perBucket + j];
            }
            out.add(sum / perBucket.toFloat());
        }
        return out;
    }

    function fillInternalGaps(history as Lang.Array<Lang.Float>) as Void {
        for (var i = 1; i < history.size() - 1; i++) {
            if (history[i] > 0.0) { continue; }
            var left = i - 1;
            var right = i + 1;
            while (left >= 0 && history[left] <= 0.0) { left--; }
            while (right < history.size() && history[right] <= 0.0) { right++; }
            if (left >= 0 && right < history.size()) {
                var t = (i - left).toFloat() / (right - left).toFloat();
                history[i] = history[left] + (history[right] - history[left]) * t;
            }
        }
    }

    function normHr(hr as Lang.Float) as Lang.Float {
        var value = hr;
        if (value < HR_MIN) { value = HR_MIN; }
        if (value > HR_MAX) { value = HR_MAX; }
        return (value - HR_MIN) / (HR_MAX - HR_MIN);
    }

    function heightForHr(hr as Lang.Float) as Lang.Float {
        return 0.35 + normHr(hr) * 0.65;
    }

    // Normalized HR of the oldest (edge < 0) or newest (edge > 0) bucket that
    // holds data; 0.5 when the window is empty.
    function edgeHr(history as Lang.Array<Lang.Float>?, edge as Lang.Number) as Lang.Float {
        if (history == null) { return 0.5; }
        var i = (edge < 0) ? 0 : history.size() - 1;
        while (i >= 0 && i < history.size()) {
            if (history[i] > 0.0) { return normHr(history[i]); }
            i += (edge < 0) ? 1 : -1;
        }
        return 0.5;
    }

    // Pick the strongest two 15-minute landmarks, separated by at least one
    // hour. Their x positions remain their true locations in the window.
    function landmarkPeaks(history as Lang.Array<Lang.Float>) as Lang.Array<Lang.Array<Lang.Float>> {
        var host = 0;
        for (var i = 1; i < history.size(); i++) {
            if (history[i] > history[host]) { host = i; }
        }
        var guest = -1;
        var guestHr = -1.0;
        for (var i = 0; i < history.size(); i++) {
            var distance = i - host;
            if (distance < 0) { distance = -distance; }
            if (distance >= 4 && history[i] > guestHr) {
                guest = i;
                guestHr = history[i];
            }
        }
        if (guest < 0) { guest = (host < HISTORY_BUCKETS / 2) ? HISTORY_BUCKETS - 1 : 0; }
        var denom = (HISTORY_BUCKETS - 1).toFloat();
        return [
            [host.toFloat() / denom, heightForHr(history[host]), 0.15] as Lang.Array<Lang.Float>,
            [guest.toFloat() / denom, heightForHr(history[guest]), 0.15] as Lang.Array<Lang.Float>
        ] as Lang.Array<Lang.Array<Lang.Float>>;
    }

    function refreshHistory() as Void {
        var sums = emptyBuckets();
        var counts = emptyBuckets();
        var valid = 0;
        mLatestHr = null;

        if ((Toybox has :ActivityMonitor) && (ActivityMonitor has :getHeartRateHistory)) {
            var iterator = null;
            try {
                iterator = ActivityMonitor.getHeartRateHistory(new Time.Duration(HISTORY_SECONDS), false);
            } catch (ex) {
                iterator = null;
            }
            if (iterator != null) {
                var start = Time.now().value() - HISTORY_SECONDS;
                var sample = iterator.next();
                while (sample != null) {
                    var hr = sample.heartRate;
                    var when = sample.when;
                    if (hr != null && when != null &&
                        hr != ActivityMonitor.INVALID_HR_SAMPLE && hr > 0) {
                        var elapsed = when.value() - start;
                        var bucket = (elapsed * HISTORY_BUCKETS / HISTORY_SECONDS).toNumber();
                        if (bucket < 0) { bucket = 0; }
                        if (bucket >= HISTORY_BUCKETS) { bucket = HISTORY_BUCKETS - 1; }
                        sums[bucket] += hr.toFloat();
                        counts[bucket] += 1.0;
                        mLatestHr = hr.toNumber();
                        valid++;
                    }
                    sample = iterator.next();
                }
            }
        }

        if (valid < 8) {
            mHistory = mockBuckets();
        } else {
            var history = emptyBuckets();
            for (var i = 0; i < HISTORY_BUCKETS; i++) {
                if (counts[i] > 0.0) { history[i] = sums[i] / counts[i]; }
            }
            // Only internal holes are interpolated. Leading/trailing missing
            // time remains blank in the distant ridge rather than invented.
            fillInternalGaps(history);
            mHistory = history;
        }
        mPeaks = landmarkPeaks(mHistory as Lang.Array<Lang.Float>);
    }

    function latestHeartRateText() as Lang.String? {
        return (mLatestHr == null) ? null : mLatestHr.format("%d");
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
        return minuteOfDay / 5;
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

        // Five-minute refresh tracks new history samples without doing the
        // iterator and buffered painting work on every one-second update.
        refreshHistory();
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

        // The foreground masses carry the two ends of the window: the oldest
        // hour on the left, the newest (now) on the right.
        var hStart = edgeHr(mHistory, -1);
        var hEnd = edgeHr(mHistory, 1);

        drawPaper(dc);
        drawCelestial(dc, width, height);

        // 1. far plane: ghost and far ridges, the horizon haze
        if (mFar != null) {
            dc.drawScaledBitmap(-(w * 0.02), h * 0.33, w * 1.04, h * 0.29, mFar);
        }

        // 2. light mist between the far and mid planes
        if (mMistLite != null) {
            dc.drawScaledBitmap(-(w * 0.10), h * 0.50, w * 1.20, h * 0.17, mMistLite);
        }

        // 3. guest: the second landmark, recessed
        if (mGuest != null) {
            var gH = h * 0.50 * (0.55 + 0.45 * h1);
            var gW = gH * (GUEST_W / GUEST_H);
            var gX = guestNx * w - GUEST_APEX_FRAC * gW;
            var gY = h * 0.71 - gH;
            dc.drawScaledBitmap(gX, gY, gW, gH, mGuest);
        }

        // 4. host: the strongest landmark, the hero
        if (mHost != null) {
            var hH = h * 0.70 * (0.72 + 0.38 * h0);
            var hW = hH * (HOST_W / HOST_H);
            var hX = hostNx * w - HOST_APEX_FRAC * hW;
            var hY = h * 0.87 - hH;
            dc.drawScaledBitmap(hX, hY, hW, hH, mHost);
        }

        // 5. full mist dissolving the mid-plane bases
        if (mMist != null) {
            dc.drawScaledBitmap(-(w * 0.03), h * 0.69, w * 1.06, h * 0.20, mMist);
        }

        // 6. foreground masses: left = oldest hour, right = newest
        if (mFgLeft != null) {
            var lH = h * 0.58 * (0.80 + 0.20 * hStart);
            var lW = w * 0.74;
            dc.drawScaledBitmap(-(w * 0.04), h - lH + h * 0.03, lW, lH, mFgLeft);
        }
        if (mFgRight != null) {
            var rH = h * 0.52 * (0.80 + 0.20 * hEnd);
            var rW = w * 0.68;
            dc.drawScaledBitmap(w - rW + w * 0.04, h - rH + h * 0.03, rW, rH, mFgRight);
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
