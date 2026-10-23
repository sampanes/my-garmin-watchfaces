using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Application;
using Toybox.FitContributor;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Position;
using Toybox.Sensor;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;
using Toybox.WatchUi;

// T19/T20: record a walk the way the pet's "walk with me" power would, then check what
// Garmin Connect shows. GPS and HR are NOT recorded unless the app enables them, so both
// are switched on explicitly before the session starts.
class WalkProbeView extends WatchUi.View {
    const SESSION_NAME = "Walk Probe";  // createSession suggests 15 characters at most.
    const MOOD_FIELD_ID = 0;            // Must match the fitField id in resources/fit.
    const MOOD_WRITE_SECONDS = 5;

    const STATE_IDLE = 0;
    const STATE_RECORDING = 1;
    const STATE_SAVED = 2;
    const STATE_DISCARDED = 3;
    const STATE_FAILED = 4;

    // How a recording ended. CLOSED means onStop arrived while recording: the watch shut
    // the app (T20), and the session was saved on the way out.
    const END_SELECT = 1;
    const END_BACK = 2;
    const END_CLOSED = 3;
    const END_MENU = 4;

    var mSession as ActivityRecording.Session?;
    var mMoodField as FitContributor.Field?;
    var mTimer as Timer.Timer?;
    var mGpsOn as Lang.Boolean = false;
    var mState as Lang.Number = STATE_IDLE;
    var mError as Lang.String = "";
    var mStartedAt as Lang.Number = 0;
    var mElapsed as Lang.Number = 0;
    var mQuality as Position.Quality = Position.QUALITY_NOT_AVAILABLE;
    var mFixes as Lang.Number = 0;      // Location events received while recording.
    var mHeartRate as Lang.Number = -1;
    var mMood as Lang.Number = 0;
    var mLastResult as Lang.String = "";
    var mLastDetail as Lang.String = "";

    // T20 evidence: how often and how long the screen went away while recording, and
    // whether location events kept arriving while it was away.
    var mHidden as Lang.Boolean = false;
    var mHiddenAt as Lang.Number = 0;
    var mHideCount as Lang.Number = 0;
    var mHiddenSeconds as Lang.Number = 0;
    var mHiddenFixes as Lang.Number = 0;

