using Toybox.ActivityMonitor;
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.SensorHistory;
using Toybox.System;
using Toybox.Time;
using Toybox.WatchUi;

class WristDiaryView extends WatchUi.View {
    const MAX_RECORDS = 60;
    const KEY_COUNT = "count";
    const KEY_NEXT = "next";

    const I_TIME = 0;
    const I_STEPS = 1;
    const I_CALORIES = 2;
    const I_MODERATE = 3;
    const I_VIGOROUS = 4;
    const I_STRESS = 5;
    const I_HR_LATEST = 6;
    const I_HR_MIN = 7;
    const I_HR_AVG = 8;
    const I_HR_MAX = 9;
    const I_BODY_BATTERY = 10;
    const I_DISTANCE_CM = 11;
    const I_FLOORS = 12;
    const RECORD_SIZE = 13;

    var mPage as Lang.Number = 0;
    var mRecord as Lang.Array<Lang.Number>;
    var mPrevious as Lang.Array<Lang.Number>?;
    var mSavedClock as Lang.String = "--:--";
    var mStatus as Lang.String = "SAVING";

    function initialize() {
        View.initialize();
        mRecord = missingRecord();
        captureNow();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        dc.setColor(0x6ED6A8, Graphics.COLOR_BLACK);
        dc.drawText(centerX, 25, Graphics.FONT_SMALL,
                    (mPage == 0) ? "DAILY" : "BODY",
                    Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(centerX, 55, Graphics.FONT_XTINY,
                    mStatus + " " + mSavedClock,
                    Graphics.TEXT_JUSTIFY_CENTER);

        if (mPage == 0) {
            drawDaily(dc, width);
        } else {
            drawBody(dc, width);
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(centerX, height - 51, Graphics.FONT_XTINY,
                    "UP/DN   SEL SAVE",
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawDaily(dc as Graphics.Dc, width as Lang.Number) as Void {
        drawMetric(dc, width, 96, "STEPS", numberText(mRecord[I_STEPS]),
                   deltaText(I_STEPS));
        drawMetric(dc, width, 151, "ACTIVE",
                   numberText(activeTotal(mRecord)) + " min",
                   activeDeltaText());
        drawMetric(dc, width, 206, "CALORIES",
                   numberText(mRecord[I_CALORIES]), deltaText(I_CALORIES));
        drawMetric(dc, width, 261, "DISTANCE",
                   distanceText(mRecord[I_DISTANCE_CM]), "");
        drawMetric(dc, width, 316, "FLOORS",
                   numberText(mRecord[I_FLOORS]), deltaText(I_FLOORS));
    }

    function drawBody(dc as Graphics.Dc, width as Lang.Number) as Void {
        drawMetric(dc, width, 96, "STRESS",
                   numberText(mRecord[I_STRESS]), "");
        drawMetric(dc, width, 151, "HEART RATE",
                   bpmText(mRecord[I_HR_LATEST]), "");
        drawMetric(dc, width, 206, "HR 4H MIN/AVG/MAX",
                   hrRangeText(), "");
        drawMetric(dc, width, 261, "BODY BATTERY",
                   numberText(mRecord[I_BODY_BATTERY]), "");
        drawMetric(dc, width, 316, "RECORDS",
                   numberText(readStoredNumber(KEY_COUNT, 0)), "of 60");
    }

    function drawMetric(dc as Graphics.Dc, width as Lang.Number, y as Lang.Number,
                        label as Lang.String, value as Lang.String,
                        detail as Lang.String) as Void {
        var left = width * 15 / 100;
        var right = width * 85 / 100;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(left, y, Graphics.FONT_XTINY, label,
                    Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(right, y, Graphics.FONT_SMALL, value,
                    Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (detail.length() > 0) {
            dc.setColor(0x6ED6A8, Graphics.COLOR_BLACK);
            dc.drawText(right, y + 18, Graphics.FONT_XTINY, detail,
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function nextPage() as Void {
        mPage = (mPage + 1) % 2;
        WatchUi.requestUpdate();
    }

    function previousPage() as Void {
        mPage -= 1;
        if (mPage < 0) { mPage = 1; }
        WatchUi.requestUpdate();
    }

    function captureNow() as Void {
        var clock = System.getClockTime();
        mSavedClock = clock.hour.format("%02d") + ":" + clock.min.format("%02d");
        mStatus = "SAVING";

        var record = missingRecord();
        record[I_TIME] = Time.now().value();
        captureActivity(record);
        captureHeartRate(record);
        record[I_BODY_BATTERY] = latestBodyBattery();

        try {
            mPrevious = saveRecord(record);
            mRecord = record;
            mStatus = "SAVED";
            exportAllRecords();
        } catch (e) {
            mRecord = record;
            mStatus = "SAVE ERROR";
            System.println("WRIST_DIARY_ERROR," + e.getErrorMessage());
        }
        WatchUi.requestUpdate();
    }

    function captureActivity(record as Lang.Array<Lang.Number>) as Void {
        var info = ActivityMonitor.getInfo();
        var steps = info.steps;
        var calories = info.calories;
        var distance = info.distance;
        var floors = info.floorsClimbed;
        var stress = info.stressScore;
        if (steps != null) { record[I_STEPS] = steps; }
        if (calories != null) { record[I_CALORIES] = calories; }
        if (distance != null) { record[I_DISTANCE_CM] = distance; }
        if (floors != null) { record[I_FLOORS] = floors; }
        if (stress != null) { record[I_STRESS] = stress; }
        var active = info.activeMinutesDay;
        if (active != null) {
            record[I_MODERATE] = active.moderate;
            record[I_VIGOROUS] = active.vigorous;
        }
    }

    function captureHeartRate(record as Lang.Array<Lang.Number>) as Void {
        var iterator = ActivityMonitor.getHeartRateHistory(new Time.Duration(4 * 3600), false);

        var count = 0;
        var sum = 0;
        var minimum = 999;
        var maximum = -1;
        var latest = -1;
        var sample = iterator.next();
        while (sample != null) {
            var hr = sample.heartRate;
            if (hr != null && hr != ActivityMonitor.INVALID_HR_SAMPLE && hr > 0) {
                if (hr < minimum) { minimum = hr; }
                if (hr > maximum) { maximum = hr; }
                sum += hr;
                count += 1;
                latest = hr;
            }
            sample = iterator.next();
        }

        if (count > 0) {
            record[I_HR_LATEST] = latest;
            record[I_HR_MIN] = minimum;
            record[I_HR_AVG] = sum / count;
            record[I_HR_MAX] = maximum;
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
            if (data == null) { return -1; }
            return data.toNumber();
        } catch (e) {
            System.println("WRIST_DIARY_BB_ERROR," + e.getErrorMessage());
            return -1;
        }
    }

    function saveRecord(record as Lang.Array<Lang.Number>) as Lang.Array<Lang.Number>? {
        var count = readStoredNumber(KEY_COUNT, 0);
        var next = readStoredNumber(KEY_NEXT, 0);
        var previous = null;

        if (count > 0) {
            var previousIndex = next - 1;
            if (previousIndex < 0) { previousIndex = MAX_RECORDS - 1; }
            previous = loadRecord(previousIndex);
        }

        Application.Storage.setValue("r" + next,
                                     record as Application.Storage.ValueType);
        next = (next + 1) % MAX_RECORDS;
        if (count < MAX_RECORDS) { count += 1; }
        Application.Storage.setValue(KEY_NEXT, next);
        Application.Storage.setValue(KEY_COUNT, count);
        return previous;
    }

    function exportAllRecords() as Void {
        var count = readStoredNumber(KEY_COUNT, 0);
        var next = readStoredNumber(KEY_NEXT, 0);
        System.println("WRIST_DIARY_BEGIN," + count);
        System.println("epoch,steps,calories,moderate,vigorous,stress,hr_latest,hr_min,hr_avg,hr_max,body_battery,distance_cm,floors");
        var start = next - count;
        while (start < 0) { start += MAX_RECORDS; }
        for (var i = 0; i < count; i += 1) {
            var index = (start + i) % MAX_RECORDS;
            var record = loadRecord(index);
            if (record != null) { System.println(csvLine(record)); }
        }
        System.println("WRIST_DIARY_END");
    }

    function loadRecord(index as Lang.Number) as Lang.Array<Lang.Number>? {
        var value = Application.Storage.getValue("r" + index);
        if (value instanceof Lang.Array) {
            var record = value as Lang.Array<Lang.Number>;
            if (record.size() == RECORD_SIZE) { return record; }
        }
        return null;
    }

    function readStoredNumber(key as Lang.String, fallback as Lang.Number) as Lang.Number {
        var value = Application.Storage.getValue(key);
        return (value instanceof Lang.Number) ? (value as Lang.Number) : fallback;
    }

    function missingRecord() as Lang.Array<Lang.Number> {
        var record = [] as Lang.Array<Lang.Number>;
        for (var i = 0; i < RECORD_SIZE; i += 1) { record.add(-1); }
        return record;
    }

    function csvLine(record as Lang.Array<Lang.Number>) as Lang.String {
        var line = "" + record[0];
        for (var i = 1; i < record.size(); i += 1) {
            line += "," + record[i];
        }
        return line;
    }

    function activeTotal(record as Lang.Array<Lang.Number>) as Lang.Number {
        if (record[I_MODERATE] < 0 || record[I_VIGOROUS] < 0) { return -1; }
        return record[I_MODERATE] + record[I_VIGOROUS];
    }

    function activeDeltaText() as Lang.String {
        var previous = mPrevious;
        if (previous == null) { return ""; }
        var currentValue = activeTotal(mRecord);
        var previousValue = activeTotal(previous);
        return formattedDelta(currentValue, previousValue);
    }

    function deltaText(index as Lang.Number) as Lang.String {
        var previous = mPrevious;
        if (previous == null) { return ""; }
        return formattedDelta(mRecord[index], previous[index]);
    }

    function formattedDelta(currentValue as Lang.Number,
                            previousValue as Lang.Number) as Lang.String {
        if (currentValue < 0 || previousValue < 0 || currentValue < previousValue) {
            return "";
        }
        return "+" + (currentValue - previousValue);
    }

    function numberText(value as Lang.Number) as Lang.String {
        return (value < 0) ? "--" : value.format("%d");
    }

    function bpmText(value as Lang.Number) as Lang.String {
        return (value < 0) ? "--" : value.format("%d") + " bpm";
    }

    function distanceText(value as Lang.Number) as Lang.String {
        if (value < 0) { return "--"; }
        return (value.toFloat() / 100000.0).format("%.1f") + " km";
    }

    function hrRangeText() as Lang.String {
        if (mRecord[I_HR_MIN] < 0 || mRecord[I_HR_AVG] < 0 || mRecord[I_HR_MAX] < 0) {
            return "-- / -- / --";
        }
        return mRecord[I_HR_MIN].format("%d") + " / " +
               mRecord[I_HR_AVG].format("%d") + " / " +
               mRecord[I_HR_MAX].format("%d");
    }
}
