using Toybox.System;
using Toybox.WatchUi;

class WristDiaryDelegate extends WatchUi.BehaviorDelegate {
    var mView as WristDiaryView;

    function initialize(view as WristDiaryView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() {
        mView.noteInput();
        mView.exportNow();
        return true;
    }

    function onBack() {
        // Back is the escape hatch. Save compact records, then leave; the
        // potentially large text export remains an explicit Select action.
        // A failed save must never keep the wearer inside the app.
        mView.noteInput();
        try {
            mView.stopSession(WristDiaryView.EXIT_BACK);
        } catch (e) {
            System.println("FRIEND_STOP_ERROR," + e.getErrorMessage());
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    // Unused behaviors are still counted as input, then left to the system.
    function onNextPage() {
        mView.noteInput();
        return false;
    }

    function onPreviousPage() {
        mView.noteInput();
        return false;
    }

    function onMenu() {
        mView.noteInput();
        return false;
    }
}
