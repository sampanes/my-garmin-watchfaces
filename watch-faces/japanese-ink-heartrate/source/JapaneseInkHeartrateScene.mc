using Toybox.ActivityMonitor;
using Toybox.Application;
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
// 2026-10-28: one time axis for both landmarks (x = 0.36..0.80 of the width,
// four hours ago to now, clear of the inscription); an optional true-HR
// overlay so the gap between the data and the painting is visible at a
// glance; and a night mode (settings: nightStart/nightEnd hours) that swaps
// in the moonlit negative plane set (pale ink on black paper) so the face
// stops lighting the bedroom.
//
// 2026-10-29: the overlay is a silhouette, not a hairline. The first cut
// plotted the samples against the top of the host's bitmap RECTANGLE, which
// put the line in the sky 100 px above the paint. Now the data is drawn on
// the host's CREST scale (the apex pixel sits 31% down the host bitmap) as
// a translucent vermilion wash under a brush edge, with a dot on each
// painted crest, so it reads as a mountain against a mountain. Composing
// John's real logs through the preview then showed two defects the mock
// never could: the guest picker accepted an empty bucket, and the guest's
// own higher base let it out-top the host at a lower heart rate. Now the
// guest needs a data bucket an hour away or is not drawn, and its crest
// sits on the host's crest scale (crestY), a little lower.
//
// Layout numbers are ported 1:1 from scripts/compose_preview.py, which mocks
// this exact recipe at 416x416. Iterate there first; it is far faster.
//
// 2026-10-29, later: the RENDERER_PLAN §13 probe (PROBE below), a card of
// four hardware comparisons in place of the painting, written blind for one
// build at home and a wrist photo.

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
    // Which plane set is in the graphics pool: -1 none, 0 day, 1 night.
    var mLoadedSet as Lang.Number = -1;

    // HR peak descriptor cache. Each element is [nx, h, s] — normalized x
    // position, normalized height, spread. Sorted descending by h so
    // index 0 = host (dominant), index 1 = guest.
    var mPeaks as Lang.Array<Lang.Array<Lang.Float>>?;
    // Sixteen 15-minute averages, oldest to newest. Zero means that portion
    // of the four-hour window was unavailable (for example after a reboot).
    var mHistory as Lang.Array<Lang.Float>?;
    var mLatestHr as Lang.Number?;
    // Raw samples of the window for the true-HR overlay, oldest first:
    // normalized time (0 = four hours ago, 1 = now) and normalized HR.
    var mTraceNx as Lang.Array<Lang.Float>?;
    var mTraceHr as Lang.Array<Lang.Float>?;

    // Settings (resources/settings), re-read on every buffered render.
    var mShowTrace as Lang.Boolean = true;
    var mNightStart as Lang.Number = 21;
    var mNightEnd as Lang.Number = 6;
    var mNight as Lang.Boolean = false;

    const HR_MIN = 45.0;
    const HR_MAX = 160.0;
    const HISTORY_BUCKETS = 16;
    const HISTORY_SECONDS = 4 * 3600;
    // Dc.fillPolygon takes at most 64 points (common/graphics/DC_PART1); the
    // wash is the trace plus two floor corners. 58 columns on a 183 px axis
    // is about one point every 3 px, which is the display's resolution.
    const TRACE_MAX = 58;
    const TRACE_FLOOR_PAD = 0.02;     // wash floor this far under the lowest sample

    // Asset native dimensions (must match gen_ink_layers.py outputs) and
    // where the painted crest sits inside each bitmap (alpha >= 40, measured
    // 2026-10-29, identical on the day and night sets).
    const HOST_W = 340.0;
    const HOST_H = 260.0;
    const HOST_APEX_FRAC = 0.47;      // crest x within the host bitmap
    const HOST_APEX_Y = 0.31;         // crest y: 31% down the host bitmap
    const GUEST_W = 260.0;
    const GUEST_H = 190.0;
    const GUEST_APEX_FRAC = 0.46;     // crest x (0.42 sat 8 px off the axis)
    const GUEST_APEX_Y = 0.12;        // crest y: 12% down the guest bitmap
    // The guest crest sits on the host's crest scale, this much lower (it is
    // the further, paler mountain). Until 2026-10-29 it stood on its own
    // higher base and out-topped the host even at a lower heart rate.
    const GUEST_RECESS = 0.03;
    const MIST_W = 416;
    const MIST_H = 110;

    // ------------------------------------------------------- the §13 probe
    // RENDERER_PLAN §13: what can the FR265 blend? Set PROBE to true, build,
    // sideload, photograph the wrist, set it back (never commit it true).
    // The card replaces the painting (the View skips the inscription) with
    // four rows; each tile holds its image, or the word ERR (the call threw
    // and the face stayed alive) or n/a (the API is absent at runtime). The
    // DAY planes are used whatever the hour: multiply onto black paper is
    // black, so the night set would answer nothing. The expected card is
    // scripts/compose_preview.py --probe; a tile that matches it is a row
    // that survives, a tile that matches its left neighbor is a no-op.
    //   A  the mist band's middle (8-bit alpha, native scale) over dark gray,
    //      painted into a buffer made with ALPHA_BLENDING_FULL, one made with
    //      ALPHA_BLENDING_PARTIAL, and straight onto the screen. Soft = that
    //      surface blends 8-bit alpha; a hard cut-out = 1-bit (forum 340936).
    //      The docs make FULL the default, so the first tile is what the
    //      painting already gets; the scene buffer itself is made with FULL
    //      spelled out (the title says whether that call was accepted).
    //   B  the host plane 75 px tall: drawScaledBitmap (point sampling) beside
    //      drawBitmap2 with an AffineTransform scale and FILTER_MODE_BILINEAR.
    //      Barcode strokes left and smooth ones right = §13 row 2 is the fix.
    //   C  mist_band_lite as baked (62% alpha) beside mist_band under a white
    //      50%-alpha :tintColor, the same crop over the same gray. A paler
    //      right tile = the tint is the global-alpha knob; the same density
    //      as the full band = the tint's alpha is ignored here.
    //   D  two guest planes overlapping by half: source-over beside
    //      BLEND_MODE_MULTIPLY. A darker overlap on the right = multiply
    //      works (the docs want a GPU); identical tiles = it is ignored.
    const PROBE = false;
    const PROBE_GROUND = 0x5A5550;
    const PROBE_INK = 0x18120E;
    var mProbeFull as Graphics.BufferedBitmap?;
    var mProbePartial as Graphics.BufferedBitmap?;
    // How the scene buffer was made in probe mode: full (ALPHA_BLENDING_FULL
    // accepted), plain (that call threw; made without the option), none.
    var mProbeBufferNote as Lang.String = "none";

    function initialize() {
        readSettings();
        mNight = computeNight();
        loadPlanes(mNight);
        refreshHistory();
    }

    // ------------------------------------------------------------ settings

    function propValue(key as Lang.String) {
        var value = null;
        try {
            value = Application.Properties.getValue(key);
        } catch (ex) {
            value = null;
        }
        return value;
    }

    function propBool(key as Lang.String, fallback as Lang.Boolean) as Lang.Boolean {
        var value = propValue(key);
        if (value instanceof Lang.Boolean) { return value as Lang.Boolean; }
        if (value instanceof Lang.Number) { return (value as Lang.Number) != 0; }
        return fallback;
    }

    function propHour(key as Lang.String, fallback as Lang.Number) as Lang.Number {
        var value = propValue(key);
        if (value instanceof Lang.Number || value instanceof Lang.Float) {
            var hour = (value as Lang.Numeric).toNumber();
            if (hour >= 0 && hour <= 24) { return hour; }
        }
        return fallback;
    }

    function readSettings() as Void {
        mShowTrace = propBool("trueHrOverlay", true);
        mNightStart = propHour("nightStart", 21);
        mNightEnd = propHour("nightEnd", 6);
    }

    // Night mode is a clock window from the settings; equal hours = off.
    function computeNight() as Lang.Boolean {
        if (mNightStart == mNightEnd) { return false; }
        var hour = System.getClockTime().hour;
        if (mNightStart < mNightEnd) {
            return hour >= mNightStart && hour < mNightEnd;
        }
        return hour >= mNightStart || hour < mNightEnd;
    }

    function isNight() as Lang.Boolean {
        return mNight;
    }

    function isProbe() as Lang.Boolean {
        return PROBE;
    }

    // Settings changed (or anything else that must repaint before the next
    // five-minute key): forget the buffer's key so the next draw re-renders.
    function invalidate() as Void {
        mLastSceneKey = -1;
    }

    // -------------------------------------------------------------- planes

    // Only one set sits in the graphics pool at a time: the other set's
    // references are dropped before the new one loads. The probe card is
    // always the day set (see PROBE).
    function loadPlanes(night as Lang.Boolean) as Void {
        var set = (night && !PROBE) ? 1 : 0;
        if (set == mLoadedSet) { return; }
        mFar = null;
        mHost = null;
        mGuest = null;
        mMist = null;
        mMistLite = null;
        mFgLeft = null;
        mFgRight = null;
        mPaperGrain = null;
        if (WatchUi has :loadResource) {
            if (night) {
                mFar = WatchUi.loadResource(Rez.Drawables.FarRangeNight);
                mHost = WatchUi.loadResource(Rez.Drawables.HostMountainNight);
                mGuest = WatchUi.loadResource(Rez.Drawables.GuestMountainNight);
                mMist = WatchUi.loadResource(Rez.Drawables.MistBandNight);
                mMistLite = WatchUi.loadResource(Rez.Drawables.MistBandLiteNight);
                mFgLeft = WatchUi.loadResource(Rez.Drawables.FgLeftNight);
                mFgRight = WatchUi.loadResource(Rez.Drawables.FgRightNight);
                // No grain on the night paper: black stays black.
            } else {
                mFar = WatchUi.loadResource(Rez.Drawables.FarRangeTuned);
                mHost = WatchUi.loadResource(Rez.Drawables.HostMountainTuned);
                mGuest = WatchUi.loadResource(Rez.Drawables.GuestMountainTuned);
                mMist = WatchUi.loadResource(Rez.Drawables.MistBandTuned);
                mMistLite = WatchUi.loadResource(Rez.Drawables.MistBandLiteTuned);
                mFgLeft = WatchUi.loadResource(Rez.Drawables.FgLeftTuned);
                mFgRight = WatchUi.loadResource(Rez.Drawables.FgRightTuned);
                mPaperGrain = WatchUi.loadResource(Rez.Drawables.PaperGrainTuned);
            }
        }
        mLoadedSet = set;
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

    function mockTrace() as Void {
        var source = generateMockHR();
        var nxs = [] as Lang.Array<Lang.Float>;
        var hrs = [] as Lang.Array<Lang.Float>;
        var denom = (source.size() - 1).toFloat();
        for (var i = 0; i < source.size(); i++) {
            nxs.add(i.toFloat() / denom);
            hrs.add(normHr(source[i]));
        }
        mTraceNx = nxs;
        mTraceHr = hrs;
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

    function heightForNorm(norm as Lang.Float) as Lang.Float {
        return 0.35 + norm * 0.65;
    }

    function heightForHr(hr as Lang.Float) as Lang.Float {
        return heightForNorm(normHr(hr));
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

    // The host is the strongest 15-minute bucket. The guest is the strongest
    // bucket WITH DATA at least an hour away; an empty bucket is not a
    // landmark (until 2026-10-29 a window missing its first hours after a
    // reboot grew a full-size guest out of nothing). With no such bucket
    // there is no guest: one episode, one mountain. Each x stays its true
    // location in the window.
    function landmarkPeaks(history as Lang.Array<Lang.Float>) as Lang.Array<Lang.Array<Lang.Float>> {
        var host = 0;
        for (var i = 1; i < history.size(); i++) {
            if (history[i] > history[host]) { host = i; }
        }
        var guest = -1;
        var guestHr = 0.0;
        for (var i = 0; i < history.size(); i++) {
            var distance = i - host;
            if (distance < 0) { distance = -distance; }
            if (distance >= 4 && history[i] > guestHr) {
                guest = i;
                guestHr = history[i];
            }
        }
        var denom = (HISTORY_BUCKETS - 1).toFloat();
        var peaks = [
            [host.toFloat() / denom, heightForHr(history[host]), 0.15] as Lang.Array<Lang.Float>
        ] as Lang.Array<Lang.Array<Lang.Float>>;
        if (guest >= 0) {
            peaks.add([guest.toFloat() / denom, heightForHr(history[guest]), 0.15] as Lang.Array<Lang.Float>);
        }
        return peaks;
    }

    function refreshHistory() as Void {
        var sums = emptyBuckets();
        var counts = emptyBuckets();
        var valid = 0;
        mLatestHr = null;
        var traceNx = [] as Lang.Array<Lang.Float>;
        var traceHr = [] as Lang.Array<Lang.Float>;

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
                        var nx = elapsed.toFloat() / HISTORY_SECONDS.toFloat();
                        if (nx < 0.0) { nx = 0.0; }
                        if (nx > 1.0) { nx = 1.0; }
                        traceNx.add(nx);
                        traceHr.add(normHr(hr.toFloat()));
                    }
                    sample = iterator.next();
                }
            }
        }

        if (valid < 8) {
            mHistory = mockBuckets();
            mockTrace();
        } else {
            var history = emptyBuckets();
            for (var i = 0; i < HISTORY_BUCKETS; i++) {
                if (counts[i] > 0.0) { history[i] = sums[i] / counts[i]; }
            }
            // Only internal holes are interpolated. Leading/trailing missing
            // time remains blank in the distant ridge rather than invented.
            fillInternalGaps(history);
            mHistory = history;
            storeTrace(traceNx, traceHr);
        }
        mPeaks = landmarkPeaks(mHistory as Lang.Array<Lang.Float>);
    }

    // Keep at most TRACE_MAX samples. Groups are reduced to their highest
    // sample, never their first, so a peak survives the thinning.
    function storeTrace(nxs as Lang.Array<Lang.Float>, hrs as Lang.Array<Lang.Float>) as Void {
        if (nxs.size() <= TRACE_MAX) {
            mTraceNx = nxs;
            mTraceHr = hrs;
            return;
        }
        var stride = (nxs.size() + TRACE_MAX - 1) / TRACE_MAX;
        var outNx = [] as Lang.Array<Lang.Float>;
        var outHr = [] as Lang.Array<Lang.Float>;
        for (var i = 0; i < nxs.size(); i += stride) {
            var best = i;
            for (var j = i + 1; j < i + stride && j < nxs.size(); j++) {
                if (hrs[j] > hrs[best]) { best = j; }
            }
            outNx.add(nxs[best]);
            outHr.add(hrs[best]);
        }
        mTraceNx = outNx;
        mTraceHr = outHr;
    }

    function latestHeartRateText() as Lang.String? {
        // Local copy: the type checker narrows locals after a null test,
        // not member variables.
        var hr = mLatestHr;
        if (hr == null) { return null; }
        return hr.format("%d");
    }

    // ------------------------------------------------------------ mapping
    // The landscape's time axis: 0 (four hours ago) .. 1 (now) maps to
    // x = 0.36..0.80 of the width, which keeps every apex clear of the
    // inscription column. The true-HR overlay uses the same two functions,
    // so wherever the art departs from the data, the departure shows.

    function peakX(nx as Lang.Float) as Lang.Float {
        var clamped = nx;
        if (clamped < 0.0) { clamped = 0.0; }
        if (clamped > 1.0) { clamped = 1.0; }
        return 0.20 + clamped * 0.60;
    }

    function axisX(nx as Lang.Float) as Lang.Float {
        return 0.36 + (peakX(nx) - 0.20) * 0.73;
    }

    // Host plane height for a landmark height (heightForHr output).
    function hostHeight(hNorm as Lang.Float, h as Lang.Float) as Lang.Float {
        return h * 0.70 * (0.50 + 0.60 * hNorm);
    }

    // The host's CREST scale: the y the host crest has when the host is sized
    // for a landmark height (45 bpm -> 0.527 h, 160 bpm -> 0.337 h). The
    // guest crest and the overlay both sit on it, so one height means one
    // heart rate everywhere in the painting.
    function crestY(hNorm as Lang.Float, h as Lang.Float) as Lang.Float {
        return h * 0.87 - (1.0 - HOST_APEX_Y) * hostHeight(hNorm, h);
    }

    function traceY(norm as Lang.Float, h as Lang.Float) as Lang.Float {
        return crestY(heightForNorm(norm), h);
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
        if (PROBE) {
            drawProbeScreenTile(dc, dc.getWidth().toFloat(), dc.getHeight().toFloat());
        }
    }

    // Five-minute key. The night window flips on an hour, which is always a
    // key boundary, so the swap never waits.
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
            mBuffer = null;
            if (PROBE) {
                // §13 row 1: the option spelled out (the documented default).
                try {
                    mBuffer = Graphics.createBufferedBitmap({
                        :width => width, :height => height,
                        :alphaBlending => Graphics.ALPHA_BLENDING_FULL
                    }).get() as Graphics.BufferedBitmap;
                    mProbeBufferNote = (mBuffer != null) ? "full" : "null";
                } catch (ex) {
                    mBuffer = null;
                    mProbeBufferNote = "plain";
                }
            }
            if (mBuffer == null) {
                mBuffer = Graphics.createBufferedBitmap(options).get() as Graphics.BufferedBitmap;
            }
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
        readSettings();
        mNight = computeNight();
        loadPlanes(mNight);
        refreshHistory();
        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight);
        mLastSceneKey = sceneKey;
    }

    // -------------------------------------------------------- composition

    function renderScene(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
        if (PROBE) {
            renderProbe(dc, width, height);
            return;
        }

        var w = width.toFloat();
        var h = height.toFloat();

        // Both landmarks sit on the one time axis. The guest apex also stays
        // right of the inscription column (x >= 0.34) and clear of the host
        // massif; when it cannot do both on its own side it crosses over.
        // No second landmark (landmarkPeaks) means no guest plane.
        var peaks = mPeaks;
        var h0 = 0.6;
        var h1 = 0.5;
        var hostNx = 0.5;
        var guestNx = 0.25;
        var hasGuest = false;
        if (peaks != null && peaks.size() >= 1) {
            hostNx = axisX(peaks[0][0]);
            h0 = peaks[0][1];
        }
        if (peaks != null && peaks.size() >= 2) {
            hasGuest = true;
            guestNx = axisX(peaks[1][0]);
            h1 = peaks[1][1];
            if (guestNx < 0.34) { guestNx = 0.34; }
            var dxp = hostNx - guestNx;
            if (dxp < 0.0) { dxp = -dxp; }
            if (dxp < 0.30) {
                guestNx = (hostNx < 0.55) ? hostNx + 0.34 : hostNx - 0.34;
                if (guestNx < 0.34) { guestNx = 0.34; }
                if (guestNx > 0.84) { guestNx = 0.84; }
            }
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

        // 3. guest: the second landmark, its crest on the host's crest scale
        //    and GUEST_RECESS lower, so a lower heart rate is a lower peak
        var gH = h * 0.50 * (0.40 + 0.70 * h1);
        var gY = crestY(h1, h) + h * GUEST_RECESS - GUEST_APEX_Y * gH;
        if (hasGuest && mGuest != null) {
            var gW = gH * (GUEST_W / GUEST_H);
            var gX = guestNx * w - GUEST_APEX_FRAC * gW;
            dc.drawScaledBitmap(gX, gY, gW, gH, mGuest);
        }

        // 4. host: the strongest landmark, the hero
        var hH = hostHeight(h0, h);
        var hY = h * 0.87 - hH;
        if (mHost != null) {
            var hW = hH * (HOST_W / HOST_H);
            var hX = hostNx * w - HOST_APEX_FRAC * hW;
            dc.drawScaledBitmap(hX, hY, hW, hH, mHost);
        }

        // 5. full mist dissolving the mid-plane bases
        if (mMist != null) {
            dc.drawScaledBitmap(-(w * 0.03), h * 0.69, w * 1.06, h * 0.20, mMist);
        }

        // 6. foreground masses: left = oldest hour, right = newest
        if (mFgLeft != null) {
            var lH = h * 0.58 * (0.65 + 0.45 * hStart);
            var lW = w * 0.74;
            dc.drawScaledBitmap(-(w * 0.04), h - lH + h * 0.03, lW, lH, mFgLeft);
        }
        if (mFgRight != null) {
            var rH = h * 0.52 * (0.65 + 0.45 * hEnd);
            var rW = w * 0.68;
            dc.drawScaledBitmap(w - rW + w * 0.04, h - rH + h * 0.03, rW, rH, mFgRight);
        }

        // 7. paper grain over everything: converts "screen" to "paper"
        if (mPaperGrain != null) {
            dc.drawScaledBitmap(0, 0, width, height, mPaperGrain);
        }

        // 8. the data itself, for judging the painting against it. The dots
        //    go on the painted crests (the apex pixel inside each plane, not
        //    the top of its rectangle).
        if (mShowTrace) {
            drawTrace(dc, w, h,
                      hostNx * w, hY + HOST_APEX_Y * hH,
                      guestNx * w, hasGuest ? gY + GUEST_APEX_Y * gH : -1.0);
        }
    }

    // The data as a SILHOUETTE in the painting's own grammar: a translucent
    // vermilion wash under the data's skyline on the host crest scale, a
    // crisp brush edge along the skyline, and a dot on each painted crest.
    // Where the wash rises above the ink the painting under-states; where
    // ink stands above the edge it over-states. The wash's floor hugs the
    // window's lowest sample, so it is the data's own relief, not a box.
    // guestAy < 0 means the painting has no guest this window.
    function drawTrace(dc as Graphics.Dc, w as Lang.Float, h as Lang.Float,
                       hostAx as Lang.Float, hostAy as Lang.Float,
                       guestAx as Lang.Float, guestAy as Lang.Float) as Void {
        var nxs = mTraceNx;
        var hrs = mTraceHr;
        if (nxs == null || hrs == null || nxs.size() < 2) { return; }

        // Numeric, the element type fillPolygon/drawLine declare, so the
        // level-2 type checker has no subtyping to reason about.
        var pts = [] as Lang.Array<Lang.Array<Lang.Numeric>>;
        var floor = 0;
        for (var i = 0; i < nxs.size(); i++) {
            var x = (w * axisX(nxs[i])).toNumber();
            var y = traceY(hrs[i], h).toNumber();
            if (y > floor) { floor = y; }
            pts.add([x, y] as Lang.Array<Lang.Numeric>);
        }
        floor += (h * TRACE_FLOOR_PAD).toNumber();

        // The wash: trace plus two floor corners, at most TRACE_MAX + 2 points.
        var poly = [] as Lang.Array<Lang.Array<Lang.Numeric>>;
        for (var i = 0; i < pts.size(); i++) { poly.add(pts[i]); }
        poly.add([pts[pts.size() - 1][0], floor] as Lang.Array<Lang.Numeric>);
        poly.add([pts[0][0], floor] as Lang.Array<Lang.Numeric>);
        if (mNight) {
            dc.setFill(Graphics.createColor(0x50, 200, 70, 50));
        } else {
            dc.setFill(Graphics.createColor(0x3C, 176, 52, 38));
        }
        dc.fillPolygon(poly);

        // The edge and the crest dots, opaque (setFill explicitly, so the
        // dots never inherit the wash's alpha).
        var edge = mNight ? 0xEC6E54 : 0xA62C1E;
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        dc.setFill(edge);
        dc.setPenWidth(2);
        for (var i = 1; i < pts.size(); i++) {
            dc.drawLine(pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1]);
        }
        dc.setPenWidth(1);
        dc.fillCircle(hostAx.toNumber(), hostAy.toNumber(), 4);
        if (guestAy >= 0.0) {
            dc.fillCircle(guestAx.toNumber(), guestAy.toNumber(), 4);
        }
    }

    function drawPaper(dc as Graphics.Dc) as Void {
        var paper = mNight ? 0x000000 : 0xF2EEE6;
        dc.setColor(paper, paper);
        dc.clear();
    }

    // ------------------------------------------------------- the §13 probe
    // (see PROBE above for what each row asks; geometry in fractions of the
    // screen, every tile inside the circle: the top row's corners are the
    // tightest at 64..352 px on 416)

    // Row A geometry, shared with the screen tile: [x0, y, tileW, tileH, gap].
    function probeRowA(w as Lang.Float, h as Lang.Float) as Lang.Array<Lang.Number> {
        return [
            (w * 0.17).toNumber(), (h * 0.14).toNumber(),
            (w * 0.20).toNumber(), (h * 0.15).toNumber(),
            (w * 0.03).toNumber()
        ] as Lang.Array<Lang.Number>;
    }

    function renderProbe(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var w = width.toFloat();
        var h = height.toFloat();
        dc.setColor(0xF2EEE6, 0xF2EEE6);
        dc.clear();

        // Title: the firmware's API level and how the scene buffer was made.
        var version = "?";
        var settings = System.getDeviceSettings();
        if (settings has :monkeyVersion) {
            var v = settings.monkeyVersion;
            version = v[0].format("%d") + "." + v[1].format("%d") + "." + v[2].format("%d");
        }
        probeLabel(dc, w * 0.5, h * 0.075, "PROBE " + version + " " + mProbeBufferNote);

        // A. 8-bit alpha into a FULL surface, a PARTIAL surface (and, drawn
        //    later by drawProbeScreenTile, the screen).
        var a = probeRowA(w, h);
        if (mProbeFull == null) { mProbeFull = probeBuffer(a[2], a[3], true); }
        if (mProbePartial == null) { mProbePartial = probeBuffer(a[2], a[3], false); }
        probeAlphaTile(dc, a[0], a[1], a[2], a[3], mProbeFull);
        probeAlphaTile(dc, a[0] + a[2] + a[4], a[1], a[2], a[3], mProbePartial);
        probeFrame(dc, a[0] + 2 * (a[2] + a[4]), a[1], a[2], a[3]);
        probeLabel(dc, w * 0.5, h * 0.325, "A: full | partial | screen");

        // B. the host plane, point sampling beside bilinear.
        var bX = (w * 0.08).toNumber();
        var bY = (h * 0.36).toNumber();
        var bW = (w * 0.40).toNumber();
        var bH = (h * 0.18).toNumber();
        var bX2 = bX + bW + (w * 0.04).toNumber();
        probeFrame(dc, bX, bY, bW, bH);
        probeFrame(dc, bX2, bY, bW, bH);
        if (mHost != null) {
            var hostH = bH.toFloat();
            var hostW = hostH * (HOST_W / HOST_H);
            var inset = (bW.toFloat() - hostW) / 2.0;
            dc.drawScaledBitmap(bX.toFloat() + inset, bY.toFloat(), hostW, hostH, mHost);
            if ((Graphics has :AffineTransform) && (dc has :drawBitmap2)) {
                try {
                    var t = new Graphics.AffineTransform();
                    t.scale(hostW / HOST_W, hostH / HOST_H);
                    dc.drawBitmap2(bX2.toFloat() + inset, bY.toFloat(), mHost,
                                   { :transform => t, :filterMode => Graphics.FILTER_MODE_BILINEAR });
                } catch (ex) {
                    probeWord(dc, bX2, bY, bW, bH, "ERR");
                }
            } else {
                probeWord(dc, bX2, bY, bW, bH, "n/a");
            }
        }
        probeLabel(dc, w * 0.5, h * 0.575, "B: point | bilinear");

        // C. the baked 62% mist beside the full mist under a 50% white tint,
        //    the same crop of the band's middle over the same gray (the mist
        //    is paper-colored, so on paper it would be invisible).
        var cY = (h * 0.60).toNumber();
        var cH = (h * 0.11).toNumber();
        var offX = (MIST_W - bW) / 2;
        var offY = (MIST_H - cH) / 2;
        probeFrame(dc, bX, cY, bW, cH);
        probeFrame(dc, bX2, cY, bW, cH);
        dc.setColor(PROBE_GROUND, PROBE_GROUND);
        dc.fillRectangle(bX, cY, bW, cH);
        dc.fillRectangle(bX2, cY, bW, cH);
        if (mMistLite != null) {
            dc.setClip(bX, cY, bW, cH);
            dc.drawBitmap(bX - offX, cY - offY, mMistLite);
            dc.clearClip();
        }
        if (mMist != null) {
            if (dc has :drawBitmap2) {
                try {
                    dc.setClip(bX2, cY, bW, cH);
                    dc.drawBitmap2(bX2 - offX, cY - offY, mMist,
                                   { :tintColor => Graphics.createColor(0x80, 255, 255, 255) });
                    dc.clearClip();
                } catch (ex) {
                    dc.clearClip();
                    probeWord(dc, bX2, cY, bW, cH, "ERR");
                }
            } else {
                probeWord(dc, bX2, cY, bW, cH, "n/a");
            }
        }
        probeLabel(dc, w * 0.5, h * 0.745, "C: baked 62% | tint 50%");

        // D. two guests overlapping by half, source-over beside multiply.
        var dX = (w * 0.235).toNumber();
        var dY = (h * 0.78).toNumber();
        var dW = (w * 0.25).toNumber();
        var dH = (h * 0.12).toNumber();
        var dX2 = dX + dW + (w * 0.03).toNumber();
        probeFrame(dc, dX, dY, dW, dH);
        probeFrame(dc, dX2, dY, dW, dH);
        if (mGuest != null) {
            var gH = dH.toFloat() * 0.9;
            var gW = gH * (GUEST_W / GUEST_H);
            var gY = dY.toFloat() + (dH.toFloat() - gH) / 2.0;
            var second = dW.toFloat() - 3.0 - gW;
            dc.drawScaledBitmap(dX.toFloat() + 3.0, gY, gW, gH, mGuest);
            dc.drawScaledBitmap(dX.toFloat() + second, gY, gW, gH, mGuest);
            if (dc has :setBlendMode) {
                var failed = false;
                try {
                    dc.setBlendMode(Graphics.BLEND_MODE_MULTIPLY);
                    dc.drawScaledBitmap(dX2.toFloat() + 3.0, gY, gW, gH, mGuest);
                    dc.drawScaledBitmap(dX2.toFloat() + second, gY, gW, gH, mGuest);
                } catch (ex) {
                    failed = true;
                }
                probeBlendDefault(dc);
                if (failed) {
                    probeWord(dc, dX2, dY, dW, dH, "ERR");
                }
            } else {
                probeWord(dc, dX2, dY, dW, dH, "n/a");
            }
        }
        probeLabel(dc, w * 0.5, h * 0.93, "D: over | multiply");
    }

    // Row A's third tile, straight onto the screen after the buffer blit.
    function drawProbeScreenTile(dc as Graphics.Dc, w as Lang.Float, h as Lang.Float) as Void {
        var a = probeRowA(w, h);
        var x = a[0] + 2 * (a[2] + a[4]);
        var y = a[1];
        if (mMist == null) {
            probeWord(dc, x, y, a[2], a[3], "ERR");
            return;
        }
        try {
            dc.setColor(PROBE_GROUND, PROBE_GROUND);
            dc.fillRectangle(x, y, a[2], a[3]);
            dc.setClip(x, y, a[2], a[3]);
            dc.drawBitmap(x - (MIST_W - a[2]) / 2, y - (MIST_H - a[3]) / 2, mMist);
            dc.clearClip();
        } catch (ex) {
            dc.clearClip();
            probeWord(dc, x, y, a[2], a[3], "ERR");
        }
    }

    // A small surface for row A with the alpha-blending level asked for,
    // or null when the call is refused.
    function probeBuffer(width as Lang.Number, height as Lang.Number,
                         full as Lang.Boolean) as Graphics.BufferedBitmap? {
        if (!(Graphics has :createBufferedBitmap)) { return null; }
        try {
            var mode = full ? Graphics.ALPHA_BLENDING_FULL : Graphics.ALPHA_BLENDING_PARTIAL;
            return Graphics.createBufferedBitmap({
                :width => width, :height => height, :alphaBlending => mode
            }).get() as Graphics.BufferedBitmap;
        } catch (ex) {
            return null;
        }
    }

    // Row A: the mist's middle at native scale over dark gray, painted into
    // the given small surface and then placed on the card.
    function probeAlphaTile(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                            w as Lang.Number, h as Lang.Number,
                            surface as Graphics.BufferedBitmap?) as Void {
        probeFrame(dc, x, y, w, h);
        if (surface == null || mMist == null) {
            probeWord(dc, x, y, w, h, "ERR");
            return;
        }
        try {
            var sdc = surface.getDc();
            sdc.setColor(PROBE_GROUND, PROBE_GROUND);
            sdc.clear();
            sdc.drawBitmap(-((MIST_W - w) / 2), -((MIST_H - h) / 2), mMist);
            dc.drawBitmap(x, y, surface);
        } catch (ex) {
            probeWord(dc, x, y, w, h, "ERR");
        }
    }

    function probeBlendDefault(dc as Graphics.Dc) as Void {
        try {
            dc.setBlendMode(Graphics.BLEND_MODE_DEFAULT);
        } catch (ex) {
            // nothing to restore: the mode never took
        }
    }

    function probeFrame(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                        w as Lang.Number, h as Lang.Number) as Void {
        dc.setColor(PROBE_INK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawRectangle(x - 1, y - 1, w + 2, h + 2);
    }

    function probeWord(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                       w as Lang.Number, h as Lang.Number, word as Lang.String) as Void {
        dc.setColor(PROBE_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + w / 2, y + h / 2, Graphics.FONT_XTINY, word,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function probeLabel(dc as Graphics.Dc, cx as Lang.Float, cy as Lang.Float,
                        text as Lang.String) as Void {
        dc.setColor(PROBE_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx.toNumber(), cy.toNumber(), Graphics.FONT_XTINY, text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
