using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

// Iteration 1 baseline — see RENDERER_PLAN.md §12.
// Intentionally minimal: paper + one flat "body-wash placeholder" rectangle
// where the body_wash_soft.png will eventually live.
// No HR descriptor, no peaks, no stamps yet. This is the clean slate we
// rebuild composition on top of.

class JapaneseInkHeartrateScene {

    var mBuffer as Graphics.BufferedBitmap?;
    var mBufferWidth as Lang.Number = 0;
    var mBufferHeight as Lang.Number = 0;
    var mLastSceneKey as Lang.Number = -1;

    // Kept loaded (and tuned-imported in drawables.xml) so iteration 3 can
    // use it without a separate rebuild of the resource manifest.
    var mVerticalFadeDescent;
    // Iteration 2: authored wash that substitutes for the canvas gradient
    // Garmin lacks. See scripts/gen_body_wash.py.
    var mBodyWash;
    // Iteration 4: darkest mark in the scene — anchors the eye to "peak" and
    // flips the descents from reading-as-smoke to reading-as-cliff-descent.
    // See scripts/gen_crest_anchor.py.
    var mCrestAnchor;
    // Iteration 6: mist strip drawn after descents/crests to erase their
    // lower portions and imply one connected landform under the peaks.
    // See scripts/gen_mist_strip.py.
    var mMistStrip;

    // Iteration 7: HR peak descriptor cache. Each element is [nx, h, s] —
    // normalized x position, normalized height, and spatial spread. Sorted
    // descending by h so index 0 = host (dominant), index 1 = guest (second).
    // Ported from playgrounds/ink-sandbox/main.js:156 `hrToPeaks`.
    var mPeaks as Lang.Array<Lang.Array<Lang.Float>>?;

    // HR_MIN / HR_MAX match the sandbox normalization range. Values outside
    // [HR_MIN, HR_MAX] are clamped at normalization time.
    const HR_MIN = 45.0;
    const HR_MAX = 160.0;

    function initialize() {
        if (WatchUi has :loadResource) {
            mVerticalFadeDescent = WatchUi.loadResource(Rez.Drawables.VerticalFadeDescentTuned);
            mBodyWash = WatchUi.loadResource(Rez.Drawables.BodyWashSoftTuned);
            mCrestAnchor = WatchUi.loadResource(Rez.Drawables.CrestAnchorTuned);
            mMistStrip = WatchUi.loadResource(Rez.Drawables.MistStripTuned);
        }
        mPeaks = computePeaks();
    }

    // Iteration 7 mock HR data — deterministic 48-sample series representing
    // ~4h of 5-min-spaced readings. Two visible effort bumps: a mild rise
    // near index 7–10 and a stronger peak near index 23–27. Good test input
    // because a count=3 descriptor should produce [low, high, low] heights.
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

    // Port of hrToPeaks (sandbox main.js:156): take `count` evenly-spaced
    // samples from the smoothed series, return a [nx, h, s] descriptor per
    // sample. Not peak-detection — positions are temporal (nx = time), heights
    // are HR-derived. Matches sandbox behavior exactly.
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

    // Sort descriptors descending by h (peaks[0] = host). Simple selection
    // sort — we only ever have 3–5 peaks, so algorithmic efficiency is moot.
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

    function computePeaks() as Lang.Array<Lang.Array<Lang.Float>> {
        var hr = generateMockHR();
        var smoothed = smoothHR(hr, 7);
        var raw = hrToPeaks(smoothed, 3);
        return sortPeaksByHeight(raw);
    }

    // Map a peak's nx (0..1) to a screen x-fraction in the safe band
    // [0.20, 0.80]. Crests and descents need margin so they don't clip edges.
    function peakX(nx as Lang.Float) as Lang.Float {
        var clamped = nx;
        if (clamped < 0.0) { clamped = 0.0; }
        if (clamped > 1.0) { clamped = 1.0; }
        return 0.20 + clamped * 0.60;
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

        drawPaper(dc, width, height);
        drawCelestial(dc, width, height);
        // Iter 8 pivot: silhouette polygon replaces stamp-only mountain.
        // Iter 8b: body_wash re-enabled as a tonal overlay over the silhouette
        // so the wash adds the warmth and internal variation that a Garmin
        // gradient can't. drawDescents stays disabled (the silhouette is the
        // mountain — descent stamps inside it would re-introduce tendrils).
        drawMountainSilhouette(dc, width, height);
        drawBodyWash(dc, width, height);
        drawCrest(dc, width, height);
        drawMist(dc, width, height);
    }

    function drawPaper(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        // Flat warm washi. Radial subtle lighting added sparingly so the paper
        // doesn't read as a solid swatch.
        dc.setColor(0xF2EEE6, 0xF2EEE6);
        dc.clear();

        dc.setFill(Graphics.createColor(10, 255, 250, 244));
        dc.fillCircle((width * 26) / 100, (height * 18) / 100, (width * 32) / 100);
    }

