using Toybox.ActivityMonitor;
using Toybox.Ant;
using Toybox.Application;
using Toybox.Attention;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Sensor;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.UserProfile;
using Toybox.WatchUi;

class PetHardwareProbeView extends WatchUi.View {
    var mProbeIndex as Lang.Number = 0;
    var mLines as Lang.Array<Lang.String>;

    const PROBE_COUNT = 10;

    // T23/T24: one generic ANT channel, master (TX) or slave (RX). Spike B
    // parameters (03-ble-live.md): public network, RF 66 (not 57), a fixed
    // non-zero device number, 4 Hz. The payload is "PET" + 0 0 0 0 + counter.
    const ANT_RF = 66;
    const ANT_DEVICE_NUMBER = 0xBEEF;
    const ANT_DEVICE_TYPE = 1;
    const ANT_TRANS_TYPE = 1;
    const ANT_PERIOD = 8192;          // 32768 / 8192 = 4 messages per second
    var mAnt as Ant.GenericChannel?;
    var mAntTx as Lang.Boolean = false;
    var mAntOpen as Lang.Boolean = false;
    var mAntTxCount as Lang.Number = 0;     // EVENT_TX events (master)
    var mAntRxCount as Lang.Number = 0;     // broadcasts received (slave)
    var mAntFailCount as Lang.Number = 0;   // every other RF event
    var mAntLastEvent as Lang.Number = -1;  // last RF event code
    var mAntCounter as Lang.Number = 0;     // master: last counter sent; slave: last seen

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
        leaveProbe();
        mProbeIndex = (mProbeIndex + 1) % PROBE_COUNT;
        resetLines();
    }

    function previousProbe() as Void {
        leaveProbe();
        mProbeIndex -= 1;
        if (mProbeIndex < 0) {
            mProbeIndex = PROBE_COUNT - 1;
        }
        resetLines();
    }

    // Probes that hold a resource give it back when the wearer scrolls
    // away, so the next probe runs on a clean watch and the final numbers
    // are saved.
    function leaveProbe() as Void {
        if (mProbeIndex == 8 || mProbeIndex == 9) {
            if (mAnt != null) {
                releaseAnt();
                setResult(antLines("DONE"));
            }
        }
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
        } else if (mProbeIndex == 6) {
            probeBarometer();
        } else if (mProbeIndex == 7) {
            probeComplications();
        } else if (mProbeIndex == 8) {
            probeAnt(true);
        } else {
            probeAnt(false);
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
        } else if (mProbeIndex == 6) {
            return "T17";
        } else if (mProbeIndex == 7) {
            return "T15";
        } else if (mProbeIndex == 8) {
            return "T23";
        }
        return "T24";
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
        } else if (mProbeIndex == 6) {
            return "BARO";
        } else if (mProbeIndex == 7) {
            return "COMP";
        } else if (mProbeIndex == 8) {
            return "ANT TX";
        }
        return "ANT RX";
    }

    function setResult(lines as Lang.Array<Lang.String>) as Void {
        mLines = lines;
        saveLines(lines);
        System.println(getProbeCode() + ": " + lines.toString());
    }

    // Live counters (ANT at 4 Hz, complication callbacks) repaint without a
    // Storage write per tick; the final numbers are saved by setResult when
    // the probe stops.
    function showLines(lines as Lang.Array<Lang.String>) as Void {
        mLines = lines;
        WatchUi.requestUpdate();
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

    // Tones are silently suppressed when the system sound setting is off, so a
    // "no beep" observation is only meaningful alongside the tonesOn state.
    function probeTone() as Void {
        try {
            var settings = System.getDeviceSettings();
            var sysTones = (settings has :tonesOn) && settings.tonesOn;
            if (!(Attention has :playTone)) {
                setResult([ "NO API", "SND " + yesNo(sysTones) ] as Lang.Array<Lang.String>);
                return;
            }
            Attention.playTone(Attention.TONE_SUCCESS);
            setResult([
                "SND " + yesNo(sysTones),
                "BEEP?"
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function probeVibe() as Void {
        try {
            var settings = System.getDeviceSettings();
            var sysVibe = (settings has :vibrateOn) && settings.vibrateOn;
            if (!(Attention has :vibrate)) {
                setResult([ "NO API", "VIB " + yesNo(sysVibe) ] as Lang.Array<Lang.String>);
                return;
            }
            Attention.vibrate([
                new Attention.VibeProfile(25, 200),
                new Attention.VibeProfile(100, 200),
                new Attention.VibeProfile(25, 200)
            ]);
            setResult([
                "VIB " + yesNo(sysVibe),
                "PAT?"
            ] as Lang.Array<Lang.String>);
        } catch (e) {
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    // Distinguish "module/method absent" from "iterator null" from "no samples":
    // that three-way split is the datum T7 exists to capture.
    function probeBodyBattery() as Void {
        try {
            if (!((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getBodyBatteryHistory))) {
                setResult([ "NO API" ] as Lang.Array<Lang.String>);
                return;
            }
            // Typed non-null in the SDK, so the null branch read as
            // unreachable; the cast keeps the firmware-returned-null case
            // (what NO ITER reports) without the warning.
            var history = SensorHistory.getBodyBatteryHistory({}) as SensorHistory.SensorHistoryIterator?;
            if (history == null) {
                setResult([ "NO ITER" ] as Lang.Array<Lang.String>);
                return;
            }
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

            var sampleText = "NO API";
            var ageText = "AGE n/a";
            if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getStressHistory)) {
                var history = SensorHistory.getStressHistory({}) as SensorHistory.SensorHistoryIterator?;
                if (history == null) {
                    sampleText = "NO ITER";
                } else {
                    var sample = history.next();
                    sampleText = (sample == null) ? "null" : ("" + sample.data);
                    // T8 asks whether the history timestamps are sane: report the
                    // newest sample's age in minutes.
                    var newest = history.getNewestSampleTime();
                    if (newest != null) {
                        var ageMin = (Time.now().value() - newest.value()) / 60;
                        ageText = "AGE " + ageMin + "m";
                    }
                }
            }

            setResult([
                "N " + stress,
                "H " + sampleText,
                ageText
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
            // Format floats compactly: raw Float toString overflows the 8-char
            // display clip (e.g. "101325.123456") and hides the reading.
            // Copied to locals: the checker narrows a local after a null
            // test, never a member (COMPILER_FACTS 1.4).
            if ((sensorInfo != null) && (sensorInfo has :pressure)) {
                var p = sensorInfo.pressure;
                if (p != null) { pressure = p.format("%.0f"); }
            }
            if ((sensorInfo != null) && (sensorInfo has :altitude)) {
                var alt = sensorInfo.altitude;
                if (alt != null) { altitude = alt.format("%.1f"); }
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

    // T15: can a DEVICE APP subscribe to complications, or only a watch face?
    // Answered by the compiler (SDK 9.1, 2026-10-30): a watch-app may not
    // declare ComplicationSubscriber ("permission is invalid for app type
    // 'watch-app'"), and without it every Toybox.Complications reference is
    // a compile error. So a device app can neither subscribe nor read; the
    // row only reports that.
    function probeComplications() as Void {
        setResult([ "NO: compiler", "watch-app may", "not use", "Complications" ] as Lang.Array<Lang.String>);
    }

    // T23 (master, TX) and T24 (slave, RX): one generic ANT channel on the
    // Spike B parameters. First SELECT acquires, configures and opens it;
    // the lines then count live: a master counts EVENT_TX (one per
    // transmission, 4 Hz when the radio is really sending), a slave counts
    // broadcasts received and shows the counter byte of the last one. EV is
    // the last RF event code (0x03 TX, 0x01 search timeout, 0x02 RX fail,
    // 0x07 closed, 0xFF the wearer declined the connection prompt). Second
    // SELECT, or scrolling away, closes and releases the channel and saves
    // the final numbers. T23 is answered by one watch (OPEN YES and TX
    // climbing); T24 needs the other watch running this probe's RX row.
    function probeAnt(tx as Lang.Boolean) as Void {
        try {
            if (!((Toybox has :Ant) && (Ant has :GenericChannel))) {
                setResult([ "NO API" ] as Lang.Array<Lang.String>);
                return;
            }
            if (mAnt != null) {
                releaseAnt();
                setResult(antLines("STOP"));
                return;
            }
            mAntTx = tx;
            mAntOpen = false;
            mAntTxCount = 0;
            mAntRxCount = 0;
            mAntFailCount = 0;
            mAntLastEvent = -1;
            mAntCounter = 0;

            var assignment = new Ant.ChannelAssignment(
                tx ? Ant.CHANNEL_TYPE_TX_NOT_RX : Ant.CHANNEL_TYPE_RX_NOT_TX,
                Ant.NETWORK_PUBLIC);
            var channel = new Ant.GenericChannel(method(:onAntMessage), assignment);
            mAnt = channel;
            var config = new Ant.DeviceConfig({
                :deviceNumber => ANT_DEVICE_NUMBER,
                :deviceType => ANT_DEVICE_TYPE,
                :transmissionType => ANT_TRANS_TYPE,
                :messagePeriod => ANT_PERIOD,
                :radioFrequency => ANT_RF,
                :searchTimeoutLowPriority => 12,   // 30 s, the maximum
                :searchThreshold => 0
            });
            var configured = channel.setDeviceConfig(config);
            mAntOpen = channel.open();
            if (tx && mAntOpen) {
                sendAntCounter();
            }
            setResult(antLines("CFG " + yesNo(configured)));
        } catch (e) {
            releaseAnt();
            setResult([ "ERROR", shortText(e.getErrorMessage(), 16) ] as Lang.Array<Lang.String>);
        }
    }

    function antLines(first as Lang.String) as Lang.Array<Lang.String> {
        return [
            first,
            "OPEN " + yesNo(mAntOpen),
            (mAntTx ? "TX " + mAntTxCount : "RX " + mAntRxCount),
            "N " + mAntCounter + " F " + mAntFailCount,
            "EV " + ((mAntLastEvent < 0) ? "-" : mAntLastEvent.format("%02X"))
        ] as Lang.Array<Lang.String>;
    }

    // The master's broadcast payload: "PET", four zero bytes, a counter the
    // slave can check for gaps. Each EVENT_TX loads the next one.
    function sendAntCounter() as Void {
        var channel = mAnt;
        if (channel == null) {
            return;
        }
        mAntCounter = (mAntCounter + 1) % 256;
        var message = new Ant.Message();
        message.setPayload([ 0x50, 0x45, 0x54, 0, 0, 0, 0, mAntCounter ] as Lang.Array<Lang.Number>);
        channel.sendBroadcast(message);
    }

    // Channel response events arrive as payload [message id, code]: an RF
    // event (MSG_ID_RF_EVENT) carries the event code, anything else is the
    // response to a command (open, config) and is shown as its code too.
    function onAntMessage(message as Ant.Message) as Void {
        try {
            var payload = message.getPayload();
            if (message.messageId == Ant.MSG_ID_CHANNEL_RESPONSE_EVENT) {
                var responseTo = (payload.size() > 0) ? (payload[0] & 0xFF) : -1;
                var code = (payload.size() > 1) ? (payload[1] & 0xFF) : -1;
                if (responseTo == Ant.MSG_ID_RF_EVENT) {
                    mAntLastEvent = code;
                    if (code == Ant.MSG_CODE_EVENT_TX) {
                        mAntTxCount += 1;
                        sendAntCounter();
                    } else if (code == Ant.MSG_CODE_EVENT_CHANNEL_CLOSED ||
                               code == Ant.MSG_CODE_EVENT_CONNECTION_REJECTED) {
                        mAntOpen = false;
                    } else {
                        mAntFailCount += 1;
                    }
                } else if (code != Ant.MSG_CODE_RESPONSE_NO_ERROR) {
                    // a command the radio refused (wrong state, id not set)
                    mAntLastEvent = code;
                    mAntFailCount += 1;
                }
            } else if (message.messageId == Ant.MSG_ID_BROADCAST_DATA) {
                mAntRxCount += 1;
                if (payload.size() >= 8) {
                    mAntCounter = payload[7] & 0xFF;
                }
            }
        } catch (e) {
            mAntFailCount += 1;
        }
        if (mProbeIndex == 8 || mProbeIndex == 9) {
            showLines(antLines("LIVE"));
        }
    }

    function releaseAnt() as Void {
        var channel = mAnt;
        mAnt = null;
        if (channel == null) {
            return;
        }
        try {
            channel.release();      // closes it first when open
        } catch (e) {
            System.println("ANT release failed: " + e.getErrorMessage());
        }
        mAntOpen = false;
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
