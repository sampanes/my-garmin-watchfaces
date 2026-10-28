using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Lang;
using Toybox.Position;
using Toybox.Sensor;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

// A small, timer-free FIT recorder for Friend's explicit Walk mode. The owning
// view supplies the one-second tick and remains responsible for navigation.
// In particular, close() never throws away an active recording implicitly.
class FriendWalkRecorder {
    const STATE_IDLE = 0;
    const STATE_READY = 1;
    const STATE_RECORDING = 2;
    const STATE_RESULT = 3;
    const STATE_FAILED = 4;

    const END_SELECT = 1;
    const END_BACK = 2;
    const END_CLOSED = 3;
    const END_DISCARD = 4;

    const SESSION_NAME = "Friend Walk";

    var mSession as ActivityRecording.Session?;
    var mState as Lang.Number = STATE_IDLE;
    var mGpsOn as Lang.Boolean = false;
    var mHeartRateForced as Lang.Boolean = false;
    var mClosing as Lang.Boolean = false;
    var mSaved as Lang.Boolean = false;
    var mStartedAt as Lang.Number = 0;
    var mElapsed as Lang.Number = 0;
    var mDistanceMeters as Lang.Number = 0;
    var mFixes as Lang.Number = 0;
    var mQuality as Position.Quality = Position.QUALITY_NOT_AVAILABLE;
    var mResult as Lang.String = "";
    var mError as Lang.String = "";
    var mEndReason as Lang.Number = 0;

    function initialize() {
    }

    // Entering ready mode starts GPS acquisition, but a usable fix is not a
    // prerequisite for START. The FIT route begins with the first usable fix.
    function enterReady() as Lang.Boolean {
        if (mState == STATE_RECORDING || mClosing) { return false; }
        if (mSession != null && !discardSessionAfterFailure()) {
            fail("CLEANUP ERR", "Previous FIT session is still open");
            return false;
        }
        resetRun();
        mState = STATE_READY;
        if (!startGps()) { return false; }
        WatchUi.requestUpdate();
        return true;
    }

    // Re-acquire location events after the owning view becomes visible again.
    function onShow() as Void {
        if (mState == STATE_READY || mState == STATE_RECORDING) {
            startGps();
        }
    }

    function start() as Lang.Boolean {
        if (mState != STATE_READY || mClosing) { return false; }
        if (!(Toybox has :ActivityRecording)) {
            fail("NO REC API", "ActivityRecording unavailable");
            return false;
        }
        if (!startGps()) { return false; }

        // ActivityRecording only puts HR in the FIT when the app explicitly
        // enables it. Friend's high-frequency accelerometer listener is managed
        // separately by WristDiaryView.
        try {
            Sensor.setEnabledSensors(
                [Sensor.SENSOR_HEARTRATE] as Lang.Array<Sensor.SensorType>);
            mHeartRateForced = true;
        } catch (e) {
            System.println("FRIEND_WALK_HR_ERROR," + e.getErrorMessage());
        }

        var started = false;
        try {
            var session = ActivityRecording.createSession({
                :name => SESSION_NAME,
                :sport => Activity.SPORT_WALKING
            });
            mSession = session;
            started = session.start();
            if (!started) {
                discardSessionAfterFailure();
                fail("START ERR", "Session.start returned false");
            }
        } catch (e) {
            System.println("FRIEND_WALK_START_ERROR," + e.getErrorMessage());
            discardSessionAfterFailure();
            var detail = e.getErrorMessage();
            // The cast is for the level-2 type checker: every compiled file in
            // this repo casts a nullable out of a ternary the same way.
            fail("START ERR", (detail == null) ? "" : (detail as Lang.String));
        }

        if (!started) { return false; }
        mState = STATE_RECORDING;
        mStartedAt = Time.now().value();
        mElapsed = 0;
        mDistanceMeters = 0;
        mFixes = 0;
        mSaved = false;
        mResult = "";
        mError = "";
        mEndReason = 0;
        tick();
        System.println("FRIEND_WALK_START," + mStartedAt + "," + mQuality);
        WatchUi.requestUpdate();
        return true;
    }

    // The owner calls this from its existing one-second timer. Activity.Info is
    // read rather than retaining positions, so the recorder holds no route data.
    function tick() as Void {
        if (mState != STATE_RECORDING) { return; }
        mElapsed = elapsedNow();
        try {
            var info = Activity.getActivityInfo();
            if (info != null) {
                var distance = info.elapsedDistance;
                if (distance != null) {
                    mDistanceMeters = distance.toNumber();
                }
            }
        } catch (e) { }
    }

