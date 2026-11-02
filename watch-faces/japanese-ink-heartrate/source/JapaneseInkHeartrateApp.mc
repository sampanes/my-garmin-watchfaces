using Toybox.Application;
using Toybox.Math;
using Toybox.System;
using Toybox.WatchUi;

class JapaneseInkHeartrateApp extends Application.AppBase {

    var mView as JapaneseInkHeartrateView?;

    function initialize() {
        AppBase.initialize();
        Math.srand(System.getTimer());
    }

    function getInitialView() {
        var view = new JapaneseInkHeartrateView();
        mView = view;
        return [ view, new JapaneseInkHeartrateDelegate() ];
    }

    // The watch's own Customize menu (a USB-installed face has none on the
    // phone). Unannotated like getInitialView: the tuple return type.
    function getSettingsView() {
        return [ new JapaneseInkHeartrateSettingsMenu(), new JapaneseInkHeartrateSettingsDelegate() ];
    }

    // Settings edited from the phone or the watch menu (true-HR overlay,
    // night hours) repaint at once instead of at the next five-minute key.
    function onSettingsChanged() as Void {
        var view = mView;
        if (view != null) {
            view.onSettingsChanged();
        }
        WatchUi.requestUpdate();
    }

}

function getApp() as JapaneseInkHeartrateApp {
    return Application.getApp() as JapaneseInkHeartrateApp;
}
