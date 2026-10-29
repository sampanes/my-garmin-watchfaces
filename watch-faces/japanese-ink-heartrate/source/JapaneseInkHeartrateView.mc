using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateView extends WatchUi.WatchFace {

    var mIsLowPower as Lang.Boolean = false;
    var mScene as JapaneseInkHeartrateScene;

    // Baked by scripts/gen_ink_font.py: brush-written digits for the
    // minutes, brush kanji numerals for the hour, carved-stamp digits for
    // the seal (resources/fonts).
    var mInkFont as WatchUi.FontResource;
    var mKanjiFont as WatchUi.FontResource;
    var mSealFont as WatchUi.FontResource;

    // Sumi ink for the inscription digits (the darkest ink in the painting),
    // pale ink on the night paper; vermillion for the seal, dimmed at night.
    const INK = 0x18120E;
    const INK_NIGHT = 0xD8D2C6;
    const SEAL_RED_R = 176;
    const SEAL_RED_G = 52;
    const SEAL_RED_B = 38;
    const SEAL_NIGHT_R = 150;
    const SEAL_NIGHT_G = 44;
    const SEAL_NIGHT_B = 32;

    function initialize() {
        WatchUi.WatchFace.initialize();
        mScene = new JapaneseInkHeartrateScene();
        mInkFont = WatchUi.loadResource(Rez.Fonts.InkDigits) as WatchUi.FontResource;
        mKanjiFont = WatchUi.loadResource(Rez.Fonts.KanjiHours) as WatchUi.FontResource;
        mSealFont = WatchUi.loadResource(Rez.Fonts.SealDigits) as WatchUi.FontResource;
    }

    function onLayout(dc as Graphics.Dc) as Void {
        mScene.onLayout(dc);
    }

    function onShow() as Void {
    }

    function onSettingsChanged() as Void {
        mScene.invalidate();
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
            // The RENDERER_PLAN §13 probe card (Scene PROBE) takes the
            // whole screen; no inscription over it.
            if (mScene.isProbe()) {
                return;
            }
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

    // One numeral as a one-character string: 0 = 〇, 1-9 the kanji digits.
    // Code points rather than literals keep this source ASCII.
    function kanjiDigit(digit as Lang.Number) as Lang.String {
        var code = 0x3007;
        switch (digit) {
            case 1: code = 0x4E00; break;
            case 2: code = 0x4E8C; break;
            case 3: code = 0x4E09; break;
            case 4: code = 0x56DB; break;
            case 5: code = 0x4E94; break;
            case 6: code = 0x516D; break;
            case 7: code = 0x4E03; break;
            case 8: code = 0x516B; break;
            case 9: code = 0x4E5D; break;
        }
        return code.toChar().toString();
    }

    // The hour as a column of one or two numerals, top first: 0 = 〇, 1-9,
    // 10 = 十, 11-19 = 十X, 20 = 廿, 21-23 = 廿X. Twenty is written with the
    // single character so no hour needs a third line, which would run the
    // column into the bezel.
    function kanjiHour(hour as Lang.Number) as Lang.Array<Lang.String> {
        var out = [] as Lang.Array<Lang.String>;
        var tens = hour / 10;
        var ones = hour % 10;
        if (tens == 1) {
            out.add((0x5341).toChar().toString());
        } else if (tens >= 2) {
            out.add((0x5EFF).toChar().toString());
        }
        if (ones != 0 || tens == 0) {
            out.add(kanjiDigit(ones));
        }
        return out;
    }

    // The time as a painter's inscription in the upper-left void: the hour
    // in kanji numerals stacked top to bottom, the minutes in brush digits
    // beneath, and a vermillion artist's seal under those carrying the live
    // heart rate. The hour column is anchored at its bottom glyph so one-
    // and two-glyph hours sit the same distance above the minutes. Layout
    // numbers mirror scripts/compose_preview.py.
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
        var hourGlyphs = kanjiHour(hour);
        var minText = clockTime.min.format("%02d");

        var colX = ((width * 22) / 100) + xOff;
        var hourBottomY = ((height * 265) / 1000) + yOff;
        var hourPitch = (height * 10) / 100;
        var minY = ((height * 375) / 1000) + yOff;

        var night = mScene.isNight();
        if (isAod) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(night ? INK_NIGHT : INK, Graphics.COLOR_TRANSPARENT);
        }
        var count = hourGlyphs.size();
        for (var i = 0; i < count; i++) {
            dc.drawText(colX, hourBottomY - (count - 1 - i) * hourPitch, mKanjiFont, hourGlyphs[i],
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.drawText(colX, minY, mInkFont, minText,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (isAod) {
            return;
        }

        // Artist's seal: rounded vermillion square, live HR inside in the
        // carved seal digits (three of them fit with the 8.5% size).
        var sealSize = (width * 85) / 1000;
        var sealX = colX - (sealSize / 2);
        var sealY = (height * 465) / 1000;
        if (night) {
            dc.setFill(Graphics.createColor(0xEB, SEAL_NIGHT_R, SEAL_NIGHT_G, SEAL_NIGHT_B));
        } else {
            dc.setFill(Graphics.createColor(0xEB, SEAL_RED_R, SEAL_RED_G, SEAL_RED_B));
        }
        dc.fillRoundedRectangle(sealX, sealY, sealSize, sealSize, sealSize / 7);

        var hrText = currentHeartRateText();
        if (hrText != null) {
            dc.setColor(0xF4EEE2, Graphics.COLOR_TRANSPARENT);
            dc.drawText(colX, sealY + (sealSize / 2), mSealFont, hrText,
                        Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function currentHeartRateText() as Lang.String? {
        // Watch faces are guaranteed ActivityMonitor history access with the
        // SensorHistory permission; Activity.currentHeartRate is primarily an
        // activity/data-field API and may be null in a watch-face context.
        return mScene.latestHeartRateText();
    }

}
