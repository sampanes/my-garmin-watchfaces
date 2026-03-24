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
        var timeColor = 0x231B16;
        var ridgeColor = Graphics.COLOR_DK_GRAY;
        var accentColor = 0xBFAF99;

        if (isAmoledSleepMode()) {
            timeColor = Graphics.COLOR_WHITE;
            ridgeColor = Graphics.COLOR_DK_GRAY;
            accentColor = Graphics.COLOR_DK_GRAY;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
        } else {
            drawPaperBackground(dc, width, height);
            drawSkyAccent(dc, width, height);
            drawMist(dc, width, height);
            drawDistantRidge(dc, width, height);
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

        drawTime(dc, centerX + xOffset, centerY + yOffset, timeColor);

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
        dc.setColor(Graphics.COLOR_WHITE, 0xEFE5D6);
        dc.clear();

        dc.setColor(0xECE0CE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, height / 8, width, height / 12);
        dc.setColor(0xF4EBDD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (height * 2) / 3, width, height / 6);
        dc.setColor(0xEADBC5, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (height * 5) / 6, width, height / 8);
    }

    function drawSkyAccent(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var clockTime = System.getClockTime();
        var arcWidth = width - 90;
        var progress = (clockTime.hour * 60 + clockTime.min).toFloat() / 1440.0;
        var sunX = 45 + (arcWidth * progress).toNumber();
        var sunY = 58 + (((progress - 0.5) * (progress - 0.5)) * 80).toNumber();

        dc.setColor(0xE8DDCC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX - 1, sunY + 1, 11);
        dc.setColor(0xD7BCA1, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sunX, sunY, 6);
        dc.setColor(0xCDB398, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(sunX + 1, sunY, 9);
    }

    function drawDistantRidge(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var samples = [0.54, 0.50, 0.44, 0.48, 0.46, 0.40, 0.45, 0.42];
        var ridge = makeRidgePoints(width, height, (height * 11) / 20, 20, samples, 2);

        fillRidgeWash(dc, width, height, ridge, [0xDDD0C0, 0xD3C5B3, 0xC9B9A6], [26, 14, 0]);
        drawRidgeFragments(dc, ridge, 0xE3D9CB, 3);
    }

    function drawMist(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var mistY = (height * 29) / 50;
        dc.setColor(0xF1E8DD, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(22, mistY, width - 78, 8);
        dc.fillRectangle(70, mistY + 12, width - 150, 7);
        dc.setColor(0xF7F0E7, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(12, mistY + 20, width - 64, 8);
        dc.fillRectangle(120, mistY + 30, width - 176, 6);
        dc.fillRectangle(54, mistY + 38, width - 132, 5);
    }

    function drawPrimaryRidge(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        var samples = [0.70, 0.66, 0.48, 0.54, 0.62, 0.58, 0.38, 0.50, 0.42, 0.46];
        var ridge = makeRidgePoints(width, height, (height * 17) / 25, 52, samples, 4);

        fillRidgeWash(dc, width, height, ridge, [0x8A7B70, 0x65584F, 0x3C312A], [36, 18, 0]);
        drawRidgeFragments(dc, ridge, 0x9A8B7E, 4);
        fadeLowerMountain(dc, width, height);
    }

    function drawAodRidge(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number, ridgeColor as Lang.Number) as Void {
        var ridgeY = (height * 3) / 4;
        dc.setColor(ridgeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(width / 8, ridgeY + 4, width / 3, ridgeY - 6);
        dc.drawLine(width / 3, ridgeY - 6, (width * 2) / 3, ridgeY + 2);
        dc.drawLine((width * 2) / 3, ridgeY + 2, (width * 7) / 8, ridgeY - 4);
    }

    function drawTime(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, timeColor as Lang.Number) as Void {
        var timeText = getTimeString();

        if (isAmoledSleepMode()) {
            dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                x,
                y,
                Graphics.FONT_NUMBER_HOT,
                timeText,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
            return;
        }

        dc.setColor(0xF8F0E5, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x + 2,
            y + 3,
            Graphics.FONT_NUMBER_HOT,
            timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        dc.setColor(timeColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            y,
            Graphics.FONT_NUMBER_HOT,
            timeText,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

    }

    function drawTimeUnderline(dc as Graphics.Dc, centerX as Lang.Number, centerY as Lang.Number, accentColor as Lang.Number) as Void {
        dc.setColor(accentColor, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(centerX - 58, centerY + 66, centerX + 58, centerY + 66);
        dc.drawLine(centerX - 34, centerY + 72, centerX + 34, centerY + 72);
    }

    function makeRidgePoints(
        width as Lang.Number,
        height as Lang.Number,
        baseY as Lang.Number,
        amplitude as Lang.Number,
        samples as Lang.Array,
        jitterStrength as Lang.Number
    ) as Lang.Array {
        var ridge = [ [0, height], [0, baseY + amplitude / 2] ];
        var sampleCount = samples.size();
        var step = width / (sampleCount - 1);
        var i = 0;

        while (i < sampleCount) {
            var x = (i * step);
            var raw = samples[i];
            var shaped = raw * raw;
            var jitter = getDeterministicJitter(i, jitterStrength);
            var y = baseY - (shaped * amplitude) + jitter;

            ridge.add([x, y]);
            i += 1;
        }

        ridge.add([width, height]);
        return ridge;
    }

    function fillRidgeWash(
        dc as Graphics.Dc,
        width as Lang.Number,
        height as Lang.Number,
        ridge as Lang.Array,
        colors as Lang.Array,
        offsets as Lang.Array
    ) as Void {
        var i = 0;

        while (i < colors.size()) {
            dc.setColor(colors[i], Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon(offsetRidge(ridge, offsets[i], height));
            i += 1;
        }
    }

    function offsetRidge(ridge as Lang.Array, offsetY as Lang.Number, height as Lang.Number) as Lang.Array {
        var shifted = [];
        var i = 0;

        while (i < ridge.size()) {
            var point = ridge[i];
            var y = point[1];

            if (i < ridge.size() - 1 && i > 0) {
                y += offsetY;
            } else {
                y = height;
            }

            shifted.add([point[0], y]);
            i += 1;
        }

        return shifted;
    }

    function drawRidgeFragments(dc as Graphics.Dc, ridge as Lang.Array, color as Lang.Number, segmentStride as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);

        var i = 1;
        while (i < ridge.size() - 2) {
            var p1 = ridge[i];
            var p2 = ridge[i + 1];

            if ((i % segmentStride) != 0) {
                dc.drawLine(p1[0], p1[1], p2[0], p2[1]);
            }

            i += 1;
        }
    }

    function fadeLowerMountain(dc as Graphics.Dc, width as Lang.Number, height as Lang.Number) as Void {
        dc.setColor(0x6F6258, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (height * 37) / 40, width, height / 20);
        dc.setColor(0xA69788, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (height * 39) / 40, width, height / 24);
        dc.setColor(0xD8C9B7, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, (height * 41) / 40, width, height / 28);
    }

    function getDeterministicJitter(index as Lang.Number, strength as Lang.Number) as Lang.Number {
        var pattern = [0, -2, 1, -1, 2, -3, 1, 0, -2, 2, -1];
        return pattern[index % pattern.size()] * strength / 3;
    }

}
