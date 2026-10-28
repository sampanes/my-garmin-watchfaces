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

    // Settings edited from the phone (true-HR overlay, night hours) repaint
    // at once instead of at the next five-minute key.
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