    function initialize() {
        View.initialize();
        var last = Application.Storage.getValue("last");
        if (last instanceof Lang.String) { mLastResult = last as Lang.String; }
        var detail = Application.Storage.getValue("last_detail");
        if (detail instanceof Lang.String) { mLastDetail = detail as Lang.String; }
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    // GPS starts as soon as the screen shows, so the fix can settle before START.
    function onShow() as Void {
        if (mHidden) {
            mHidden = false;
            var away = Time.now().value() - mHiddenAt;
            mHiddenSeconds += away;
            System.println("WALK_SHOW," + elapsedNow() + "," + away + "," + mHiddenFixes);
        }
        startGps();
        if (mTimer == null) {
            mTimer = new Timer.Timer();
            (mTimer as Timer.Timer).start(method(:onSecond), 1000, true);
        }
        WatchUi.requestUpdate();
    }

    // GPS and the timer are left running on purpose: T20 asks whether the track
    // continues while the app is not on screen.
    function onHide() as Void {
        if (mState == STATE_RECORDING && !mHidden) {
            mHidden = true;
            mHiddenAt = Time.now().value();
            mHideCount += 1;
            System.println("WALK_HIDE," + elapsedNow());
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;

        drawLine(dc, centerX, height * 13 / 100, "WALK PROBE", 0x3E7A62, [Graphics.FONT_XTINY]);
        drawLine(dc, centerX, height * 27 / 100, stateText(), Graphics.COLOR_WHITE,
                 [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawLine(dc, centerX, height * 41 / 100, "GPS " + qualityText(mQuality),
                 qualityColor(mQuality), [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawLine(dc, centerX, height * 55 / 100, elapsedText(), Graphics.COLOR_WHITE,
                 [Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM]);
        var hr = (mHeartRate > 0) ? mHeartRate.toString() : "--";
        drawLine(dc, centerX, height * 68 / 100, "HR " + hr + "   FIX " + mFixes,
                 Graphics.COLOR_WHITE, [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawLine(dc, centerX, height * 80 / 100, footerText(), Graphics.COLOR_LT_GRAY,
                 [Graphics.FONT_XTINY]);

        drawStartHint(dc);
    }

    function drawLine(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                      text as Lang.String, color as Lang.Number,
                      fonts as Lang.Array<Graphics.FontDefinition>) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, fitFont(dc, text, fonts, y), text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // A short arc on the rim beside START, as in Friend.
    function drawStartHint(dc as Graphics.Dc) as Void {
        var center = dc.getWidth() / 2;
        dc.setColor(0x6ED6A8, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(8);
        dc.drawArc(center, dc.getHeight() / 2, center - 6,
                   Graphics.ARC_COUNTER_CLOCKWISE, 22, 42);
    }

    function startGps() as Void {
        if (mGpsOn) { return; }
        try {
            // The plain LOCATION_CONTINUOUS form (API 1.0.0) picks no GNSS configuration;
            // the :configuration dictionary form (3.3.6) is not needed to prove the map.
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            mGpsOn = true;
            mQuality = Position.getInfo().accuracy;
        } catch (e) {
            mError = "NO GPS";
            System.println("WALK_GPS_ERROR," + e.getErrorMessage());
        }
    }

    function stopGps() as Void {
        var timer = mTimer;
        if (timer != null) { timer.stop(); }
        mTimer = null;
        if (!mGpsOn) { return; }
        mGpsOn = false;
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
        } catch (e) { }
    }

    function onPosition(info as Position.Info) as Void {
        mQuality = info.accuracy;
        if (mState == STATE_RECORDING) {
            mFixes += 1;
            if (mHidden) { mHiddenFixes += 1; }
        }
        WatchUi.requestUpdate();
    }

    function onSecond() as Void {
        readHeartRate();
        if (mState == STATE_RECORDING) {
            mElapsed = elapsedNow();
            if ((mElapsed % MOOD_WRITE_SECONDS) == 0) { writeMood(); }
        }
        WatchUi.requestUpdate();
    }

    function readHeartRate() as Void {
        try {
            var heartRate = Sensor.getInfo().heartRate;
            mHeartRate = (heartRate != null) ? (heartRate as Lang.Number) : -1;
        } catch (e) { }
    }

    function isRecording() as Lang.Boolean {
        return mState == STATE_RECORDING;
    }

    // Keep end-reason constants private to the view. Monkey C class constants are
    // not static members, so callers use these named actions instead.
    function finishFromStart() as Void {
        finish(END_SELECT);
    }

    function finishFromBack() as Void {
        finish(END_BACK);
    }

    function finishFromSystemClose() as Void {
        finish(END_CLOSED);
    }

    // Recording starts even without a fix; the route simply begins at the first fix.
    function startRecording() as Void {
        if (!(Toybox has :ActivityRecording)) {
            mState = STATE_FAILED;
            mError = "NO REC API";
            WatchUi.requestUpdate();
            return;
        }
        startGps();
        try {
            // Enables connected ANT+ sensors and the watch's own HR "if possible" (API docs).
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Lang.Array<Sensor.SensorType>);
        } catch (e) {
            System.println("WALK_HR_ERROR," + e.getErrorMessage());
        }

        var started = false;
        try {
            var session = ActivityRecording.createSession({
                :name => SESSION_NAME,
                :sport => Activity.SPORT_WALKING
            });
            mSession = session;
            // A record-level field: Connect should chart it if it shows developer data.
            mMoodField = session.createField("pet_mood", MOOD_FIELD_ID,
                FitContributor.DATA_TYPE_UINT8,
                { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "lvl" });
            session.start();
            started = true;
        } catch (e) {
            System.println("WALK_START_ERROR," + e.getErrorMessage());
            // createSession hands back an unsaved session next time, so drop this one.
            var failed = mSession;
            if (failed != null) {
                try { failed.discard(); } catch (e2) { }
            }
            mSession = null;
            mMoodField = null;
            mState = STATE_FAILED;
            mError = "START ERR";
            WatchUi.requestUpdate();
        }

        if (!started) { return; }
        mState = STATE_RECORDING;
        mError = "";
        mStartedAt = Time.now().value();
        mElapsed = 0;
        mFixes = 0;
        mHideCount = 0;
        mHiddenSeconds = 0;
        mHiddenFixes = 0;
        writeMood();
        System.println("WALK_START," + mStartedAt + "," + mQuality);
        WatchUi.requestUpdate();
    }

    // A staircase that steps once a minute (0..4), so the chart is easy to recognize.
    // The value persists between writes; Garmin writes record data at most once a second.
    function writeMood() as Void {
        mMood = (mElapsed / 60) % 5;
        var field = mMoodField;
        if (field == null) { return; }
        try {
            field.setData(mMood);
        } catch (e) {
            System.println("WALK_FIELD_ERROR," + e.getErrorMessage());
        }
    }

    // Stops and saves. Safe to call more than once; only a running recording is saved.
    function finish(reason as Lang.Number) as Void {
        if (mState != STATE_RECORDING) { return; }
        mElapsed = elapsedNow();
        var saved = false;
        var session = mSession;
        if (session != null) {
            try {
                if (session.isRecording()) { session.stop(); }
                saved = session.save();
            } catch (e) {
                System.println("WALK_SAVE_ERROR," + e.getErrorMessage());
            }
        }
        mState = saved ? STATE_SAVED : STATE_FAILED;
        if (!saved) { mError = "SAVE ERR"; }
        endRecording(reason);
    }

    // Menu while recording: throw the attempt away instead of saving it.
    function discard() as Void {
        if (mState != STATE_RECORDING) { return; }
        mElapsed = elapsedNow();
        var session = mSession;
        if (session != null) {
            try {
                if (session.isRecording()) { session.stop(); }
                session.discard();
            } catch (e) {
                System.println("WALK_DISCARD_ERROR," + e.getErrorMessage());
            }
        }
        mState = STATE_DISCARDED;
        endRecording(END_MENU);
    }

    function endRecording(reason as Lang.Number) as Void {
        mSession = null;
        mMoodField = null;
        if (mHidden) {
            mHidden = false;
            mHiddenSeconds += Time.now().value() - mHiddenAt;
        }
        // Kept in storage so a T20 run that the watch closed can be read on reopening.
        mLastResult = stateText() + " " + elapsedText() + " " + endText(reason);
        mLastDetail = detailText();
        try {
            Application.Storage.setValue("last", mLastResult);
            Application.Storage.setValue("last_detail", mLastDetail);
        } catch (e) { }
        System.println("WALK_END," + reason + "," + mState + "," + mElapsed + "," + mFixes +
                       "," + mHideCount + "," + mHiddenSeconds + "," + mHiddenFixes);
        WatchUi.requestUpdate();
    }

    function stateText() as Lang.String {
        if (mState == STATE_RECORDING) {
            return (mQuality >= Position.QUALITY_USABLE) ? "RECORDING" : "REC NO FIX";
        }
        if (mState == STATE_SAVED) { return "SAVED"; }
        if (mState == STATE_DISCARDED) { return "DISCARDED"; }
        if (mState == STATE_FAILED) { return mError; }
        if (!mError.equals("")) { return mError; }
        return (mQuality >= Position.QUALITY_USABLE) ? "READY" : "WAITING FIX";
    }

    // Fixes, then times hidden, seconds hidden and fixes that arrived while hidden.
    function detailText() as Lang.String {
        return "FIX " + mFixes + " HID " + mHideCount + "x " + mHiddenSeconds + "s +" +
               mHiddenFixes;
    }

    // The idle footer alternates every three seconds between the last result and its
    // detail, because one line is too narrow for both on the round screen.
    function footerText() as Lang.String {
        var flip = ((Time.now().value() / 3) % 2) == 1;
        if (mState == STATE_RECORDING) {
            return (mHideCount > 0) ? detailText() : "START saves  MENU discards";
        }
        if (mState == STATE_IDLE) {
            if (mLastResult.equals("")) { return "START records  BACK exits"; }
            return flip ? mLastDetail : "LAST " + mLastResult;
        }
        return (flip && !mLastDetail.equals("")) ? mLastDetail : "START again  BACK exits";
    }

    function endText(reason as Lang.Number) as Lang.String {
        if (reason == END_SELECT) { return "START"; }
        if (reason == END_BACK) { return "BACK"; }
        if (reason == END_CLOSED) { return "CLOSED"; }
        return "MENU";
    }

    function qualityText(quality as Position.Quality) as Lang.String {
        if (quality == Position.QUALITY_GOOD) { return "GOOD"; }
        if (quality == Position.QUALITY_USABLE) { return "USABLE"; }
        if (quality == Position.QUALITY_POOR) { return "POOR"; }
        if (quality == Position.QUALITY_LAST_KNOWN) { return "LAST KNOWN"; }
        return "NONE";
    }

    function qualityColor(quality as Position.Quality) as Lang.Number {
        if (quality == Position.QUALITY_GOOD) { return 0x6ED6A8; }
        if (quality == Position.QUALITY_USABLE) { return 0xE8CF70; }
        if (quality == Position.QUALITY_POOR) { return 0xFFB15C; }
        return 0xFF6060;
    }

    function elapsedNow() as Lang.Number {
        return (mStartedAt > 0) ? (Time.now().value() - mStartedAt) : 0;
    }

    function elapsedText() as Lang.String {
        return (mElapsed / 60).format("%02d") + ":" + (mElapsed % 60).format("%02d");
    }

    // The largest font in the list whose text fits the round screen at this height.
    function fitFont(dc as Graphics.Dc, text as Lang.String,
                     fonts as Lang.Array<Graphics.FontDefinition>,
                     y as Lang.Number) as Graphics.FontDefinition {
        for (var i = 0; i < fonts.size(); i += 1) {
            var font = fonts[i];
            if (dc.getTextWidthInPixels(text, font) <=
                chordWidth(dc, y, dc.getFontHeight(font))) {
                return font;
            }
        }
        return fonts[fonts.size() - 1];
    }

    function chordWidth(dc as Graphics.Dc, y as Lang.Number,
                        lineHeight as Lang.Number) as Lang.Number {
        var radius = dc.getWidth() / 2;
        var top = absolute(y - lineHeight / 2 - radius);
        var bottom = absolute(y + lineHeight / 2 - radius);
        var far = (top > bottom) ? top : bottom;
        if (far >= radius) { return 0; }
        return (Math.sqrt(radius * radius - far * far) * 2).toNumber() - 24;
    }

    function absolute(value as Lang.Number) as Lang.Number {
        return (value < 0) ? -value : value;
    }
}
