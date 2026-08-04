using Toybox.WatchUi;

class WristDiaryDelegate extends WatchUi.BehaviorDelegate {
    var mView as WristDiaryView;

    function initialize(view as WristDiaryView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() {
        mView.captureNow();
        return true;
    }

    function onNextPage() {
        mView.nextPage();
        return true;
    }

    function onPreviousPage() {
        mView.previousPage();
        return true;
    }
}
