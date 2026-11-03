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
// 2026-11-02: the fidelity test (scripts/fidelity_test.py, from home)
// scored the 2026-10-31 recipe at a guest in 12 of 13 synthetic windows, a
// flat resting one included: any data bucket an hour from the host
// qualified, so noise did. A guest now also needs GUEST_PROMINENCE bpm
// over the valley between it and the host; the host's own shoulder and a
// resting window's noise are not a second landmark.
//
// 2026-11-03: the opinion-round relief (compose_preview.py round 6, John
// judged six rounds of it on 11-02) replaces the host/guest landmarks.
// The window's floor is a level far horizon on the crest scale; every run
// of buckets standing over it is a mass on one deep base (0.87 H), a spire,
// broad peak or wide mountain by its duration, its crest on the crest scale
// at the run's place on a full-width time axis; a near range fills the
// thirds of the screen the masses leave empty. Masses and near hills are
// paper cutouts baked into their PNGs (scripts/bake_cutouts.py), so the
// horizon and farther masses hide behind them. They are loaded per render
// and dropped, so the graphics pool only ever holds one frame's planes.
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

    // The fixed planes of the loaded set (day or night). Typed so the
    // checker sees them; it does not narrow a member after a null test
    // (COMPILER_FACTS 1.4), so every draw site copies the plane to a local
    // first. The horizon, masses and near hills are loaded per render
    // (loadPlane), drawn and dropped.
    var mMist as Graphics.BitmapType?;
    var mMistLite as Graphics.BitmapType?;
    var mFgLeft as Graphics.BitmapType?;
    var mFgRight as Graphics.BitmapType?;
    var mPaperGrain as Graphics.BitmapType?;
    // Which plane set is in the graphics pool: -1 none, 0 day, 1 night.
    var mLoadedSet as Lang.Number = -1;

    // The relief of the current window (computeRelief): the horizon's crest
    // y in px (negative = none), the masses in draw order as [left, top,
    // width, height, crestX, crestY, plane, flip, host] (M_* indices) and
    // the near hills as [left, top, width, height, plane].
    var mHorizonY as Lang.Float = -1.0;
    var mMasses as Lang.Array<Lang.Array<Lang.Float>>?;
    var mNear as Lang.Array<Lang.Array<Lang.Float>>?;

    // The planes by index (P_*): width/height of the PNG and the painted
    // crest inside it (alpha >= 40, measured 2026-11-03 from the day PNGs,
    // as compose_preview.measure_apex does). The flipped wide planes use
    // 1 - x.
    var mPlaneAspect as Lang.Array<Lang.Float> =
        [0.6, 0.6, 1.25, 1.25, 1.4117647, 1.4117647, 2.0, 2.0] as Lang.Array<Lang.Float>;
    var mPlaneApexX as Lang.Array<Lang.Float> =
        [0.4417, 0.4444, 0.40, 0.49, 0.2469, 0.2531, 0.4938, 0.3078] as Lang.Array<Lang.Float>;
    var mPlaneApexY as Lang.Array<Lang.Float> =
        [0.2667, 0.17, 0.1417, 0.10, 0.1794, 0.2088, 0.0, 0.1062] as Lang.Array<Lang.Float>;
    // The near hills lean outward from their third's center (fraction of W).
    var mNearLean as Lang.Array<Lang.Float> = [-0.05, 0.03, 0.05] as Lang.Array<Lang.Float>;

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
    // wash is the trace plus two floor corners. 58 columns on the full-width
    // axis is a point every 7 px, finer than the 15-minute buckets.
    const TRACE_MAX = 58;
    const TRACE_FLOOR_PAD = 0.02;     // wash floor this far under the lowest sample

    // The relief (compose_preview.py, round 6). bpm unless noted.
    const FLOOR_RANK = 8;         // the floor is the (n / 8)-th lowest data bucket (3rd of 16)
    const RUN_MIN = 6.0;          // a bucket this far over the floor belongs to a run
    const MASS_MIN = 15.0;        // a run's crest must stand this far over the floor
    const VALLEY_MIN = 8.0;       // a valley this deep under both summits splits a run
    const SPIRE_UPTO = 2;         // buckets: a run this short is a spire (30 min)
    const WIDE_FROM = 6;          // buckets: a run this long is the wide mountain (90 min)
    const BASE_Y = 0.87;          // every mass's foot (fraction of H), under the mist
    const WIDE_SUMMIT_IN = 0.20;  // the wide summit sits this far into its run from the high end
    const WIDE_END_TOL = 5.0;     // a run whose ends differ by less keeps its summit at its start
    const NEAR_CREST_Y = 0.60;    // the near range's crest (fraction of H)
    const NEAR_H = 0.21;          // its height (fraction of H) ...
    const NEAR_HR_SPAN = 30.0;    // ... up by almost half over this much of its third over the floor
    const NEAR_EMPTY = 0.25;      // a third with less mass cover than this is empty
    const CREST_LO_Y = 0.58;      // the crest scale: 45 bpm sits here (fraction of H) ...
    const CREST_HI_Y = 0.26;      // ... and 160 bpm here
    const HORIZON_W = 416.0;      // horizon.png, drawn full width at native height on 416
    const HORIZON_H = 56.0;
    const HORIZON_APEX_Y = 0.1607;

    // Plane indices (mPlane* tables, loadPlane).
    const P_SPIRE = 0;
    const P_SPIRE_PALE = 1;
    const P_BROAD = 2;
    const P_BROAD_PALE = 3;
    const P_WIDE = 4;
    const P_WIDE_PALE = 5;
    const P_NEAR = 6;
    const P_NEAR2 = 7;

    // Run fields (runMass) and mass fields (mMasses).
    const R_LO = 0;
    const R_HI = 1;
    const R_BUCKETS = 2;
    const R_PEAK = 3;
    const R_ELEV = 4;
    const R_NX = 5;
    const R_LEAN_END = 6;
    const M_CX = 4;
    const M_CY = 5;
    const M_PLANE = 6;
    const M_FLIP = 7;
    const M_HOST = 8;

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
    //   B  the broad plane 75 px tall: drawScaledBitmap (point sampling) beside
    //      drawBitmap2 with an AffineTransform scale and FILTER_MODE_BILINEAR.
    //      Barcode strokes left and smooth ones right = §13 row 2 is the fix.
    //   C  mist_band_lite as baked (62% alpha) beside mist_band under a white
    //      50%-alpha :tintColor, the same crop over the same gray. A paler
    //      right tile = the tint is the global-alpha knob; the same density
    //      as the full band = the tint's alpha is ignored here.
    //   D  two pale spires overlapping by half: source-over beside
    //      BLEND_MODE_MULTIPLY. A darker overlap on the right = multiply
    //      works (the docs want a GPU); identical tiles = it is ignored.
    const PROBE = false;
    const PROBE_GROUND = 0x5A5550;
    const PROBE_INK = 0x18120E;
    const PROBE_B_W = 300.0;     // broad_cut.png
    const PROBE_B_H = 240.0;
    const PROBE_D_W = 180.0;     // spire_pale_cut.png
    const PROBE_D_H = 300.0;
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

    function propValue(key as Lang.String) as Lang.Object? {
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

    // Only one set of fixed planes sits in the graphics pool at a time: the
    // other set's references are dropped before the new one loads. The
    // probe card is always the day set (see PROBE).
    function loadPlanes(night as Lang.Boolean) as Void {
        var set = (night && !PROBE) ? 1 : 0;
        if (set == mLoadedSet) { return; }
        mMist = null;
        mMistLite = null;
        mFgLeft = null;
        mFgRight = null;
        mPaperGrain = null;
        if (set == 1) {
            mMist = WatchUi.loadResource(Rez.Drawables.MistBandNight) as Graphics.BitmapType;
            mMistLite = WatchUi.loadResource(Rez.Drawables.MistBandLiteNight) as Graphics.BitmapType;
            mFgLeft = WatchUi.loadResource(Rez.Drawables.FgLeftNight) as Graphics.BitmapType;
            mFgRight = WatchUi.loadResource(Rez.Drawables.FgRightNight) as Graphics.BitmapType;
            // No grain on the night paper: black stays black.
        } else {
            mMist = WatchUi.loadResource(Rez.Drawables.MistBandTuned) as Graphics.BitmapType;
            mMistLite = WatchUi.loadResource(Rez.Drawables.MistBandLiteTuned) as Graphics.BitmapType;
            mFgLeft = WatchUi.loadResource(Rez.Drawables.FgLeftTuned) as Graphics.BitmapType;
            mFgRight = WatchUi.loadResource(Rez.Drawables.FgRightTuned) as Graphics.BitmapType;
            mPaperGrain = WatchUi.loadResource(Rez.Drawables.PaperGrainTuned) as Graphics.BitmapType;
        }
        mLoadedSet = set;
    }

    // A mass or near-hill cutout, loaded for one render. Null when the pool
    // refuses it: that plane is skipped and the face stays alive.
    function loadPlane(p as Lang.Number, flip as Lang.Boolean, night as Lang.Boolean) as Graphics.BitmapType? {
        var id = null;
        if (p == P_SPIRE) {
            id = night ? Rez.Drawables.SpireCutNight : Rez.Drawables.SpireCut;
        } else if (p == P_SPIRE_PALE) {
            id = night ? Rez.Drawables.SpirePaleCutNight : Rez.Drawables.SpirePaleCut;
        } else if (p == P_BROAD) {
            id = night ? Rez.Drawables.BroadCutNight : Rez.Drawables.BroadCut;
        } else if (p == P_BROAD_PALE) {
            id = night ? Rez.Drawables.BroadPaleCutNight : Rez.Drawables.BroadPaleCut;
        } else if (p == P_WIDE) {
            if (flip) {
                id = night ? Rez.Drawables.WideFlipCutNight : Rez.Drawables.WideFlipCut;
            } else {
                id = night ? Rez.Drawables.WideCutNight : Rez.Drawables.WideCut;
            }
        } else if (p == P_WIDE_PALE) {
            if (flip) {
                id = night ? Rez.Drawables.WidePaleFlipCutNight : Rez.Drawables.WidePaleFlipCut;
            } else {
                id = night ? Rez.Drawables.WidePaleCutNight : Rez.Drawables.WidePaleCut;
            }
        } else if (p == P_NEAR) {
            id = night ? Rez.Drawables.NearHillCutNight : Rez.Drawables.NearHillCut;
        } else if (p == P_NEAR2) {
            id = night ? Rez.Drawables.NearHill2CutNight : Rez.Drawables.NearHill2Cut;
        }
        if (id == null) { return null; }
        var bmp = null;
        try {
            bmp = WatchUi.loadResource(id) as Graphics.BitmapType;
        } catch (ex) {
            bmp = null;
        }
        return bmp;
    }

    function loadHorizon(night as Lang.Boolean) as Graphics.BitmapType? {
        var bmp = null;
        try {
            bmp = WatchUi.loadResource(night ? Rez.Drawables.HorizonNight : Rez.Drawables.Horizon) as Graphics.BitmapType;
        } catch (ex) {
            bmp = null;
        }
        return bmp;
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

    // ------------------------------------------------------------- relief
    // compose_preview.py mid_plane_layout, round 6, line for line.

    // The window's floor: the third-lowest of sixteen data buckets, so one
    // odd bucket cannot drag it (0.0 for an empty window).
    function floorLevel(history as Lang.Array<Lang.Float>) as Lang.Float {
        var vals = [] as Lang.Array<Lang.Float>;
        for (var i = 0; i < history.size(); i++) {
            var v = history[i];
            if (v <= 0.0) { continue; }
            var j = vals.size();
            vals.add(v);
            while (j > 0 && vals[j - 1] > v) {
                vals[j] = vals[j - 1];
                j--;
            }
            vals[j] = v;
        }
        if (vals.size() == 0) { return 0.0; }
        return vals[vals.size() / FLOOR_RANK];
    }

    function maxIn(history as Lang.Array<Lang.Float>, lo as Lang.Number, hi as Lang.Number) as Lang.Float {
        var best = history[lo];
        for (var i = lo + 1; i <= hi; i++) {
            if (history[i] > best) { best = history[i]; }
        }
        return best;
    }

    // Cut a run at its deepest interior valley that drops VALLEY_MIN under
    // the summits on both sides, again on each side. The valley bucket goes
    // to both halves (it is both slopes).
    function splitAtValleys(history as Lang.Array<Lang.Float>, lo as Lang.Number, hi as Lang.Number,
                            out as Lang.Array<Lang.Array<Lang.Number>>) as Void {
        var best = -1;
        var bestDrop = 0.0;
        for (var v = lo + 1; v < hi; v++) {
            var left = maxIn(history, lo, v - 1);
            var right = maxIn(history, v + 1, hi);
            var drop = ((left < right) ? left : right) - history[v];
            if (drop >= VALLEY_MIN && (best < 0 || drop > bestDrop)) {
                best = v;
                bestDrop = drop;
            }
        }
        if (best < 0) {
            out.add([lo, hi] as Lang.Array<Lang.Number>);
            return;
        }
        splitAtValleys(history, lo, best, out);
        splitAtValleys(history, best, hi, out);
    }

    // Maximal runs of data buckets RUN_MIN over the floor, each split at its
    // valleys: [lo, hi] in time order.
    function splitRuns(history as Lang.Array<Lang.Float>, floor as Lang.Float) as Lang.Array<Lang.Array<Lang.Number>> {
        var out = [] as Lang.Array<Lang.Array<Lang.Number>>;
        var n = history.size();
        var i = 0;
        while (i < n) {
            if (history[i] > 0.0 && history[i] - floor >= RUN_MIN) {
                var j = i;
                while (j + 1 < n && history[j + 1] > 0.0 && history[j + 1] - floor >= RUN_MIN) {
                    j++;
                }
                splitAtValleys(history, i, j, out);
                i = j + 1;
            } else {
                i++;
            }
        }
        return out;
    }

    // A run as a mass (R_* fields): its crest heart rate (the highest trace
    // sample inside its buckets, so five minutes of stairs paint their spike
    // and not their fifteen-minute average), its height over the floor, its
    // place on the axis (the centroid of its height over the floor) and
    // whether its end stands higher than its start.
    function runMass(history as Lang.Array<Lang.Float>, floor as Lang.Float,
                     lo as Lang.Number, hi as Lang.Number, denom as Lang.Float) as Lang.Array<Lang.Float> {
        var peak = maxIn(history, lo, hi);
        var nxs = mTraceNx;
        var hrs = mTraceHr;
        if (nxs != null && hrs != null) {
            var x0 = (lo - 0.5) / denom;
            var x1 = (hi + 0.5) / denom;
            for (var i = 0; i < nxs.size() && i < hrs.size(); i++) {
                if (nxs[i] >= x0 && nxs[i] <= x1) {
                    var bpm = HR_MIN + hrs[i] * (HR_MAX - HR_MIN);
                    if (bpm > peak) { peak = bpm; }
                }
            }
        }
        var wsum = 0.0;
        var xsum = 0.0;
        for (var i = lo; i <= hi; i++) {
            var wt = history[i] - floor;
            if (wt < 0.0) { wt = 0.0; }
            wsum += wt;
            xsum += i * wt;
        }
        var cx = (wsum > 0.0) ? xsum / wsum : 0.0;
        // the first two and last two buckets (the mock's slices: the first
        // pair may reach one bucket past a one-bucket run)
        var headHi = lo + 1;
        if (headHi > history.size() - 1) { headHi = history.size() - 1; }
        var head = 0.0;
        for (var i = lo; i <= headHi; i++) { head += history[i]; }
        head = head / (headHi - lo + 1);
        var tailLo = (hi - 1 >= lo) ? hi - 1 : lo;
        var tail = 0.0;
        for (var i = tailLo; i <= hi; i++) { tail += history[i]; }
        tail = tail / (hi - tailLo + 1);
        return [lo.toFloat(), hi.toFloat(), (hi - lo + 1).toFloat(), peak, peak - floor,
                cx / denom, (tail - head > WIDE_END_TOL) ? 1.0 : 0.0] as Lang.Array<Lang.Float>;
    }

    // Which plane a mass gets, by its duration; the host takes the dark
    // planes, every other mass the pale twin.
    function massPlane(buckets as Lang.Number, pale as Lang.Boolean) as Lang.Number {
        if (buckets <= SPIRE_UPTO) { return pale ? P_SPIRE_PALE : P_SPIRE; }
        if (buckets >= WIDE_FROM) { return pale ? P_WIDE_PALE : P_WIDE; }
        return pale ? P_BROAD_PALE : P_BROAD;
    }

    // Draw order: pale masses first (the taller farther), the host last.
    function massAfter(a as Lang.Array<Lang.Float>, b as Lang.Array<Lang.Float>) as Lang.Boolean {
        if (a[M_HOST] != b[M_HOST]) { return a[M_HOST] > b[M_HOST]; }
        return a[M_CY] > b[M_CY];
    }

    function computeRelief(w as Lang.Float, h as Lang.Float) as Void {
        mHorizonY = -1.0;
        var masses = [] as Lang.Array<Lang.Array<Lang.Float>>;
        var near = [] as Lang.Array<Lang.Array<Lang.Float>>;
        mMasses = masses;
        mNear = near;
        var history = mHistory;
        if (history == null) { return; }
        var floor = floorLevel(history);
        if (floor <= 0.0) { return; }
        mHorizonY = crestY(heightForHr(floor), h);
        var denom = (history.size() - 1).toFloat();
        var bucketPx = w / denom;

        // the runs that stand MASS_MIN over the floor; the highest crest is
        // the host (the first, on a tie)
        var spans = splitRuns(history, floor);
        var runs = [] as Lang.Array<Lang.Array<Lang.Float>>;
        var host = -1;
        for (var i = 0; i < spans.size(); i++) {
            var r = runMass(history, floor, spans[i][0], spans[i][1], denom);
            if (r[R_ELEV] < MASS_MIN) { continue; }
            if (host < 0 || r[R_PEAK] > runs[host][R_PEAK]) { host = runs.size(); }
            runs.add(r);
        }

        // every mass on the deep base, its crest on the crest scale, its
        // width its plane's own aspect
        for (var i = 0; i < runs.size(); i++) {
            var r = runs[i];
            var isHost = (i == host);
            var p = massPlane(r[R_BUCKETS].toNumber(), !isHost);
            var ax = mPlaneApexX[p];
            var ay = mPlaneApexY[p];
            var cy = crestY(heightForHr(r[R_PEAK]), h);
            var mh = (BASE_Y * h - cy) / (1.0 - ay);
            var mw = mPlaneAspect[p] * mh;
            var flip = false;
            var cx = 0.0;
            var left = 0.0;
            if (p == P_WIDE || p == P_WIDE_PALE) {
                // the summit WIDE_SUMMIT_IN into the run from its higher end,
                // the level shoulder over the rest (mirrored for the right)
                var x0 = (r[R_LO] - 0.5) * bucketPx;
                var x1 = (r[R_HI] + 0.5) * bucketPx;
                flip = r[R_LEAN_END] > 0.5;
                if (flip) {
                    cx = x1 - WIDE_SUMMIT_IN * (x1 - x0);
                    left = cx - (1.0 - ax) * mw;
                } else {
                    cx = x0 + WIDE_SUMMIT_IN * (x1 - x0);
                    left = cx - ax * mw;
                }
            } else {
                cx = axisX(r[R_NX]) * w;
                left = cx - ax * mw;
            }
            masses.add([left, BASE_Y * h - mh, mw, mh, cx, cy, p.toFloat(),
                        flip ? 1.0 : 0.0, isHost ? 1.0 : 0.0] as Lang.Array<Lang.Float>);
        }
        // a stable insertion sort into draw order
        for (var i = 1; i < masses.size(); i++) {
            var m = masses[i];
            var j = i;
            while (j > 0 && massAfter(masses[j - 1], m)) {
                masses[j] = masses[j - 1];
                j--;
            }
            masses[j] = m;
        }

        // the near range: a third of the screen the masses leave empty gets
        // a near hill, nudged up by that third's heart rate over the floor;
        // both outer thirds when all three are empty
        var third = w / 3.0;
        var empty = [] as Lang.Array<Lang.Number>;
        for (var k = 0; k < 3; k++) {
            var a = k * third;
            var b = a + third;
            var covered = 0.0;
            for (var i = 0; i < masses.size(); i++) {
                var m = masses[i];
                var lo = m[0] + 0.15 * m[2];
                var hi = m[0] + 0.85 * m[2];
                if (lo < a) { lo = a; }
                if (hi > b) { hi = b; }
                if (hi > lo) { covered += hi - lo; }
            }
            if (covered / third < NEAR_EMPTY) { empty.add(k); }
        }
        if (empty.size() == 3) {
            empty = [0, 2] as Lang.Array<Lang.Number>;
        }
        for (var e = 0; e < empty.size(); e++) {
            var k = empty[e];
            var a = k * third;
            var b = a + third;
            var loB = (a / bucketPx + 0.5).toNumber();
            var hiB = (b / bucketPx + 0.5).toNumber();
            var sum = 0.0;
            var n = 0;
            for (var i = (loB < 0) ? 0 : loB; i <= hiB && i < history.size(); i++) {
                if (history[i] > 0.0) {
                    sum += history[i];
                    n++;
                }
            }
            var over = (n > 0) ? sum / n - floor : 0.0;
            if (over < 0.0) { over = 0.0; }
            var span = over / NEAR_HR_SPAN;
            if (span > 1.0) { span = 1.0; }
            var p = (k == 1) ? P_NEAR2 : P_NEAR;
            var nh = NEAR_H * h * (0.85 + 0.45 * span);
            var nw = mPlaneAspect[p] * nh;
            var cx = 0.5 * (a + b) + mNearLean[k] * w;
            near.add([cx - mPlaneApexX[p] * nw, NEAR_CREST_Y * h - mPlaneApexY[p] * nh,
                      nw, nh, p.toFloat()] as Lang.Array<Lang.Float>);
        }
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
    // The landscape's time axis is the full width (11-02, John: the oldest
    // hour may sit under the time and the seal, it matters least). The
    // masses and the true-HR overlay use the same axis and crest scale, so
    // wherever the art departs from the data, the departure shows.

    function axisX(nx as Lang.Float) as Lang.Float {
        if (nx < 0.0) { return 0.0; }
        if (nx > 1.0) { return 1.0; }
        return nx;
    }

    // The painting's one vertical scale, for a landmark height (0.35..1.0,
    // heightForNorm): 45 bpm at CREST_LO_Y, 160 bpm at CREST_HI_Y. The
    // horizon, every crest and the overlay sit on it, so one height means
    // one heart rate everywhere in the painting.
    function crestY(hNorm as Lang.Float, h as Lang.Float) as Lang.Float {
        var norm = (hNorm - 0.35) / 0.65;
        return h * (CREST_LO_Y + (CREST_HI_Y - CREST_LO_Y) * norm);
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
        computeRelief(w, h);

        // The foreground masses carry the two ends of the window: the oldest
        // hour on the left, the newest (now) on the right.
        var hStart = edgeHr(mHistory, -1);
        var hEnd = edgeHr(mHistory, 1);

        drawPaper(dc);
        drawCelestial(dc, width, height);

        // 1. the far range as a level line at the window's floor, its crest
        //    row on the crest scale; every mass is a cutout over it
        if (mHorizonY >= 0.0) {
            var horizon = loadHorizon(mNight);
            if (horizon != null) {
                var hzH = HORIZON_H * (w / HORIZON_W);
                dc.drawScaledBitmap(0, mHorizonY - HORIZON_APEX_Y * hzH, w, hzH, horizon);
            }
        }

        // 2. light mist between the far and mid planes
        var mistLite = mMistLite;
        if (mistLite != null) {
            dc.drawScaledBitmap(-(w * 0.10), h * 0.50, w * 1.20, h * 0.17, mistLite);
        }

        // 3. the masses: pale ones first, the host last (none on a flat day)
        var masses = mMasses;
        if (masses != null) {
            for (var i = 0; i < masses.size(); i++) {
                var m = masses[i];
                var bmp = loadPlane(m[M_PLANE].toNumber(), m[M_FLIP] > 0.5, mNight);
                if (bmp != null) {
                    dc.drawScaledBitmap(m[0], m[1], m[2], m[3], bmp);
                }
            }
        }

        // 4. the near range: a near hill in each third the masses leave empty
        var near = mNear;
        if (near != null) {
            for (var i = 0; i < near.size(); i++) {
                var n = near[i];
                var bmp = loadPlane(n[4].toNumber(), false, mNight);
                if (bmp != null) {
                    dc.drawScaledBitmap(n[0], n[1], n[2], n[3], bmp);
                }
            }
        }

        // 5. full mist dissolving the mid-plane bodies and the near range's
        //    feet, beginning just under the near crests
        var mist = mMist;
        if (mist != null) {
            dc.drawScaledBitmap(-(w * 0.03), h * 0.66, w * 1.06, h * 0.22, mist);
        }

        // 6. foreground masses: left = oldest hour, right = newest
        var fgLeft = mFgLeft;
        if (fgLeft != null) {
            var lH = h * 0.58 * (0.65 + 0.45 * hStart);
            var lW = w * 0.74;
            dc.drawScaledBitmap(-(w * 0.04), h - lH + h * 0.03, lW, lH, fgLeft);
        }
        var fgRight = mFgRight;
        if (fgRight != null) {
            var rH = h * 0.52 * (0.65 + 0.45 * hEnd);
            var rW = w * 0.68;
            dc.drawScaledBitmap(w - rW + w * 0.04, h - rH + h * 0.03, rW, rH, fgRight);
        }

        // 7. paper grain over everything: converts "screen" to "paper"
        var grain = mPaperGrain;
        if (grain != null) {
            dc.drawScaledBitmap(0, 0, width, height, grain);
        }

        // 8. the data itself, for judging the painting against it, with a
        //    dot on every painted crest
        if (mShowTrace) {
            drawTrace(dc, w, h);
        }
    }

    // The data as a SILHOUETTE in the painting's own grammar: a translucent
    // vermilion wash under the data's skyline on the crest scale, a crisp
    // brush edge along the skyline, and a dot on each painted crest. Where
    // the wash rises above the ink the painting under-states; where ink
    // stands above the edge it over-states. The wash's floor hugs the
    // window's lowest sample, so it is the data's own relief, not a box.
    function drawTrace(dc as Graphics.Dc, w as Lang.Float, h as Lang.Float) as Void {
        var nxs = mTraceNx;
        var hrs = mTraceHr;
        if (nxs == null || hrs == null || nxs.size() < 2) { return; }

        // fillPolygon declares Array<Graphics.Point2D> (a two-element tuple);
        // SDK 9.1 rejects an open Array<Array<Numeric>> there.
        var pts = [] as Lang.Array<Graphics.Point2D>;
        var floor = 0;
        for (var i = 0; i < nxs.size(); i++) {
            var x = (w * axisX(nxs[i])).toNumber();
            var y = traceY(hrs[i], h).toNumber();
            if (y > floor) { floor = y; }
            pts.add([x, y] as Graphics.Point2D);
        }
        floor += (h * TRACE_FLOOR_PAD).toNumber();

        // The wash: trace plus two floor corners, at most TRACE_MAX + 2 points.
        var poly = [] as Lang.Array<Graphics.Point2D>;
        for (var i = 0; i < pts.size(); i++) { poly.add(pts[i]); }
        poly.add([pts[pts.size() - 1][0], floor] as Graphics.Point2D);
        poly.add([pts[0][0], floor] as Graphics.Point2D);
        if (mNight) {
            dc.setFill(Graphics.createColor(0x50, 200, 70, 50));
        } else {
            dc.setFill(Graphics.createColor(0x3C, 176, 52, 38));
        }
        dc.fillPolygon(poly);

        // The edge and the crest dots, opaque. setFill takes 0xAARRGGBB, so a
        // bare 0xRRGGBB there is alpha 0 and the dots vanish (seen in the
        // sim 2026-10-30); createColor carries the alpha.
        var edge = mNight ? 0xEC6E54 : 0xA62C1E;
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        dc.setFill(mNight ? Graphics.createColor(0xFF, 0xEC, 0x6E, 0x54)
                          : Graphics.createColor(0xFF, 0xA6, 0x2C, 0x1E));
        dc.setPenWidth(2);
        for (var i = 1; i < pts.size(); i++) {
            dc.drawLine(pts[i - 1][0], pts[i - 1][1], pts[i][0], pts[i][1]);
        }
        dc.setPenWidth(1);
        var masses = mMasses;
        if (masses != null) {
            for (var i = 0; i < masses.size(); i++) {
                dc.fillCircle(masses[i][M_CX].toNumber(), masses[i][M_CY].toNumber(), 4);
            }
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

        // B. the broad plane, point sampling beside bilinear.
        var bX = (w * 0.08).toNumber();
        var bY = (h * 0.36).toNumber();
        var bW = (w * 0.40).toNumber();
        var bH = (h * 0.18).toNumber();
        var bX2 = bX + bW + (w * 0.04).toNumber();
        probeFrame(dc, bX, bY, bW, bH);
        probeFrame(dc, bX2, bY, bW, bH);
        var host = loadPlane(P_BROAD, false, false);
        if (host != null) {
            var hostH = bH.toFloat();
            var hostW = hostH * (PROBE_B_W / PROBE_B_H);
            var inset = (bW.toFloat() - hostW) / 2.0;
            dc.drawScaledBitmap(bX.toFloat() + inset, bY.toFloat(), hostW, hostH, host);
            if ((Graphics has :AffineTransform) && (dc has :drawBitmap2)) {
                try {
                    var t = new Graphics.AffineTransform();
                    t.scale(hostW / PROBE_B_W, hostH / PROBE_B_H);
                    dc.drawBitmap2(bX2.toFloat() + inset, bY.toFloat(), host,
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
        var mistLite = mMistLite;
        if (mistLite != null) {
            dc.setClip(bX, cY, bW, cH);
            dc.drawBitmap(bX - offX, cY - offY, mistLite);
            dc.clearClip();
        }
        var mist = mMist;
        if (mist != null) {
            if (dc has :drawBitmap2) {
                try {
                    dc.setClip(bX2, cY, bW, cH);
                    dc.drawBitmap2(bX2 - offX, cY - offY, mist,
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

        // D. two pale spires overlapping by half, source-over beside multiply.
        var dX = (w * 0.235).toNumber();
        var dY = (h * 0.78).toNumber();
        var dW = (w * 0.25).toNumber();
        var dH = (h * 0.12).toNumber();
        var dX2 = dX + dW + (w * 0.03).toNumber();
        probeFrame(dc, dX, dY, dW, dH);
        probeFrame(dc, dX2, dY, dW, dH);
        var guest = loadPlane(P_SPIRE_PALE, false, false);
        if (guest != null) {
            var gH = dH.toFloat() * 0.9;
            var gW = gH * (PROBE_D_W / PROBE_D_H);
            var gY = dY.toFloat() + (dH.toFloat() - gH) / 2.0;
            var second = dW.toFloat() - 3.0 - gW;
            dc.drawScaledBitmap(dX.toFloat() + 3.0, gY, gW, gH, guest);
            dc.drawScaledBitmap(dX.toFloat() + second, gY, gW, gH, guest);
            if (dc has :setBlendMode) {
                var failed = false;
                try {
                    dc.setBlendMode(Graphics.BLEND_MODE_MULTIPLY);
                    dc.drawScaledBitmap(dX2.toFloat() + 3.0, gY, gW, gH, guest);
                    dc.drawScaledBitmap(dX2.toFloat() + second, gY, gW, gH, guest);
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
        var mist = mMist;
        if (mist == null) {
            probeWord(dc, x, y, a[2], a[3], "ERR");
            return;
        }
        try {
            dc.setColor(PROBE_GROUND, PROBE_GROUND);
            dc.fillRectangle(x, y, a[2], a[3]);
            dc.setClip(x, y, a[2], a[3]);
            dc.drawBitmap(x - (MIST_W - a[2]) / 2, y - (MIST_H - a[3]) / 2, mist);
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
        var mist = mMist;
        if (surface == null || mist == null) {
            probeWord(dc, x, y, w, h, "ERR");
            return;
        }
        try {
            var sdc = surface.getDc();
            sdc.setColor(PROBE_GROUND, PROBE_GROUND);
            sdc.clear();
            sdc.drawBitmap(-((MIST_W - w) / 2), -((MIST_H - h) / 2), mist);
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
