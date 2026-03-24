using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateView extends WatchUi.WatchFace {

    var mIsLowPower = false;

    function initialize() {
        WatchUi.WatchFace.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
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

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (mIsLowPower && needsBurnInProtection()) {
            xOffset = (System.getClockTime().min % 3) - 1;
            yOffset = ((System.getClockTime().min / 3) % 3) - 1;
        }

        dc.drawText(
            centerX + xOffset,
            centerY + yOffset,
            Graphics.FONT_NUMBER_HOT,
            getTimeString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
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

}
