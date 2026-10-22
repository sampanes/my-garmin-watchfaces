using Toybox.ActivityMonitor;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;
using Toybox.Sensor;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;
using Toybox.WatchUi;

// The first dogfood build deliberately keeps the old Wrist Diary application UUID.
// Installing it updates that app slot instead of leaving a third prototype on the watch.
class WristDiaryView extends WatchUi.View {
    const APP_VERSION = "0.4.0";
    const SCHEMA = 3;           // On-watch storage layout.
    const EXPORT_FORMAT = 4;    // Log export layout; read-friend.ps1 holds the columns.
    const LIVE_INTERVAL_SECONDS = 20;
    const MAX_LIVE = 700;       // Just under four hours of foreground detail.
    const MAX_SNAPSHOTS = 60;   // Roughly a month at two opens per day.
    const MAX_SESSIONS = 60;
    const MAX_CHAPTERS = 60;
    // Garmin rotates the app log at about 5 KB and keeps one older file, so only an
    // export under 5 KB always survives whole. These counts keep it near 4.6 KB.
    const EXPORT_LIVE = 90;     // Newest 30 minutes at full 20-second resolution.
    const EXPORT_SNAPSHOTS = 4;
    const EXPORT_SESSIONS = 8;
    const EXPORT_CHAPTERS = 10;

    const CHAPTER_IDLE = 0;
    const CHAPTER_ACTIVE = 1;

    // Why the session ended. OTHER means onStop arrived without Back: the watch
    // closed the app (timeout, wrist-off, a native activity, ...). A crash never
    // reaches stopSession, so it leaves no session summary at all.
    const EXIT_UNKNOWN = 0;
    const EXIT_BACK = 1;
    const EXIT_OTHER = 2;

    const MOOD_CALM = 0;
    const MOOD_EFFORT = 1;
    const MOOD_REMEMBER = 2;

    const L_EPOCH = 0;
    const L_SESSION = 1;
    const L_ELAPSED = 2;
    const L_HR = 3;
    const L_HR_DELTA = 4;
    const L_MOTION_AVG = 5;
    const L_MOTION_PEAK = 6;
    const L_MOVING_PCT = 7;
    const L_STEPS = 8;
    const L_STRESS = 9;
    const L_BODY_BATTERY = 10;

    var mTimer as Timer.Timer?;
    var mStarted as Lang.Boolean = false;
    var mStopped as Lang.Boolean = false;
    var mSessionId as Lang.Number = 0;
    var mStartedAt as Lang.Number = 0;
    var mElapsed as Lang.Number = 0;
    var mExitReason as Lang.Number = EXIT_UNKNOWN;
    var mInputCount as Lang.Number = 0;
    var mLastInputElapsed as Lang.Number = -1;
    var mBatteryStart as Lang.Number = -1;
    var mMemoryPeak as Lang.Number = 0;
    var mHideCount as Lang.Number = 0;

    var mBaselineMin as Lang.Number = -1;
    var mBaselineAvg as Lang.Number = -1;
    var mBaselineMax as Lang.Number = -1;
    var mHeartRate as Lang.Number = -1;
    var mHrMin as Lang.Number = 999;
    var mHrMax as Lang.Number = -1;
    var mHrSum as Lang.Number = 0;
    var mHrCount as Lang.Number = 0;
    var mWindowHrMin as Lang.Number = 999;
    var mWindowHrMax as Lang.Number = -1;
    var mWindowHrSum as Lang.Number = 0;
    var mWindowHrCount as Lang.Number = 0;

    var mMotionSum as Lang.Number = 0;
    var mMotionPeak as Lang.Number = 0;
    var mMotionSamples as Lang.Number = 0;
    var mMovingSamples as Lang.Number = 0;
    var mSessionMotionSum as Lang.Number = 0;
    var mSessionMotionSamples as Lang.Number = 0;
    var mSessionMotionPeak as Lang.Number = 0;
    var mSessionMovingSamples as Lang.Number = 0;
    var mPreviousX as Lang.Number?;
    var mPreviousY as Lang.Number?;
    var mPreviousZ as Lang.Number?;

    var mSteps as Lang.Number = -1;
    var mStress as Lang.Number = -1;
    var mBodyBattery as Lang.Number = -1;
    var mStartSteps as Lang.Number = -1;
    var mStartStress as Lang.Number = -1;
    var mStartBodyBattery as Lang.Number = -1;
    var mStatus as Lang.String = "HELLO";

