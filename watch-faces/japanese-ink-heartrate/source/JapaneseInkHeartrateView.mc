using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateView extends WatchUi.WatchFace {

    var mIsLowPower as Lang.Boolean = false;

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
        var timeColor = Graphics.COLOR_BLACK;
        var ridgeColor = Graphics.COLOR_DK_GRAY;
        var accentColor = Graphics.COLOR_LT_GRAY;

        if (isAmoledSleepMode()) {
            timeColor = Graphics.COLOR_WHITE;
            ridgeColor = Graphics.COLOR_DK_GRAY;
            accentColor = Graphics.COLOR_DK_GRAY;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
        } else {
            drawPaperBackground(dc, width, height);
            drawSkyAccent(dc, width, height);
            drawPrimaryRidge(dc, width, height);
        }

        if (mIsLowPower && needsBurnInProtection()) {
            var minute = System.getClockTime().min;
            xOffset = (minute % 3) - 1;
            yOffset = ((minute / 3) % 3) - 1;
        }

        if (isAmoledSleepMode()) {
            drawAodRidge(dc, width, height, ridgeColor);
        }

        dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX + xOffset,
            centerY + yOffset,
            Graphics.FONT_NUMBER_HOT,
            getTimeString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        if (!isAmoledSleepMode()) {
            drawTimeUnderline(dc, centerX, centerY, accentColor);
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

    function drawPaperBackground(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, 0xF1E8D8);
        dc.clear();

        // A few soft horizontal bands keep the background from feeling flat.
        dc.setColor(0xE8DECC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 6, width, height / 12);
        dc.setColor(0xECE3D4, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (height * 2) / 3, width, height / 10);
    }

    function drawSkyAccent(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var clockTime = System.getClockTime();
        var arcWidth = width - 90;
        var progress = (clockTime.hour * 60 + clockTime.min).toFloat() / 1440.0;
        var sunX = 45 + (arcWidth * progress).toNumber();
        var sunY = 58 + (((progress - 0.5) * (progress - 0.5)) * 80).toNumber();

        dc.setColor(0xB7A28A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, 10);
        dc.setColor(0xD8CAB8, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sunX, sunY, 14);
    }

    function drawPrimaryRidge(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var baseY = (height * 3) / 5;
        var points = [
            [0, height],
            [0, baseY + 40],
            [width / 9, baseY + 18],
            [width / 4, baseY - 6],
            [width / 2, baseY + 12],
            [(width * 2) / 3, baseY - 24],
            [(width * 5) / 6, baseY + 6],
            [width, baseY - 10],
            [width, height]
        ];

        dc.setColor(0x2A231E, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(points);

        dc.setColor(0x6E6257, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(0, baseY + 30, width / 9, baseY + 8);
        dc.drawLine(width / 9, baseY + 8, width / 4, baseY - 14);
        dc.drawLine(width / 4, baseY - 14, width / 2, baseY + 2);
        dc.drawLine(width / 2, baseY + 2, (width * 2) / 3, baseY - 34);
        dc.drawLine((width * 2) / 3, baseY - 34, (width * 5) / 6, baseY - 2);
        dc.drawLine((width * 5) / 6, baseY - 2, width, baseY - 16);
    }

    function drawAodRidge(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, ridgeColor as Lang.Number) as Void {
        var ridgeY = (height * 3) / 4;
        dc.setColor(ridgeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(width / 8, ridgeY + 4, width / 3, ridgeY - 6);
        dc.drawLine(width / 3, ridgeY - 6, (width * 2) / 3, ridgeY + 2);
        dc.drawLine((width * 2) / 3, ridgeY + 2, (width * 7) / 8, ridgeY - 4);
    }

    function drawTimeUnderline(dc as Graphics.Dc, centerX as Lang.Number, centerY as Lang.Number, accentColor as Lang.Number) as Void {
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX - 52, centerY + 42, centerX + 52, centerY + 42);
        dc.drawLine(centerX - 38, centerY + 48, centerX + 38, centerY + 48);
    }

}
