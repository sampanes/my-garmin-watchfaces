using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;
using Toybox.Time;
using Toybox.UserProfile;
using Toybox.Weather;
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
// glance; and a night mode (then settings: nightStart/nightEnd hours; since
// 2026-11-06 sunset to sunrise, no setting) that swaps
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
// 2026-11-03, later: the shape library. John, on a study that assembled
// mountains from brush primitives: whole known shapes beat bespoke ones, so
// have many. Each mass is now one of the library's whole painted mountains
// (scripts/gen_shape_library.py: since 2026-11-05 the 24 ChatGPT mountains
// from the art sheets, 300 px tall, skirt at the bottom, day and night
// cutouts), CHOSEN per run by the staged fitter against the stored trace
// and drawn at its baked height with its crest on the run's peak: sunk, its
// width stretched to the run (FIT_STRETCH_LO..HI, 2026-11-05), its foot
// behind the bank and the mist. The
// profile table is generated (JapaneseInkHeartrateShapes.mc), the same
// numbers the mock reads (scripts/shape_table.json). The fit is plain
// floating point; the mock's is double precision, so a near tie between two
// shapes may break differently here.
//
// 2026-11-05: the foreground is one whole-face painting from the art sheets
// (scripts/bake_foregrounds.py: ten, five scenes by two painters), chosen by
// the month and the day (foregroundIndex) or the "foreground" setting, drawn
// over everything but the grain. The two script-painted foreground masses
// (fg_left / fg_right, sized by the window's ends) are gone.
//
// 2026-11-05, later: the far range (the horizon), the two mist bands and
// the near hills are pieces of the ChatGPT strip sheet (scripts/
// bake_planes.py), the last script-painted art gone but the paper grain.
// Their sizes, crests and loaders are generated
// (JapaneseInkHeartratePlanes.mc); the placement is unchanged.
//
// 2026-11-05, evening: the props (scripts/bake_props.py), each by one rule
// so a prop always means something (compose_preview.prop_rules): the sun,
// and the moon by its phase, on the arc in place of the drawn discs; geese
// when today's step goal is met; a village in a window with no
// mountain; a hiker on the highest workout summit clear of the time
// column; a lantern under 30% battery. Read once per scene job (five
// minutes), drawn 1:1.
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
    // (loadHorizon, loadShape, loadNear), drawn and dropped.
    var mMist as Graphics.BitmapType?;
    var mMistLite as Graphics.BitmapType?;
    var mPaperGrain as Graphics.BitmapType?;
    // Which plane set is in the graphics pool: -1 none, 0 day, 1 night.
    var mLoadedSet as Lang.Number = -1;

    // The relief of the current window (the pending relief job): the horizon's crest
    // y in px (negative = none), the masses in draw order as [left, top,
    // width, height, crestX, crestY, plane, flip, host] (M_* indices) and
    // the near hills as [left, top, width, height, plane].
    var mHorizonY as Lang.Float = -1.0;
    var mMasses as Lang.Array<Lang.Array<Lang.Float>>?;
    var mNear as Lang.Array<Lang.Array<Lang.Float>>?;

    // A scene refresh is split across onUpdate calls so the shape-library
    // search cannot consume one callback's watchdog budget. Setup gets its
    // own update, FIT_SHAPES_PER_UPDATE candidates are scored on each later
    // update, and painting gets one final update. The old buffered frame
    // remains visible until the replacement is complete.
    var mJobState as Lang.Number = 0;
    var mJobSceneKey as Lang.Number = -1;
    var mHasBufferedScene as Lang.Boolean = false;
    var mFitRuns as Lang.Array<Lang.Array<Lang.Float>>?;
    var mFitSmpX as Lang.Array<Lang.Float>?;
    var mFitSmpY as Lang.Array<Lang.Float>?;
    var mFitBase as Lang.Array<Lang.Float>?;
    var mFitHost as Lang.Number = -1;
    var mFitRunIndex as Lang.Number = 0;
    var mFitShapeIndex as Lang.Number = 0;
    var mFitBucketPx as Lang.Float = 0.0;
    var mFitFloorHr as Lang.Float = 0.0;
    var mFitFloorY as Lang.Float = 0.0;
    var mFitScale as Lang.Float = 1.0;
    var mFitWidth as Lang.Float = 0.0;
    var mFitHeight as Lang.Float = 0.0;
    var mFitRunX0 as Lang.Float = 0.0;
    var mFitRunX1 as Lang.Float = 0.0;
    var mFitSummitX as Lang.Float = 0.0;
    var mFitCrestY as Lang.Float = 0.0;
    var mFitHasBest as Lang.Boolean = false;
    var mFitBestErr as Lang.Float = 0.0;
    var mFitBestIndex as Lang.Number = -1;
    var mFitBestLeft as Lang.Float = 0.0;
    var mFitBestStretch as Lang.Float = 1.0;
    var mFitStretchLo as Lang.Float = 0.67;

    // The near hills by index (P_NEAR*): width/height of the PNG and the
    // painted crest inside it (JapaneseInkHeartratePlanes.mc, measured by the
    // bake as compose_preview.measure_apex does), read once.
    var mPlaneAspect as Lang.Array<Lang.Float> = [] as Lang.Array<Lang.Float>;
    var mPlaneApexX as Lang.Array<Lang.Float> = [] as Lang.Array<Lang.Float>;
    var mPlaneApexY as Lang.Array<Lang.Float> = [] as Lang.Array<Lang.Float>;
    // The shape library's profile table (JapaneseInkHeartrateShapes.mc),
    // read once.
    var mShapeW as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mShapeH as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mShapeAx as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mShapeAy as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mShapeTop as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    // The ridge trees' size table (JapaneseInkHeartrateTrees.mc), read once,
    // and this scene's trees as [left, top, tree, size], drawn 1:1.
    var mTreeSizes as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mTreeFoot as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mTrees as Lang.Array<Lang.Array<Lang.Number>>?;
    // px: the apex is tried this far from the run's summit (FIT_SLIDE)
    var mFitSlide as Lang.Array<Lang.Float> = [0.0, -12.0, 12.0, -24.0, 24.0] as Lang.Array<Lang.Float>;
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
    // The seal carries the live HR (true) or the date ("Red seal = HR" off).
    var mSealHr as Lang.Boolean = true;
    // Each piece's own toggle (lantern, geese, hiker, village),
    // and the hour in kanji (false = brush digits; the View asks).
    var mShowLantern as Lang.Boolean = true;
    var mShowGeese as Lang.Boolean = true;
    var mShowHiker as Lang.Boolean = true;
    var mShowVillage as Lang.Boolean = true;
    var mHourKanji as Lang.Boolean = true;
    var mShowSwallow as Lang.Boolean = true;
    // The weather painting behind the grasses (WX_*, WX_NONE for none),
    // read once per scene job; the "Weather" setting.
    var mWeather as Lang.Number = -1;
    var mShowWeather as Lang.Boolean = true;
    // The sky's cloud level, 0 (none) to 4 (cloudy), from the same
    // conditions (cloudLevel).
    var mCloudLevel as Lang.Number = 0;
    var mForeground as Lang.Number = 0;   // the "foreground" setting: 0 by season, 1..FG_SEASONS a scene
    // The props' inputs, read once per scene job (readPropInputs).
    var mStepsMet as Lang.Boolean = false;
    var mBatteryLow as Lang.Boolean = false;
    var mDayOfMonth as Lang.Number = 1;
    var mWorkout as Lang.Boolean = false;    // a recorded activity in the window (the hiker)
    var mNotified as Lang.Boolean = false;   // unread notifications (the swallow)
    // The seal's baseline: the profile's resting HR (0 = none), else the
    // window's floor; and whether the seal shows working (sealWork).
    var mRestingHr as Lang.Number = 0;
    var mFloor as Lang.Float = 0.0;
    var mSealWork as Lang.Boolean = false;
    var mPropW as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mPropH as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    // Today's sunrise and sunset, minutes after local midnight
    // (readSunTimes); 06:00 and 18:00 until the watch knows where it is.
    var mSunrise as Lang.Number = 360;
    var mSunset as Lang.Number = 1080;
    var mNight as Lang.Boolean = false;
    // Palette of the frame currently on screen. Once a completed frame
    // exists, a pending day/night scene does not recolor its inscription.
    var mDisplayedNight as Lang.Boolean = false;

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
    const WIDE_END_TOL = 5.0;     // a run whose ends differ by less leans neither way
    const FIT_HIGH = 25.0;        // px of rise over the floor that doubles a sample's weight
    const FIT_OVER_TOL = 3.0;     // px a shape may stand over the data before it pays extra ...
    const FIT_OVER_K = 2.0;       // ... this much per px: the art must not claim more effort
    const FIT_APEX_K = 1.0;       // error per px between a shape's apex and the run's summit
    const FIT_STRETCH_LO = 0.67;  // a shape's width is stretched to its run's width, within ...
    const FIT_STRETCH_HI = 1.5;   // ... this (compose_preview.FIT_STRETCH)
    const SUB_MAX = 4;            // separate efforts inside one run that each get a mass, at most ...
    const SUB_STRETCH_LO = 0.30;  // ... each stretched no narrower than this (compose_preview.SUB_STRETCH)
    const FOOT_Y = 0.80;          // a placed shape's bottom edge must reach this far down (H)
    const LIB_W = 416.0;          // the screen width the library was baked for
    const TREE_MAX = 3;           // ridge trees per window, at most ...
    const TREE_NEED = 9.0;        // ... each where the data stands this many px over the ridge ...
    const TREE_OVER = 3.0;        // ... the tallest baked size within this many px over the data ...
    const TREE_GAP = 16.0;        // ... this far from another tree (px) ...
    const TREE_SINK = 2;          // ... its foot this many px into the ridge
    const NEAR_CREST_Y = 0.60;    // the near range's crest (fraction of H)
    const NEAR_H = 0.21;          // its height (fraction of H) ...
    const NEAR_HR_SPAN = 30.0;    // ... up by almost half over this much of its third over the floor
    const NEAR_EMPTY = 0.25;      // a third with less mass cover than this is empty
    const CREST_LO_Y = 0.58;      // the crest scale: 45 bpm sits here (fraction of H) ...
    const CREST_HI_Y = 0.26;      // ... and 160 bpm here
    // (HORIZON_W, HORIZON_H, HORIZON_APEX_Y and the mist sizes are in
    // JapaneseInkHeartratePlanes.mc, generated by scripts/bake_planes.py.)

    const JOB_IDLE = 0;
    const JOB_FITTING = 1;
    const JOB_READY = 2;
    // Eight shapes = at most 48 placements in one active update, below the
    // measured-safe 52-placement experiment. Setup and final painting never
    // share that callback. Lowering this changes latency, not the winners.
    const FIT_SHAPES_PER_UPDATE = 8;

    // Near-hill indices (mPlane* tables, loadNear).
    const P_NEAR = 0;
    const P_NEAR2 = 1;

    // Run fields (runMass) and mass fields (mMasses).
    const R_LO = 0;
    const R_HI = 1;
    const R_BUCKETS = 2;
    const R_PEAK = 3;
    const R_ELEV = 4;
    const R_NX = 5;
    const R_LEAN_END = 6;
    // a piece (one mass to fit) is a run's fields and then these
    const P_X0 = 7;               // its span on the face, px ...
    const P_X1 = 8;
    const P_SX = 9;               // its summit x, px (-1: find it in the samples)
    const P_SUB = 10;             // 1: one effort of several in its run (narrower stretch)
    const P_HOST = 11;            // 1: the host mass (drawn last)
    const M_CX = 4;
    const M_CY = 5;
    const M_PLANE = 6;
    const M_FLIP = 7;
    const M_HOST = 8;
    const M_ELEV = 9;

    // The props (compose_preview's constants of the same names).
    const SYNODIC = 29.530588853;     // days from new moon to new moon
    const NEW_MOON_EPOCH = 947182440; // a new moon: 2000-01-06 18:14 UTC
    const MOON_NEW = 1.85;            // days either side of new moon with no moon ...
    const MOON_FULL = 1.85;           // ... and either side of full with the full moon
    const GEESE_Y = 0.21;             // the geese's middle (H) ...
    const GEESE_X_SUN_LEFT = 0.68;    // ... here (W) when the sun/moon is on the left half
    const GEESE_X_SUN_RIGHT = 0.45;   // ... here when it is on the right
    const VILLAGE_X = 0.50;           // a quiet window's village, its middle (W) ...
    const VILLAGE_FOOT = 0.92;        // ... its foot here (H), in the ground layer (John, 11-06)
    const HIKER_SINK = 7;             // px it sinks under the summit (stands just below it)
    const INSCRIPTION_BOX_X = 0.36;   // the time column and seal with their halos:
    const INSCRIPTION_BOX_Y = 0.60;   // x and y under these (W, H) take no prop
    // the low-battery lantern stands where John placed it on each
    // foreground (SPOT_LANTERN_X / _FOOT, scripts/bake_spots.py)
    const BATTERY_LOW = 30.0;         // percent under which the lantern shows
    const SEAL_WORK = 30.0;           // bpm over the resting baseline that turns the seal rectangular ...
    const SEAL_HYST = 8.0;            // ... and back to the oval this far under that
    const WIND_LEAVES = 8.0;          // m/s over which the leaves blow without a "windy" forecast
    const WX_STALE = 10800;           // s: an observation older than this shows no weather
    const CLOUDS_X = 0.64;            // a cloudy sky's cloud bank, its middle (W) ...
    const CLOUDS_Y = 0.145;           // ... and (H), clear of the time column
    // the cloud over the sun by level 1-3, its middle's offset (W, H) from
    // the sun's middle (compose_preview.CLOUD_OVER)
    const WISP_DX = 0.024;
    const WISP_DY = 0.043;
    const BAND_DX = 0.014;
    const BAND_DY = 0.029;
    const BANDS2_DX = 0.010;
    const BANDS2_DY = 0.010;
    const CLOUD_SPILL = 0.40;         // a cloud over the sun may fade this share of its width past the rim
    const MOON_MIST_DROP = 0.015;     // the moon behind cloud: its painting's middle this far (H) under the arc

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
    const PROBE_B_W = 439.0;     // shape_peak_cut.png
    const PROBE_B_H = 300.0;
    const PROBE_D_W = 310.0;     // shape_spire_cut.png
    const PROBE_D_H = 300.0;
    var mProbeFull as Graphics.BufferedBitmap?;
    var mProbePartial as Graphics.BufferedBitmap?;
    // How the scene buffer was made in probe mode: full (ALPHA_BLENDING_FULL
    // accepted), plain (that call threw; made without the option), none.
    var mProbeBufferNote as Lang.String = "none";

    function initialize() {
        mShapeW = shapeW();
        mShapeH = shapeH();
        mShapeAx = shapeApexX();
        mShapeAy = shapeApexY();
        mShapeTop = shapeTop();
        mTreeSizes = treeSizes();
        mPropW = propW();
        mPropH = propH();
        mPlaneAspect = planeAspect();
        mPlaneApexX = planeApexX();
        mPlaneApexY = planeApexY();
        mTreeFoot = treeFoot();
        readSettings();
        readPropInputs();
        mNight = computeNight();
        mDisplayedNight = mNight;
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

    function propNumber(key as Lang.String, fallback as Lang.Number, max as Lang.Number) as Lang.Number {
        var value = propValue(key);
        if (value instanceof Lang.Number || value instanceof Lang.Float) {
            var n = (value as Lang.Numeric).toNumber();
            if (n >= 0 && n <= max) { return n; }
        }
        return fallback;
    }

    function readSettings() as Void {
        mShowTrace = propBool("trueHrOverlay", true);
        mSealHr = propBool("sealHr", true);
        mShowLantern = propBool("lantern", true);
        mShowGeese = propBool("geese", true);
        mShowHiker = propBool("hiker", true);
        mShowVillage = propBool("village", true);
        mHourKanji = propBool("hourKanji", true);
        mShowWeather = propBool("weather", true);
        mShowSwallow = propBool("swallow", true);
        mForeground = propNumber("foreground", 0, FG_SEASONS);
    }

    // Which foreground shows (compose_preview.foreground_index): the season
    // from the month (Dec-Feb winter, Mar-May spring, Jun-Aug summer,
    // Sep-Nov autumn) unless the setting names a scene (1..FG_SEASONS), and
    // the painter alternating with the day of the month.
    // The wind's painting for the foreground's season (John, 11-06): dry
    // leaves in winter, cherry petals in spring, the maples otherwise; any
    // other weather unchanged (compose_preview.wind_painting).
    function seasonalWeather(wx as Lang.Number) as Lang.Number {
        if (wx != WX_WIND) { return wx; }
        var season = foregroundIndex() / FG_PAINTERS;
        if (season == 0) { return WX_WIND_SPRING; }
        if (season == 3) { return WX_WIND_WINTER; }
        return wx;
    }

    function foregroundIndex() as Lang.Number {
        var info = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var m = info.month;
        var month = (m instanceof Lang.Number) ? (m as Lang.Number) : 1;
        var day = info.day;
        var season = (mForeground >= 1 && mForeground <= FG_SEASONS) ? mForeground - 1
                     : ((month % 12) / 3 + 3) % 4;
        return season * FG_PAINTERS + day % FG_PAINTERS;
    }

    // The props' inputs, once per scene job: today's step goal, the
    // battery, the day of the month.
    function readPropInputs() as Void {
        mStepsMet = false;
        if (Toybox has :ActivityMonitor) {
            var info = ActivityMonitor.getInfo();
            if (info != null) {
                var steps = info.steps;
                var goal = info.stepGoal;
                if (steps != null && goal != null && goal > 0 && steps >= goal) {
                    mStepsMet = true;
                }
            }
        }
        var battery = System.getSystemStats().battery;
        mBatteryLow = battery < BATTERY_LOW;
        var day = Time.Gregorian.info(Time.now(), Time.FORMAT_SHORT).day;
        mDayOfMonth = (day instanceof Lang.Number) ? (day as Lang.Number) : 1;
        mWeather = readWeather();
        readSunTimes();
        mWorkout = workoutInWindow();
        var notes = System.getDeviceSettings().notificationCount;
        mNotified = (notes != null && notes > 0);
        mRestingHr = 0;
        if (Toybox has :UserProfile) {
            var profile = UserProfile.getProfile();
            if (profile != null && (profile has :restingHeartRate)) {
                var rest = profile.restingHeartRate;
                if (rest != null && rest > 0) {
                    mRestingHr = rest;
                }
            }
        }
    }

    // The seal under the time works (the rectangle) once the latest HR stands
    // SEAL_WORK over the baseline, and rests (the oval) once it falls
    // SEAL_HYST under that again, so it does not flicker on the line
    // (compose_preview.seal_shape). Called by the View on every update.
    // The weather painting for now (compose_preview.weather_veil): the
    // current conditions' painting, else the leaves when the wind is over
    // WIND_LEAVES; none when the observation is stale or missing.
    function readWeather() as Lang.Number {
        mCloudLevel = 0;
        if (!(Toybox has :Weather)) { return WX_NONE; }
        var cc = Weather.getCurrentConditions();
        if (cc == null) { return WX_NONE; }
        var obs = cc.observationTime;
        if (obs != null && Time.now().value() - obs.value() > WX_STALE) { return WX_NONE; }
        var veil = WX_NONE;
        var c = cc.condition;
        if (c != null) {
            veil = weatherForCondition(c);
            mCloudLevel = cloudLevel(c);
        }
        if (veil == WX_NONE) {
            var wind = cc.windSpeed;
            if (wind != null && wind >= WIND_LEAVES) { veil = WX_WIND; }
        }
        return veil;
    }

    // A storm over snow over rain over light rain; then wind.
    function weatherForCondition(c as Lang.Number) as Lang.Number {
        if (c == Weather.CONDITION_THUNDERSTORMS || c == Weather.CONDITION_SCATTERED_THUNDERSTORMS
            || c == Weather.CONDITION_TORNADO || c == Weather.CONDITION_HURRICANE
            || c == Weather.CONDITION_TROPICAL_STORM) {
            return WX_STORM;
        }
        if (c == Weather.CONDITION_SNOW || c == Weather.CONDITION_WINTRY_MIX
            || c == Weather.CONDITION_LIGHT_SNOW || c == Weather.CONDITION_HEAVY_SNOW
            || c == Weather.CONDITION_LIGHT_RAIN_SNOW || c == Weather.CONDITION_HEAVY_RAIN_SNOW
            || c == Weather.CONDITION_RAIN_SNOW || c == Weather.CONDITION_ICE
            || c == Weather.CONDITION_FLURRIES || c == Weather.CONDITION_SLEET
            || c == Weather.CONDITION_ICE_SNOW) {
            return WX_SNOW;
        }
        if (c == Weather.CONDITION_RAIN || c == Weather.CONDITION_HAIL
            || c == Weather.CONDITION_HEAVY_RAIN || c == Weather.CONDITION_HEAVY_SHOWERS
            || c == Weather.CONDITION_FREEZING_RAIN) {
            return WX_RAIN;
        }
        if (c == Weather.CONDITION_SCATTERED_SHOWERS || c == Weather.CONDITION_UNKNOWN_PRECIPITATION
            || c == Weather.CONDITION_LIGHT_RAIN || c == Weather.CONDITION_LIGHT_SHOWERS
            || c == Weather.CONDITION_SHOWERS || c == Weather.CONDITION_DRIZZLE) {
            return WX_RAIN_LIGHT;
        }
        if (c == Weather.CONDITION_WINDY || c == Weather.CONDITION_SQUALL) {
            return WX_WIND;
        }
        return WX_NONE;
    }

    // The sky's cloud level (compose_preview.cloud_level), by Garmin's own
    // names: 4 cloudy or a chance of rain or snow, 3 mostly cloudy, 2
    // partly cloudy, 1 thin clouds, partly clear, mist, haze or smoke; 0.
    function cloudLevel(c as Lang.Number) as Lang.Number {
        if (c == Weather.CONDITION_CLOUDY
            || c == Weather.CONDITION_CHANCE_OF_SHOWERS || c == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS
            || c == Weather.CONDITION_CHANCE_OF_SNOW || c == Weather.CONDITION_CHANCE_OF_RAIN_SNOW
            || c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN || c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW
            || c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW) {
            return 4;
        }
        if (c == Weather.CONDITION_MOSTLY_CLOUDY) { return 3; }
        if (c == Weather.CONDITION_PARTLY_CLOUDY) { return 2; }
        if (c == Weather.CONDITION_PARTLY_CLEAR
            || c == Weather.CONDITION_THIN_CLOUDS || c == Weather.CONDITION_FOG
            || c == Weather.CONDITION_HAZY || c == Weather.CONDITION_MIST
            || c == Weather.CONDITION_HAZE || c == Weather.CONDITION_SMOKE
            || c == Weather.CONDITION_DUST || c == Weather.CONDITION_SAND
            || c == Weather.CONDITION_SANDSTORM || c == Weather.CONDITION_VOLCANIC_ASH) {
            return 1;
        }
        return 0;
    }

    // Today's sunrise and sunset where the weather was observed, else where
    // the watch last was (both need the Positioning permission). Kept from
    // the last good read when neither is known.
    function readSunTimes() as Void {
        if (!(Toybox has :Weather) || !(Weather has :getSunrise)) { return; }
        var loc = null;
        var cc = Weather.getCurrentConditions();
        if (cc != null) { loc = cc.observationLocationPosition; }
        if (loc == null) {
            var info = Activity.getActivityInfo();
            if (info != null) { loc = info.currentLocation; }
        }
        if (loc == null) { return; }
        var now = Time.now();
        var rise = Weather.getSunrise(loc, now);
        var fall = Weather.getSunset(loc, now);
        if (rise == null || fall == null) { return; }
        var r = minuteOf(rise);
        var f = minuteOf(fall);
        if (r < f) {
            mSunrise = r;
            mSunset = f;
        }
    }

    // A moment as minutes after local midnight.
    function minuteOf(m as Time.Moment) as Lang.Number {
        var info = Time.Gregorian.info(m, Time.FORMAT_SHORT);
        return (info.hour as Lang.Number) * 60 + (info.min as Lang.Number);
    }

    // A recorded activity (a workout saved on the watch) that overlaps the
    // four hours on the face: the hiker's rule. The heart rate alone said
    // "workout" on a lazy day (John, 11-06).
    function workoutInWindow() as Lang.Boolean {
        if (!(Toybox has :UserProfile) || !(UserProfile has :getUserActivityHistory)) { return false; }
        var since = Time.now().value() - HISTORY_SECONDS;
        var it = UserProfile.getUserActivityHistory();
        if (it == null) { return false; }
        var a = it.next();
        while (a != null) {
            var start = a.startTime;
            if (start != null) {
                var end = start.value();
                var dur = a.duration;
                if (dur != null) { end += dur.value(); }
                if (end >= since) { return true; }
            }
            a = it.next();
        }
        return false;
    }

    // The weather painting showing, or WX_NONE (the setting off, or none).
    function weatherShown() as Lang.Number {
        return mShowWeather ? mWeather : WX_NONE;
    }

    function sealShowsHr() as Lang.Boolean {
        return mSealHr;
    }

    // The hour in kanji numerals (true) or the brush digits ("Hour in
    // kanji" off). Called by the View on every update.
    function hourInKanji() as Lang.Boolean {
        return mHourKanji;
    }

    function sealWork() as Lang.Boolean {
        var hr = mLatestHr;
        var base = (mRestingHr > 0) ? mRestingHr.toFloat() : mFloor;
        if (hr == null || base <= 0.0) {
            mSealWork = false;
        } else if (hr.toFloat() >= base + SEAL_WORK) {
            mSealWork = true;
        } else if (hr.toFloat() < base + SEAL_WORK - SEAL_HYST) {
            mSealWork = false;
        }
        return mSealWork;
    }

    // The moon's prop now (compose_preview.moon_prop): -1 near new moon,
    // PROP_MOON_FULL near full, else the waxing or waning crescent.
    function moonProp() as Lang.Number {
        var days = (Time.now().value() - NEW_MOON_EPOCH).toFloat() / 86400.0;
        var age = days - (days / SYNODIC).toNumber() * SYNODIC;   // days > 0: truncation is floor
        var half = SYNODIC / 2.0;
        if (age < MOON_NEW || age > SYNODIC - MOON_NEW) { return -1; }
        var off = age - half;
        if (off < 0.0) { off = -off; }
        if (off <= MOON_FULL) { return PROP_MOON_FULL; }
        return (age < half) ? PROP_MOON_WAXING : PROP_MOON_WANING;
    }

    // A prop at (x, y), its top-left, 1:1; skipped when the pool refuses it.
    function drawProp(dc as Graphics.Dc, i as Lang.Number, x as Lang.Number, y as Lang.Number) as Void {
        var bmp = null;
        try {
            bmp = loadPropBitmap(i, mNight);
        } catch (ex) {
            bmp = null;
        }
        if (bmp != null) {
            dc.drawBitmap(x, y, bmp);
        }
    }

    // The sun or moon's x on the arc (drawCelestial), for the geese's side.
    function celestialX(width as Lang.Number) as Lang.Number {
        var t = arcT(minuteNow());
        return (width * 20) / 100 + ((width * 60) / 100 * t).toNumber();
    }

    // ... and its y.
    function celestialY(height as Lang.Number) as Lang.Number {
        var t = arcT(minuteNow());
        return (height * 14) / 100 - (Math.sin(t * 3.14159) * (height * 6) / 100).toNumber();
    }

    function minuteNow() as Lang.Number {
        var clockTime = System.getClockTime();
        return (clockTime.hour * 60) + clockTime.min;
    }

    // Night from sunset to sunrise (readSunTimes).
    function nightAt(minute as Lang.Number) as Lang.Boolean {
        return minute < mSunrise || minute >= mSunset;
    }

    // Where the sun or moon is on its arc, 0..1 west to east: the sun from
    // sunrise to sunset, the moon from sunset to the next sunrise
    // (compose_preview.arc_t).
    function arcT(minute as Lang.Number) as Lang.Float {
        if (!nightAt(minute)) {
            return (minute - mSunrise).toFloat() / (mSunset - mSunrise).toFloat();
        }
        var into = (minute >= mSunset) ? minute - mSunset : minute + 1440 - mSunset;
        return into.toFloat() / (1440 - (mSunset - mSunrise)).toFloat();
    }

    // The village in a window with a horizon and no mountain: large and
    // low, just behind the foreground (John, 11-06; the hut is out).
    function drawVillage(dc as Graphics.Dc, w as Lang.Float, h as Lang.Float) as Void {
        var masses = mMasses;
        if (!mShowVillage) { return; }
        if (mHorizonY < 0.0 || (masses != null && masses.size() > 0)) { return; }
        drawProp(dc, PROP_VILLAGE, (VILLAGE_X * w - mPropW[PROP_VILLAGE] / 2.0).toNumber(),
                 (VILLAGE_FOOT * h - mPropH[PROP_VILLAGE]).toNumber());
    }

    // The hiker, while a recorded workout overlaps the window, on the
    // highest summit whose hiker would be clear of the time column; the
    // geese for the step goal, on the side away from the sun or moon; the
    // swallow for unread notifications, at its spot (bake_spots.py).
    function drawAirProps(dc as Graphics.Dc, width as Lang.Number, w as Lang.Float, h as Lang.Float) as Void {
        var masses = mMasses;
        if (masses != null && mShowHiker && mWorkout) {
            var bw = mPropW[PROP_HIKER];
            var bh = mPropH[PROP_HIKER];
            var best = -1;
            var bestY = 0.0;
            for (var i = 0; i < masses.size(); i++) {
                var m = masses[i];
                var x = m[M_CX] - bw / 2.0;
                var y = m[M_CY] - bh + HIKER_SINK;
                if (x < INSCRIPTION_BOX_X * w && y < INSCRIPTION_BOX_Y * h) { continue; }
                if (best < 0 || m[M_CY] < bestY) {
                    best = i;
                    bestY = m[M_CY];
                }
            }
            if (best >= 0) {
                var m = masses[best];
                drawProp(dc, PROP_HIKER, (m[M_CX] - bw / 2.0).toNumber(),
                         (m[M_CY] - bh + HIKER_SINK).toNumber());
            }
        }
        if (mStepsMet && mShowGeese) {
            var gx = (celestialX(width) < width / 2) ? GEESE_X_SUN_LEFT : GEESE_X_SUN_RIGHT;
            drawProp(dc, PROP_GEESE, (gx * w - mPropW[PROP_GEESE] / 2.0).toNumber(),
                     (GEESE_Y * h - mPropH[PROP_GEESE] / 2.0).toNumber());
        }
        if (mNotified && mShowSwallow) {
            var sx = SPOT_SWALLOW_X * w / SPOT_FACE;
            var sy = SPOT_SWALLOW_FOOT * h / SPOT_FACE;
            drawProp(dc, PROP_SWALLOW, (sx - mPropW[PROP_SWALLOW] / 2.0).toNumber(),
                     (sy - mPropH[PROP_SWALLOW]).toNumber());
        }
    }

    // Night mode (black paper, pale ink) from sunset to sunrise; no setting
    // (John, 11-06).
    function computeNight() as Lang.Boolean {
        return nightAt(minuteNow());
    }

    function isNight() as Lang.Boolean {
        return mDisplayedNight;
    }

    function isProbe() as Lang.Boolean {
        return PROBE;
    }

    // Settings changed (or anything else that must repaint before the next
    // five-minute key): forget the buffer's key so the next draw re-renders.
    function invalidate() as Void {
        mLastSceneKey = -1;
        cancelSceneJob();
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
        mPaperGrain = null;
        if (set == 1) {
            mMist = loadMistBitmap(false, true);
            mMistLite = loadMistBitmap(true, true);
            // No grain on the night paper: black stays black.
        } else {
            mMist = loadMistBitmap(false, false);
            mMistLite = loadMistBitmap(true, false);
            mPaperGrain = WatchUi.loadResource(Rez.Drawables.PaperGrainTuned) as Graphics.BitmapType;
        }
        mLoadedSet = set;
    }

    // The day's foreground painting, loaded for one render (null when refused).
    function loadForeground(i as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {
        var bmp = null;
        try {
            bmp = loadForegroundBitmap(i, night);
        } catch (ex) {
            bmp = null;
        }
        return bmp;
    }

    // A near-hill cutout, loaded for one render. Null when the pool refuses
    // it: that hill is skipped and the face stays alive.
    function loadNear(p as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {
        var bmp = null;
        try {
            bmp = loadNearBitmap(p, night);
        } catch (ex) {
            bmp = null;
        }
        return bmp;
    }

    // A library shape's cutout, loaded for one render (null when refused).
    function loadShape(i as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {
        var bmp = null;
        try {
            bmp = loadShapeBitmap(i, night);
        } catch (ex) {
            bmp = null;
        }
        return bmp;
    }

    // A ridge tree at one baked size, loaded for one render (null when refused).
    function loadTree(i as Lang.Number, k as Lang.Number, night as Lang.Boolean) as Graphics.BitmapType? {
        var bmp = null;
        try {
            bmp = loadTreeBitmap(i, k, night);
        } catch (ex) {
            bmp = null;
        }
        return bmp;
    }

    function loadHorizon(night as Lang.Boolean) as Graphics.BitmapType? {
        var bmp = null;
        try {
            bmp = loadHorizonBitmap(night);
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

    // What one sample costs when the top of the ink there is py: the
    // distance to the data, weighted up on high ground, and more where the
    // ink stands over the data (compose_preview.fit_cost).
    function fitCost(py as Lang.Float, y as Lang.Float, floorY as Lang.Float) as Lang.Float {
        var rise = floorY - y;
        var wgt = 1.0 + ((rise > 0.0) ? rise / FIT_HIGH : 0.0);
        var diff = py - y;
        var c = ((diff < 0.0) ? -diff : diff) * wgt;
        if (diff < -FIT_OVER_TOL) { c += FIT_OVER_K * (-FIT_OVER_TOL - diff); }
        return c;
    }

    // Score one library shape for the current run, its width stretched so
    // that the part of it over the far bank is as wide as the run (within
    // FIT_STRETCH_LO..HI; the height never changes). Shapes and placements are
    // visited in exactly the same order as compose_preview.fit_shape. The
    // strict comparison keeps the first candidate on a tie, even though the
    // search is now spread across updates. fitCost is inlined in the hot loop
    // to reduce each chunk's watchdog cost without changing its arithmetic.
    function scoreFitShape(i as Lang.Number) as Void {
        var smpX = mFitSmpX;
        var smpY = mFitSmpY;
        var base = mFitBase;
        if (smpX == null || smpY == null || base == null) { return; }

        var s = mFitScale;
        var top0 = mFitCrestY - mShapeAy[i] * s;
        if (top0 + mShapeH[i] * s < FOOT_Y * mFitHeight) { return; }

        var tops = mShapeTop;
        var slides = mFitSlide.size();
        var topBase = i * SHAPE_K;

        // the stretch: the shape's columns over the far bank span the run
        var vis = 0;
        for (var k = 0; k < SHAPE_K; k++) {
            var tk = tops[topBase + k];
            if (tk >= 0 && top0 + tk * s < mFitFloorY) { vis++; }
        }
        if (vis < 1) { vis = 1; }
        var st = (mFitRunX1 - mFitRunX0) * SHAPE_K / (vis * mShapeW[i] * s);
        if (st < mFitStretchLo) { st = mFitStretchLo; }
        if (st > FIT_STRETCH_HI) { st = FIT_STRETCH_HI; }
        var sw = mShapeW[i] * s * st;
        var ax = mShapeAx[i] * s * st;
        for (var p = 0; p <= slides; p++) {
            var left = (p < slides) ? mFitSummitX + mFitSlide[p] - ax :
                       0.5 * (mFitRunX0 + mFitRunX1) - 0.5 * sw;
            var off = left + ax - mFitSummitX;
            var err = FIT_APEX_K * ((off < 0.0) ? -off : off);
            for (var j = 0; j < smpX.size(); j++) {
                var d = smpX[j] - left;
                if (d >= sw) { break; }
                if (d >= 0.0) {
                    var t = tops[topBase + (d * SHAPE_K / sw).toNumber()];
                    if (t >= 0) {
                        var py = top0 + t * s;
                        if (py < mFitFloorY) {
                            var y = smpY[j];
                            var rise = mFitFloorY - y;
                            var wgt = 1.0 + ((rise > 0.0) ? rise / FIT_HIGH : 0.0);
                            var diff = py - y;
                            var cost = ((diff < 0.0) ? -diff : diff) * wgt;
                            if (diff < -FIT_OVER_TOL) {
                                cost += FIT_OVER_K * (-FIT_OVER_TOL - diff);
                            }
                            err += cost - base[j];
                        }
                    }
                }
            }
            if (!mFitHasBest || err < mFitBestErr) {
                mFitHasBest = true;
                mFitBestErr = err;
                mFitBestIndex = i;
                mFitBestLeft = left;
                mFitBestStretch = st;
            }
        }
    }

    // The first index of the lowest value in arr[a..b].
    function lowestIn(arr as Lang.Array<Lang.Float>, a as Lang.Number, b as Lang.Number) as Lang.Number {
        var best = a;
        for (var k = a + 1; k <= b; k++) {
            if (arr[k] < arr[best]) { best = k; }
        }
        return best;
    }

    // The separate efforts inside one run, from the stored trace (about four
    // minutes a sample, where a bucket is fifteen): [[nx, bpm, nx0, nx1]] in
    // time order, each a local high standing MASS_MIN over the floor and
    // parted from its neighbor by a dip of VALLEY_MIN under the lower of the
    // two; nx0..nx1 is its share of the run, cut at the dips. Empty when the
    // run is one effort (2026-11-06: four 5-minute intervals painted as one
    // block). compose_preview.trace_peaks, step for step.
    function traceSubPeaks(floor as Lang.Float, x0 as Lang.Float, x1 as Lang.Float) as Lang.Array<Lang.Array<Lang.Float>> {
        var none = [] as Lang.Array<Lang.Array<Lang.Float>>;
        var nxs = mTraceNx;
        var hrs = mTraceHr;
        if (nxs == null || hrs == null) { return none; }
        var px = [] as Lang.Array<Lang.Float>;
        var ph = [] as Lang.Array<Lang.Float>;
        for (var i = 0; i < nxs.size() && i < hrs.size(); i++) {
            if (nxs[i] >= x0 && nxs[i] <= x1) {
                px.add(nxs[i]);
                ph.add(HR_MIN + hrs[i] * (HR_MAX - HR_MIN));
            }
        }
        if (px.size() < 3) { return none; }
        var pk = [] as Lang.Array<Lang.Number>;   // the index of each effort's high
        for (var i = 0; i < px.size(); i++) {
            var hr = ph[i];
            if (pk.size() == 0) {
                if (hr - floor >= MASS_MIN) { pk.add(i); }
                continue;
            }
            var last = pk[pk.size() - 1];
            var top = ph[last];
            var dip = lowestIn(ph, last, i);
            var lower = (top < hr) ? top : hr;
            if (hr > top && dip == last) {
                pk[pk.size() - 1] = i;            // still climbing the same effort
            } else if (hr - floor >= MASS_MIN && lower - ph[dip] >= VALLEY_MIN) {
                pk.add(i);                        // a new effort past a real dip
            } else if (hr > top) {
                pk[pk.size() - 1] = i;            // a shallow dip: the same effort, higher
            }
        }
        if (pk.size() < 2) { return none; }
        // keep the SUB_MAX highest (of equals, the earlier), in time order
        while (pk.size() > SUB_MAX) {
            var drop = 0;
            for (var k = 1; k < pk.size(); k++) {
                if (ph[pk[k]] <= ph[pk[drop]]) { drop = k; }
            }
            pk.remove(pk[drop]);
        }
        var out = [] as Lang.Array<Lang.Array<Lang.Float>>;
        for (var k = 0; k < pk.size(); k++) {
            var a = x0;
            if (k > 0) { a = px[lowestIn(ph, pk[k - 1], pk[k])]; }
            var b = x1;
            if (k < pk.size() - 1) { b = px[lowestIn(ph, pk[k], pk[k + 1])]; }
            out.add([px[pk[k]], ph[pk[k]], a, b] as Lang.Array<Lang.Float>);
        }
        return out;
    }

    // Draw order: the other masses first (the taller farther), the host last.
    function massAfter(a as Lang.Array<Lang.Float>, b as Lang.Array<Lang.Float>) as Lang.Boolean {
        if (a[M_HOST] != b[M_HOST]) { return a[M_HOST] > b[M_HOST]; }
        return a[M_CY] > b[M_CY];
    }

    // Build the cheap, immutable half of a fit job. No library shape is
    // scored in this callback; advanceReliefJob does that on later updates.
    function startReliefJob(w as Lang.Float, h as Lang.Float) as Void {
        mHorizonY = -1.0;
        mTrees = null;
        var masses = [] as Lang.Array<Lang.Array<Lang.Float>>;
        var near = [] as Lang.Array<Lang.Array<Lang.Float>>;
        mMasses = masses;
        mNear = near;
        var history = mHistory;
        if (history == null) {
            mJobState = JOB_READY;
            return;
        }
        var floor = floorLevel(history);
        mFloor = floor;
        if (floor <= 0.0) {
            mJobState = JOB_READY;
            return;
        }
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

        // the pieces to fit: a run's separate efforts (traceSubPeaks), one
        // each, else the run whole; the host run's highest piece (the
        // first, on a tie) is the host
        var pieces = [] as Lang.Array<Lang.Array<Lang.Float>>;
        for (var i = 0; i < runs.size(); i++) {
            var r = runs[i];
            var x0 = (r[R_LO] - 0.5) / denom;
            var x1 = (r[R_HI] + 0.5) / denom;
            var subs = traceSubPeaks(floor, x0, x1);
            var first = pieces.size();
            if (subs.size() > 0) {
                for (var k = 0; k < subs.size(); k++) {
                    var sb = subs[k];
                    pieces.add([r[R_LO], r[R_HI], r[R_BUCKETS], sb[1], sb[1] - floor, r[R_NX], r[R_LEAN_END],
                                sb[2] * w, sb[3] * w, sb[0] * w, 1.0, 0.0] as Lang.Array<Lang.Float>);
                }
            } else {
                pieces.add([r[R_LO], r[R_HI], r[R_BUCKETS], r[R_PEAK], r[R_ELEV], r[R_NX], r[R_LEAN_END],
                            x0 * w, x1 * w, -1.0, 0.0, 0.0] as Lang.Array<Lang.Float>);
            }
            if (i == host) {
                var top = first;
                for (var k = first + 1; k < pieces.size(); k++) {
                    if (pieces[k][R_PEAK] > pieces[top][R_PEAK]) { top = k; }
                }
                pieces[top][P_HOST] = 1.0;
            }
        }

        // the samples the fit scores: the stored trace, else the buckets
        var smpX = [] as Lang.Array<Lang.Float>;
        var smpY = [] as Lang.Array<Lang.Float>;
        var nxs = mTraceNx;
        var hrs = mTraceHr;
        if (nxs != null && hrs != null && nxs.size() > 0) {
            for (var i = 0; i < nxs.size() && i < hrs.size(); i++) {
                smpX.add(w * axisX(nxs[i]));
                smpY.add(traceY(hrs[i], h));
            }
        } else {
            for (var i = 0; i < history.size(); i++) {
                if (history[i] > 0.0) {
                    smpX.add(w * axisX(i / denom));
                    smpY.add(crestY(heightForHr(history[i]), h));
                }
            }
        }
        var floorY = mHorizonY;
        var s = w / LIB_W;
        var base = [] as Lang.Array<Lang.Float>;
        for (var j = 0; j < smpY.size(); j++) { base.add(fitCost(floorY, smpY[j], floorY)); }

        mFitRuns = pieces;
        mFitSmpX = smpX;
        mFitSmpY = smpY;
        mFitBase = base;
        mFitHost = host;
        mFitRunIndex = 0;
        mFitShapeIndex = 0;
        mFitBucketPx = bucketPx;
        mFitFloorHr = floor;
        mFitFloorY = floorY;
        mFitScale = s;
        mFitWidth = w;
        mFitHeight = h;

        if (pieces.size() == 0) {
            finishReliefJob();
            mJobState = JOB_READY;
            return;
        }
        prepareFitRun();
        mJobState = JOB_FITTING;
    }

    // Cache the geometry shared by all SHAPE_COUNT candidates for one run.
    function prepareFitRun() as Void {
        var runs = mFitRuns;
        var smpX = mFitSmpX;
        var smpY = mFitSmpY;
        if (runs == null || smpX == null || smpY == null || mFitRunIndex >= runs.size()) {
            finishReliefJob();
            mJobState = JOB_READY;
            return;
        }
        var r = runs[mFitRunIndex];
        mFitRunX0 = r[P_X0];
        mFitRunX1 = r[P_X1];
        mFitCrestY = crestY(heightForHr(r[R_PEAK]), mFitHeight);
        mFitStretchLo = (r[P_SUB] > 0.5) ? SUB_STRETCH_LO : FIT_STRETCH_LO;

        // An effort's summit is its own high; a whole run's is its highest
        // sample inside it, else its centroid.
        if (r[P_SX] >= 0.0) {
            mFitSummitX = r[P_SX];
        } else {
            mFitSummitX = axisX(r[R_NX]) * mFitWidth;
            var found = false;
            var bestY = 0.0;
            for (var j = 0; j < smpX.size(); j++) {
                if (smpX[j] >= mFitRunX0 && smpX[j] <= mFitRunX1 &&
                    (!found || smpY[j] < bestY)) {
                    mFitSummitX = smpX[j];
                    bestY = smpY[j];
                    found = true;
                }
            }
        }
        mFitShapeIndex = 0;
        mFitHasBest = false;
        mFitBestErr = 0.0;
        mFitBestIndex = -1;
        mFitBestLeft = 0.0;
        mFitBestStretch = 1.0;
    }

    // Advance a fixed number of candidates. A chunk may finish one run and
    // continue into the next, but it never changes shape/placement order.
    function advanceReliefJob() as Void {
        if (mJobState != JOB_FITTING) { return; }
        var count = 0;
        while (count < FIT_SHAPES_PER_UPDATE && mJobState == JOB_FITTING) {
            scoreFitShape(mFitShapeIndex);
            mFitShapeIndex++;
            count++;
            if (mFitShapeIndex >= SHAPE_COUNT) {
                finishFitRun();
            }
        }
    }

    function finishFitRun() as Void {
        var runs = mFitRuns;
        var masses = mMasses;
        if (runs == null || masses == null || mFitRunIndex >= runs.size()) {
            finishReliefJob();
            mJobState = JOB_READY;
            return;
        }
        if (mFitHasBest) {
            var si = mFitBestIndex;
            var left = mFitBestLeft;
            var s = mFitScale;
            var sx = s * mFitBestStretch;
            var cy = mFitCrestY;
            masses.add([left, cy - mShapeAy[si] * s, mShapeW[si] * sx, mShapeH[si] * s,
                        left + mShapeAx[si] * sx, cy, si.toFloat(), 0.0,
                        runs[mFitRunIndex][P_HOST],
                        runs[mFitRunIndex][R_ELEV]] as Lang.Array<Lang.Float>);
        }

        mFitRunIndex++;
        if (mFitRunIndex >= runs.size()) {
            finishReliefJob();
            mJobState = JOB_READY;
        } else {
            prepareFitRun();
        }
    }

    // Complete the cheap layout work after every run has a winning shape.
    function finishReliefJob() as Void {
        var masses = mMasses;
        var near = mNear;
        var history = mHistory;
        if (masses == null || near == null || history == null) { return; }

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
        var w = mFitWidth;
        var h = mFitHeight;
        var bucketPx = mFitBucketPx;
        var floor = mFitFloorHr;
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

    // Up to TREE_MAX ridge trees (compose_preview.place_trees). Where a
    // sample of the data stands TREE_NEED or more over the painted ridge
    // (the topmost mass profile there, from the shape table), a tree stands
    // on the ridge: the most over first, TREE_GAP apart, at the tallest
    // baked size within TREE_OVER of the data. Which tree is (sample index
    // * 3 + pick) mod TREE_COUNT. Runs in the painting update, after the fit.
    function placeTrees() as Void {
        mTrees = null;
        var masses = mMasses;
        var smpX = mFitSmpX;
        var smpY = mFitSmpY;
        if (masses == null || smpX == null || smpY == null) { return; }
        var floorY = mFitFloorY;
        var n = smpX.size();
        var need = [] as Lang.Array<Lang.Float>;
        var ridge = [] as Lang.Array<Lang.Float>;
        for (var j = 0; j < n; j++) {
            var x = smpX[j];
            var top = 0.0;
            var found = false;
            for (var q = 0; q < masses.size(); q++) {
                var m = masses[q];
                var d = x - m[0];
                if (d < 0.0 || d >= m[2]) { continue; }
                var si = m[M_PLANE].toNumber();
                var t = mShapeTop[si * SHAPE_K + (d * SHAPE_K / m[2]).toNumber()];
                if (t < 0) { continue; }
                var py = m[1] + t * m[3] / mShapeH[si];
                if (py < floorY && (!found || py < top)) {
                    top = py;
                    found = true;
                }
            }
            need.add(found ? top - smpY[j] : -1.0);
            ridge.add(top);
        }

        var trees = [] as Lang.Array<Lang.Array<Lang.Number>>;
        var xs = [] as Lang.Array<Lang.Float>;
        var sizes = mTreeSizes;
        for (var pick = 0; pick < TREE_MAX; pick++) {
            var best = -1;
            for (var j = 0; j < n; j++) {
                if (need[j] < TREE_NEED) { continue; }
                var tooClose = false;
                for (var q = 0; q < xs.size(); q++) {
                    var dx = smpX[j] - xs[q];
                    if (dx < 0.0) { dx = -dx; }
                    if (dx < TREE_GAP) {
                        tooClose = true;
                        break;
                    }
                }
                if (tooClose) { continue; }
                if (best < 0 || need[j] > need[best]) { best = j; }
            }
            if (best < 0) { break; }
            var k = 0;
            for (var q = 0; q < sizes.size(); q++) {
                if (sizes[q] <= need[best] + TREE_OVER) { k = q; }
            }
            var i = (best * 3 + pick) % TREE_COUNT;
            var x = smpX[best];
            xs.add(x);
            trees.add([(x + 0.5).toNumber() - mTreeFoot[i * TREE_SIZES + k],
                       (ridge[best] + 0.5).toNumber() - sizes[k] + TREE_SINK,
                       i, k] as Lang.Array<Lang.Number>);
        }
        mTrees = trees;
    }

    function cancelSceneJob() as Void {
        mJobState = JOB_IDLE;
        mJobSceneKey = -1;
        mFitRuns = null;
        mFitSmpX = null;
        mFitSmpY = null;
        mFitBase = null;
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
        var width = dc.getWidth();
        var height = dc.getHeight();
        ensureBuffer(width, height);
        var sceneKey = getSceneKey();

        if (mBuffer == null) {
            drawWithoutBuffer(dc, width, height, sceneKey);
            return;
        }

        // Each branch is deliberately exclusive: setup, fitting and final
        // painting never share an onUpdate callback.
        if (mJobState == JOB_IDLE && sceneKey != mLastSceneKey) {
            startSceneJob(sceneKey, width, height);
        } else if (mJobState == JOB_FITTING) {
            advanceReliefJob();
        } else if (mJobState == JOB_READY) {
            finishBufferedScene();
        }

        var buffer = mBuffer;
        if (buffer != null) {
            dc.drawBitmap(0, 0, buffer);
        }
        if (PROBE) {
            drawProbeScreenTile(dc, dc.getWidth().toFloat(), dc.getHeight().toFloat());
        }
    }

    // Five-minute key. An hour boundary also changes the key; a coherent job
    // already in progress finishes first, then the next active update starts
    // the new day/night scene.
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
        mHasBufferedScene = false;
        cancelSceneJob();
    }

    function startSceneJob(sceneKey as Lang.Number, width as Lang.Number,
                           height as Lang.Number) as Void {
        mJobSceneKey = sceneKey;

        // Five-minute refresh tracks new history samples without doing the
        // iterator on every one-second update. It gets a callback of its own.
        readSettings();
        readPropInputs();
        mNight = computeNight();
        loadPlanes(mNight);
        refreshHistory();
        if (PROBE) {
            mJobState = JOB_READY;
        } else {
            startReliefJob(width.toFloat(), height.toFloat());
        }

        // A newly allocated buffer has no old frame to preserve. Give the
        // first few fit updates paper, sky and the data floor instead.
        var buffer = mBuffer;
        if (!mHasBufferedScene && buffer != null) {
            renderPendingScene(buffer.getDc(), width, height);
            mDisplayedNight = mNight;
        }
    }

    function finishBufferedScene() as Void {
        var buffer = mBuffer;
        if (buffer == null) { return; }
        placeTrees();
        renderScene(buffer.getDc(), mBufferWidth, mBufferHeight);
        mLastSceneKey = mJobSceneKey;
        mHasBufferedScene = true;
        mDisplayedNight = mNight;
        cancelSceneJob();
    }

    function drawWithoutBuffer(dc as Graphics.Dc, width as Lang.Number,
                               height as Lang.Number, sceneKey as Lang.Number) as Void {
        if (mJobState == JOB_IDLE && sceneKey != mLastSceneKey) {
            startSceneJob(sceneKey, width, height);
            renderPendingScene(dc, width, height);
            mDisplayedNight = mNight;
            return;
        }
        if (mJobState == JOB_FITTING) {
            advanceReliefJob();
            renderPendingScene(dc, width, height);
            return;
        }
        if (mJobState == JOB_READY) {
            placeTrees();
            renderScene(dc, width, height);
            mLastSceneKey = mJobSceneKey;
            mDisplayedNight = mNight;
            cancelSceneJob();
            return;
        }
        // No cache API: repaint the already-fitted scene, but never refit it.
        renderScene(dc, width, height);
    }

    function renderPendingScene(dc as Graphics.Dc, width as Lang.Number,
                                height as Lang.Number) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        drawPaper(dc);
        drawCelestial(dc, width, height);
        if (mHorizonY >= 0.0) {
            var horizon = loadHorizon(mNight);
            if (horizon != null) {
                var w = width.toFloat();
                var hzH = HORIZON_H * (w / HORIZON_W);
                dc.drawScaledBitmap(0, mHorizonY - HORIZON_APEX_Y * hzH, w, hzH, horizon);
            }
        }
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

        drawPaper(dc);
        // rain, a storm or snow replaces the sun or moon; the wind does not
        var wx = weatherShown();
        if (wx == WX_NONE || wx == WX_WIND) {
            drawSky(dc, width, height, mShowWeather ? mCloudLevel : 0);
        }

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

        // 3. the masses: library shapes, the host last (none on a flat day)
        var masses = mMasses;
        if (masses != null) {
            for (var i = 0; i < masses.size(); i++) {
                var m = masses[i];
                var bmp = loadShape(m[M_PLANE].toNumber(), mNight);
                if (bmp != null) {
                    dc.drawScaledBitmap(m[0], m[1], m[2], m[3], bmp);
                }
            }
        }

        // 3b. ridge trees where the data stands over the painted ridge, 1:1
        var trees = mTrees;
        if (trees != null) {
            for (var i = 0; i < trees.size(); i++) {
                var t = trees[i];
                var bmp = loadTree(t[2], t[3], mNight);
                if (bmp != null) {
                    dc.drawBitmap(t[0], t[1], bmp);
                }
            }
        }

        // 3c. the hiker on a workout's summit; the geese for the step goal
        drawAirProps(dc, width, w, h);

        // 3d. the weather: one whole-face painting behind the grasses, so
        //     the near hills, the mist and the foreground frame it
        if (wx != WX_NONE) {
            var wxBmp = null;
            try {
                wxBmp = loadWeatherBitmap(seasonalWeather(wx), mNight);
            } catch (ex) {
                wxBmp = null;
            }
            if (wxBmp != null) {
                dc.drawScaledBitmap(0, 0, width, height, wxBmp);
            }
        }

        // 4. the near range: a near hill in each third the masses leave empty
        var near = mNear;
        if (near != null) {
            for (var i = 0; i < near.size(); i++) {
                var n = near[i];
                var bmp = loadNear(n[4].toNumber(), mNight);
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

        // 5b. a quiet window's village, then the low-battery lantern where
        //     John placed it on this foreground, just behind it, so the
        //     painting's grass stands in front and blends them in
        drawVillage(dc, w, h);
        var fgi = foregroundIndex();
        if (mBatteryLow && mShowLantern) {
            var lx = (SPOT_LANTERN_X[fgi] as Lang.Number) * w / SPOT_FACE;
            var ly = (SPOT_LANTERN_FOOT[fgi] as Lang.Number) * h / SPOT_FACE;
            drawProp(dc, PROP_LANTERN, (lx - mPropW[PROP_LANTERN] / 2.0).toNumber(),
                     (ly - mPropH[PROP_LANTERN]).toNumber());
        }

        // 6. the foreground: one whole-face painting for the season and the
        //    day (foregroundIndex), over everything but the grain
        var fg = loadForeground(fgi, mNight);
        if (fg != null) {
            dc.drawScaledBitmap(0, 0, width, height, fg);
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
        var host = loadShape(SHAPE_PEAK, false);
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
        // (since 2026-11-05 the two bands are different strips of the sheet,
        // so C compares the tint against a different mist, not the same one)
        var offLX = (MIST_LITE_W - bW) / 2;
        var offLY = (MIST_LITE_H - cH) / 2;
        probeFrame(dc, bX, cY, bW, cH);
        probeFrame(dc, bX2, cY, bW, cH);
        dc.setColor(PROBE_GROUND, PROBE_GROUND);
        dc.fillRectangle(bX, cY, bW, cH);
        dc.fillRectangle(bX2, cY, bW, cH);
        var mistLite = mMistLite;
        if (mistLite != null) {
            dc.setClip(bX, cY, bW, cH);
            dc.drawBitmap(bX - offLX, cY - offLY, mistLite);
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
        var guest = loadShape(SHAPE_SPIRE, false);
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

    // The sun or moon and its cloud, one painting per cloud level, never a
    // cloud copied or moved (compose_preview.prop_rules; John, 11-06): by
    // day the sun under the wisp, the band or the two bands; by night the
    // moon veiled (levels 1-2) or hidden (3) in its own painting, nothing
    // at new moon; the bank alone, upper right, at 4.
    function drawSky(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number,
                     level as Lang.Number) as Void {
        var w = width.toFloat();
        var h = height.toFloat();
        if (level >= 4) {
            drawProp(dc, PROP_CLOUD_BANK, (CLOUDS_X * w - mPropW[PROP_CLOUD_BANK] / 2.0).toNumber(),
                     (CLOUDS_Y * h - mPropH[PROP_CLOUD_BANK] / 2.0).toNumber());
            return;
        }
        if (level <= 0) {
            drawCelestial(dc, width, height);
            return;
        }
        var x = celestialX(width);
        var y = celestialY(height);
        if (nightAt(minuteNow())) {
            var moon = mistyMoon(moonProp(), level >= 3);
            if (moon >= 0) {
                drawProp(dc, moon, x - mPropW[moon] / 2,
                         (y + MOON_MIST_DROP * h - mPropH[moon] / 2.0).toNumber());
            }
            return;
        }
        drawProp(dc, PROP_SUN, x - mPropW[PROP_SUN] / 2, y - mPropH[PROP_SUN] / 2);
        var cloud = PROP_CLOUD_WISP;
        var dx = WISP_DX;
        var dy = WISP_DY;
        if (level == 2) {
            cloud = PROP_CLOUD_BAND;
            dx = BAND_DX;
            dy = BAND_DY;
        } else if (level == 3) {
            cloud = PROP_CLOUD_BANDS2;
            dx = BANDS2_DX;
            dy = BANDS2_DY;
        }
        var cw = mPropW[cloud].toFloat();
        var cy = y + dy * h;
        var cx = cloudX(x + dx * w, cy, cw, w);
        drawProp(dc, cloud, (cx - cw / 2.0).toNumber(), (cy - mPropH[cloud] / 2.0).toNumber());
    }

    // The moon behind cloud for a moon prop (moonProp): veiled, or hidden
    // when thick; -1 stays -1 (new moon).
    function mistyMoon(moon as Lang.Number, thick as Lang.Boolean) as Lang.Number {
        if (moon == PROP_MOON_FULL) { return thick ? PROP_MOON_FULL_HIDDEN : PROP_MOON_FULL_VEIL; }
        if (moon == PROP_MOON_WAXING) { return thick ? PROP_MOON_WAXING_HIDDEN : PROP_MOON_WAXING_VEIL; }
        if (moon == PROP_MOON_WANING) { return thick ? PROP_MOON_WANING_HIDDEN : PROP_MOON_WANING_VEIL; }
        return -1;
    }

    // A cloud's middle x, moved off the time column and in from the rim
    // (compose_preview.cloud_x): cw its width, w the face's.
    function cloudX(cx as Lang.Float, cy as Lang.Float, cw as Lang.Float, w as Lang.Float) as Lang.Float {
        var r = w / 2.0;
        var lo = INSCRIPTION_BOX_X * w + cw / 2.0;
        var d = r * r - (cy - r) * (cy - r);
        if (d < 0.0) { d = 0.0; }
        var hi = r + Math.sqrt(d) - CLOUD_SPILL * cw;
        if (lo > hi) { return (lo + hi) / 2.0; }
        if (cx < lo) { return lo; }
        if (cx > hi) { return hi; }
        return cx;
    }

    // The sun arcs from sunrise to sunset, the moon from sunset to sunrise,
    // west to east on a sin parabola (arcT).
    function drawCelestial(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var isNight = nightAt(minuteNow());
        var x = celestialX(width);
        var y = celestialY(height);
        // The sun, or the moon by its phase (none near new moon): props from
        // the sheet, centered on the arc; the night cut in night mode.
        var prop = isNight ? moonProp() : PROP_SUN;
        if (prop >= 0) {
            drawProp(dc, prop, x - mPropW[prop] / 2, y - mPropH[prop] / 2);
        }
    }

}
