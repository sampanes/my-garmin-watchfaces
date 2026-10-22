using Toybox.System;
using Toybox.WatchUi;

class WalkProbeDelegate extends WatchUi.BehaviorDelegate {
    var mView as WalkProbeView;

    function initialize(view as WalkProbeView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    // START: begin recording, or stop and save the running one.
    function onSelect() {
        if (mView.isRecording()) {
            mView.finish(WalkProbeView.END_SELECT);
        } else {
            mView.startRecording();
        }
        return true;
    }

    // Back while recording stops and saves, then stays on the result screen so the
    // wearer sees SAVED. Back while idle leaves the app.
    function onBack() {
        if (mView.isRecording()) {
            try {
                mView.finish(WalkProbeView.END_BACK);
            } catch (e) {
                System.println("WALK_STOP_ERROR," + e.getErrorMessage());
            }
            return true;
        }
        mView.stopGps();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // Menu (hold UP on the FR265) throws a botched recording away instead of saving it.
    function onMenu() {
        if (mView.isRecording()) {
            mView.discard();
            return true;
        }
        return false;
    }
}