    function drawCelestial(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var clockTime = System.getClockTime();
        var minuteOfDay = (clockTime.hour * 60) + clockTime.min;
        var orbitT = minuteOfDay.toFloat() / 1440.0;
        var x = (width * 22) / 100 + ((width * 46) / 100 * orbitT).toNumber();
        var y = (height * 18) / 100 - (Math.sin(orbitT * 6.28318) * (height * 5) / 100).toNumber();

        dc.setFill(Graphics.createColor(12, 210, 196, 176));
        dc.fillCircle(x, y, 16);
        dc.setFill(Graphics.createColor(20, 242, 235, 223));
        dc.fillCircle(x, y, 10);
    }

    // Iter 8b: body_wash now overlays the silhouette area, providing the
    // tonal warmth and gradient feel that a flat fillPolygon can't. Scaled
    // to span the silhouette's vertical extent (peak top ~53% to baseline
    // 75%) so the feathered top edge bleeds into the upper paper and the
    // harder bottom edge sits inside the silhouette base.
    function drawBodyWash(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        if (mBodyWash == null) {
            return;
        }

        var washWidth = width;
        var washHeight = (height * 26) / 100;
        var washX = 0;
        var washY = (height * 50) / 100;

        dc.drawScaledBitmap(washX, washY, washWidth, washHeight, mBodyWash);
    }

    // RENDERER_PLAN §7 steps 6 & 7 — selective vertical descents. Iter 7
    // drives host/guest x-positions from the HR peak descriptor.
    //
    // Source asset is 32x128 RGBA with built-in top-to-bottom fade.
    function drawDescents(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        if (mVerticalFadeDescent == null || mPeaks == null || mPeaks.size() < 2) {
            return;
        }

        var hostNx = peakX(mPeaks[0][0]);
        var guestNx = peakX(mPeaks[1][0]);

        // Prevent crest/descent overlap if peaks land too close — push the
        // guest to the farther side to maintain readable hierarchy.
        if ((hostNx - guestNx).abs() < 0.20) {
            guestNx = (hostNx < 0.50) ? hostNx + 0.25 : hostNx - 0.25;
            if (guestNx < 0.20) { guestNx = 0.20; }
            if (guestNx > 0.80) { guestNx = 0.80; }
        }

        // Host: full-scale streak.
        var hostWidth = (width * 11) / 100;
        var hostHeight = (height * 40) / 100;
        var hostX = (width.toFloat() * hostNx).toNumber() - (hostWidth / 2);
        var hostY = (height * 40) / 100;
        dc.drawScaledBitmap(hostX, hostY, hostWidth, hostHeight, mVerticalFadeDescent);

        // Guest: smaller + shorter.
        var guestWidth = (width * 7) / 100;
        var guestHeight = (height * 26) / 100;
        var guestX = (width.toFloat() * guestNx).toNumber() - (guestWidth / 2);
        var guestY = (height * 45) / 100;
        dc.drawScaledBitmap(guestX, guestY, guestWidth, guestHeight, mVerticalFadeDescent);
    }

    // Crests now sit at the silhouette's actual peak vertices. Y is computed
    // from the same Gaussian profile as the polygon, so the crest stamp
    // visually caps the mountain rather than floating above it.
    function drawCrest(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        if (mCrestAnchor == null || mPeaks == null || mPeaks.size() < 2) {
            return;
        }

        var baseY = (height * 70) / 100;
        var amp = (height * 30) / 100;

        // Host: dominant crest. Centered on host's actual peak (nx → screen x).
        var hostNx = mPeaks[0][0];
        var hostScreenX = (width.toFloat() * hostNx).toNumber();
        var hostScreenY = baseY - (amp.toFloat() * profileValue(hostNx)).toNumber();
        var hostCrestW = (width * 24) / 100;
        var hostCrestH = (height * 11) / 100;
        // Crest's lower ~third should overlap the polygon's peak — so put the
        // crest's center slightly above the peak vertex.
        dc.drawScaledBitmap(
            hostScreenX - (hostCrestW / 2),
            hostScreenY - (hostCrestH * 2 / 3),
            hostCrestW,
            hostCrestH,
            mCrestAnchor
        );

        // Guest: subordinate crest — half scale, same vertex-anchored logic.
        var guestNx = mPeaks[1][0];
        var guestScreenX = (width.toFloat() * guestNx).toNumber();
        var guestScreenY = baseY - (amp.toFloat() * profileValue(guestNx)).toNumber();
        var guestCrestW = (width * 13) / 100;
        var guestCrestH = (height * 6) / 100;
        dc.drawScaledBitmap(
            guestScreenX - (guestCrestW / 2),
            guestScreenY - (guestCrestH * 2 / 3),
            guestCrestW,
            guestCrestH,
            mCrestAnchor
        );
    }