    // A chapter is intentionally neutral: it means Friend saw sustained effort
    // evidence, not that it knows which exercise (or non-exercise) caused it.
    var mEvidenceBits as Lang.Number = 0;
    var mBucketCount as Lang.Number = 0;
    var mChapterState as Lang.Number = CHAPTER_IDLE;
    var mChapterStart as Lang.Number = 0;
    var mChapterLastStrong as Lang.Number = 0;
    var mChapterHrMin as Lang.Number = 999;
    var mChapterHrMax as Lang.Number = -1;
    var mChapterHrSum as Lang.Number = 0;
    var mChapterHrCount as Lang.Number = 0;
    var mChapterDeltaPeak as Lang.Number = -1;
    var mChapterMotionSum as Lang.Number = 0;
    var mChapterMotionPeak as Lang.Number = 0;
    var mChapterMovingSum as Lang.Number = 0;
    var mChapterBuckets as Lang.Number = 0;
    var mChapterAgeBuckets as Lang.Number = 0;
    var mChapterStepsStart as Lang.Number = -1;
    var mChapterStepsEnd as Lang.Number = -1;
    var mChapterReason as Lang.Number = 0;
    var mSessionChapters as Lang.Number = 0;
    var mLifetimeChapters as Lang.Number = 0;
    var mLastChapterDuration as Lang.Number = 0;
    var mLastChapterEpoch as Lang.Number = 0;

    function initialize() {
        View.initialize();
        migrateFromDiary();
        readFourHourBaseline();
        refreshSlowSignals();
        mSessionId = Time.now().value();
        mStartedAt = mSessionId;
        mStartSteps = mSteps;
        mStartStress = mStress;
        mStartBodyBattery = mBodyBattery;
        mBatteryStart = batteryPercent();
        mLifetimeChapters = readNumber("chapter_total", 0);
        mLastChapterDuration = readNumber("chapter_last_duration", 0);
        mLastChapterEpoch = readNumber("chapter_last_epoch", 0);
        saveSnapshot();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        startSession();
    }

