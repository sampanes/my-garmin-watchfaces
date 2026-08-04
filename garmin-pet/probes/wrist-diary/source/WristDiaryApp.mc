using Toybox.Application;

class WristDiaryApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new WristDiaryView();
        return [ view, new WristDiaryDelegate(view) ];
    }
}
