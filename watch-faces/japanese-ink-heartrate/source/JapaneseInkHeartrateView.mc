using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateView extends WatchUi.WatchFace {

    var mIsLowPower as Lang.Boolean = false;
    var mScene as JapaneseInkHeartrateScene;

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
        var centerX = width / 2;
        var centerY = height / 2;
        var xOffset = 0;
        var yOffset = 0;

        if (isAmoledSleepMode()) {
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

        drawTime(dc, centerX + xOffset, centerY + yOffset, isAmoledSleepMode());

        if (!isAmoledSleepMode()) {
            drawTimeUnderline(dc, centerX, centerY);
        }
    }

    function onEnterSleep() as Void {
        mIsLowPower = true;
    }

    function onExitSleep() as Void {
        mIsLowPower = false;
    }

    function getTimeString() as Lang.String {
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        var minuteText = clockTime.min.format("%02d");
        var settings = System.getDeviceSettings();

        if ((settings has :is24Hour) && !settings.is24Hour) {
            if (hour == 0) {
                hour = 12;
            } else if (hour > 12) {
                hour = hour - 12;
            }
        }

        return Lang.format("$1$:$2$", [hour, minuteText]);
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

    function drawTime(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, isAod as Lang.Boolean) as Void {
        var timeText = getTimeString();

        if (isAod) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x,
                y,
                Graphics.FONT_NUMBER_HOT,
                timeText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        dc.setColor(0xFAF2E8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + 2,
            y + 3,
            Graphics.FONT_NUMBER_HOT,
            timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(0x231B16, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            y,
            Graphics.FONT_NUMBER_HOT,
            timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
    }

    function drawTimeUnderline(dc as Graphics.Dc, centerX as Lang.Number, centerY as Lang.Number) as Void {
        dc.setColor(0xBFAF99, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX - 58, centerY + 66, centerX + 58, centerY + 66);
        dc.drawLine(centerX - 34, centerY + 72, centerX + 34, centerY + 72);
    }

}