    // Iter 8 — the missing primitive. Compute a Gaussian-summed height
    // profile across screen width from the HR peak descriptor, then fill
    // a polygon with that silhouette. Direct port of the sandbox's
    // profile()+fillMtn() math (playgrounds/ink-sandbox/main.js:176, 210),
    // minus the Canvas linear gradient that Garmin lacks. The crest stamp
    // (drawn next) provides the dark-at-peak concentration the gradient
    // would have given.
    //
    // Polygon resolution: 33 samples across width. Peaks use max-aggregate
    // (one peak's contribution doesn't add to another's) — matches sandbox
    // profile() behavior. baseY at 70% of height; tallest peak rises to
    // 40% of height.
    function drawMountainSilhouette(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        if (mPeaks == null || mPeaks.size() == 0) {
            return;
        }

        var samples = 33;
        // Iter 8b: baseline nudged lower so the silhouette doesn't sit so
        // high; amplitude kept tall (time-overlap is intentionally not a
        // constraint — see iter-8b conversation notes).
        var baseY = (height * 75) / 100;
        var amp = (height * 30) / 100;

        // Build polygon: bottom-left → up-left baseline → top profile → up-right baseline → bottom-right.
        var poly = [] as Lang.Array<[Lang.Numeric, Lang.Numeric]>;
        poly.add([0, height] as [Lang.Numeric, Lang.Numeric]);
        poly.add([0, baseY] as [Lang.Numeric, Lang.Numeric]);

        for (var i = 0; i < samples; i++) {
            var nx = i.toFloat() / (samples - 1).toFloat();
            var v = profileValue(nx);
            // Iter 8b: deterministic ridge jitter via summed sines —
            // breaks up the smooth Gaussian outline so the ridge reads as
            // organic ink, not algorithm-perfect curve. Sins are cheap and
            // give correlated (smooth-feeling) noise across i.
            var phase = i.toFloat();
            var jitter = (Math.sin(phase * 1.73) * 2.4 + Math.sin(phase * 3.19 + 0.7) * 1.6).toNumber();
            var x = (nx * width.toFloat()).toNumber();
            var y = baseY - (amp.toFloat() * v).toNumber() + jitter;
            poly.add([x, y] as [Lang.Numeric, Lang.Numeric]);
        }

        poly.add([width, baseY] as [Lang.Numeric, Lang.Numeric]);
        poly.add([width, height] as [Lang.Numeric, Lang.Numeric]);

        // Iter 8b: alpha dropped from 0xCC to 0x66 so the silhouette is a
        // wash rather than a slab — body_wash + mist + crest now have room
        // to do tonal work over and inside it.
        dc.setFill(Graphics.createColor(0x66, 78, 74, 68));
        dc.fillPolygon(poly);
    }

    // Max-aggregate Gaussian peak summation. Returns normalized height
    // contribution at nx in [0,1]. Matches sandbox profile() core logic.
    // CIQ Math has no `exp`; use `pow(E, x)` instead.
    const E = 2.718281828459045;
    function profileValue(nx as Lang.Float) as Lang.Float {
        var v = 0.0;
        var peaks = mPeaks;
        if (peaks == null) {
            return 0.0;
        }
        for (var p = 0; p < peaks.size(); p++) {
            var px = peaks[p][0];
            var ph = peaks[p][1];
            var ps = peaks[p][2];
            var d = nx - px;
            var contribution = ph * Math.pow(E, -(d * d) / (2.0 * ps * ps)).toFloat();
            if (contribution > v) { v = contribution; }
        }
        return v.toFloat();
    }

    // RENDERER_PLAN §7 step 10 — mist as erasure. Drawn AFTER the silhouette
    // and crests so it visibly overwrites their lower portions with the warm
    // off-white mist color. The strip's asymmetric horizontal density and
    // uneven top edge (baked into the authored PNG) do the compositional
    // work; placement is just one drawScaledBitmap call.
    function drawMist(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        if (mMistStrip == null) {
            return;
        }

        // Spans 95% of width. Vertical center ~61% — overlaps the lower ~25%
        // of the host descent and the lower ~40% of the guest descent, plus
        // the lower edge of the body wash. Erases their bases; implies that
        // everything below this line dissolves into atmospheric mist.
        var mistWidth = (width * 95) / 100;
        var mistHeight = (height * 14) / 100;
        var mistX = (width - mistWidth) / 2;
        var mistY = (height * 54) / 100;

        dc.drawScaledBitmap(mistX, mistY, mistWidth, mistHeight, mMistStrip);
    }

}