    function saveFromSelect() as Lang.Boolean {
        return save(END_SELECT);
    }

    // These entry points deliberately share the idempotent save path. The view
    // can always continue its Friend summary and Back/system-close cleanup.
    function saveFromBack() as Lang.Boolean {
        return save(END_BACK);
    }

    function saveFromSystemClose() as Lang.Boolean {
        return save(END_CLOSED);
    }

    function save(reason as Lang.Number) as Lang.Boolean {
        if (mState == STATE_RESULT) { return mSaved; }
        if (mState != STATE_RECORDING || mClosing) { return false; }
        mClosing = true;
        tick();

        var saved = false;
        var stopped = true;
        var session = mSession;
        if (session != null) {
            try {
                if (session.isRecording()) { stopped = session.stop(); }
                if (stopped) { saved = session.save(); }
            } catch (e) {
                System.println("FRIEND_WALK_SAVE_ERROR," + e.getErrorMessage());
            }
            if (!saved) {
                // A stopped-but-unsaved session can be returned by the next
                // createSession(), so keep the reference unless discard succeeds.
                discardSessionAfterFailure();
            }
        }

        if (saved) { mSession = null; }
        mSaved = saved;
        mEndReason = reason;
        mClosing = false;
        stopGps();
        stopForcedHeartRate();
        if (saved) {
            mState = STATE_RESULT;
            mResult = "SAVED " + endText(reason);
            mError = "";
        } else {
            mState = STATE_FAILED;
            mResult = "";
            mError = "SAVE ERR";
        }
        System.println("FRIEND_WALK_END," + reason + "," + (saved ? 1 : 0) + "," +
                       mElapsed + "," + mDistanceMeters + "," + mFixes);
        WatchUi.requestUpdate();
        return saved;
    }

    // Explicit recovery/testing action only. Back, system close, and close()
    // never route here, so an active walk is not silently discarded.
    function discard() as Lang.Boolean {
        if (mState == STATE_RESULT && !mSaved) { return true; }
        if (mState != STATE_RECORDING || mClosing) { return false; }
        mClosing = true;
        tick();
        var discarded = discardSessionAfterFailure();
        mSaved = false;
        mEndReason = END_DISCARD;
        mClosing = false;
        stopGps();
        stopForcedHeartRate();
        if (discarded) {
            mResult = "DISCARDED";
            mError = "";
            mState = STATE_RESULT;
        } else {
            mResult = "";
            mError = "CLEANUP ERR";
            mState = STATE_FAILED;
        }
        System.println("FRIEND_WALK_END," + END_DISCARD + ",0," + mElapsed + "," +
                       mDistanceMeters + "," + mFixes);
        WatchUi.requestUpdate();
        return true;
    }

    // Cancel READY or leave RESULT/FAILED. It is intentionally a no-op while
    // recording; the caller must choose saveFromBack/SystemClose or discard().
    function close() as Lang.Boolean {
        if (mState == STATE_RECORDING || mClosing) { return false; }
        if (mSession != null && !discardSessionAfterFailure()) {
            mState = STATE_FAILED;
            mError = "CLEANUP ERR";
            stopGps();
            stopForcedHeartRate();
            WatchUi.requestUpdate();
            return false;
        }
        stopGps();
        stopForcedHeartRate();
        mState = STATE_IDLE;
        WatchUi.requestUpdate();
        return true;
    }

