using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateView extends WatchUi.WatchFace {

    var mIsLowPower as Lang.Boolean = false;
    var mScene as JapaneseInkHeartrateScene;

    // Sumi ink for the inscription digits; vermillion for the seal.
    const INK = 0x342A22;
    const SEAL_RED_R = 176;
    const SEAL_RED_G = 52;
    const SEAL_RED_B = 38;

    function initialize() {
        WatchUi.WatchFace.initialize();
        mScene = new JapaneseInkHeartrateScene();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        mScene.onLayout(dc);
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var xOffset = 0;
        var yOffset = 0;

        var aod = isAmoledSleepMode();
        if (aod) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            drawAodRidge(dc, width, height);
        } else {
            mScene.draw(dc);
        }

        if (mIsLowPower && needsBurnInProtection()) {
            var minute = System.getClockTime().min;
            xOffset = (minute % 3) - 1;
            yOffset = ((minute / 3) % 3) - 1;
        }

        drawInscription(dc, width, height, xOffset, yOffset, aod);
    }

    function onEnterSleep() as Void {
        mIsLowPower = true;
    }

    function onExitSleep() as Void {
        mIsLowPower = false;
    }

    function needsBurnInProtection() as Lang.Boolean {
        var settings = System.getDeviceSettings();
        return (settings has :requiresBurnInProtection) && settings.requiresBurnInProtection;
    }

    function isAmoledSleepMode() as Lang.Boolean {
        return mIsLowPower && needsBurnInProtection();
    }

    function drawAodRidge(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var ridgeY = (height * 3) / 4;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(width / 8, ridgeY + 4, width / 3, ridgeY - 6);
        dc.drawLine(width / 3, ridgeY - 6, (width * 2) / 3, ridgeY + 2);
        dc.drawLine((width * 2) / 3, ridgeY + 2, (width * 7) / 8, ridgeY - 4);
    }

    // The time as a painter's inscription: hour above minutes in a column in
    // the upper-left void, with a vermillion artist's seal beneath carrying
    // the live heart rate. Mirrors the inscription+seal grammar of the
    // reference paintings (and replaces the face-center digits).
    function drawInscription(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number,
                             xOff as Lang.Number, yOff as Lang.Number, isAod as Lang.Boolean) as Void {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var settings = System.getDeviceSettings();
        if ((settings has :is24Hour) && !settings.is24Hour) {
            if (hour == 0) {
                hour = 12;
            } else if (hour > 12) {
                hour = hour - 12;
            }
        }
        var hourText = hour.format("%d");
        var minText = clockTime.min.format("%02d");

        var colX = ((width * 22) / 100) + xOff;
        var hourY = ((height * 21) / 100) + yOff;
        var minY = ((height * 33) / 100) + yOff;

        if (isAod) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(colX, hourY, Graphics.FONT_LARGE, hourText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(colX, minY, Graphics.FONT_LARGE, minText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (isAod) {
            return;
        }

        // Artist's seal: rounded vermillion square, live HR inside.
        var sealSize = (width * 67) / 1000;
        var sealX = colX - (sealSize / 2);
        var sealY = (height * 425) / 1000;
        dc.setFill(Graphics.createColor(0xEB, SEAL_RED_R, SEAL_RED_G, SEAL_RED_B));
        dc.fillRoundedRectangle(sealX, sealY, sealSize, sealSize, sealSize / 7);

        var hrText = currentHeartRateText();
        if (hrText != null) {
            dc.setColor(0xF4EEE2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colX, sealY + (sealSize / 2), Graphics.FONT_XTINY, hrText,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // The tiny caption makes the landscape's temporal meaning explicit
        // without turning the painting into a dashboard.
        dc.setColor(0x686259, Graphics.COLOR_TRANSPARENT);
        dc.drawText(colX, (height * 525) / 1000, Graphics.FONT_XTINY, "4h",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function currentHeartRateText() as Lang.String? {
        // Watch faces are guaranteed ActivityMonitor history access with the
        // SensorHistory permission; Activity.currentHeartRate is primarily an
        // activity/data-field API and may be null in a watch-face context.
        return mScene.latestHeartRateText();
    }

}
