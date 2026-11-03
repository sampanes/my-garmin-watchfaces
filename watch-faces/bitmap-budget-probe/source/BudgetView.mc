using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

// Two passes, a chunk per onUpdate so no single update runs long:
//   sweep  every generated bitmap is loaded, drawn into a full-screen
//          buffer and dropped, as the ink face does with its masses. A
//          failure is a bitmap the watch cannot load at all.
//   hold   the first HOLD_MAX are loaded and KEPT, all redrawn as each one
//          joins, until one fails: how many planes one frame could hold
//          at once (the graphics-pool budget).
// Log lines (System.println: the simulator console via monkeydo, or on the
// watch GARMIN/Apps/LOGS/<prg name>.txt when that file exists):
//   BUDGET_START,<count>,<heap total>,<heap used>
//   BUDGET_LOAD,<i>,<1 ok | 0 failed>,<ms>,<w>x<h>[,<error>]
//   BUDGET_HOLD,<k held>,<heap used>,<1 ok | 0 failed>[,<error>]
//   BUDGET_DONE,<count>,<loaded>,<failed>,<max ms>,<total ms>,<held>
class BudgetView extends WatchUi.WatchFace {

    const CHUNK = 12;
    const HOLD_MAX = 48;

    var mIds as Lang.Array<Lang.ResourceId> = [] as Lang.Array<Lang.ResourceId>;
    var mBuffer as Graphics.BufferedBitmap?;
    var mNext as Lang.Number = 0;
    var mLoaded as Lang.Number = 0;
    var mFailed as Lang.Number = 0;
    var mMaxMs as Lang.Number = 0;
    var mTotalMs as Lang.Number = 0;
    var mHeld as Lang.Array<Graphics.BitmapType> = [] as Lang.Array<Graphics.BitmapType>;
    var mHoldDone as Lang.Boolean = false;
    var mDone as Lang.Boolean = false;
    var mStarted as Lang.Boolean = false;

    function initialize() {
        WatchFace.initialize();
        mIds = budgetIds();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        if (Graphics has :createBufferedBitmap) {
            mBuffer = Graphics.createBufferedBitmap({
                :width => dc.getWidth(), :height => dc.getHeight()
            }).get() as Graphics.BufferedBitmap;
        }
    }

    function heapUsed() as Lang.Number {
        return System.getSystemStats().usedMemory;
    }

    function load(i as Lang.Number) as Graphics.BitmapType {
        return WatchUi.loadResource(mIds[i]) as Graphics.BitmapType;
    }

    // a spread of positions, like the masses
    function paint(bmp as Graphics.BitmapType, i as Lang.Number) as Void {
        var buffer = mBuffer;
        if (buffer == null) { return; }
        var bdc = buffer.getDc();
        bdc.drawScaledBitmap((i * 37) % 300, 60 + (i * 53) % 200, 120, 90, bmp);
    }

    function step() as Void {
        if (!mStarted) {
            mStarted = true;
            var stats = System.getSystemStats();
            System.println("BUDGET_START," + mIds.size() + "," + stats.totalMemory + "," + stats.usedMemory);
        }
        var stop = mNext + CHUNK;
        while (mNext < mIds.size() && mNext < stop) {
            var i = mNext;
            mNext++;
            var t0 = System.getTimer();
            try {
                var bmp = load(i);
                paint(bmp, i);
                var ms = System.getTimer() - t0;
                mLoaded++;
                mTotalMs += ms;
                if (ms > mMaxMs) { mMaxMs = ms; }
                System.println("BUDGET_LOAD," + i + ",1," + ms + "," + bmp.getWidth() + "x" + bmp.getHeight());
            } catch (ex) {
                mFailed++;
                System.println("BUDGET_LOAD," + i + ",0," + (System.getTimer() - t0) + ",?," + ex.getErrorMessage());
            }
        }
        if (mNext < mIds.size()) { return; }

        if (!mHoldDone) {
            var holdStop = mHeld.size() + CHUNK;
            while (!mHoldDone && mHeld.size() < holdStop) {
                var k = mHeld.size();
                if (k >= HOLD_MAX || k >= mIds.size()) {
                    mHoldDone = true;
                } else {
                    try {
                        mHeld.add(load(k));
                        for (var j = 0; j < mHeld.size(); j++) { paint(mHeld[j], j); }
                        System.println("BUDGET_HOLD," + mHeld.size() + "," + heapUsed() + ",1");
                    } catch (ex) {
                        System.println("BUDGET_HOLD," + (k + 1) + "," + heapUsed() + ",0," + ex.getErrorMessage());
                        mHoldDone = true;
                    }
                }
            }
            if (!mHoldDone) { return; }
        }

        System.println("BUDGET_DONE," + mIds.size() + "," + mLoaded + "," + mFailed + "," +
                       mMaxMs + "," + mTotalMs + "," + mHeld.size());
        mDone = true;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        if (!mDone) { step(); }
        if (mDone && mHeld.size() > 0) {
            // let go of the held set once it is reported
            mHeld = [] as Lang.Array<Graphics.BitmapType>;
        }
        dc.setColor(0xF2EEE6, 0xF2EEE6);
        dc.clear();
        var buffer = mBuffer;
        if (buffer != null) { dc.drawBitmap(0, 0, buffer); }
        dc.setColor(0x18120E, Graphics.COLOR_TRANSPARENT);
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.drawText(w / 2, h / 2 - 40, Graphics.FONT_SMALL, mDone ? "DONE" : "WORKING",
                    Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, h / 2, Graphics.FONT_XTINY,
                    "loaded " + mLoaded + "/" + mIds.size() + " failed " + mFailed,
                    Graphics.TEXT_JUSTIFY_CENTER);
        if (!mDone) { WatchUi.requestUpdate(); }
    }

}
