using Toybox.Application;

class JapaneseInkHeartrateApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new JapaneseInkHeartrateView(), new JapaneseInkHeartrateDelegate() ];
    }

}

function getApp() as JapaneseInkHeartrateApp {
    return Application.getApp() as JapaneseInkHeartrateApp;
}
