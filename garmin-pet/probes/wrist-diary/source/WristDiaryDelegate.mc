using Toybox.System;
using Toybox.WatchUi;

class WristDiaryDelegate extends WatchUi.BehaviorDelegate {
    var mView as WristDiaryView;

    function initialize(view as WristDiaryView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    // START is the one primary action. The view says when it means "leave".
    function onSelect() {
        mView.noteInput();
        if (mView.selectAction()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }

    // A tap pets the friend and is never passed on as START, so a sleeve or a
    // palm on the touchscreen cannot start, end or save a walk.
    function onTap(clickEvent) {
        mView.noteInput();
        mView.tapAction();
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
        // The session is saved. If it earned something, the friend shows it
        // before Friend leaves; Back or START again, or 20 seconds, leaves.
        try {
            if (mView.beginExitReward()) { return true; }
        } catch (e2) {
            System.println("FRIEND_REWARD_ERROR," + e2.getErrorMessage());
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onNextPage() {
        mView.noteInput();
        mView.pageAction(1);
        return true;
    }

    function onPreviousPage() {
        mView.noteInput();
        mView.pageAction(-1);
        return true;
    }

    function onMenu() {
        mView.noteInput();
        mView.menuAction();
        return true;
    }
}
