using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;

// On-watch settings. A face copied over USB gets no "Customize" in Garmin
// Connect (only store installs carry the settings form to the phone), so
// the same properties are edited here: long-press the face (or pick it in
// the watch-face list) -> Customize.
class JapaneseInkHeartrateSettingsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({:title => "Ink face"});
        addItem(new WatchUi.ToggleMenuItem("True HR line", null, :overlay,
            settingBool("trueHrOverlay", true), null));
        addItem(new WatchUi.ToggleMenuItem("Lantern = Low Batt", "Under 30%", :lantern,
            settingBool("lantern", true), null));
        addItem(new WatchUi.ToggleMenuItem("Geese = Step Goal", "Goal met today", :geese,
            settingBool("geese", true), null));
        addItem(new WatchUi.ToggleMenuItem("Hiker = Workout", "On its summit", :hiker,
            settingBool("hiker", true), null));
        addItem(new WatchUi.ToggleMenuItem("Village = Calm", "No peaks, 4 h", :village,
            settingBool("village", true), null));
        addItem(new WatchUi.ToggleMenuItem("Hour in kanji", "Off: brush digits", :hourKanji,
            settingBool("hourKanji", true), null));
        addItem(new WatchUi.ToggleMenuItem("Red seal = HR", "Off: the date", :sealHr,
            settingBool("sealHr", true), null));
        addItem(new WatchUi.ToggleMenuItem("Weather", "Rain, snow, wind", :weather,
            settingBool("weather", true), null));
        addItem(new WatchUi.MenuItem("Night from",
            hourLabel(settingHour("nightStart", 21)), :nightStart, null));
        addItem(new WatchUi.MenuItem("Night until",
            hourLabel(settingHour("nightEnd", 6)), :nightEnd, null));
        addItem(new WatchUi.MenuItem("Foreground",
            sceneLabel(settingNumber("foreground", 0, FG_SEASONS)), :foreground, null));
    }

}

class JapaneseInkHeartrateSettingsDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    // A toggle flips itself; an hour row steps one hour forward per press
    // (23 wraps to 0). Night is off while "from" equals "until". The
    // foreground row steps through by-season and the five scenes.
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :overlay) {
            Application.Properties.setValue("trueHrOverlay",
                (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :lantern || id == :geese || id == :hiker || id == :village
                   || id == :hourKanji) {
            // a piece's own toggle (toggleKey: the property behind it)
            Application.Properties.setValue(toggleKey(id),
                (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :sealHr) {
            Application.Properties.setValue("sealHr",
                (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :weather) {
            Application.Properties.setValue("weather",
                (item as WatchUi.ToggleMenuItem).isEnabled());
        } else if (id == :nightStart || id == :nightEnd) {
            var key = (id == :nightStart) ? "nightStart" : "nightEnd";
            var hour = (settingHour(key, (id == :nightStart) ? 21 : 6) + 1) % 24;
            Application.Properties.setValue(key, hour);
            item.setSubLabel(hourLabel(hour));
        } else if (id == :foreground) {
            var scene = (settingNumber("foreground", 0, FG_SEASONS) + 1) % (FG_SEASONS + 1);
            Application.Properties.setValue("foreground", scene);
            item.setSubLabel(sceneLabel(scene));
        }
        getApp().onSettingsChanged();
    }

}

// The property behind a piece's toggle (the menu ids above).
function toggleKey(id as Lang.Object or Null) as Lang.String {
    if (id == :lantern) { return "lantern"; }
    if (id == :geese) { return "geese"; }
    if (id == :hiker) { return "hiker"; }
    if (id == :village) { return "village"; }
    return "hourKanji";
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

function settingNumber(key as Lang.String, fallback as Lang.Number, max as Lang.Number) as Lang.Number {
    var value = Application.Properties.getValue(key);
    if (value instanceof Lang.Number) {
        var n = value as Lang.Number;
        if (n >= 0 && n <= max) { return n; }
    }
    return fallback;
}

// The foreground setting's label: by season, or one of the baked scenes
// (scripts/bake_foregrounds.py SEASONS order).
function sceneLabel(scene as Lang.Number) as Lang.String {
    if (scene == 1) { return "Spring"; }
    if (scene == 2) { return "Summer"; }
    if (scene == 3) { return "Autumn"; }
    if (scene == 4) { return "Winter"; }
    if (scene == 5) { return "Mountain pass"; }
    return "By season";
}

// 12-hour labels, as the watch is set: 0 -> "12 AM", 21 -> "9 PM".
function hourLabel(hour as Lang.Number) as Lang.String {
    var h12 = hour % 12;
    if (h12 == 0) { h12 = 12; }
    return h12.format("%d") + ((hour < 12) ? " AM" : " PM");
}
