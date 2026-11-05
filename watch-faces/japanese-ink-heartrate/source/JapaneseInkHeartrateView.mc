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
    // Line heights of those fonts (their .fnt "common lineHeight"): the ink
    // is drawn LEFT / TOP at a line top of centre - lineHeight / 2, as
    // compose_preview.py does, so the halo bitmaps can be placed exactly.
    const INK_LINE_H = 54;
    const KANJI_LINE_H = 48;

    // The paper halo under the inscription (scripts/gen_halo.py): one
    // bitmap per glyph, the glyph widened and blurred, in paper colour
    // (black at night), drawn first so a branch behind the time fades back
    // to bare paper. Each is its ink glyph's cell grown by HALO_PAD on every
    // side, drawn at (pen - HALO_PAD, line top - HALO_PAD). Bitmaps, not a
    // font: a font keeps only a few alpha levels and clips to its line box.
    const HALO_PAD = 27;   // gen_halo.py prints it
    // Kanji code points in the order of the halo id lists: 0-9, ten, twenty.
    const KANJI_CODES = [0x3007, 0x4E00, 0x4E8C, 0x4E09, 0x56DB, 0x4E94, 0x516D,
                         0x4E03, 0x516B, 0x4E5D, 0x5341, 0x5EFF];
    var mHaloDigit as Lang.Array<Lang.ResourceId>;
    var mHaloDigitNight as Lang.Array<Lang.ResourceId>;
    var mHaloKanji as Lang.Array<Lang.ResourceId>;
    var mHaloKanjiNight as Lang.Array<Lang.ResourceId>;
    // Five slots (hour glyph 1-2, minute digit 1-2, seal): the bitmap held
    // for each and what it shows; a slot reloads only when that changes
    // (a load costs ~57 ms on the watch, so not every update).
    var mHaloKeys as Lang.Array<Lang.String> = ["", "", "", "", ""];
    var mHaloBmps as Lang.Array<Graphics.BitmapType or Null> = [null, null, null, null, null];
    // The seal from the sheet (bake_props.py: PROP_SEAL_OVAL at rest,
    // PROP_SEAL_SQUARE at work), held like a halo slot: reloaded only when
    // the shape or day/night changes.
    var mSealKey as Lang.String = "";
    var mSealBmp as Graphics.BitmapType or Null = null;
    var mSealW as Lang.Number = 0;
    var mSealH as Lang.Number = 0;

    // Sumi ink for the inscription digits (the darkest ink in the painting),
    // pale ink on the night paper.
    const INK = 0x18120E;
    const INK_NIGHT = 0xD8D2C6;

    function initialize() {
        WatchUi.WatchFace.initialize();
        mScene = new JapaneseInkHeartrateScene();
        mInkFont = WatchUi.loadResource(Rez.Fonts.InkDigits) as WatchUi.FontResource;
        mKanjiFont = WatchUi.loadResource(Rez.Fonts.KanjiHours) as WatchUi.FontResource;
        mSealFont = WatchUi.loadResource(Rez.Fonts.SealDigits) as WatchUi.FontResource;
        mHaloDigit = [Rez.Drawables.HaloD0, Rez.Drawables.HaloD1, Rez.Drawables.HaloD2,
                      Rez.Drawables.HaloD3, Rez.Drawables.HaloD4, Rez.Drawables.HaloD5,
                      Rez.Drawables.HaloD6, Rez.Drawables.HaloD7, Rez.Drawables.HaloD8,
                      Rez.Drawables.HaloD9] as Lang.Array<Lang.ResourceId>;
        mHaloDigitNight = [Rez.Drawables.HaloD0Night, Rez.Drawables.HaloD1Night,
                           Rez.Drawables.HaloD2Night, Rez.Drawables.HaloD3Night,
                           Rez.Drawables.HaloD4Night, Rez.Drawables.HaloD5Night,
                           Rez.Drawables.HaloD6Night, Rez.Drawables.HaloD7Night,
                           Rez.Drawables.HaloD8Night, Rez.Drawables.HaloD9Night] as Lang.Array<Lang.ResourceId>;
        mHaloKanji = [Rez.Drawables.HaloK3007, Rez.Drawables.HaloK4e00, Rez.Drawables.HaloK4e8c,
                      Rez.Drawables.HaloK4e09, Rez.Drawables.HaloK56db, Rez.Drawables.HaloK4e94,
                      Rez.Drawables.HaloK516d, Rez.Drawables.HaloK4e03, Rez.Drawables.HaloK516b,
                      Rez.Drawables.HaloK4e5d, Rez.Drawables.HaloK5341,
                      Rez.Drawables.HaloK5eff] as Lang.Array<Lang.ResourceId>;
        mHaloKanjiNight = [Rez.Drawables.HaloK3007Night, Rez.Drawables.HaloK4e00Night,
                           Rez.Drawables.HaloK4e8cNight, Rez.Drawables.HaloK4e09Night,
                           Rez.Drawables.HaloK56dbNight, Rez.Drawables.HaloK4e94Night,
                           Rez.Drawables.HaloK516dNight, Rez.Drawables.HaloK4e03Night,
                           Rez.Drawables.HaloK516bNight, Rez.Drawables.HaloK4e5dNight,
                           Rez.Drawables.HaloK5341Night,
                           Rez.Drawables.HaloK5effNight] as Lang.Array<Lang.ResourceId>;
    }

    // The halo bitmap for one slot, loaded only when the slot's key changes.
    function halo(slot as Lang.Number, key as Lang.String, rez as Lang.ResourceId) as Graphics.BitmapType {
        var bmp = mHaloBmps[slot];
        if (bmp == null || !key.equals(mHaloKeys[slot])) {
            mHaloBmps[slot] = null;   // drop the old one before loading the new
            bmp = WatchUi.loadResource(rez) as Graphics.BitmapType;
            mHaloBmps[slot] = bmp;
            mHaloKeys[slot] = key;
        }
        return bmp;
    }

    function kanjiIndex(glyph as Lang.String) as Lang.Number {
        var code = glyph.toCharArray()[0].toNumber();
        for (var k = 0; k < KANJI_CODES.size(); k++) {
            if (KANJI_CODES[k] == code) {
                return k;
            }
        }
        return 0;
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
        var count = hourGlyphs.size();
        var sealSize = (width * 85) / 1000;
        var sealX = colX - (sealSize / 2);
        var sealY = (height * 465) / 1000;

        // Where every glyph lands: the hour glyphs one per line, the minutes
        // one glyph at a time from a pen centred on the pair, each as
        // [glyph, pen x, line top].
        var placed = [] as Lang.Array<Lang.Array>;
        for (var i = 0; i < count; i++) {
            var g = hourGlyphs[i];
            placed.add([g, colX - (dc.getTextWidthInPixels(g, mKanjiFont) / 2),
                        hourBottomY - (count - 1 - i) * hourPitch - (KANJI_LINE_H / 2)]);
        }
        var pen = colX - (dc.getTextWidthInPixels(minText, mInkFont) / 2);
        for (var j = 0; j < minText.length(); j++) {
            var d = minText.substring(j, j + 1) as Lang.String;
            placed.add([d, pen, minY - (INK_LINE_H / 2)]);
            pen += dc.getTextWidthInPixels(d, mInkFont);
        }

        if (!isAod) {
            // the paper halo first, under everything the inscription draws
            for (var i = 0; i < placed.size(); i++) {
                var p = placed[i];
                var glyph = p[0] as Lang.String;
                var rez;
                if (i < count) {
                    var k = kanjiIndex(glyph);
                    rez = night ? mHaloKanjiNight[k] : mHaloKanji[k];
                } else {
                    var n = glyph.toNumber() as Lang.Number;
                    rez = night ? mHaloDigitNight[n] : mHaloDigit[n];
                }
                // slots 0-1 hour, 2-3 minutes; a one-glyph hour leaves slot 1
                var slot = i < count ? i : 2 + (i - count);
                dc.drawBitmap((p[1] as Lang.Number) - HALO_PAD, (p[2] as Lang.Number) - HALO_PAD,
                              halo(slot, glyph + (night ? "n" : "d"), rez));
            }
            dc.drawBitmap(sealX - HALO_PAD, sealY - HALO_PAD,
                          halo(4, night ? "n" : "d",
                               night ? Rez.Drawables.HaloSealNight : Rez.Drawables.HaloSeal));
        }
        if (isAod) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(night ? INK_NIGHT : INK, Graphics.COLOR_TRANSPARENT);
        }
        for (var i = 0; i < placed.size(); i++) {
            var p = placed[i];
            dc.drawText(p[1] as Lang.Number, p[2] as Lang.Number, i < count ? mKanjiFont : mInkFont,
                        p[0] as Lang.String, Graphics.TEXT_JUSTIFY_LEFT);
        }

        if (isAod) {
            return;
        }

        // Artist's seal from the sheet, centered where the drawn square was,
        // live HR inside in the carved seal digits: the oval while the HR
        // rests near the baseline, the square once it works (Scene sealWork).
        var shape = mScene.sealWork() ? PROP_SEAL_SQUARE : PROP_SEAL_OVAL;
        var key = shape.toString() + (night ? "n" : "d");
        if (mSealBmp == null || !key.equals(mSealKey)) {
            mSealBmp = null;
            try {
                mSealBmp = loadPropBitmap(shape, night);
            } catch (ex) {
                mSealBmp = null;
            }
            mSealKey = key;
            mSealW = propW()[shape];
            mSealH = propH()[shape];
        }
        var sealBmp = mSealBmp;
        if (sealBmp != null) {
            dc.drawBitmap(colX - mSealW / 2, sealY + sealSize / 2 - mSealH / 2, sealBmp);
        }

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
