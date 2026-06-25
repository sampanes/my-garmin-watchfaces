using Toybox.WatchUi;

class PetHardwareProbeDelegate extends WatchUi.BehaviorDelegate {
    var mView as PetHardwareProbeView;

    function initialize(view as PetHardwareProbeView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onSelect() {
        mView.runCurrentProbe();
        return true;
    }

    function onNextPage() {
        mView.nextProbe();
        return true;
    }

    function onPreviousPage() {
        mView.previousProbe();
        return true;
    }
}
