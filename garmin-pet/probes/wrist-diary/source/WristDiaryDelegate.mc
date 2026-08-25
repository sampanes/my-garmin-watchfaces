using Toybox.WatchUi;

class WristDiaryDelegate extends WatchUi.BehaviorDelegate {
    var mView as WristDiaryView;

    function initialize(view as WristDiaryView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() {
        mView.exportNow();
        return true;
    }

    function onBack() {
        // Back is the escape hatch. Save compact records, then leave; the
        // potentially large text export remains an explicit Select action.
        mView.stopSession();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
