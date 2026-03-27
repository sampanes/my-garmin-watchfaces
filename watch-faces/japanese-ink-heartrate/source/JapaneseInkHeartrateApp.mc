using Toybox.Application;
using Toybox.Math;
using Toybox.System;

class JapaneseInkHeartrateApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
        Math.srand(System.getTimer());
    }

    function getInitialView() {
        return [ new JapaneseInkHeartrateView(), new JapaneseInkHeartrateDelegate() ];
    }

}

function getApp() as JapaneseInkHeartrateApp {
    return Application.getApp() as JapaneseInkHeartrateApp;
}