    function startGps() as Lang.Boolean {
        if (mGpsOn) { return true; }
        try {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS,
                                          method(:onPosition));
            mGpsOn = true;
        } catch (e) {
            System.println("FRIEND_WALK_GPS_ERROR," + e.getErrorMessage());
            var detail = e.getErrorMessage();
            fail("NO GPS", (detail == null) ? "" : (detail as Lang.String));
            return false;
        }
        // A synchronous info read is only a convenience. Location events are
        // already enabled, so a getInfo failure must not lose cleanup ownership.
        try { mQuality = Position.getInfo().accuracy; } catch (e2) { }
        return true;
    }

    function stopGps() as Void {
        if (!mGpsOn) { return; }
        try {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, null);
            mGpsOn = false;
        } catch (e) {
            System.println("FRIEND_WALK_GPS_STOP_ERROR," + e.getErrorMessage());
        }
    }

    // setEnabledSensors() is separate from Friend's raw accelerometer listener.
    // Release the HR/ANT request after the FIT session so the home screen does
    // not keep activity-grade sensing enabled indefinitely.
    function stopForcedHeartRate() as Void {
        if (!mHeartRateForced) { return; }
        try {
            Sensor.setEnabledSensors([] as Lang.Array<Sensor.SensorType>);
            mHeartRateForced = false;
        } catch (e) {
            System.println("FRIEND_WALK_HR_STOP_ERROR," + e.getErrorMessage());
        }
    }

    function onPosition(info as Position.Info) as Void {
        mQuality = info.accuracy;
        if (mState == STATE_RECORDING) { mFixes += 1; }
        WatchUi.requestUpdate();
    }

    function isIdle() as Lang.Boolean { return mState == STATE_IDLE; }
    function isReady() as Lang.Boolean { return mState == STATE_READY; }
    function isRecording() as Lang.Boolean { return mState == STATE_RECORDING; }
    function isResult() as Lang.Boolean { return mState == STATE_RESULT; }
    function isFailed() as Lang.Boolean { return mState == STATE_FAILED; }
    function state() as Lang.Number { return mState; }
    function elapsed() as Lang.Number { return mElapsed; }
    function elapsedSeconds() as Lang.Number { return mElapsed; }
    function distanceMeters() as Lang.Number { return mDistanceMeters; }
    function fixes() as Lang.Number { return mFixes; }
    function gpsQuality() as Position.Quality { return mQuality; }
    function resultText() as Lang.String { return mResult; }
    function errorText() as Lang.String { return mError; }
    function endReason() as Lang.Number { return mEndReason; }

    function stateText() as Lang.String {
        if (mState == STATE_READY) {
            return (mQuality >= Position.QUALITY_USABLE) ? "READY" : "WAITING FIX";
        }
        if (mState == STATE_RECORDING) {
            return (mQuality >= Position.QUALITY_USABLE) ? "WALKING" : "WALK NO FIX";
        }
        if (mState == STATE_RESULT) { return mResult; }
        if (mState == STATE_FAILED) { return mError; }
        return "OFF";
    }

    function qualityText() as Lang.String {
        if (mQuality == Position.QUALITY_GOOD) { return "GOOD"; }
        if (mQuality == Position.QUALITY_USABLE) { return "USABLE"; }
        if (mQuality == Position.QUALITY_POOR) { return "POOR"; }
        if (mQuality == Position.QUALITY_LAST_KNOWN) { return "LAST KNOWN"; }
        return "NONE";
    }

    function elapsedText() as Lang.String {
        return (mElapsed / 60).format("%02d") + ":" +
               (mElapsed % 60).format("%02d");
    }

    function resetRun() as Void {
        mSession = null;
        mClosing = false;
        mSaved = false;
        mStartedAt = 0;
        mElapsed = 0;
        mDistanceMeters = 0;
        mFixes = 0;
        mQuality = Position.QUALITY_NOT_AVAILABLE;
        mResult = "";
        mError = "";
        mEndReason = 0;
    }

    function discardSessionAfterFailure() as Lang.Boolean {
        var session = mSession;
        if (session == null) { return true; }
        try {
            if (session.isRecording() && !session.stop()) { return false; }
            if (!session.discard()) { return false; }
        } catch (e) {
            System.println("FRIEND_WALK_CLEANUP_ERROR," + e.getErrorMessage());
            return false;
        }
        mSession = null;
        return true;
    }

    function fail(label as Lang.String, detail as Lang.String) as Void {
        mState = STATE_FAILED;
        mError = label;
        mResult = "";
        mClosing = false;
        stopGps();
        stopForcedHeartRate();
        System.println("FRIEND_WALK_ERROR," + label + "," + detail);
        WatchUi.requestUpdate();
    }

    function elapsedNow() as Lang.Number {
        return (mStartedAt > 0) ? (Time.now().value() - mStartedAt) : 0;
    }

    function endText(reason as Lang.Number) as Lang.String {
        if (reason == END_SELECT) { return "START"; }
        if (reason == END_BACK) { return "BACK"; }
        if (reason == END_CLOSED) { return "CLOSED"; }
        return "DISCARDED";
    }
}
