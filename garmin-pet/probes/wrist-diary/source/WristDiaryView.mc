using Toybox.ActivityMonitor;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Sensor;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.Timer;
using Toybox.WatchUi;

// The first dogfood build deliberately keeps the old Wrist Diary application UUID.
// Installing it updates that app slot instead of leaving a third prototype on the watch.
class WristDiaryView extends WatchUi.View {
    const APP_VERSION = "0.3.0";
    const SCHEMA = 3;
    const LIVE_INTERVAL_SECONDS = 20;
    const MAX_LIVE = 700;       // Just under four hours of foreground detail.
    const MAX_SNAPSHOTS = 60;   // Roughly a month at two opens per day.
    const MAX_SESSIONS = 60;
    const MAX_CHAPTERS = 60;
    const EXPORT_LIVE = 48;     // Chapters preserve detail; this trace preserves four-hour shape.
    const EXPORT_SNAPSHOTS = 8;
    const EXPORT_SESSIONS = 8;
    const EXPORT_CHAPTERS = 12;

    const CHAPTER_IDLE = 0;
    const CHAPTER_ACTIVE = 1;

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

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var centerX = width / 2;
        dc.setColor(0x6ED6A8, Graphics.COLOR_BLACK);
        dc.drawText(centerX, 22, Graphics.FONT_SMALL, "FRIEND v" + APP_VERSION,
                    Graphics.TEXT_JUSTIFY_CENTER);

        drawFace(dc, centerX, 128);
        drawMemoryMarks(dc, centerX, 205);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(centerX, 228, Graphics.FONT_MEDIUM, statusText(),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(centerX, 276, Graphics.FONT_SMALL, heartText(),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(centerX, 313, Graphics.FONT_XTINY,
                    "MEM " + mLifetimeChapters + "   " + elapsedText(),
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(centerX, 342, Graphics.FONT_XTINY, "BACK EXIT   SEL EXPORT",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawFace(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number) as Void {
        var effort = effortScore();
        var color = (mChapterState == CHAPTER_ACTIVE || effort > 35) ?
                    0xFFB15C : 0x6ED6A8;
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.setPenWidth(6);
        dc.drawCircle(x, y, 67);
        dc.fillCircle(x - 23, y - 13, 7);
        dc.fillCircle(x + 23, y - 13, 7);
        dc.setPenWidth(5);
        if (effort > 35) {
            dc.drawArc(x, y + 17, 25, Graphics.ARC_COUNTER_CLOCKWISE, 200, 340);
        } else {
            dc.drawLine(x - 22, y + 25, x + 22, y + 25);
        }
    }

    function drawMemoryMarks(dc as Graphics.Dc, x as Lang.Number,
                             y as Lang.Number) as Void {
        var count = (mLifetimeChapters < 8) ? mLifetimeChapters : 8;
        var startX = x - ((count - 1) * 9 / 2);
        dc.setColor(0xE8CF70, Graphics.COLOR_BLACK);
        for (var i = 0; i < count; i += 1) {
            var radius = ((i + mLifetimeChapters) % 3 == 0) ? 4 : 3;
            dc.fillCircle(startX + i * 9, y, radius);
        }
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

    function stopSession() as Void {
        if (mStopped) { return; }
        mStopped = true;
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
            mSessionChapters, mLastChapterDuration, mLifetimeChapters
        ] as Lang.Array<Lang.Number>);
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
        System.println("FRIEND_EXPORT_BEGIN," + SCHEMA + "," + APP_VERSION);
        exportRecentRing("snap", MAX_SNAPSHOTS, EXPORT_SNAPSHOTS,
            "epoch,steps,calories,moderate,vigorous,stress,hr4h_min,hr4h_avg,hr4h_max,body_battery,distance_cm,floors");
        exportRecentRing("session3", MAX_SESSIONS, EXPORT_SESSIONS,
            "start_epoch,end_epoch,duration_s,hr4h_min,hr4h_avg,hr4h_max,hr_min,hr_avg,hr_max,motion_avg,motion_peak,moving_pct,steps_start,steps_end,stress_start,stress_end,bb_start,bb_end,chapters,last_chapter_s,lifetime_chapters");
        exportRecentRing("chapter3", MAX_CHAPTERS, EXPORT_CHAPTERS,
            "start_epoch,end_epoch,duration_s,partial,baseline_hr,hr_min,hr_avg,hr_max,hr_delta_peak,motion_avg,motion_peak,moving_pct,steps_start,steps_end,reason");
        exportSampledRing("live3", MAX_LIVE, EXPORT_LIVE,
            "epoch,session_epoch,elapsed_s,hr_last,hr_min,hr_avg,hr_max,hr_delta_avg,motion_avg,motion_peak,moving_pct,steps,stress,body_battery,chapter_state");
        System.println("FRIEND_EXPORT_END");
    }

    function exportRecentRing(prefix as Lang.String, maximum as Lang.Number,
                              exportMaximum as Lang.Number,
                              header as Lang.String) as Void {
        var count = readNumber(prefix + "_count", 0);
        var next = readNumber(prefix + "_next", 0);
        var exportCount = (count < exportMaximum) ? count : exportMaximum;
        System.println("FRIEND_" + prefix + "_BEGIN," + exportCount);
        System.println(header);
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

    function exportSampledRing(prefix as Lang.String, maximum as Lang.Number,
                               exportMaximum as Lang.Number,
                               header as Lang.String) as Void {
        var count = readNumber(prefix + "_count", 0);
        var next = readNumber(prefix + "_next", 0);
        var exportCount = (count < exportMaximum) ? count : exportMaximum;
        System.println("FRIEND_" + prefix + "_BEGIN," + exportCount);
        System.println(header);
        var start = next - count;
        while (start < 0) { start += maximum; }
        for (var i = 0; i < exportCount; i += 1) {
            var logicalIndex = i;
            if (count > exportCount && exportCount > 1) {
                logicalIndex = i * (count - 1) / (exportCount - 1);
            }
            var value = Application.Storage.getValue(
                prefix + "_" + ((start + logicalIndex) % maximum));
            if (value instanceof Lang.Array) {
                System.println(csvLine(value as Lang.Array<Lang.Number>));
            }
        }
        System.println("FRIEND_" + prefix + "_END");
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
        mStatus = "DATA READY";
        WatchUi.requestUpdate();
    }

    function effortScore() as Lang.Number {
        var delta = heartDelta();
        if (delta < 0) { delta = 0; }
        var motion = currentMotionAverage() / 4;
        return delta + motion;
    }

    function statusText() as Lang.String {
        if (mStatus == "DATA READY") { return mStatus; }
        if (mChapterState == CHAPTER_ACTIVE) { return "WITH YOU"; }
        if (mLastChapterDuration > 0 &&
            ((Time.now().value() - mLastChapterEpoch) <= 300 || mElapsed <= 30)) {
            var minutes = (mLastChapterDuration + 30) / 60;
            if (minutes < 1) { minutes = 1; }
            return "I SAW " + minutes + " MIN";
        }
        if (effortScore() > 35) { return "I SEE IT"; }
        if (mHeartRate < 0) { return "WATCHING"; }
        return "I'M HERE";
    }

    function heartText() as Lang.String {
        if (mHeartRate < 0) { return "HR --"; }
        var delta = heartDelta();
        if (delta >= 0) { return "HR " + mHeartRate + "   +" + delta; }
        return "HR " + mHeartRate + "   " + delta;
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