    // The screen went away (a notification, another app, or the app closing).
    function onHide() as Void {
        mHideCount += 1;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var mood = moodNow();

        // Every line is placed as a share of the screen and sized to the chord of
        // the round display where it sits, so nothing runs off the bezel.
        var y = height * 10 / 100;
        var title = "FRIEND " + APP_VERSION;
        dc.setColor(0x3E7A62, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, fitFont(dc, title, [Graphics.FONT_XTINY], y),
                    title, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawFace(dc, centerX, height * 30 / 100, height * 13 / 100, mood);
        drawMemoryMarks(dc, centerX, height * 46 / 100);

        y = height * 56 / 100;
        var status = statusText();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, fitFont(dc, status,
                    [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY], y),
                    status, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawHeartLine(dc, centerX, height * 69 / 100);

        y = height * 80 / 100;
        var info = mLifetimeChapters + ((mLifetimeChapters == 1) ? " memory   " : " memories   ") +
                   elapsedText();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, y, fitFont(dc, info, [Graphics.FONT_XTINY], y),
                    info, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawStartHint(dc);
    }

    function moodNow() as Lang.Number {
        if (mChapterState == CHAPTER_ACTIVE || effortScore() > 35) { return MOOD_EFFORT; }
        if (recentlyRemembered()) { return MOOD_REMEMBER; }
        return MOOD_CALM;
    }

    function moodColor(mood as Lang.Number) as Lang.Number {
        if (mood == MOOD_EFFORT) { return 0xFFB15C; }
        if (mood == MOOD_REMEMBER) { return 0xE8CF70; }
        return 0x6ED6A8;
    }

    function drawFace(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                      radius as Lang.Number, mood as Lang.Number) as Void {
        dc.setColor(0x10241C, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, radius);
        dc.setColor(moodColor(mood), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(5);
        dc.drawCircle(x, y, radius);

        if (mood == MOOD_EFFORT) {
            // Open, laughing mouth: a disc with its top half painted back out.
            var mouth = radius * 30 / 100;
            var mouthY = y + radius * 16 / 100;
            dc.fillCircle(x, mouthY, mouth);
            dc.setColor(0x10241C, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x - mouth - 1, mouthY - mouth - 1, mouth * 2 + 2, mouth + 1);
            dc.setColor(moodColor(mood), Graphics.COLOR_TRANSPARENT);
        } else {
            dc.drawArc(x, y - radius * 18 / 100, radius * 58 / 100,
                       Graphics.ARC_COUNTER_CLOCKWISE, 240, 300);
        }

        // Eyes go on top: the open mouth paints over its own top half.
        var eyeX = radius * 36 / 100;
        var eyeY = y - radius * 16 / 100;
        var eye = radius * 11 / 100;
        if (mood == MOOD_REMEMBER) {
            // Happy closed eyes: two small upturned arcs.
            dc.setPenWidth(4);
            dc.drawArc(x - eyeX, eyeY + eye, eye + 2, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
            dc.drawArc(x + eyeX, eyeY + eye, eye + 2, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
        } else {
            dc.fillEllipse(x - eyeX, eyeY, eye, eye * 14 / 10);
            dc.fillEllipse(x + eyeX, eyeY, eye, eye * 14 / 10);
        }
    }

    function drawMemoryMarks(dc as Graphics.Dc, x as Lang.Number,
                             y as Lang.Number) as Void {
        var count = (mLifetimeChapters < 10) ? mLifetimeChapters : 10;
        if (count == 0) { return; }
        var gap = 16;
        var startX = x - ((count - 1) * gap / 2);
        dc.setColor(0xE8CF70, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < count; i += 1) {
            dc.fillCircle(startX + i * gap, y, 5);
        }
    }

    function drawHeartLine(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number) as Void {
        var text = "--";
        if (mHeartRate >= 0) {
            text = mHeartRate.toString();
            if (mBaselineAvg >= 0) {
                var delta = heartDelta();
                text += (delta >= 0) ? ("   +" + delta) : ("   " + delta);
            }
        }
        // "MM " reserves room for the drawn heart while choosing the font.
        var font = fitFont(dc, "MM " + text,
                           [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY], y);
        var size = dc.getFontHeight(font) * 30 / 100;
        var total = size * 3 + dc.getTextWidthInPixels(text, font);
        var heartX = x - total / 2 + size;

        // A drawn heart, so it never depends on a font having the glyph.
        dc.setColor(0xFF6B6B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(heartX - size / 2, y - size / 3, size / 2 + 1);
        dc.fillCircle(heartX + size / 2, y - size / 3, size / 2 + 1);
        dc.fillPolygon([[heartX - size - 1, y - size / 4], [heartX + size + 1, y - size / 4],
                        [heartX, y + size]]);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(heartX + size * 2, y, font, text,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Garmin's own convention: a short arc on the rim beside the START button
    // (top right on the FR265) marks the press that saves the export.
    function drawStartHint(dc as Graphics.Dc) as Void {
        var center = dc.getWidth() / 2;
        dc.setColor(0x6ED6A8, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(8);
        dc.drawArc(center, dc.getHeight() / 2, center - 6,
                   Graphics.ARC_COUNTER_CLOCKWISE, 22, 42);
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

    function startSession() as Void {
        if (mStarted) { return; }
        mStarted = true;
        mStatus = "WATCHING";
        try {
            Sensor.registerSensorDataListener(method(:onSensorData), {
                :period => 1,
                :accelerometer => {
                    :enabled => true,
                    :sampleRate => 25
                }
            });
        } catch (e) {
            mStatus = "HR ONLY";
            System.println("FRIEND_SENSOR_ERROR," + e.getErrorMessage());
        }
        mTimer = new Timer.Timer();
        (mTimer as Timer.Timer).start(method(:onSecond), 1000, true);
        WatchUi.requestUpdate();
    }

    // Every behavior the delegate sees counts, so a session summary can show how
    // long the app sat untouched before it ended.
    function noteInput() as Void {
        mInputCount += 1;
        mLastInputElapsed = mElapsed;
    }

    function stopSession(reason as Lang.Number) as Void {
        if (mStopped) { return; }
        mStopped = true;
        mExitReason = reason;
        System.println("FRIEND_EXIT," + reason + "," + mElapsed + "," +
                       mLastInputElapsed + "," + mInputCount);
        var timer = mTimer;
        if (timer != null) { timer.stop(); }
        try { Sensor.unregisterSensorDataListener(); } catch (e) { }
        if (mElapsed > 0) {
            captureLive();
            if (mChapterState == CHAPTER_ACTIVE) { finishChapter(1); }
            saveSessionSummary();
        }
    }

    function onSecond() as Void {
        mElapsed += 1;
        readLiveHeartRate();
        if ((mElapsed % 60) == 0) { refreshSlowSignals(); }
        if ((mElapsed % LIVE_INTERVAL_SECONDS) == 0) { captureLive(); }
        WatchUi.requestUpdate();
    }

    function onSensorData(sensorData as Sensor.SensorData) as Void {
        var accel = sensorData.accelerometerData;
        if (accel == null) { return; }
        var xs = accel.x;
        var ys = accel.y;
        var zs = accel.z;
        var size = xs.size();
        for (var i = 0; i < size; i += 1) {
            var x = xs[i] as Lang.Number;
            var y = ys[i] as Lang.Number;
            var z = zs[i] as Lang.Number;
            if (mPreviousX != null && mPreviousY != null && mPreviousZ != null) {
                var change = absolute(x - (mPreviousX as Lang.Number)) +
                             absolute(y - (mPreviousY as Lang.Number)) +
                             absolute(z - (mPreviousZ as Lang.Number));
                mMotionSum += change;
                mSessionMotionSum += change;
                mMotionSamples += 1;
                mSessionMotionSamples += 1;
                if (change > mMotionPeak) { mMotionPeak = change; }
                if (change > mSessionMotionPeak) { mSessionMotionPeak = change; }
                if (change >= 120) {
                    mMovingSamples += 1;
                    mSessionMovingSamples += 1;
                }
            }
            mPreviousX = x;
            mPreviousY = y;
            mPreviousZ = z;
        }
    }

    function readLiveHeartRate() as Void {
        try {
            var info = Sensor.getInfo();
            var heartRate = info.heartRate;
            if (heartRate != null) {
                var hr = heartRate as Lang.Number;
                mHeartRate = hr;
                if (hr > 0) {
                    if (hr < mHrMin) { mHrMin = hr; }
                    if (hr > mHrMax) { mHrMax = hr; }
                    mHrSum += hr;
                    mHrCount += 1;
                    if (hr < mWindowHrMin) { mWindowHrMin = hr; }
                    if (hr > mWindowHrMax) { mWindowHrMax = hr; }
                    mWindowHrSum += hr;
                    mWindowHrCount += 1;
                }
            }
        } catch (e) { }
    }

    function refreshSlowSignals() as Void {
        try {
            var info = ActivityMonitor.getInfo();
            var steps = info.steps;
            var stress = info.stressScore;
            if (steps != null) { mSteps = steps as Lang.Number; }
            if (stress != null) { mStress = stress as Lang.Number; }
        } catch (e) { }
        mBodyBattery = latestBodyBattery();
    }

    function readFourHourBaseline() as Void {
        try {
            var iterator = ActivityMonitor.getHeartRateHistory(new Time.Duration(4 * 3600), false);
            var count = 0;
            var sum = 0;
            var minimum = 999;
            var maximum = -1;
            var sample = iterator.next();
            while (sample != null) {
                var hr = sample.heartRate;
                if (hr != null && hr != ActivityMonitor.INVALID_HR_SAMPLE && hr > 0) {
                    if (hr < minimum) { minimum = hr; }
                    if (hr > maximum) { maximum = hr; }
                    sum += hr;
                    count += 1;
                }
                sample = iterator.next();
            }
            if (count > 0) {
                mBaselineMin = minimum;
                mBaselineAvg = sum / count;
                mBaselineMax = maximum;
            }
        } catch (e) {
            System.println("FRIEND_BASELINE_ERROR," + e.getErrorMessage());
        }
    }

    function latestBodyBattery() as Lang.Number {
        try {
            var history = SensorHistory.getBodyBatteryHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            });
            var sample = history.next();
            if (sample == null) { return -1; }
            var data = sample.data;
            if (data != null) { return data.toNumber(); }
        } catch (e) { }
        return -1;
    }

    function saveSnapshot() as Void {
        var info = ActivityMonitor.getInfo();
        var moderate = -1;
        var vigorous = -1;
        var active = info.activeMinutesDay;
        if (active != null) {
            moderate = active.moderate;
            vigorous = active.vigorous;
        }
        saveRing("snap", MAX_SNAPSHOTS, [
            Time.now().value(), mSteps, numberOrMissing(info.calories), moderate, vigorous,
            mStress, mBaselineMin, mBaselineAvg, mBaselineMax, mBodyBattery,
            numberOrMissing(info.distance), numberOrMissing(info.floorsClimbed)
        ] as Lang.Array<Lang.Number>);
    }

    function captureLive() as Void {
        refreshSlowSignals();
        notePeakMemory();
        var hrAvg = (mWindowHrCount > 0) ? (mWindowHrSum / mWindowHrCount) : -1;
        var hrMin = (mWindowHrCount > 0) ? mWindowHrMin : -1;
        var hrMax = (mWindowHrCount > 0) ? mWindowHrMax : -1;
        var hrDeltaAvg = (hrAvg > 0 && mBaselineAvg > 0) ?
                         (hrAvg - mBaselineAvg) : -1;
        var motionAvg = currentMotionAverage();
        var movingPct = percentage(mMovingSamples, mMotionSamples);
        updateChapter(hrMin, hrAvg, hrMax, hrDeltaAvg,
                      motionAvg, mMotionPeak, movingPct);
        saveRing("live3", MAX_LIVE, [
            Time.now().value(), mSessionId, mElapsed, mHeartRate,
            hrMin, hrAvg, hrMax, hrDeltaAvg,
            motionAvg, mMotionPeak, movingPct, mSteps, mStress, mBodyBattery,
            mChapterState
        ] as Lang.Array<Lang.Number>);
        mWindowHrMin = 999;
        mWindowHrMax = -1;
        mWindowHrSum = 0;
        mWindowHrCount = 0;
        mMotionSum = 0;
        mMotionPeak = 0;
        mMotionSamples = 0;
        mMovingSamples = 0;
    }

    function updateChapter(hrMin as Lang.Number, hrAvg as Lang.Number,
                           hrMax as Lang.Number, hrDeltaAvg as Lang.Number,
                           motionAvg as Lang.Number, motionPeak as Lang.Number,
                           movingPct as Lang.Number) as Void {
        var heartStrong = (hrDeltaAvg >= 10);
        var motionStrong = (movingPct >= 30 || motionAvg >= 120);
        var strong = heartStrong || motionStrong;
        var reason = (motionStrong ? 1 : 0) + (heartStrong ? 2 : 0);

        mEvidenceBits = (mEvidenceBits * 2 + (strong ? 1 : 0)) % 256;
        mBucketCount += 1;

        if (mChapterState == CHAPTER_IDLE) {
            if (strong && countRecentEvidence(3) >= 2) {
                startChapter();
                addChapterBucket(hrMin, hrAvg, hrMax, hrDeltaAvg,
                                 motionAvg, motionPeak, movingPct, reason);
            }
            return;
        }

        mChapterAgeBuckets += 1;
        if (strong) {
            addChapterBucket(hrMin, hrAvg, hrMax, hrDeltaAvg,
                             motionAvg, motionPeak, movingPct, reason);
        }

        // Six quiet buckets out of the latest eight closes the chapter at its
        // last strong evidence, excluding a forgotten-at-the-desk tail.
        if (mChapterAgeBuckets >= 8 && countRecentEvidence(8) <= 2) {
            finishChapter(0);
        }
    }

    function startChapter() as Void {
        mChapterState = CHAPTER_ACTIVE;
        mChapterStart = Time.now().value() - (2 * LIVE_INTERVAL_SECONDS);
        if (mChapterStart < mSessionId) { mChapterStart = mSessionId; }
        mChapterLastStrong = Time.now().value();
        mChapterHrMin = 999;
        mChapterHrMax = -1;
        mChapterHrSum = 0;
        mChapterHrCount = 0;
        mChapterDeltaPeak = -1;
        mChapterMotionSum = 0;
        mChapterMotionPeak = 0;
        mChapterMovingSum = 0;
        mChapterBuckets = 0;
        mChapterAgeBuckets = 0;
        mChapterStepsStart = mSteps;
        mChapterStepsEnd = mSteps;
        mChapterReason = 0;
        mStatus = "WITH YOU";
    }

    function addChapterBucket(hrMin as Lang.Number, hrAvg as Lang.Number,
                              hrMax as Lang.Number, hrDeltaAvg as Lang.Number,
                              motionAvg as Lang.Number, motionPeak as Lang.Number,
                              movingPct as Lang.Number, reason as Lang.Number) as Void {
        mChapterLastStrong = Time.now().value();
        if (hrMin > 0 && hrMin < mChapterHrMin) { mChapterHrMin = hrMin; }
        if (hrMax > mChapterHrMax) { mChapterHrMax = hrMax; }
        if (hrAvg > 0) {
            mChapterHrSum += hrAvg;
            mChapterHrCount += 1;
        }
        if (hrDeltaAvg > mChapterDeltaPeak) { mChapterDeltaPeak = hrDeltaAvg; }
        mChapterMotionSum += motionAvg;
        if (motionPeak > mChapterMotionPeak) { mChapterMotionPeak = motionPeak; }
        mChapterMovingSum += movingPct;
        mChapterBuckets += 1;
        mChapterStepsEnd = mSteps;
        mChapterReason = mergeReason(mChapterReason, reason);
    }

    function finishChapter(partial as Lang.Number) as Void {
        if (mChapterState != CHAPTER_ACTIVE) { return; }
        var duration = mChapterLastStrong - mChapterStart;
        if (duration < LIVE_INTERVAL_SECONDS) { duration = LIVE_INTERVAL_SECONDS; }
        var hrAvg = (mChapterHrCount > 0) ?
                    (mChapterHrSum / mChapterHrCount) : -1;
        var motionAvg = (mChapterBuckets > 0) ?
                        (mChapterMotionSum / mChapterBuckets) : 0;
        var movingPct = (mChapterBuckets > 0) ?
                        (mChapterMovingSum / mChapterBuckets) : 0;
        saveRing("chapter3", MAX_CHAPTERS, [
            mChapterStart, mChapterLastStrong, duration, partial,
            mBaselineAvg,
            (mChapterHrCount > 0) ? mChapterHrMin : -1,
            hrAvg, mChapterHrMax, mChapterDeltaPeak,
            motionAvg, mChapterMotionPeak, movingPct,
            mChapterStepsStart, mChapterStepsEnd, mChapterReason
        ] as Lang.Array<Lang.Number>);

        mSessionChapters += 1;
        mLifetimeChapters += 1;
        mLastChapterDuration = duration;
        mLastChapterEpoch = mChapterLastStrong;
        Application.Storage.setValue("chapter_total", mLifetimeChapters);
        Application.Storage.setValue("chapter_last_duration", duration);
        Application.Storage.setValue("chapter_last_epoch", mLastChapterEpoch);
        mChapterState = CHAPTER_IDLE;
        mEvidenceBits = 0;
        mStatus = "I REMEMBER";
    }

    function countRecentEvidence(window as Lang.Number) as Lang.Number {
        var bits = mEvidenceBits;
        var count = 0;
        var available = (mBucketCount < window) ? mBucketCount : window;
        for (var i = 0; i < available; i += 1) {
            count += bits % 2;
            bits = bits / 2;
        }
        return count;
    }

    function mergeReason(existing as Lang.Number, newest as Lang.Number) as Lang.Number {
        if (existing == 0) { return newest; }
        if (newest == 0 || existing == newest) { return existing; }
        return 3;
    }

    function saveSessionSummary() as Void {
        refreshSlowSignals();
        var hrAvg = (mHrCount > 0) ? (mHrSum / mHrCount) : -1;
        var motionAvg = (mSessionMotionSamples > 0) ?
                        (mSessionMotionSum / mSessionMotionSamples) : 0;
        saveRing("session3", MAX_SESSIONS, [
            mSessionId, Time.now().value(), mElapsed,
            mBaselineMin, mBaselineAvg, mBaselineMax,
            (mHrCount > 0) ? mHrMin : -1, hrAvg, mHrMax,
            motionAvg, mSessionMotionPeak,
            percentage(mSessionMovingSamples, mSessionMotionSamples),
            mStartSteps, mSteps, mStartStress, mStress,
            mStartBodyBattery, mBodyBattery,
            mSessionChapters, mLastChapterDuration, mLifetimeChapters,
            mExitReason, mLastInputElapsed, mInputCount,
            mBatteryStart, batteryPercent(), mMemoryPeak / 1024, mHideCount
        ] as Lang.Array<Lang.Number>);
    }

    function batteryPercent() as Lang.Number {
        try {
            return System.getSystemStats().battery.toNumber();
        } catch (e) { }
        return -1;
    }

    function notePeakMemory() as Void {
        var used = System.getSystemStats().usedMemory;
        if (used > mMemoryPeak) { mMemoryPeak = used; }
    }

    function saveRing(prefix as Lang.String, maximum as Lang.Number,
                      record as Lang.Array<Lang.Number>) as Void {
        var count = readNumber(prefix + "_count", 0);
        var next = readNumber(prefix + "_next", 0);
        Application.Storage.setValue(prefix + "_" + next,
                                     record as Application.Storage.ValueType);
        next = (next + 1) % maximum;
        if (count < maximum) { count += 1; }
        Application.Storage.setValue(prefix + "_next", next);
        Application.Storage.setValue(prefix + "_count", count);
    }

    function exportAllRecords() as Void {
        System.println("FRIEND_EXPORT_BEGIN," + EXPORT_FORMAT + "," + APP_VERSION);
        exportDevice();
        exportRecentRing("snap", MAX_SNAPSHOTS, EXPORT_SNAPSHOTS);
        exportRecentRing("session3", MAX_SESSIONS, EXPORT_SESSIONS);
        exportRecentRing("chapter3", MAX_CHAPTERS, EXPORT_CHAPTERS);
        exportCompactLive();
        System.println("FRIEND_EXPORT_END");
    }

    function exportDevice() as Void {
        try {
            var settings = System.getDeviceSettings();
            var firmware = settings.firmwareVersion;
            var ciq = settings.monkeyVersion;
            System.println("FRIEND_DEVICE," + settings.partNumber + "," +
                           firmware[0] + "." + firmware[1].format("%02d") + "," +
                           ciq[0] + "." + ciq[1] + "." + ciq[2]);
        } catch (e) { }
    }

    function exportRecentRing(prefix as Lang.String, maximum as Lang.Number,
                              exportMaximum as Lang.Number) as Void {
        var count = readNumber(prefix + "_count", 0);
        var next = readNumber(prefix + "_next", 0);
        var exportCount = (count < exportMaximum) ? count : exportMaximum;
        System.println("FRIEND_" + prefix + "_BEGIN," + exportCount);
        var start = next - exportCount;
        while (start < 0) { start += maximum; }
        for (var i = 0; i < exportCount; i += 1) {
            var value = Application.Storage.getValue(prefix + "_" + ((start + i) % maximum));
            if (value instanceof Lang.Array) {
                System.println(csvLine(value as Lang.Array<Lang.Number>));
            }
        }
        System.println("FRIEND_" + prefix + "_END");
    }

    // The newest live records, oldest first, 22 characters each instead of ~65.
    // "S,session_epoch,epoch,steps" sets the base for the rows after it; each row is
    // fixed-width base 36: seconds since the previous row (2), hr min/avg/max (2 each),
    // motion avg (2), motion peak (3), moving % (2), steps since the previous row (2),
    // stress (2), body battery (2), chapter state (1). All z's means missing.
    function exportCompactLive() as Void {
        var digits = "0123456789abcdefghijklmnopqrstuvwxyz".toCharArray();
        var count = readNumber("live3_count", 0);
        var next = readNumber("live3_next", 0);
        var exportCount = (count < EXPORT_LIVE) ? count : EXPORT_LIVE;
        System.println("FRIEND_live4_BEGIN," + exportCount);
        var start = next - exportCount;
        while (start < 0) { start += MAX_LIVE; }
        var session = -1;
        var lastEpoch = 0;
        var lastSteps = -1;
        for (var i = 0; i < exportCount; i += 1) {
            var value = Application.Storage.getValue("live3_" + ((start + i) % MAX_LIVE));
            if (!(value instanceof Lang.Array)) { continue; }
            var record = value as Lang.Array<Lang.Number>;
            if (record.size() < 15) { continue; }
            var steps = record[11];
            // A new base whenever a delta would not fit: new session, a long gap, or
            // steps that went backwards (midnight) or jumped.
            if (record[1] != session || record[0] - lastEpoch > 1294 ||
                (steps >= 0 && (lastSteps < 0 || steps < lastSteps ||
                                steps - lastSteps > 1294))) {
                session = record[1];
                lastEpoch = record[0];
                lastSteps = steps;
                System.println("S," + session + "," + lastEpoch + "," + lastSteps);
            }
            var stepsDelta = (steps >= 0) ? (steps - lastSteps) : -1;
            System.println(base36(record[0] - lastEpoch, 2, digits) +
                           base36(record[4], 2, digits) + base36(record[5], 2, digits) +
                           base36(record[6], 2, digits) + base36(record[8], 2, digits) +
                           base36(record[9], 3, digits) + base36(record[10], 2, digits) +
                           base36(stepsDelta, 2, digits) + base36(record[12], 2, digits) +
                           base36(record[13], 2, digits) + base36(record[14], 1, digits));
            lastEpoch = record[0];
            if (steps >= 0) { lastSteps = steps; }
        }
        System.println("FRIEND_live4_END");
    }

    // Fixed-width base 36. Negative means missing and prints as all z's; anything too
    // large is clamped one below that.
    function base36(value as Lang.Number, width as Lang.Number,
                    digits as Lang.Array<Lang.Char>) as Lang.String {
        var limit = 1;
        for (var i = 0; i < width; i += 1) { limit *= 36; }
        var number = value;
        if (number < 0) {
            number = limit - 1;
        } else if (number > limit - 2) {
            number = limit - 2;
        }
        var text = "";
        for (var j = 0; j < width; j += 1) {
            text = digits[number % 36].toString() + text;
            number = number / 36;
        }
        return text;
    }

    function migrateFromDiary() as Void {
        if (readNumber("friend_schema", 0) == SCHEMA) { return; }
        // The previous app used r0..r59. Leave those values harmlessly in place rather
        // than risking a destructive migration; all Friend data uses namespaced keys.
        Application.Storage.setValue("friend_schema", SCHEMA);
    }

    function exportNow() as Void {
        captureLive();
        exportAllRecords();
        mStatus = "SAVED";
        WatchUi.requestUpdate();
    }

    function effortScore() as Lang.Number {
        var delta = heartDelta();
        if (delta < 0) { delta = 0; }
        var motion = currentMotionAverage() / 4;
        return delta + motion;
    }

    function statusText() as Lang.String {
        if (mStatus == "SAVED") { return mStatus; }
        if (mChapterState == CHAPTER_ACTIVE) { return "WITH YOU"; }
        if (recentlyRemembered()) {
            var minutes = (mLastChapterDuration + 30) / 60;
            if (minutes < 1) { minutes = 1; }
            return "I SAW " + minutes + " MIN";
        }
        if (effortScore() > 35) { return "I SEE IT"; }
        if (mHeartRate < 0) { return "WATCHING"; }
        return "I'M HERE";
    }

    // For a few minutes after a chapter (and the first 30 s of a visit) the
    // friend talks about what it saw.
    function recentlyRemembered() as Lang.Boolean {
        return mLastChapterDuration > 0 &&
               ((Time.now().value() - mLastChapterEpoch) <= 300 || mElapsed <= 30);
    }

    function heartDelta() as Lang.Number {
        if (mHeartRate < 0 || mBaselineAvg < 0) { return -1; }
        return mHeartRate - mBaselineAvg;
    }

    function currentMotionAverage() as Lang.Number {
        return (mMotionSamples > 0) ? (mMotionSum / mMotionSamples) : 0;
    }

    function percentage(part as Lang.Number, total as Lang.Number) as Lang.Number {
        return (total > 0) ? (part * 100 / total) : 0;
    }

    function elapsedText() as Lang.String {
        return (mElapsed / 60).format("%02d") + ":" + (mElapsed % 60).format("%02d");
    }

    function absolute(value as Lang.Number) as Lang.Number {
        return (value < 0) ? -value : value;
    }

    function numberOrMissing(value as Lang.Number?) as Lang.Number {
        return (value == null) ? -1 : (value as Lang.Number);
    }

    function readNumber(key as Lang.String, fallback as Lang.Number) as Lang.Number {
        var value = Application.Storage.getValue(key);
        return (value instanceof Lang.Number) ? (value as Lang.Number) : fallback;
    }

    function csvLine(record as Lang.Array<Lang.Number>) as Lang.String {
        var line = "" + record[0];
        for (var i = 1; i < record.size(); i += 1) { line += "," + record[i]; }
        return line;
    }
}
