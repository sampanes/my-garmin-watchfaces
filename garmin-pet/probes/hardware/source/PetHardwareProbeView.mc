using Toybox.ActivityMonitor;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Sensor;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.UserProfile;
using Toybox.WatchUi;

class PetHardwareProbeView extends WatchUi.View {
    var mProbeIndex as Lang.Number = 0;
    var mLines as Lang.Array<Lang.String>;

    const PROBE_COUNT = 7;

    function initialize() {
        View.initialize();
        mLines = [ "SEL", "RUN" ] as Lang.Array<Lang.String>;
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var centerX = width / 2;
        var usableTop = 82;
        var usableBottom = height - 54;
        var lineStep = 56;
        var blockHeight = (mLines.size() - 1) * lineStep;
        var lineY = ((usableTop + usableBottom) / 2) - (blockHeight / 2);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(centerX, 18, Graphics.FONT_LARGE, getProbeCode() + " " + getProbeTitle(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        for (var i = 0; i < mLines.size(); i += 1) {
            dc.drawText(centerX, lineY, Graphics.FONT_LARGE, shortText(mLines[i], 8),
                        Graphics.TEXT_JUSTIFY_CENTER);
            lineY += lineStep;
            if (lineY > usableBottom) {
                break;
            }
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(centerX, height - 24, Graphics.FONT_SMALL,
                    "SEL  UP/DN",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    function nextProbe() as Void {
        mProbeIndex = (mProbeIndex + 1) % PROBE_COUNT;
        resetLines();
    }

    function previousProbe() as Void {
        mProbeIndex -= 1;
        if (mProbeIndex < 0) {
            mProbeIndex = PROBE_COUNT - 1;
        }
        resetLines();
    }

    function resetLines() as Void {
        if (!loadSavedLines()) {
            mLines = [ "SEL", "RUN" ] as Lang.Array<Lang.String>;
        }
        WatchUi.requestUpdate();
    }

    function runCurrentProbe() as Void {
        if (mProbeIndex == 0) {
            probeDeviceInfo();
        } else if (mProbeIndex == 1) {
            probeTone();
        } else if (mProbeIndex == 2) {
            probeVibe();
        } else if (mProbeIndex == 3) {
            probeBodyBattery();
        } else if (mProbeIndex == 4) {
            probeStress();
        } else if (mProbeIndex == 5) {
            probeVo2();
        } else {
            probeBarometer();
        }
        WatchUi.requestUpdate();
    }

    function getProbeCode() as Lang.String {
        if (mProbeIndex == 0) {
            return "T0";
        } else if (mProbeIndex == 1) {
            return "T1";
        } else if (mProbeIndex == 2) {
            return "T2";
        } else if (mProbeIndex == 3) {
            return "T7";
        } else if (mProbeIndex == 4) {
            return "T8";
        } else if (mProbeIndex == 5) {
            return "T14";
        }
        return "T17";
    }

    function getProbeTitle() as Lang.String {
        if (mProbeIndex == 0) {
            return "DEV";
        } else if (mProbeIndex == 1) {
            return "BEEP";
        } else if (mProbeIndex == 2) {
            return "BUZZ";
        } else if (mProbeIndex == 3) {
            return "BB";
        } else if (mProbeIndex == 4) {
            return "STR";
        } else if (mProbeIndex == 5) {
            return "VO2";
        }
        return "BARO";
    }

    function setResult(lines as Lang.Array<Lang.String>) as Void {
        mLines = lines;
        saveLines(lines);
        System.println(getProbeCode() + ": " + lines.toString());
    }

    function saveLines(lines as Lang.Array<Lang.String>) as Void {
        try {
            var code = getProbeCode();
            Application.Storage.setValue(code + "_n", lines.size());
            for (var i = 0; i < lines.size(); i += 1) {
                Application.Storage.setValue(code + "_" + i, lines[i]);
            }
        } catch (e) {
            System.println("Storage save failed: " + e.getErrorMessage());
        }
    }

    function loadSavedLines() as Lang.Boolean {
        try {
            var code = getProbeCode();
            var countValue = Application.Storage.getValue(code + "_n");
            if (!(countValue instanceof Lang.Number)) {
                return false;
            }

            var count = countValue as Lang.Number;
            var lines = [] as Lang.Array<Lang.String>;
            for (var i = 0; i < count; i += 1) {
                var line = Application.Storage.getValue(code + "_" + i);
                if (line instanceof Lang.String) {
                    lines.add(line as Lang.String);
                }
            }

            if (lines.size() > 0) {
                mLines = lines;
                return true;
            }
        } catch (e) {
            System.println("Storage load failed: " + e.getErrorMessage());
        }
        return false;
    }

    function probeDeviceInfo() as Void {
        try {
            var settings = System.getDeviceSettings();
            setResult([
                settings.screenWidth + "x" + settings.screenHeight,
                "AOD " + yesNo((settings has :requiresBurnInProtection) && settings.requiresBurnInProtection),
                "24H " + yesNo((settings has :is24Hour) && settings.is24Hour)
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function probeTone() as Void {
        try {
            Attention.playTone(Attention.TONE_SUCCESS);
            setResult([
                "BEEP?",
                "Y/N"
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function probeVibe() as Void {
        try {
            Attention.vibrate([
                new Attention.VibeProfile(25, 200),
                new Attention.VibeProfile(100, 200),
                new Attention.VibeProfile(25, 200)
            ]);
            setResult([
                "PAT?",
                "FLAT?"
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function probeBodyBattery() as Void {
        try {
            var history = SensorHistory.getBodyBatteryHistory({});
            var sample = history.next();
            if (sample == null) {
                setResult([ "NULL" ] as Lang.Array<Lang.String>);
            } else {
                setResult([
                    "" + sample.data
                ] as Lang.Array<Lang.String>);
            }
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function probeStress() as Void {
        try {
            var info = ActivityMonitor.getInfo();
            var stress = "n/a";
            if ((info != null) && (info has :stressScore)) {
                stress = "" + info.stressScore;
            }

            var history = SensorHistory.getStressHistory({});
            var sample = history.next();
            var sampleText = "null";
            if (sample != null) {
                sampleText = "" + sample.data;
            }

            setResult([
                "N " + stress,
                "H " + sampleText
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function probeVo2() as Void {
        try {
            var profile = UserProfile.getProfile();
            var run = "n/a";
            var bike = "n/a";
            if ((profile != null) && (profile has :vo2maxRunning)) {
                run = "" + profile.vo2maxRunning;
            }
            if ((profile != null) && (profile has :vo2maxCycling)) {
                bike = "" + profile.vo2maxCycling;
            }
            setResult([
                "R " + run,
                "B " + bike
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function probeBarometer() as Void {
        try {
            var sensorInfo = Sensor.getInfo();
            var pressure = "n/a";
            var altitude = "n/a";
            if ((sensorInfo != null) && (sensorInfo has :pressure)) {
                pressure = "" + sensorInfo.pressure;
            }
            if ((sensorInfo != null) && (sensorInfo has :altitude)) {
                altitude = "" + sensorInfo.altitude;
            }

            var activityInfo = ActivityMonitor.getInfo();
            var floors = "n/a";
            if ((activityInfo != null) && (activityInfo has :floorsClimbed)) {
                floors = "" + activityInfo.floorsClimbed;
            }

            setResult([
                "P " + pressure,
                "A " + altitude,
                "F " + floors
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function yesNo(value as Lang.Boolean) as Lang.String {
        if (value) {
            return "YES";
        }
        return "NO";
    }

    function shortText(value as Lang.String?, maxLen as Lang.Number) as Lang.String {
        if (value == null) {
            return "";
        }
        if (value.length() <= maxLen) {
            return value;
        }
        var clipped = value.substring(0, maxLen);
        if (clipped == null) {
            return "";
        }
        return clipped;
    }
}
