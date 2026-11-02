using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

// On-watch settings. A face copied over USB gets no "Customize" in Garmin
// Connect (only store installs carry the settings form to the phone), so
// the same three properties are edited here: long-press the face (or pick
// it in the watch-face list) -> Customize.
class JapaneseInkHeartrateSettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => "Ink face"});
        addItem(new WatchUi.ToggleMenuItem("True HR line", null, :overlay,
            settingBool("trueHrOverlay", true), null));
        addItem(new WatchUi.MenuItem("Night from",
            hourLabel(settingHour("nightStart", 21)), :nightStart, null));
        addItem(new WatchUi.MenuItem("Night until",
            hourLabel(settingHour("nightEnd", 6)), :nightEnd, null));
    }

}

class JapaneseInkHeartrateSettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    // The toggle flips itself; an hour row steps one hour forward per press
    // (23 wraps to 0). Night is off while "from" equals "until".
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :overlay) {
            Application.Properties.setValue("trueHrOverlay",
                (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :nightStart || id == :nightEnd) {
            var key = (id == :nightStart) ? "nightStart" : "nightEnd";
            var hour = (settingHour(key, (id == :nightStart) ? 21 : 6) + 1) % 24;
            Application.Properties.setValue(key, hour);
            item.setSubLabel(hourLabel(hour));
        }
        getApp().onSettingsChanged();
    }

}

function settingBool(key as Lang.String, fallback as Lang.Boolean) as Lang.Boolean {
    var value = Application.Properties.getValue(key);
    if (value instanceof Lang.Boolean) { return value as Lang.Boolean; }
    return fallback;
}

function settingHour(key as Lang.String, fallback as Lang.Number) as Lang.Number {
    var value = Application.Properties.getValue(key);
    if (value instanceof Lang.Number) { return (value as Lang.Number) % 24; }
    return fallback;
}

// 12-hour labels, as the watch is set: 0 -> "12 AM", 21 -> "9 PM".
function hourLabel(hour as Lang.Number) as Lang.String {
    var h12 = hour % 12;
    if (h12 == 0) { h12 = 12; }
    return h12.format("%d") + ((hour < 12) ? " AM" : " PM");
}
