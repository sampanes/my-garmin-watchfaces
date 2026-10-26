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
        mView.selectAction();
        return true;
    }

    function onBack() {
        mView.noteInput();
        if (!mView.backAction()) { return true; }
        // Home Back is the escape hatch. A failed compact save must never keep
        // the wearer inside the app.
        try {
            mView.stopFromBack();
        } catch (e) {
            System.println("FRIEND_STOP_ERROR," + e.getErrorMessage());
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() {
        mView.noteInput();
        mView.pageAction();
        return true;
    }

    function onPreviousPage() {
        mView.noteInput();
        mView.pageAction();
        return true;
    }

    function onMenu() {
        mView.noteInput();
        mView.menuAction();
        return true;
    }
}
