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
    const APP_VERSION = "0.10.0";
    const SCHEMA = 3;           // On-watch storage layout.
    const EXPORT_FORMAT = 6;    // Log export layout; friend-export.ps1 holds the columns.
    const LIVE_INTERVAL_SECONDS = 20;
    const MAX_LIVE = 700;       // Just under four hours of foreground detail.
    const MAX_SNAPSHOTS = 60;   // Roughly a month at two opens per day.
    const MAX_SESSIONS = 60;
    const MAX_CHAPTERS = 60;
    // Garmin rotates the app log at about 5 KB and keeps one older file, so only an
    // export under 5 KB always survives whole. These counts keep it under 4.8 KB.
    const EXPORT_LIVE = 30;     // Newest 10 minutes at full 20-second resolution.
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

    const SAVED_SECONDS = 3;

    const SCREEN_HOME = 0;
    const SCREEN_WALK = 1;
    const SCREEN_END_WALK = 2;
    const SCREEN_WALK_RESULT = 3;
    const SCREEN_EXPORT = 4;
    const SCREEN_TODAY = 5;
    const SCREEN_GROWTH = 6;
    const SCREEN_TRAIL = 7;
    const SCREEN_EGG = 8;
    const SCREEN_HATCHING = 9;
    const SCREEN_VOICE = 10;
    const SCREEN_REWARD = 11;
    const SCREEN_GREW = 12;
    const SCREEN_EVOLVE = 13;
    const SCREEN_EVOLVE_CONFIRM = 14;
    const SCREEN_EMBLEM = 15;

    const ANIM_MS = 200;            // Five frames a second while the screen shows.
    const REWARD_LINGER_MS = 20000; // The exit reward card closes itself after this.
    const HATCH_FRAMES = 14;

    const C_ACCENT = 0x3E7A62;
    const C_MINT = 0x6ED6A8;
    const C_GOLD = 0xE8CF70;
    const C_ORANGE = 0xFFB15C;

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
    var mSavedUntil as Lang.Number = 0;

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
    var mScreen as Lang.Number = SCREEN_HOME;
    var mWalk as FriendWalkRecorder;

    // The pet layer (0.8.0): saved state and economy, drawn art, voice lines.
    var mPet as FriendPet;
    var mArt as FriendArt;
    var mVoice as FriendVoice;
    var mAnimTimer as Timer.Timer?;
    var mAnimating as Lang.Boolean = false;
    var mExitTimer as Timer.Timer?;
    var mFrame as Lang.Number = 0;
    var mMood as Lang.Number = 60;          // The pet's mood, refreshed each minute.
    var mBand as Lang.Number = 0;
    var mEvoReady as Lang.Boolean = false;
    var mDayFull as Lang.Boolean = false;
    var mGreeting as Lang.String = "";
    var mSay as Lang.String = "";           // A passing line, shown until mSayUntil.
    var mSayUntil as Lang.Number = 0;
    var mSalt as Lang.Number = 0;           // Varies the canned lines between sessions.
    var mEmote as Lang.Number = 0;
    var mEmoteUntil as Lang.Number = 0;     // Frame the emote ends on.
    var mEmoteCount as Lang.Number = 0;
    var mAwakeUntil as Lang.Number = 8;     // Elapsed second a night-time friend dozes off.
    var mPending as Lang.Number = 0;        // What the open chapter would earn right now.
    var mPendingFlames as Lang.Number = 0;
    var mPickPal as Lang.Number = 0;
    var mPickVoice as Lang.Number = 0;
    var mPickForm as Lang.Number = 1;
    var mPickEmblem as Lang.Number = 0;
    var mEmblemLevel as Lang.Number = 1;    // How bright the belly emblem is, from warmth.
    var mRepick as Lang.Boolean = false;
    var mHatchFrame as Lang.Number = 0;
    var mRewardExit as Lang.Boolean = false;    // The reward card is the last stop before leaving.
    var mRecap as Lang.Boolean = false;         // The reward card is last session's, shown at open.
    var mRecapUntil as Lang.Number = 10;

    // T11 (DIY HRV): beat-to-beat intervals in ms from the sensor listener. A
    // "change" is an interval unlike the one before it, so interpolated beats
    // (a constant 1000 ms) read as 0% and real variability reads near 100%.
    // The walk pair answers the "inside a recording" half of the question.
    // mRrCount -1 means the watch refused the beat-interval option.
    var mRrCount as Lang.Number = 0;
    var mRrChanges as Lang.Number = 0;
    var mRrMin as Lang.Number = -1;
    var mRrMax as Lang.Number = -1;
    var mRrLast as Lang.Number = -1;
    var mRrWalkCount as Lang.Number = 0;
    var mRrWalkChanges as Lang.Number = 0;

    function initialize() {
        View.initialize();
        mWalk = new FriendWalkRecorder();
        mPet = new FriendPet();
        mArt = new FriendArt();
        mVoice = new FriendVoice();
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
        mSalt = (mSessionId / 60) % 1000;
        beginPet();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
        // Hide and show seconds in the log beside FRIEND_EXIT: the 2026-10-31
        // field log's two watch-closed sessions each counted 3 hides, and a
        // count alone cannot say whether the close followed one.
        System.println("FRIEND_SHOW," + mElapsed);
        startSession();
        mWalk.onShow();
        startAnimation();
    }

    // The screen went away (a notification, another app, or the app closing).
    function onHide() as Void {
        mHideCount += 1;
        System.println("FRIEND_HIDE," + mElapsed + "," + mHideCount);
        stopAnimation();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }

        if (mScreen == SCREEN_WALK) {
            drawWalkScreen(dc);
        } else if (mScreen == SCREEN_END_WALK) {
            drawEndWalkScreen(dc);
        } else if (mScreen == SCREEN_WALK_RESULT) {
            drawWalkResultScreen(dc);
        } else if (mScreen == SCREEN_EXPORT) {
            drawExportScreen(dc);
        } else if (mScreen == SCREEN_EGG || mScreen == SCREEN_HATCHING) {
            drawEggScreen(dc);
        } else if (mScreen == SCREEN_VOICE) {
            drawVoiceScreen(dc);
        } else if (mScreen == SCREEN_EMBLEM) {
            drawEmblemScreen(dc);
        } else if (mScreen == SCREEN_REWARD) {
            drawReward(dc);
        } else if (mScreen == SCREEN_GREW) {
            drawGrew(dc);
        } else if (mScreen == SCREEN_EVOLVE || mScreen == SCREEN_EVOLVE_CONFIRM) {
            drawEvolveScreen(dc);
        } else if (mScreen == SCREEN_TODAY) {
            drawToday(dc);
        } else if (mScreen == SCREEN_GROWTH) {
            drawGrowth(dc);
        } else if (mScreen == SCREEN_TRAIL) {
            drawTrail(dc);
        } else {
            drawHome(dc);
        }
    }

    // Home: the friend, alive and already observing. Every line is placed as a
    // share of the screen and sized to the chord of the round display where it
    // sits, so nothing runs off the bezel.
    function drawHome(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var width = dc.getWidth();
        var centerX = width / 2;

        drawCenteredLine(dc, centerX, height * 9 / 100, "FRIEND " + APP_VERSION, C_ACCENT,
                         [Graphics.FONT_XTINY]);
        mArt.drawSky(dc, width, height, mPet.weather(mMood), isNight(), mFrame);
        drawPet(dc, centerX, height * 54 / 100, 100, homeFace(), homePose());

        drawCenteredLine(dc, centerX, height * 63 / 100, homeLine(), Graphics.COLOR_WHITE,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawPulseRow(dc, centerX, height * 72 / 100);
        drawXpBar(dc, centerX - width * 24 / 100, height * 78 / 100, width * 48 / 100, 10,
                  mPet.xp(), mPending, mBand);
        var info = bandName(mBand) + "  " + (mPet.xp() + mPending) + "/" +
                   mPet.bandThreshold(mBand + 1);
        drawCenteredLine(dc, centerX, height * 85 / 100, info, Graphics.COLOR_LT_GRAY,
                         [Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 92 / 100, "START walk", Graphics.COLOR_DK_GRAY,
                         [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    function drawWalkScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var recording = mWalk.isRecording();

        drawCenteredLine(dc, centerX, height * 10 / 100, "FRIEND WALK", C_ACCENT,
                         [Graphics.FONT_XTINY]);
        drawPet(dc, centerX, height * 35 / 100, 45,
                recording ? FriendLook.FACE_EFFORT : FriendLook.FACE_SUNNY,
                recording ? FriendLook.POSE_RUN : FriendLook.POSE_IDLE);
        drawCenteredLine(dc, centerX, height * 43 / 100,
                         recording ? mVoice.walkStart(mPet.persona(), mSalt) : "READY TO WALK",
                         recording ? 0xFFB15C : 0x6ED6A8,
                         [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 55 / 100,
                         "GPS " + mWalk.qualityText(), Graphics.COLOR_LT_GRAY,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 67 / 100,
                         walkElapsedText(), Graphics.COLOR_WHITE,
                         [Graphics.FONT_NUMBER_MILD, Graphics.FONT_MEDIUM]);

        var hr = (mHeartRate > 0) ? mHeartRate.toString() : "--";
        drawCenteredLine(dc, centerX, height * 79 / 100,
                         walkDistanceText() + "   HR " + hr, Graphics.COLOR_LT_GRAY,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 89 / 100,
                         recording ? "START finish" : "START walk   BACK cancel",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    function drawEndWalkScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var tooShort = walkTooShort();
        drawCenteredLine(dc, centerX, height * 12 / 100, "FRIEND WALK", C_ACCENT,
                         [Graphics.FONT_XTINY]);
        drawPet(dc, centerX, height * 43 / 100, 62, FriendLook.FACE_EFFORT, FriendLook.POSE_IDLE);
        drawCenteredLine(dc, centerX, height * 53 / 100, "END WALK?", Graphics.COLOR_WHITE,
                         [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        // A walk this short is a stray press, not an activity worth a FIT file.
        drawCenteredLine(dc, centerX, height * 66 / 100,
                         tooShort ? "too short to keep" : "recording continues", C_GOLD,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 80 / 100,
                         tooShort ? "START drop it" : "START save", C_MINT,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 90 / 100,
                         tooShort ? "BACK keep walking" : "BACK resume",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    function drawWalkResultScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var failed = mWalk.isFailed();
        var kept = mWalk.wasSaved();
        var headline = "WE WALKED";
        var detail = "ACTIVITY SAVED";
        if (failed) {
            headline = "WALK FAILED";
            detail = mWalk.errorText();
        } else if (!kept) {
            headline = "NO WALK KEPT";
            detail = "too short";
        } else if (mPet.exists()) {
            detail = "SAVED   TRAIL " + kmText(mPet.trailMeters());
        }
        drawCenteredLine(dc, centerX, height * 12 / 100, "FRIEND WALK", C_ACCENT,
                         [Graphics.FONT_XTINY]);
        drawPet(dc, centerX, height * 43 / 100, 62,
                (failed || !kept) ? FriendLook.FACE_FAIR : FriendLook.FACE_JOY,
                (failed || !kept) ? FriendLook.POSE_IDLE : FriendLook.POSE_HOP);
        drawCenteredLine(dc, centerX, height * 53 / 100, headline,
                         failed ? 0xFF6060 : C_GOLD,
                         [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 66 / 100,
                         walkElapsedText() + "   " + walkDistanceText(), Graphics.COLOR_WHITE,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 78 / 100, detail,
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 90 / 100, "START home", Graphics.COLOR_LT_GRAY,
                         [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    function drawExportScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var exported = (Time.now().value() <= mSavedUntil);
        drawCenteredLine(dc, centerX, height * 11 / 100, "FRIEND " + APP_VERSION, C_ACCENT,
                         [Graphics.FONT_XTINY]);
        drawPet(dc, centerX, height * 37 / 100, 55, FriendLook.FACE_FAIR, FriendLook.POSE_IDLE);
        drawCenteredLine(dc, centerX, height * 46 / 100, "DEBUG DATA", Graphics.COLOR_WHITE,
                         [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        drawCenteredLine(dc, centerX, height * 56 / 100, beatIntervalText(),
                         Graphics.COLOR_LT_GRAY,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 65 / 100, petDebugText(),
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 76 / 100,
                         exported ? "EXPORTED" : "START export",
                         exported ? C_MINT : Graphics.COLOR_LT_GRAY,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        drawCenteredLine(dc, centerX, height * 87 / 100,
                         mPet.exists() ? "MENU new look" : "BACK egg",
                         Graphics.COLOR_DK_GRAY, [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    function drawCenteredLine(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                              text as Lang.String, color as Lang.Number,
                              fonts as Lang.Array<Graphics.FontDefinition>) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, fitFont(dc, text, fonts, y), text,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // T11 at a glance, without an export: intervals seen this session and the
    // share that differed from the one before.
    function beatIntervalText() as Lang.String {
        if (mRrCount < 0) { return "RR OFF"; }
        if (mRrCount == 0) { return "RR NONE YET"; }
        return "RR " + mRrCount + "  " + percentage(mRrChanges, mRrCount) + "% VARY";
    }

    function walkElapsedText() as Lang.String {
        var seconds = mWalk.elapsed();
        return (seconds / 60).format("%02d") + ":" + (seconds % 60).format("%02d");
    }

    function walkDistanceText() as Lang.String {
        return mWalk.distanceMeters().toNumber().format("%d") + " m";
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
            // T11: beat intervals ride on the proven 25 Hz motion listener.
            Sensor.registerSensorDataListener(method(:onSensorData), {
                :period => 1,
                :accelerometer => {
                    :enabled => true,
                    :sampleRate => 25
                },
                :heartBeatIntervals => {
                    :enabled => true
                }
            });
        } catch (e) {
            // The beat-interval option was refused: say so in the session row
            // and fall back to the motion-only listener 0.4.0 ran with.
            mRrCount = -1;
            System.println("FRIEND_RR_ERROR," + e.getErrorMessage());
            try {
                Sensor.registerSensorDataListener(method(:onSensorData), {
                    :period => 1,
                    :accelerometer => {
                        :enabled => true,
                        :sampleRate => 25
                    }
                });
            } catch (e2) {
                mStatus = "HR ONLY";
                System.println("FRIEND_SENSOR_ERROR," + e2.getErrorMessage());
            }
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

    // One primary action, interpreted by the current full-screen card. True
    // means the delegate should leave the app (the exit reward was accepted).
    function selectAction() as Lang.Boolean {
        var leave = false;
        if (mScreen == SCREEN_HOME || mScreen == SCREEN_TRAIL) {
            mWalk.enterReady();
            mScreen = mWalk.isFailed() ? SCREEN_WALK_RESULT : SCREEN_WALK;
        } else if (mScreen == SCREEN_WALK) {
            if (mWalk.isReady()) {
                mWalk.start();
                if (mWalk.isFailed()) { mScreen = SCREEN_WALK_RESULT; }
            } else if (mWalk.isRecording()) {
                mScreen = SCREEN_END_WALK;
            } else {
                mScreen = SCREEN_WALK_RESULT;
            }
        } else if (mScreen == SCREEN_END_WALK) {
            if (walkTooShort()) {
                mWalk.discard();
            } else if (mWalk.saveFromSelect()) {
                walkKept();
            }
            mScreen = SCREEN_WALK_RESULT;
        } else if (mScreen == SCREEN_WALK_RESULT) {
            // Home whether or not the cleanup worked: a FIT session that refuses
            // to discard must never trap the wearer on this card. enterReady()
            // retries the discard the next time a walk is started.
            mWalk.close();
            mScreen = homeScreen();
        } else if (mScreen == SCREEN_EXPORT) {
            exportNow();
        } else if (mScreen == SCREEN_EGG) {
            if (mRepick) {
                mScreen = SCREEN_VOICE;
            } else {
                mHatchFrame = mFrame;
                mScreen = SCREEN_HATCHING;
            }
        } else if (mScreen == SCREEN_HATCHING) {
            mScreen = SCREEN_VOICE;
        } else if (mScreen == SCREEN_VOICE) {
            if (mRepick && mBand >= 1) {
                mScreen = SCREEN_EMBLEM;
            } else {
                commitHatch();
            }
        } else if (mScreen == SCREEN_EMBLEM) {
            commitHatch();
        } else if (mScreen == SCREEN_REWARD || mScreen == SCREEN_GREW) {
            leave = advanceReward();
        } else if (mScreen == SCREEN_GROWTH) {
            if (mEvoReady) {
                mPickForm = FriendLook.FORM_ROUND;
                mScreen = SCREEN_EVOLVE;
            }
        } else if (mScreen == SCREEN_EVOLVE) {
            mScreen = SCREEN_EVOLVE_CONFIRM;
        } else if (mScreen == SCREEN_EVOLVE_CONFIRM) {
            commitEvolve();
        }
        WatchUi.requestUpdate();
        return leave;
    }

    // True means the delegate should leave the app. Every other screen consumes Back
    // as a literal step backward; a running walk gets a confirmation screen first.
    function backAction() as Lang.Boolean {
        if (mScreen == SCREEN_HOME) { return true; }
        if (mScreen == SCREEN_EGG && !mRepick) { return true; }
        if (mScreen == SCREEN_REWARD || mScreen == SCREEN_GREW) {
            var leave = advanceReward();
            WatchUi.requestUpdate();
            return leave;
        }
        if (mScreen == SCREEN_EXPORT || mScreen == SCREEN_TODAY ||
            mScreen == SCREEN_GROWTH || mScreen == SCREEN_TRAIL) {
            mScreen = homeScreen();
        } else if (mScreen == SCREEN_EGG) {
            mRepick = false;
            mScreen = SCREEN_HOME;
        } else if (mScreen == SCREEN_HATCHING || mScreen == SCREEN_VOICE) {
            mScreen = SCREEN_EGG;
        } else if (mScreen == SCREEN_EMBLEM) {
            mScreen = SCREEN_VOICE;
        } else if (mScreen == SCREEN_EVOLVE) {
            mScreen = SCREEN_GROWTH;
        } else if (mScreen == SCREEN_EVOLVE_CONFIRM) {
            mScreen = SCREEN_EVOLVE;
        } else if (mScreen == SCREEN_END_WALK) {
            mScreen = SCREEN_WALK;
        } else if (mScreen == SCREEN_WALK_RESULT) {
            // Same escape hatch as START: Back always leaves the result card.
            mWalk.close();
            mScreen = homeScreen();
        } else if (mScreen == SCREEN_WALK) {
            if (mWalk.isRecording()) {
                mScreen = SCREEN_END_WALK;
            } else {
                mWalk.close();
                mScreen = homeScreen();
            }
        }
        WatchUi.requestUpdate();
        return false;
    }

    // Up and Down browse the card stack, or the choices on a choosing screen.
    function pageAction(step as Lang.Number) as Void {
        if (mScreen == SCREEN_EGG) {
            mPickPal = (mPickPal + step + FriendLook.PALETTE_COUNT) % FriendLook.PALETTE_COUNT;
        } else if (mScreen == SCREEN_VOICE) {
            mPickVoice = (mPickVoice + step + mVoice.voiceCount()) % mVoice.voiceCount();
        } else if (mScreen == SCREEN_EVOLVE) {
            mPickForm = (mPickForm + step + FriendLook.FORM_COUNT) % FriendLook.FORM_COUNT;
        } else if (mScreen == SCREEN_EMBLEM) {
            // 0 is a bare belly, then the emblems in sheet order.
            mPickEmblem = (mPickEmblem + step + FRIEND_EMBLEMS + 1) % (FRIEND_EMBLEMS + 1);
        } else if (mPet.exists()) {
            var order = [SCREEN_HOME, SCREEN_TODAY, SCREEN_GROWTH, SCREEN_TRAIL,
                         SCREEN_EXPORT] as Lang.Array<Lang.Number>;
            for (var i = 0; i < order.size(); i += 1) {
                if (order[i] == mScreen) {
                    mScreen = order[(i + step + order.size()) % order.size()];
                    break;
                }
            }
        }
        WatchUi.requestUpdate();
    }

    function menuAction() as Void {
        if (mScreen == SCREEN_HOME || (mScreen == SCREEN_EGG && !mRepick)) {
            mScreen = SCREEN_EXPORT;
        } else if (mScreen == SCREEN_EXPORT && mPet.exists()) {
            // Dogfood escape hatch: pick the colorway, voice and belly emblem again.
            mRepick = true;
            mPickPal = mPet.palette();
            mPickVoice = mPet.persona();
            mPickEmblem = mPet.emblem();
            mScreen = SCREEN_EGG;
        }
        WatchUi.requestUpdate();
    }

    // A tap anywhere pets the friend. Touch never starts, ends or saves a walk:
    // only the START button does.
    function tapAction() as Void {
        if (mScreen != SCREEN_HOME || mStopped || !mPet.exists()) { return; }
        var asleep = isAsleep();
        mAwakeUntil = mElapsed + 30;
        if (asleep) {
            say(mVoice.woke(mPet.persona()), 4);
        } else {
            mPet.petted(Time.now().value());
            refreshPet();
            say(mVoice.petted(mPet.persona(), mEmoteCount), 4);
            startEmote(nextEmote());
        }
        WatchUi.requestUpdate();
    }

    // Keep exit-reason constants private to the view. Monkey C class constants are
    // not static members, so callers use these named actions instead.
    function stopFromBack() as Void {
        try {
            if (mWalk.isRecording() && mWalk.saveFromBack()) { walkKept(); }
        } catch (e) {
            System.println("FRIEND_WALK_EXIT_ERROR," + e.getErrorMessage());
        }
        try { mWalk.close(); } catch (e2) { }
        stopSession(EXIT_BACK);
    }

    function stopFromSystemClose() as Void {
        try {
            if (mWalk.isRecording() && mWalk.saveFromSystemClose()) { walkKept(); }
        } catch (e) {
            System.println("FRIEND_WALK_CLOSE_ERROR," + e.getErrorMessage());
        }
        try { mWalk.close(); } catch (e2) { }
        stopSession(EXIT_OTHER);
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
        // Storage on the watch is encrypted by the firmware, so the log export is
        // the only readable copy. Write it on every exit, after the summary is safe,
        // so plugging in after a session never needs the DEBUG DATA step first.
        try {
            exportAllRecords();
        } catch (e3) {
            System.println("FRIEND_AUTO_EXPORT_ERROR," + e3.getErrorMessage());
        }
    }

    function onSecond() as Void {
        mElapsed += 1;
        readLiveHeartRate();
        mWalk.tick();
        if ((mElapsed % 60) == 0) {
            refreshSlowSignals();
            refreshPet();
        }
        if ((mElapsed % LIVE_INTERVAL_SECONDS) == 0) { captureLive(); }
        // Last session's reward, shown at open, steps aside by itself.
        if (mRecap && mElapsed >= mRecapUntil &&
            (mScreen == SCREEN_REWARD || mScreen == SCREEN_GREW)) {
            advanceReward();
            mRecapUntil = mElapsed + 8;
        }
        WatchUi.requestUpdate();
    }

    function onSensorData(sensorData as Sensor.SensorData) as Void {
        // Beat intervals first, fenced off: nothing about them may cost the
        // motion evidence below.
        try {
            var hrData = sensorData.heartRateData;
            if (hrData != null && mRrCount >= 0) {
                noteBeatIntervals(hrData.heartBeatIntervals);
            }
        } catch (e) { }

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

    // Every positive interval counts; a change is one unlike the previous one.
    function noteBeatIntervals(intervals as Lang.Array<Lang.Number>) as Void {
        var walking = mWalk.isRecording();
        var size = intervals.size();
        for (var i = 0; i < size; i += 1) {
            var ms = intervals[i];
            if (ms <= 0) { continue; }
            mRrCount += 1;
            if (mRrMin < 0 || ms < mRrMin) { mRrMin = ms; }
            if (ms > mRrMax) { mRrMax = ms; }
            var changed = (mRrLast >= 0 && ms != mRrLast);
            if (changed) { mRrChanges += 1; }
            if (walking) {
                mRrWalkCount += 1;
                if (changed) { mRrWalkChanges += 1; }
            }
            mRrLast = ms;
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
            numberOrMissing(info.distance), numberOrMissing(info.floorsClimbed),
            respirationRate(info), timeToRecovery(info), oxygenSaturation(),
            pressurePascals(), stressSampleAge()
        ] as Lang.Array<Lang.Number>);
    }

    // Open hardware questions answered on every check-in (test plan T8-T12, T17).
    // Codes: -1 the watch answered null, -2 this firmware lacks the field, -3 it threw.
    function respirationRate(info as ActivityMonitor.Info) as Lang.Number {
        try {
            if (!(info has :respirationRate)) { return -2; }
            return numberOrMissing(info.respirationRate);
        } catch (e) { }
        return -3;
    }

    function timeToRecovery(info as ActivityMonitor.Info) as Lang.Number {
        try {
            if (!(info has :timeToRecovery)) { return -2; }
            return numberOrMissing(info.timeToRecovery);
        } catch (e) { }
        return -3;
    }

    function oxygenSaturation() as Lang.Number {
        try {
            var info = Sensor.getInfo();
            if (!(info has :oxygenSaturation)) { return -2; }
            return numberOrMissing(info.oxygenSaturation);
        } catch (e) { }
        return -3;
    }

    function pressurePascals() as Lang.Number {
        try {
            var info = Sensor.getInfo();
            if (!(info has :pressure)) { return -2; }
            var pressure = info.pressure;
            return (pressure == null) ? -1 : pressure.toNumber();
        } catch (e) { }
        return -3;
    }

    // Seconds since the newest stress-history sample: how fresh history is in an app.
    function stressSampleAge() as Lang.Number {
        try {
            if (!(SensorHistory has :getStressHistory)) { return -2; }
            var sample = SensorHistory.getStressHistory({
                :period => 1,
                :order => SensorHistory.ORDER_NEWEST_FIRST
            }).next();
            if (sample == null) { return -1; }
            return Time.now().value() - sample.when.value();
        } catch (e) { }
        return -3;
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
        updatePending();
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

        // The chapter feeds the pet. The row above stays the evidence; the pet
        // keeps only a watermark, so crediting the same chapter twice is harmless.
        if (mPet.exists()) {
            var points = mPet.creditChapter(mChapterStart, mChapterLastStrong, duration,
                                            mBaselineAvg, hrAvg, true);
            mPending = 0;
            mPendingFlames = 0;
            refreshPet();
            if (points > 0 && !mStopped) {
                say("+" + points + " XP", 8);
                startEmote(FriendLook.POSE_HOP);
            }
        }
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
            mBatteryStart, batteryPercent(), mMemoryPeak / 1024, mHideCount,
            mRrCount, mRrChanges, mRrMin, mRrMax, mRrWalkCount, mRrWalkChanges
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
        if (mPet.exists()) { System.println(mPet.exportLine()); }
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
                           ciq[0] + "." + ciq[1] + "." + ciq[2] + "," +
                           (settings.tonesOn ? 1 : 0) + "," + (settings.vibrateOn ? 1 : 0));
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
        mSavedUntil = Time.now().value() + SAVED_SECONDS;
        WatchUi.requestUpdate();
    }

    function effortScore() as Lang.Number {
        var delta = heartDelta();
        if (delta < 0) { delta = 0; }
        var motion = currentMotionAverage() / 4;
        return delta + motion;
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

    // ====================================================== the pet layer (0.8.0)
    // Sensing above is unchanged. Everything below turns its chapters into a
    // friend that grows: garmin-pet/12-pet-state-and-economy.md for the rules,
    // FriendPet for the state, FriendArt for the drawing, FriendVoice for lines.
    // scripts/friend_preview.py mirrors every draw* function here.

    // Meet the pet, or the egg it has not hatched from yet.
    function beginPet() as Void {
        if (!mPet.exists()) {
            mScreen = SCREEN_EGG;
            return;
        }
        var now = Time.now().value();
        mPet.creditStored();
        var reunion = mPet.open(now);
        refreshPet();
        var voice = mPet.persona();
        if (reunion) {
            mGreeting = mVoice.reunion(voice, mSalt);
        } else if (mBodyBattery >= 0 && mBodyBattery < 25) {
            mGreeting = mVoice.drained(voice, mSalt);
        } else {
            mGreeting = mVoice.hello(hourNow(), voice, mSalt);
        }
        // A reward the wearer never saw (the watch closed Friend, or nobody
        // looked) opens the next visit.
        if (mPet.owedPoints() > 0) {
            mRecap = true;
            mScreen = SCREEN_REWARD;
        }
    }

    function refreshPet() as Void {
        if (!mPet.exists()) { return; }
        var now = Time.now().value();
        mMood = mPet.moodNow(now);
        mBand = mPet.band();
        mEvoReady = mPet.evoReady(now);
        mDayFull = (mPet.dayMinutes(now) >= 30);
        mEmblemLevel = emblemLevel(mPet.warmth(now));
    }

    // The belly emblem shows the bond: dull when cool, steady when warm,
    // glowing when close.
    function emblemLevel(warm as Lang.Number) as Lang.Number {
        if (warm >= 90) { return 2; }
        if (warm >= 70) { return 1; }
        return 0;
    }

    function homeScreen() as Lang.Number {
        return mPet.exists() ? SCREEN_HOME : SCREEN_EGG;
    }

    function petStage() as Lang.Number {
        if (mBand >= 3) { return FriendLook.STAGE_ADULT; }
        if (mBand >= 1) { return FriendLook.STAGE_CHILD; }
        return FriendLook.STAGE_BABY;
    }

    function dressPet() as Void {
        mArt.setLook(petStage(), mBand, mPet.form(), mPet.evos(), mPet.palette());
        mArt.setEmblem(mPet.emblem(), mEmblemLevel);
    }

    // The friend standing on footY, at a percentage of its home-screen size.
    // Before it hatches, the egg stands there instead.
    function drawPet(dc as Graphics.Dc, x as Lang.Number, footY as Lang.Number,
                     percent as Lang.Number, face as Lang.Number,
                     pose as Lang.Number) as Void {
        var height = dc.getHeight();
        if (!mPet.exists()) {
            mArt.setLook(FriendLook.STAGE_EGG, 0, 0, 0, mPickPal);
            mArt.setPose(face, pose, mFrame);
            var eggSize = mArt.sizeFor(FriendLook.STAGE_EGG, height) * percent / 100;
            mArt.drawEgg(dc, x, footY - eggSize * 108 / 100, eggSize, 0);
            return;
        }
        dressPet();
        mArt.setPose(face, pose, mFrame);
        mArt.drawStanding(dc, x, footY, percent);
    }

    // The animation timer only runs while the screen shows.
    function startAnimation() as Void {
        if (mAnimating) { return; }
        if (mAnimTimer == null) { mAnimTimer = new Timer.Timer(); }
        (mAnimTimer as Timer.Timer).start(method(:onFrame), ANIM_MS, true);
        mAnimating = true;
    }

    function stopAnimation() as Void {
        if (!mAnimating) { return; }
        var timer = mAnimTimer;
        if (timer != null) { timer.stop(); }
        mAnimating = false;
    }

    function onFrame() as Void {
        mFrame += 1;
        if (mScreen == SCREEN_HATCHING && (mFrame - mHatchFrame) >= HATCH_FRAMES) {
            mScreen = SCREEN_VOICE;
        }
        WatchUi.requestUpdate();
    }

    function hourNow() as Lang.Number {
        return System.getClockTime().hour;
    }

    function isNight() as Lang.Boolean {
        var hour = hourNow();
        return hour >= 20 || hour < 6;
    }

    // Late at night the friend dozes, unless there is effort to watch or it was
    // just woken. Asleep is a look, never a lockout: sensing carries on.
    function isAsleep() as Lang.Boolean {
        var hour = hourNow();
        return (hour >= 23 || hour < 5) && mChapterState != CHAPTER_ACTIVE &&
               mElapsed >= mAwakeUntil && !emoteActive();
    }

    function emoteActive() as Lang.Boolean {
        return mFrame < mEmoteUntil;
    }

    function startEmote(pose as Lang.Number) as Void {
        mEmote = pose;
        mEmoteUntil = mFrame + 16;
    }

    // Petting cycles through the emotes the friend has grown into.
    function nextEmote() as Lang.Number {
        var known = 1;
        if (mBand >= 1) { known = 2; }
        if (mBand >= 2) { known = 3; }
        if (mBand >= 4) { known = 4; }
        var pick = mEmoteCount % known;
        mEmoteCount += 1;
        if (pick == 1) { return FriendLook.POSE_FLEX; }
        if (pick == 2) { return FriendLook.POSE_SPIN; }
        if (pick == 3) { return FriendLook.POSE_FLAMES; }
        return FriendLook.POSE_HOP;
    }

    function say(text as Lang.String, seconds as Lang.Number) as Void {
        mSay = text;
        mSayUntil = mElapsed + seconds;
    }

    function homeFace() as Lang.Number {
        if (mChapterState == CHAPTER_ACTIVE || effortScore() > 35) {
            return FriendLook.FACE_EFFORT;
        }
        if (emoteActive() || recentlyRemembered()) { return FriendLook.FACE_JOY; }
        if (isAsleep()) { return FriendLook.FACE_SLEEP; }
        // Mood weather 0..3 is FACE_MISTY..FACE_RADIANT.
        return mPet.weather(mMood);
    }

    function homePose() as Lang.Number {
        if (emoteActive()) { return mEmote; }
        if (mChapterState == CHAPTER_ACTIVE) { return FriendLook.POSE_RUN; }
        if (isAsleep()) { return FriendLook.POSE_SLEEP; }
        return FriendLook.POSE_IDLE;
    }

    // What the friend says under itself. A passing line wins, then what it is
    // watching, then a greeting, then quiet company.
    function homeLine() as Lang.String {
        var voice = mPet.persona();
        if (Time.now().value() <= mSavedUntil) { return "Saved."; }
        if (mElapsed < mSayUntil) { return mSay; }
        if (mChapterState == CHAPTER_ACTIVE) {
            return mVoice.effort(mPendingFlames, voice, mSalt + mElapsed / 40);
        }
        if (recentlyRemembered()) {
            var minutes = (mLastChapterDuration + 30) / 60;
            if (minutes < 1) { minutes = 1; }
            return "I saw " + minutes + " min.";
        }
        if (effortScore() > 35) { return "I see it."; }
        if (isAsleep()) { return "zzz"; }
        if (mElapsed <= 12) { return mGreeting; }
        var slot = mElapsed / 30;
        if (mEvoReady) { return mVoice.evoReady(slot); }
        if (mDayFull && (slot % 2) == 1) { return mVoice.full(voice, mSalt + slot); }
        return mVoice.idle(voice, mSalt + slot);
    }

    // Heart rate, then either its distance from the four-hour baseline or, while
    // a chapter is open, the flames and the XP it has earned so far.
    function drawPulseRow(dc as Graphics.Dc, centerX as Lang.Number, y as Lang.Number) as Void {
        var text = (mHeartRate >= 0) ? mHeartRate.toString() : "--";
        var lit = (mChapterState == CHAPTER_ACTIVE) ? mPendingFlames : 0;
        var tail = "";
        if (lit > 0) {
            tail = "+" + mPending;
        } else if (mHeartRate >= 0 && mBaselineAvg >= 0) {
            var delta = heartDelta();
            tail = (delta >= 0) ? ("+" + delta) : ("" + delta);
        }
        var font = Graphics.FONT_TINY;
        var size = dc.getFontHeight(font) * 30 / 100;
        var flame = dc.getFontHeight(font) * 34 / 100;
        var textWidth = dc.getTextWidthInPixels(text, font);
        var tailWidth = dc.getTextWidthInPixels(tail, font);
        var total = size * 3 + textWidth + 14 + lit * (flame + 6) + tailWidth;
        var x = centerX - total / 2;
        mArt.drawHeart(dc, x + size, y, size);
        x = x + size * 3;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x = x + textWidth + 14;
        for (var i = 0; i < lit; i += 1) {
            mArt.drawFlame(dc, x + flame / 2, y, flame, true);
            x = x + flame + 6;
        }
        dc.setColor((lit > 0) ? C_GOLD : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, tail, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Progress through the current band in the friend's own color, with what
    // is being earned right now in gold ahead of it.
    function drawXpBar(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                       width as Lang.Number, height as Lang.Number, xp as Lang.Number,
                       pending as Lang.Number, band as Lang.Number) as Void {
        var low = mPet.bandThreshold(band);
        var span = mPet.bandThreshold(band + 1) - low;
        var done = xp - low;
        if (done < 0) { done = 0; }
        if (done > span) { done = span; }
        var filled = width * done / span;
        var extra = width * pending / span;
        if (filled + extra > width) { extra = width - filled; }
        // A sliver narrower than the bar is tall would lose its round ends.
        if (filled > 0 && filled < height) { filled = height; }
        if (extra > 0 && filled + extra < height) { extra = height - filled; }
        dc.setColor(0x1E2A26, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, height, height / 2);
        if (extra > 0) {
            dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, filled + extra, height, height / 2);
        }
        if (filled > 0) {
            dc.setColor(mArt.bodyColor(), Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, filled, height, height / 2);
        }
    }

    function drawMeter(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                       width as Lang.Number, height as Lang.Number, value as Lang.Number,
                       full as Lang.Number, backColor as Lang.Number,
                       fillColor as Lang.Number) as Void {
        dc.setColor(backColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, width, height, height / 2);
        var filled = width * value / full;
        if (filled > width) { filled = width; }
        if (filled > 0 && filled < height) { filled = height; }
        if (filled > 0) {
            dc.setColor(fillColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(x, y, filled, height, height / 2);
        }
    }

    // ---- words ------------------------------------------------------------
    function bandName(band as Lang.Number) as Lang.String {
        var names = ["HATCHLING", "SPROUT", "TRAINEE", "ATHLETE", "VETERAN", "ACE",
                     "LEGEND", "HERO", "MYTHIC"] as Lang.Array<Lang.String>;
        if (band < names.size()) { return names[band]; }
        return "MYTHIC " + (band - 7);
    }

    // What a band brings. Every one is an expressive unlock for now: the sensing
    // ladder in doc 12 (naming moves, counting reps) waits for classifiers that
    // work on real wrists.
    function unlockWords(band as Lang.Number) as Lang.String {
        if (band == 1) { return "leaf + flex"; }
        if (band == 2) { return "headband + spin"; }
        if (band == 3) { return "grown-up form"; }
        if (band == 4) { return "flames"; }
        if (band == 5) { return "cape"; }
        if (band == 6) { return "aura"; }
        return "bragging rights";
    }

    function nextText(band as Lang.Number) as Lang.String {
        if ((band % 3) == 0) { return "next: evolution"; }
        return "next: " + unlockWords(band);
    }

    function weatherName(weather as Lang.Number) as Lang.String {
        if (weather >= 3) { return "RADIANT"; }
        if (weather == 2) { return "SUNNY"; }
        if (weather == 1) { return "FAIR"; }
        return "MISTY";
    }

    // Energy is read off the wearer's real clock; it is never a stored bar.
    function energyName() as Lang.String {
        var hour = hourNow();
        if (hour >= 23 || hour < 5) { return "asleep"; }
        if (hour >= 21) { return "winding down"; }
        return "awake";
    }

    // Fullness is today's effort minutes. It resets to peckish each day and
    // never reaches "starving".
    function snackName(minutes as Lang.Number) as Lang.String {
        if (minutes >= 30) { return "FULL"; }
        if (minutes > 0) { return "SNACKED"; }
        return "PECKISH";
    }

    function warmName(warm as Lang.Number) as Lang.String {
        if (warm >= 90) { return "IN THE ZONE"; }
        if (warm >= 70) { return "WARMED UP"; }
        if (warm >= 40) { return "LOOSE"; }
        return "RUSTY BUT FINE";
    }

    function paletteName(pal as Lang.Number) as Lang.String {
        var names = ["MINT", "PEACH", "SKY", "LILAC", "SUN", "ROSE"] as Lang.Array<Lang.String>;
        return names[pal % names.size()];
    }

    function formName(form as Lang.Number) as Lang.String {
        if (form == FriendLook.FORM_SLEEK) { return "SLEEK"; }
        if (form == FriendLook.FORM_WILD) { return "WILD"; }
        return "ROUND";
    }

    function goalName(goal as Lang.Number) as Lang.String {
        if (goal == 1000) { return "first km"; }
        if (goal == 5000) { return "5 km picnic"; }
        if (goal == 10000) { return "10 km ridge"; }
        if (goal == 21097) { return "half marathon"; }
        if (goal == 42195) { return "marathon"; }
        return "" + (goal / 1000) + " km club";
    }

    function kmText(meters as Lang.Number) as Lang.String {
        return "" + (meters / 1000) + "." + ((meters % 1000) / 100) + " km";
    }

    function petDebugText() as Lang.String {
        if (!mPet.exists()) { return "NO PET YET"; }
        return "XP " + mPet.xp() + "  B" + mBand + "  M" + mMood;
    }

    // ---- cards ------------------------------------------------------------
    // Today: three readouts derived on the spot. Nothing here is a bar that
    // drains while the wearer is away.
    function drawToday(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var width = dc.getWidth();
        var centerX = width / 2;
        var now = Time.now().value();
        var weather = mPet.weather(mMood);
        drawCenteredLine(dc, centerX, height * 10 / 100, "TODAY", C_ACCENT,
                         [Graphics.FONT_XTINY]);
        // Mist bars would cross the text here, so a misty day shows as cloud.
        mArt.drawSky(dc, width, height, (weather < 1) ? 1 : weather, isNight(), 0);
        drawCenteredLine(dc, centerX, height * 23 / 100, weatherName(weather),
                         Graphics.COLOR_WHITE, [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        drawCenteredLine(dc, centerX, height * 33 / 100,
                         "mood " + mMood + "   " + energyName(),
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);

        var minutes = mPet.dayMinutes(now);
        drawCenteredLine(dc, centerX, height * 45 / 100, snackName(minutes), C_ORANGE,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        var barWidth = width * 44 / 100;
        drawMeter(dc, centerX - barWidth / 2, height * 51 / 100, barWidth, 8, minutes, 30,
                  0x2A2018, C_ORANGE);
        drawCenteredLine(dc, centerX, height * 58 / 100, "" + minutes + " of 30 effort min",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);

        drawCenteredLine(dc, centerX, height * 70 / 100, warmName(mPet.warmth(now)), C_GOLD,
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        var held = mPet.shields(now);
        mArt.drawShield(dc, centerX - 16, height * 79 / 100, 9, held >= 1);
        mArt.drawShield(dc, centerX + 16, height * 79 / 100, 9, held >= 2);
        drawCenteredLine(dc, centerX, height * 88 / 100, "rest-day shields",
                         Graphics.COLOR_DK_GRAY, [Graphics.FONT_XTINY]);
    }

    function drawGrowth(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var width = dc.getWidth();
        var centerX = width / 2;
        var toGo = mPet.bandThreshold(mBand + 1) - mPet.xp();
        drawCenteredLine(dc, centerX, height * 10 / 100, "GROWING", C_ACCENT,
                         [Graphics.FONT_XTINY]);
        drawPet(dc, centerX, height * 37 / 100, 62, FriendLook.FACE_SUNNY, FriendLook.POSE_IDLE);
        drawCenteredLine(dc, centerX, height * 46 / 100, bandName(mBand), Graphics.COLOR_WHITE,
                         [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        drawXpBar(dc, centerX - width * 30 / 100, height * 54 / 100, width * 60 / 100, 12,
                  mPet.xp(), 0, mBand);
        drawCenteredLine(dc, centerX, height * 63 / 100,
                         (toGo > 0) ? ("" + toGo + " XP to " + bandName(mBand + 1))
                                    : "enough to evolve",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 73 / 100, nextText(mBand + 1), C_GOLD,
                         [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 82 / 100, "" + mPet.memories() + " memories",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        if (mEvoReady) {
            drawCenteredLine(dc, centerX, height * 90 / 100, "START evolve", C_MINT,
                             [Graphics.FONT_XTINY]);
            drawStartHint(dc);
        } else {
            drawCenteredLine(dc, centerX, height * 90 / 100,
                             "day " + mPet.ageDays(Time.now().value()),
                             Graphics.COLOR_DK_GRAY, [Graphics.FONT_XTINY]);
        }
    }

    // Walks with Friend add up to one long trail with landmarks along it.
    function drawTrail(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var width = dc.getWidth();
        var centerX = width / 2;
        var meters = mPet.trailMeters();
        var walks = mPet.trailWalks();
        var goal = mPet.trailGoal();
        dressPet();
        drawCenteredLine(dc, centerX, height * 11 / 100, "OUR TRAIL", C_ACCENT,
                         [Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 26 / 100, kmText(meters), Graphics.COLOR_WHITE,
                         [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM]);
        drawCenteredLine(dc, centerX, height * 38 / 100,
                         (walks == 1) ? "1 walk together" : ("" + walks + " walks together"),
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);

        // A dotted path to a flag at the next landmark.
        var left = centerX - width * 30 / 100;
        var span = width * 60 / 100;
        var y = height * 56 / 100;
        var reached = 12 * meters / goal;
        for (var i = 0; i <= 12; i += 1) {
            var x = left + span * i / 12;
            var dotY = y + (((i % 4) < 2) ? -3 : 3);
            if (i <= reached) {
                dc.setColor(mArt.bodyColor(), Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, dotY, 5);
            } else {
                dc.setColor(0x33403A, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, dotY, 3);
            }
        }
        var flagX = left + span;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawLine(flagX, y - 30, flagX, y);
        dc.setColor(C_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[flagX, y - 30], [flagX + 20, y - 23], [flagX, y - 16]]);

        drawCenteredLine(dc, centerX, height * 70 / 100, "next: " + goalName(goal), C_GOLD,
                         [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 80 / 100, kmText(goal - meters) + " to go",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 90 / 100, "START walk", Graphics.COLOR_DK_GRAY,
                         [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    // ---- the reward --------------------------------------------------------
    // One clean payoff: what the effort earned, how hard it was, one line of
    // reaction, and the bar moving toward the next band. No spreadsheet.
    function drawReward(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var width = dc.getWidth();
        var centerX = width / 2;
        var points = mPet.owedPoints();
        var lit = mPet.owedFlames();
        var hatch = (lit == 0);
        var title = "LAST TIME";
        if (hatch) {
            title = "HATCHED!";
        } else if (mRewardExit) {
            title = "EFFORT SNACK";
        }
        drawCenteredLine(dc, centerX, height * 9 / 100, title, C_ACCENT, [Graphics.FONT_XTINY]);
        drawPet(dc, centerX, height * 43 / 100, 66, FriendLook.FACE_JOY, FriendLook.POSE_HOP);
        drawCenteredLine(dc, centerX, height * 55 / 100, "+" + points + " XP", C_GOLD,
                         [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM]);
        var rowY = height * 66 / 100;
        if (hatch) {
            mArt.drawSparkle(dc, centerX - 44, rowY, 8, 0xFFF3B8);
            mArt.drawSparkle(dc, centerX, rowY, 11, 0xFFF3B8);
            mArt.drawSparkle(dc, centerX + 44, rowY, 8, 0xFFF3B8);
        } else {
            var flame = 26;
            var x = centerX - (3 * flame + 2 * 10) / 2 + flame / 2;
            for (var i = 0; i < 3; i += 1) {
                mArt.drawFlame(dc, x, rowY, flame, i < lit);
                x = x + flame + 10;
            }
        }
        drawCenteredLine(dc, centerX, height * 75 / 100,
                         hatch ? mVoice.hatched() : mVoice.reward(lit, mPet.persona(), mSalt),
                         Graphics.COLOR_WHITE, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawXpBar(dc, centerX - width * 22 / 100, height * 81 / 100, width * 44 / 100, 10,
                  mPet.xp() - points, points, mBand);
        drawCenteredLine(dc, centerX, height * 89 / 100, rewardDetail(hatch),
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    function rewardDetail(hatch as Lang.Boolean) as Lang.String {
        if (hatch) { return "" + mPet.memories() + " memories"; }
        if (mEvoReady) { return "ready to evolve!"; }
        var minutes = (mPet.owedSeconds() + 30) / 60;
        if (minutes < 1) { minutes = 1; }
        var text = "" + minutes + " min";
        if ((mPet.owedFlags() % 2) == 1) { text += "  first today"; }
        return text;
    }

    function drawGrew(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var width = dc.getWidth();
        var centerX = width / 2;
        drawCenteredLine(dc, centerX, height * 10 / 100, "GREW UP!", C_GOLD,
                         [Graphics.FONT_TINY]);
        mArt.drawSparkle(dc, width * 20 / 100, height * 26 / 100, 9, 0xFFF3B8);
        mArt.drawSparkle(dc, width * 82 / 100, height * 32 / 100, 7, 0xFFF3B8);
        mArt.drawSparkle(dc, width * 76 / 100, height * 17 / 100, 5, 0xFFF3B8);
        drawPet(dc, centerX, height * 53 / 100, 82, FriendLook.FACE_RADIANT,
                (mBand >= 1) ? FriendLook.POSE_FLEX : FriendLook.POSE_HOP);
        drawCenteredLine(dc, centerX, height * 64 / 100, bandName(mBand), Graphics.COLOR_WHITE,
                         [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        drawCenteredLine(dc, centerX, height * 75 / 100, "new: " + unlockWords(mBand), C_GOLD,
                         [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 86 / 100, "START ok", Graphics.COLOR_DK_GRAY,
                         [Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    // START or Back on the reward card. True means leave the app.
    function advanceReward() as Lang.Boolean {
        if (mScreen == SCREEN_REWARD && mPet.band() > mPet.owedBand()) {
            mScreen = SCREEN_GREW;
            return false;
        }
        mPet.clearOwed();
        refreshPet();
        if (mRewardExit) { return true; }
        mRecap = false;
        mScreen = SCREEN_HOME;
        return false;
    }

    // Called by the delegate once Back has saved the session. True means stay a
    // moment: the friend shows what this visit earned, then Friend leaves on a
    // press or by itself.
    function beginExitReward() as Lang.Boolean {
        if (mRewardExit || !mPet.exists() || mPet.owedPoints() <= 0) { return false; }
        mRewardExit = true;
        mRecap = false;
        refreshPet();
        mScreen = SCREEN_REWARD;
        if (mExitTimer == null) { mExitTimer = new Timer.Timer(); }
        (mExitTimer as Timer.Timer).start(method(:onRewardTimeout), REWARD_LINGER_MS, false);
        WatchUi.requestUpdate();
        return true;
    }

    // Nobody pressed anything: leave. The reward stays owed, so the next visit
    // opens with it.
    function onRewardTimeout() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // ---- first run: the egg -----------------------------------------------
    function drawEggScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var hatching = (mScreen == SCREEN_HATCHING);
        var title = "AN EGG!";
        if (hatching) {
            title = "IT'S HATCHING!";
        } else if (mRepick) {
            title = "NEW LOOK";
        }
        var crack = 0;
        if (hatching) {
            crack = (mFrame - mHatchFrame) / 4 + 1;
            if (crack > 3) { crack = 3; }
        }
        mArt.setLook(FriendLook.STAGE_EGG, 0, 0, 0, mPickPal);
        mArt.setPose(FriendLook.FACE_FAIR, FriendLook.POSE_IDLE, mFrame);
        var size = mArt.sizeFor(FriendLook.STAGE_EGG, height);
        drawCenteredLine(dc, centerX, height * 11 / 100, title, C_GOLD, [Graphics.FONT_TINY]);
        mArt.drawEgg(dc, centerX, height * 56 / 100 - size * 108 / 100, size, crack);
        drawCenteredLine(dc, centerX, height * 67 / 100, paletteName(mPickPal), mArt.bodyColor(),
                         [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
        if (!hatching) {
            drawCenteredLine(dc, centerX, height * 77 / 100, "UP/DOWN color",
                             Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
            drawCenteredLine(dc, centerX, height * 86 / 100,
                             mRepick ? "START next" : "START hatch", C_MINT,
                             [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
            drawStartHint(dc);
        }
    }

    // The voice is a permanent trait, so the wearer hears it before choosing.
    function drawVoiceScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var stage = FriendLook.STAGE_BABY;
        if (mRepick) {
            stage = petStage();
            mArt.setLook(stage, mBand, mPet.form(), mPet.evos(), mPickPal);
            mArt.setEmblem(mPet.emblem(), mEmblemLevel);
        } else {
            mArt.setLook(stage, 0, 0, 0, mPickPal);
        }
        mArt.setPose(FriendLook.FACE_SUNNY, FriendLook.POSE_IDLE, mFrame);
        drawCenteredLine(dc, centerX, height * 10 / 100, "HOW DO I TALK?", C_GOLD,
                         [Graphics.FONT_XTINY]);
        // A grown friend at home size would reach the title; the hatchling fits.
        mArt.drawStanding(dc, centerX, height * 40 / 100, mRepick ? 62 : 80);
        drawCenteredLine(dc, centerX, height * 51 / 100, mVoice.voiceName(mPickVoice),
                         Graphics.COLOR_WHITE, [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        drawCenteredLine(dc, centerX, height * 62 / 100, mVoice.voiceSample(mPickVoice), C_MINT,
                         [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 75 / 100, "UP/DOWN voice",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 85 / 100,
                         (mRepick && mBand >= 1) ? "START next" : "START keep", C_MINT,
                         [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    // The belly emblem, last stop of the new-look path once the friend has a
    // belly patch (band 1 on). Every emblem is on offer for now: the rules for
    // earning them (garmin-pet/art/sheets/PROMPTS.md) are not built.
    function drawEmblemScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        mArt.setLook(petStage(), mBand, mPet.form(), mPet.evos(), mPickPal);
        mArt.setEmblem(mPickEmblem, 1);
        mArt.setPose(FriendLook.FACE_SUNNY, FriendLook.POSE_IDLE, mFrame);
        drawCenteredLine(dc, centerX, height * 10 / 100, "BELLY MARK", C_GOLD,
                         [Graphics.FONT_XTINY]);
        mArt.drawStanding(dc, centerX, height * 52 / 100, 100);
        drawCenteredLine(dc, centerX, height * 62 / 100, emblemName(mPickEmblem),
                         Graphics.COLOR_WHITE, [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        drawCenteredLine(dc, centerX, height * 74 / 100, "UP/DOWN mark",
                         Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        drawCenteredLine(dc, centerX, height * 84 / 100, "START keep", C_MINT,
                         [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        drawStartHint(dc);
    }

    function emblemName(emblem as Lang.Number) as Lang.String {
        if (emblem < 1 || emblem > FRIEND_EMBLEMS) { return "BARE"; }
        return friendEmblemNames()[emblem - 1];
    }

    function commitHatch() as Void {
        if (mRepick) {
            mPet.setLook(mPickPal, mPickVoice);
            if (mBand >= 1) { mPet.setEmblem(mPickEmblem); }
            mRepick = false;
            refreshPet();
            mScreen = SCREEN_HOME;
            return;
        }
        // The egg was listening the whole time: every chapter Friend still
        // holds is credited, and the reward card shows the lot.
        mPet.hatch(Time.now().value(), mPickPal, mPickVoice);
        refreshPet();
        mGreeting = mVoice.hello(hourNow(), mPet.persona(), mSalt);
        mAwakeUntil = mElapsed + 30;
        mRecap = false;
        mScreen = (mPet.owedPoints() > 0) ? SCREEN_REWARD : SCREEN_HOME;
    }

    // ---- evolution: the one permanent fork ---------------------------------
    function drawEvolveScreen(dc as Graphics.Dc) as Void {
        var height = dc.getHeight();
        var centerX = dc.getWidth() / 2;
        var confirm = (mScreen == SCREEN_EVOLVE_CONFIRM);
        mArt.setLook(FriendLook.STAGE_ADULT, mBand + 1, mPickForm, mPet.evos() + 1,
                     mPet.palette());
        mArt.setEmblem(mPet.emblem(), mEmblemLevel);
        mArt.setPose(FriendLook.FACE_SUNNY, FriendLook.POSE_IDLE, mFrame);
        drawCenteredLine(dc, centerX, height * 10 / 100,
                         confirm ? "KEEP FOREVER?" : "WHO WILL I BE?", C_GOLD,
                         [Graphics.FONT_XTINY]);
        mArt.drawStanding(dc, centerX, height * 53 / 100, 82);
        drawCenteredLine(dc, centerX, height * 61 / 100, formName(mPickForm),
                         Graphics.COLOR_WHITE, [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]);
        if (confirm) {
            drawCenteredLine(dc, centerX, height * 73 / 100, "START yes", C_MINT,
                             [Graphics.FONT_TINY]);
            drawCenteredLine(dc, centerX, height * 83 / 100, "BACK look again",
                             Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
        } else {
            drawCenteredLine(dc, centerX, height * 73 / 100, "UP/DOWN look",
                             Graphics.COLOR_LT_GRAY, [Graphics.FONT_XTINY]);
            drawCenteredLine(dc, centerX, height * 83 / 100, "START choose", C_MINT,
                             [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        }
        drawStartHint(dc);
    }

    function commitEvolve() as Void {
        if (mPet.evolve(Time.now().value(), mPickForm)) {
            refreshPet();
            mScreen = SCREEN_GREW;
        } else {
            mScreen = SCREEN_GROWTH;
        }
    }

    // ---- walks and the live chapter ----------------------------------------
    // Under a minute and under 50 m is a stray press (the 2026-11-09 export has
    // a 5-second, 4 m walk that went to Garmin Connect as an activity).
    function walkTooShort() as Lang.Boolean {
        return mWalk.elapsed() < 60 && mWalk.distanceMeters() < 50;
    }

    function walkKept() as Void {
        if (!mPet.exists()) { return; }
        mPet.addWalk(mWalk.distanceMeters());
        say(mVoice.walkDone(mPet.persona(), mSalt), 10);
    }

    // What the open chapter would earn if it ended now, for the home screen.
    function updatePending() as Void {
        if (mChapterState != CHAPTER_ACTIVE || !mPet.exists()) {
            mPending = 0;
            mPendingFlames = 0;
            return;
        }
        var duration = mChapterLastStrong - mChapterStart;
        if (duration < LIVE_INTERVAL_SECONDS) { duration = LIVE_INTERVAL_SECONDS; }
        var hrAvg = (mChapterHrCount > 0) ? (mChapterHrSum / mChapterHrCount) : -1;
        var credit = mPet.creditFor(mChapterStart, duration, mBaselineAvg, hrAvg);
        mPending = credit[0];
        mPendingFlames = mPet.flameCount(credit[1]);
    }
}
