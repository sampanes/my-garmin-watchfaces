using Toybox.Application;
using Toybox.Lang;

class WristDiaryApp extends Application.AppBase {
    var mView as WristDiaryView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new WristDiaryView();
        mView = view;
        return [ view, new WristDiaryDelegate(view) ];
    }

    function onStop(state as Lang.Dictionary?) as Void {
        var view = mView;
        if (view != null) {
            view.stopSession();
        }
    }
}
