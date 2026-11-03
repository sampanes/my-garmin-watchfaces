using Toybox.Application;
using Toybox.WatchUi;

// A throwaway watch face that answers one question for the ink face: how
// many baked bitmaps the FR265 takes. scripts/bitmap-budget.ps1 builds it
// with N generated PNGs (copies of the ink face's real *_cut.png planes,
// each made unique), runs it, and reads the log lines BudgetView prints.
// Never installed for wear.
class BudgetApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [ new BudgetView() ];
    }

}
