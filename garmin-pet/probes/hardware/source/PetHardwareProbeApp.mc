using Toybox.Application;

class PetHardwareProbeApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        var view = new PetHardwareProbeView();
        return [ view, new PetHardwareProbeDelegate(view) ];
    }
}
