using Toybox.Application;
using Toybox.Lang;

class WalkProbeApp extends Application.AppBase {
    var mView as WalkProbeView?;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new WalkProbeView();
        mView = view;
        return [ view, new WalkProbeDelegate(view) ];
    }

    // The watch closed the app without Back (T20: another app took over, a timeout, ...).
    // Save what was recorded so the activity still reaches Connect and shows where it ended.
    function onStop(state as Lang.Dictionary?) as Void {
        var view = mView;
        if (view != null) {
            view.finishFromSystemClose();
            view.stopGps();
        }
    }
}
