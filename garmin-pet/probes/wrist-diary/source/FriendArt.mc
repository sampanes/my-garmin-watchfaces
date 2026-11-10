using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Math;

// Shared ids for how the friend looks and moves. Module constants, so the view
// and the art class name the same numbers.
module FriendLook {
    const STAGE_EGG = 0;
    const STAGE_BABY = 1;       // Band 0, still wearing its shell.
    const STAGE_CHILD = 2;      // Bands 1-2.
    const STAGE_ADULT = 3;      // After the first evolution.

    const FORM_SLEEK = 0;
    const FORM_ROUND = 1;
    const FORM_WILD = 2;
    const FORM_COUNT = 3;

    const FACE_MISTY = 0;       // The first four are the mood weather.
    const FACE_FAIR = 1;
    const FACE_SUNNY = 2;
    const FACE_RADIANT = 3;
    const FACE_EFFORT = 4;
    const FACE_JOY = 5;
    const FACE_SLEEP = 6;

    const POSE_IDLE = 0;
    const POSE_RUN = 1;
    const POSE_HOP = 2;
    const POSE_FLEX = 3;
    const POSE_SPIN = 4;
    const POSE_FLAMES = 5;
    const POSE_SLEEP = 6;

    const PALETTE_COUNT = 6;
}

// The friend, drawn from filled shapes: no bitmaps, so a colorway is a color
// table and every stage, form and accessory costs code, not heap
// (garmin-pet/09-appearance-and-transfer.md). Integer math only.
//
// scripts/friend_preview.py holds a line-for-line Python port of this class and
// renders it on a machine without the SDK. Change both together;
// `python scripts/friend_preview.py --check` compares the numbers in each
// function of the two files.
class FriendArt {
    const INK = 0x1B1B2A;
    const BLUSH = 0xFF6F8E;
    const LEAF = 0x7BE07B;
    const BAND_RED = 0xFF5A5A;
    const FLAME_OUT = 0xFF8A2A;
    const FLAME_IN = 0xFFE066;
    const SHELL = 0xF4F1E6;
    const SHADOW = 0x14201A;

    var mPalettes as Lang.Array<Lang.Array<Lang.Number>>;
    var mBob as Lang.Array<Lang.Number>;
    var mRunJump as Lang.Array<Lang.Number>;
    var mHopJump as Lang.Array<Lang.Number>;
    var mSpinWidth as Lang.Array<Lang.Number>;

    var mStage as Lang.Number = 1;
    var mBand as Lang.Number = 0;
    var mForm as Lang.Number = 1;
    var mEvos as Lang.Number = 0;
    var mPal as Lang.Number = 0;
    var mFace as Lang.Number = 1;
    var mPose as Lang.Number = 0;
    var mFrame as Lang.Number = 0;

    function initialize() {
        // body, shade, belly
        mPalettes = [
            [0x6ED6A8, 0x3E9C78, 0xC8F5E0],
            [0xFFB15C, 0xD9822B, 0xFFE2B8],
            [0x6EC1FF, 0x3A8BD1, 0xCDEBFF],
            [0xB79CFF, 0x8468D6, 0xE4DAFF],
            [0xF2D550, 0xC9A21E, 0xFFF3B8],
            [0xFF8FAF, 0xD65C82, 0xFFD6E2]
        ] as Lang.Array<Lang.Array<Lang.Number>>;
        mBob = [0, 1, 2, 2, 2, 1, 0, -1, -2, -2, -2, -1] as Lang.Array<Lang.Number>;
        mRunJump = [0, 7, 10, 7] as Lang.Array<Lang.Number>;
        mHopJump = [0, 20, 34, 40, 34, 20, 0, -5] as Lang.Array<Lang.Number>;
        mSpinWidth = [100, 72, 40, 72, 100, 72, 40, 72] as Lang.Array<Lang.Number>;
    }

    function setLook(stage as Lang.Number, band as Lang.Number, form as Lang.Number,
                     evos as Lang.Number, pal as Lang.Number) as Void {
        mStage = stage;
        mBand = band;
        mForm = form;
        mEvos = evos;
        mPal = pal % mPalettes.size();
        if (mPal < 0) { mPal = 0; }
    }

    function setPose(face as Lang.Number, pose as Lang.Number, frame as Lang.Number) as Void {
        mFace = face;
        mPose = pose;
        mFrame = frame;
    }

    function bodyColor() as Lang.Number {
        return mPalettes[mPal][0];
    }

    function shadeColor() as Lang.Number {
        return mPalettes[mPal][1];
    }

    function bellyColor() as Lang.Number {
        return mPalettes[mPal][2];
    }

    // Body radius in pixels for a stage, as a share of the screen height.
    function sizeFor(stage as Lang.Number, height as Lang.Number) as Lang.Number {
        if (stage == FriendLook.STAGE_ADULT) {
            return height * 150 / 1000;
        }
        if (stage == FriendLook.STAGE_CHILD) {
            return height * 140 / 1000;
        }
        if (stage == FriendLook.STAGE_BABY) {
            return height * 124 / 1000;
        }
        return height * 130 / 1000;
    }

    // Half the width of an a-by-b ellipse at a height dy from its center.
    function ellipseHalf(a as Lang.Number, b as Lang.Number, offset as Lang.Number) as Lang.Number {
        var dy = offset;
        if (dy < 0) {
            dy = -dy;
        }
        if (b <= 0 || dy >= b) {
            return 0;
        }
        return (a * Math.sqrt(b * b - dy * dy) / b).toNumber();
    }

    // The whole friend, centered on (cx, centerY) with body radius s.
    function draw(dc as Graphics.Dc, cx as Lang.Number, centerY as Lang.Number,
                  s as Lang.Number) as Void {
        if (mStage == FriendLook.STAGE_EGG) {
            drawEgg(dc, cx, centerY, s, 0);
            return;
        }
        var cy = centerY;
        var frame = mFrame;
        var a = s;
        var b = s;
        if (mStage == FriendLook.STAGE_BABY) {
            b = s * 94 / 100;
        } else if (mStage == FriendLook.STAGE_CHILD) {
            a = s * 94 / 100;
        } else if (mForm == FriendLook.FORM_SLEEK) {
            a = s * 84 / 100;
            b = s * 106 / 100;
        } else if (mForm == FriendLook.FORM_ROUND) {
            a = s * 108 / 100;
            b = s * 96 / 100;
        } else {
            a = s * 96 / 100;
        }

        var jump = 0;
        if (mPose == FriendLook.POSE_RUN) {
            jump = s * mRunJump[frame % 4] / 100;
        } else if (mPose == FriendLook.POSE_HOP || mPose == FriendLook.POSE_FLEX) {
            jump = s * mHopJump[frame % 8] / 100;
        } else if (mPose == FriendLook.POSE_SPIN) {
            a = a * mSpinWidth[frame % 8] / 100;
        } else if (mPose == FriendLook.POSE_SLEEP) {
            a = a * 108 / 100;
            b = b * 88 / 100;
            cy = cy + s * 12 / 100;
        } else {
            b = b + s * mBob[frame % 12] / 100;
        }
        var footY = cy + b - s * 4 / 100;
        drawShadow(dc, cx, footY + s * 10 / 100, s * 112 / 100 - jump, s);
        cy = cy - jump;
        var back = (mPose == FriendLook.POSE_SPIN && (frame % 4) == 2);

        if (mEvos >= 2) {
            drawAura(dc, cx, cy, s, frame);
        }
        if (mPose == FriendLook.POSE_FLAMES) {
            drawFlames(dc, cx, cy, s, frame);
        }
        if (mBand >= 5) {
            drawCape(dc, cx, cy, a, b, s, frame);
        }
        if (mStage == FriendLook.STAGE_ADULT) {
            dc.setColor(shadeColor(), Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx + a * 92 / 100, cy + b * 52 / 100, s * 20 / 100);
        }
        drawFeet(dc, cx, footY - jump, a, s, frame);
        if (mStage != FriendLook.STAGE_BABY) {
            drawEars(dc, cx, cy, a, b, s);
        }

        dc.setColor(bodyColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, cy, a, b);
        if (mStage != FriendLook.STAGE_BABY && !back) {
            dc.setColor(bellyColor(), Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(cx, cy + b * 40 / 100, a * 56 / 100, b * 42 / 100);
        }
        dc.setColor(bellyColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx - a * 44 / 100, cy - b * 56 / 100, a * 17 / 100, b * 10 / 100);

        if (mStage != FriendLook.STAGE_BABY) {
            drawArms(dc, cx, cy, a, b, s, frame);
        }
        if (mBand >= 2) {
            drawHeadband(dc, cx, cy, a, b, s, frame);
        }
        if (mStage == FriendLook.STAGE_BABY) {
            drawShellCap(dc, cx, cy, a, b, s);
        } else if (mBand == 1 || mBand == 2) {
            drawSprout(dc, cx, cy - b, s, frame);
        } else if (mForm == FriendLook.FORM_WILD) {
            drawTuft(dc, cx, cy - b, s);
        }
        if (!back) {
            drawFace(dc, cx, cy, a, b, s, frame);
        }
        if (mPose == FriendLook.POSE_SLEEP) {
            drawZ(dc, cx + a, cy - b * 60 / 100, s, frame);
        }
    }

    function drawShadow(dc as Graphics.Dc, cx as Lang.Number, y as Lang.Number,
                        a as Lang.Number, s as Lang.Number) as Void {
        dc.setColor(SHADOW, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, y, a, s * 15 / 100);
    }

    function drawFeet(dc as Graphics.Dc, cx as Lang.Number, y as Lang.Number,
                      a as Lang.Number, s as Lang.Number, frame as Lang.Number) as Void {
        var lift = s * 12 / 100;
        var left = 0;
        var right = 0;
        if (mPose == FriendLook.POSE_RUN) {
            if ((frame % 4) < 2) {
                left = lift;
            } else {
                right = lift;
            }
        }
        dc.setColor(shadeColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx - a * 42 / 100, y - left, s * 25 / 100, s * 13 / 100);
        dc.fillEllipse(cx + a * 42 / 100, y - right, s * 25 / 100, s * 13 / 100);
    }

    function drawEars(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                      a as Lang.Number, b as Lang.Number, s as Lang.Number) as Void {
        var body = bodyColor();
        var shade = shadeColor();
        if (mStage == FriendLook.STAGE_ADULT && mForm == FriendLook.FORM_SLEEK) {
            for (var side = -1; side <= 1; side += 2) {
                var x = cx + side * (a * 52 / 100);
                var y = cy - b * 104 / 100;
                dc.setColor(body, Graphics.COLOR_TRANSPARENT);
                dc.fillEllipse(x, y, s * 15 / 100, s * 40 / 100);
                dc.setColor(shade, Graphics.COLOR_TRANSPARENT);
                dc.fillEllipse(x, y + s * 4 / 100, s * 7 / 100, s * 26 / 100);
            }
        } else if (mStage == FriendLook.STAGE_ADULT && mForm == FriendLook.FORM_WILD) {
            for (var side = -1; side <= 1; side += 2) {
                var x = cx + side * (a * 62 / 100);
                var y = cy - b * 70 / 100;
                dc.setColor(body, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[x - s * 22 / 100, y + s * 14 / 100],
                                [x + side * (s * 20 / 100), y - s * 46 / 100],
                                [x + s * 22 / 100, y + s * 14 / 100]]);
                dc.setColor(shade, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[x - s * 10 / 100, y + s * 6 / 100],
                                [x + side * (s * 14 / 100), y - s * 28 / 100],
                                [x + s * 10 / 100, y + s * 6 / 100]]);
            }
        } else {
            var r = s * 26 / 100;
            if (mStage == FriendLook.STAGE_ADULT) {
                r = s * 30 / 100;
            }
            for (var side = -1; side <= 1; side += 2) {
                var x = cx + side * (a * 66 / 100);
                var y = cy - b * 74 / 100;
                dc.setColor(body, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, r);
                dc.setColor(shade, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, r * 52 / 100);
            }
        }
    }

    function drawArms(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                      a as Lang.Number, b as Lang.Number, s as Lang.Number,
                      frame as Lang.Number) as Void {
        dc.setColor(shadeColor(), Graphics.COLOR_TRANSPARENT);
        var armA = s * 13 / 100;
        var armB = s * 22 / 100;
        if (mPose == FriendLook.POSE_FLEX) {
            for (var side = -1; side <= 1; side += 2) {
                var x = cx + side * (a + s * 12 / 100);
                dc.fillEllipse(x, cy + s * 4 / 100, s * 24 / 100, armA);
                dc.fillEllipse(x + side * (s * 16 / 100), cy - s * 18 / 100,
                               armA, s * 26 / 100);
                dc.fillCircle(x + side * (s * 4 / 100), cy - s * 8 / 100, s * 17 / 100);
            }
            return;
        }
        var swing = 0;
        if (mPose == FriendLook.POSE_RUN) {
            swing = s * 12 / 100;
            if ((frame % 4) < 2) {
                swing = -swing;
            }
        } else if (mPose == FriendLook.POSE_HOP) {
            swing = -(s * 30 / 100);
            dc.fillEllipse(cx - a - s * 2 / 100, cy + swing, armA, armB);
            dc.fillEllipse(cx + a + s * 2 / 100, cy + swing, armA, armB);
            return;
        }
        dc.fillEllipse(cx - a + s * 2 / 100, cy + s * 18 / 100 + swing, armA, armB);
        dc.fillEllipse(cx + a - s * 2 / 100, cy + s * 18 / 100 - swing, armA, armB);
    }

    function drawHeadband(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                          a as Lang.Number, b as Lang.Number, s as Lang.Number,
                          frame as Lang.Number) as Void {
        var top = cy - b * 62 / 100;
        var bottom = cy - b * 42 / 100;
        var wTop = ellipseHalf(a, b, cy - top);
        var wBottom = ellipseHalf(a, b, cy - bottom);
        dc.setColor(BAND_RED, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - wTop, top], [cx + wTop, top],
                        [cx + wBottom, bottom], [cx - wBottom, bottom]]);
        // The knot's two tails flutter on alternate frames.
        var flutter = s * 6 / 100;
        if ((frame % 4) < 2) {
            flutter = -flutter;
        }
        var knotX = cx + wBottom - s * 2 / 100;
        var knotY = (top + bottom) / 2;
        dc.fillPolygon([[knotX, knotY - s * 5 / 100],
                        [knotX + s * 30 / 100, knotY - s * 14 / 100 + flutter],
                        [knotX + s * 26 / 100, knotY + s * 2 / 100 + flutter]]);
        dc.fillPolygon([[knotX, knotY + s * 3 / 100],
                        [knotX + s * 24 / 100, knotY + s * 12 / 100 - flutter],
                        [knotX + s * 14 / 100, knotY + s * 22 / 100 - flutter]]);
    }

    function drawShellCap(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                          a as Lang.Number, b as Lang.Number, s as Lang.Number) as Void {
        var y = cy - b * 60 / 100;
        var w = ellipseHalf(a, b, cy - y) + s * 8 / 100;
        var tooth = s * 20 / 100;
        var top = cy - b - s * 14 / 100;
        dc.setColor(SHELL, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - w, y - tooth],
                        [cx - w * 66 / 100, y],
                        [cx - w * 33 / 100, y - tooth],
                        [cx, y],
                        [cx + w * 33 / 100, y - tooth],
                        [cx + w * 66 / 100, y],
                        [cx + w, y - tooth],
                        [cx + w * 86 / 100, top + s * 22 / 100],
                        [cx + w * 50 / 100, top],
                        [cx - w * 50 / 100, top],
                        [cx - w * 86 / 100, top + s * 22 / 100]]);
        dc.setColor(bodyColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + w * 30 / 100, top + s * 20 / 100, s * 8 / 100);
    }

    function drawSprout(dc as Graphics.Dc, cx as Lang.Number, topY as Lang.Number,
                        s as Lang.Number, frame as Lang.Number) as Void {
        var sway = 0;
        if ((frame % 12) < 6) {
            sway = s * 3 / 100;
        }
        var tipX = cx + sway;
        var tipY = topY - s * 26 / 100;
        dc.setColor(LEAF, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(cx, topY + s * 4 / 100, tipX, tipY);
        dc.fillPolygon([[tipX, tipY],
                        [tipX - s * 14 / 100, tipY - s * 22 / 100],
                        [tipX - s * 34 / 100, tipY - s * 18 / 100],
                        [tipX - s * 20 / 100, tipY - s * 2 / 100]]);
        dc.fillPolygon([[tipX, tipY],
                        [tipX + s * 14 / 100, tipY - s * 22 / 100],
                        [tipX + s * 34 / 100, tipY - s * 18 / 100],
                        [tipX + s * 20 / 100, tipY - s * 2 / 100]]);
    }

    function drawTuft(dc as Graphics.Dc, cx as Lang.Number, topY as Lang.Number,
                      s as Lang.Number) as Void {
        dc.setColor(shadeColor(), Graphics.COLOR_TRANSPARENT);
        var base = topY + s * 8 / 100;
        dc.fillPolygon([[cx - s * 26 / 100, base],
                        [cx - s * 18 / 100, topY - s * 22 / 100],
                        [cx - s * 8 / 100, base - s * 4 / 100],
                        [cx, topY - s * 34 / 100],
                        [cx + s * 8 / 100, base - s * 4 / 100],
                        [cx + s * 18 / 100, topY - s * 22 / 100],
                        [cx + s * 26 / 100, base]]);
    }

    function drawCape(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                      a as Lang.Number, b as Lang.Number, s as Lang.Number,
                      frame as Lang.Number) as Void {
        var flutter = s * 5 / 100;
        if ((frame % 4) < 2) {
            flutter = -flutter;
        }
        dc.setColor(0xC8324A, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - a * 70 / 100, cy - b * 40 / 100],
                        [cx + a * 70 / 100, cy - b * 40 / 100],
                        [cx + a + s * 34 / 100, cy + b + flutter],
                        [cx + a * 40 / 100, cy + b - s * 8 / 100],
                        [cx - a - s * 34 / 100, cy + b - flutter]]);
    }

    function drawAura(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                      s as Lang.Number, frame as Lang.Number) as Void {
        dc.setColor(0xE8CF70, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(cx, cy, s * 120 / 100 + (frame % 4));
    }

    function drawFlames(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                        s as Lang.Number, frame as Lang.Number) as Void {
        var flick = s * 8 / 100;
        if ((frame % 2) == 0) {
            flick = -flick;
        }
        for (var i = 0; i < 5; i += 1) {
            var x = cx + (i - 2) * s * 58 / 100;
            var h = s * 170 / 100;
            if (i == 1 || i == 3) {
                h = s * 215 / 100;
            }
            if (i == 2) {
                h = s * 250 / 100;
            }
            if ((i % 2) == 0) {
                h = h + flick;
            } else {
                h = h - flick;
            }
            var base = cy + s * 95 / 100;
            var w = s * 40 / 100;
            dc.setColor(FLAME_OUT, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[x - w, base], [x - w * 60 / 100, base - h * 55 / 100],
                            [x, base - h], [x + w * 60 / 100, base - h * 55 / 100],
                            [x + w, base]]);
            dc.setColor(FLAME_IN, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[x - w * 55 / 100, base],
                            [x, base - h * 62 / 100],
                            [x + w * 55 / 100, base]]);
        }
    }

    function drawFace(dc as Graphics.Dc, cx as Lang.Number, cy as Lang.Number,
                      a as Lang.Number, b as Lang.Number, s as Lang.Number,
                      frame as Lang.Number) as Void {
        var face = mFace;
        var eyeDX = a * 36 / 100;
        var eyeY = cy - b * 14 / 100;
        var eyeR = s * 13 / 100;
        if (mStage == FriendLook.STAGE_BABY) {
            eyeR = s * 16 / 100;
            eyeY = cy - b * 6 / 100;
        }
        var mouthY = eyeY + s * 30 / 100;
        var blink = ((frame % 23) == 22);

        if (face == FriendLook.FACE_SUNNY || face == FriendLook.FACE_RADIANT ||
            face == FriendLook.FACE_JOY) {
            dc.setColor(BLUSH, Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(cx - a * 62 / 100, eyeY + s * 22 / 100, s * 12 / 100, s * 7 / 100);
            dc.fillEllipse(cx + a * 62 / 100, eyeY + s * 22 / 100, s * 12 / 100, s * 7 / 100);
        }

        dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
        var pen = s * 7 / 100;
        if (pen < 3) {
            pen = 3;
        }
        dc.setPenWidth(pen);
        if (face == FriendLook.FACE_SLEEP) {
            dc.drawLine(cx - eyeDX - eyeR, eyeY, cx - eyeDX + eyeR, eyeY);
            dc.drawLine(cx + eyeDX - eyeR, eyeY, cx + eyeDX + eyeR, eyeY);
        } else if (face == FriendLook.FACE_JOY) {
            // Happy closed eyes: two upturned arcs.
            dc.drawArc(cx - eyeDX, eyeY + eyeR / 2, eyeR, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
            dc.drawArc(cx + eyeDX, eyeY + eyeR / 2, eyeR, Graphics.ARC_COUNTER_CLOCKWISE, 20, 160);
        } else if (blink) {
            dc.drawLine(cx - eyeDX - eyeR, eyeY, cx - eyeDX + eyeR, eyeY);
            dc.drawLine(cx + eyeDX - eyeR, eyeY, cx + eyeDX + eyeR, eyeY);
        } else {
            dc.fillCircle(cx - eyeDX, eyeY, eyeR);
            dc.fillCircle(cx + eyeDX, eyeY, eyeR);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var shine = eyeR * 38 / 100;
            dc.fillCircle(cx - eyeDX - eyeR * 30 / 100, eyeY - eyeR * 34 / 100, shine);
            dc.fillCircle(cx + eyeDX - eyeR * 30 / 100, eyeY - eyeR * 34 / 100, shine);
            if (face == FriendLook.FACE_MISTY) {
                // Half-lidded: the body color over the top of each eye.
                dc.setColor(bodyColor(), Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cx - eyeDX - eyeR - 1, eyeY - eyeR - 1, eyeR * 2 + 2, eyeR + 1);
                dc.fillRectangle(cx + eyeDX - eyeR - 1, eyeY - eyeR - 1, eyeR * 2 + 2, eyeR + 1);
            }
            dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
            if (face == FriendLook.FACE_EFFORT) {
                // Determined brows, tilted in toward the nose.
                dc.drawLine(cx - eyeDX - eyeR, eyeY - eyeR - s * 10 / 100,
                            cx - eyeDX + eyeR, eyeY - eyeR - s * 2 / 100);
                dc.drawLine(cx + eyeDX - eyeR, eyeY - eyeR - s * 2 / 100,
                            cx + eyeDX + eyeR, eyeY - eyeR - s * 10 / 100);
            }
        }

        dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
        if (face == FriendLook.FACE_SLEEP || face == FriendLook.FACE_MISTY) {
            dc.drawLine(cx - s * 8 / 100, mouthY, cx + s * 8 / 100, mouthY);
        } else if (face == FriendLook.FACE_FAIR) {
            dc.drawArc(cx, mouthY - s * 14 / 100, s * 18 / 100,
                       Graphics.ARC_COUNTER_CLOCKWISE, 235, 305);
        } else if (face == FriendLook.FACE_SUNNY) {
            dc.drawArc(cx, mouthY - s * 16 / 100, s * 24 / 100,
                       Graphics.ARC_COUNTER_CLOCKWISE, 220, 320);
        } else {
            // Open, laughing mouth: a disc with its top half painted back out.
            var mouth = s * 17 / 100;
            if (face == FriendLook.FACE_EFFORT && (frame % 4) >= 2) {
                mouth = s * 13 / 100;
            }
            dc.fillCircle(cx, mouthY - s * 4 / 100, mouth);
            dc.setColor(bodyColor(), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - mouth - 1, mouthY - s * 4 / 100 - mouth - 1,
                             mouth * 2 + 2, mouth + 1);
            dc.setColor(BLUSH, Graphics.COLOR_TRANSPARENT);
            dc.fillEllipse(cx, mouthY - s * 4 / 100 + mouth * 70 / 100,
                           mouth * 55 / 100, mouth * 30 / 100);
        }
        if (mStage == FriendLook.STAGE_ADULT && mForm == FriendLook.FORM_WILD &&
            face != FriendLook.FACE_SLEEP) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx + s * 6 / 100, mouthY + s * 1 / 100],
                            [cx + s * 14 / 100, mouthY + s * 1 / 100],
                            [cx + s * 10 / 100, mouthY + s * 11 / 100]]);
        }

        if (face == FriendLook.FACE_EFFORT) {
            // One sweat drop that slides down the side of the head.
            var dropX = cx + a * 78 / 100;
            var dropY = cy - b * 62 / 100 + s * 6 * (frame % 4) / 100;
            var drop = s * 8 / 100;
            dc.setColor(0x7FD4FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(dropX, dropY, drop);
            dc.fillPolygon([[dropX - drop, dropY], [dropX, dropY - drop * 24 / 10],
                            [dropX + drop, dropY]]);
        }
    }

    function drawZ(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                   s as Lang.Number, frame as Lang.Number) as Void {
        var rise = s * (frame % 12) / 12;
        dc.setColor(0x9FB4C8, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + s * 14 / 100, y - rise / 2, Graphics.FONT_XTINY, "z",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(x + s * 44 / 100, y - s * 36 / 100 - rise / 2, Graphics.FONT_TINY, "Z",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // crack 0 is a whole egg; 1 to 3 is a growing crack. The egg rocks as it waits.
    function drawEgg(dc as Graphics.Dc, centerX as Lang.Number, cy as Lang.Number,
                     s as Lang.Number, crack as Lang.Number) as Void {
        var rock = mBob[mFrame % 12];
        var cx = centerX + s * rock * 3 / 100;
        var a = s * 82 / 100;
        var b = s * 108 / 100;
        drawShadow(dc, cx, cy + b, s, s);
        dc.setColor(SHELL, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, cy, a, b);
        dc.fillEllipse(cx, cy + b * 18 / 100, a * 106 / 100, b * 82 / 100);
        dc.setColor(bodyColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - a * 38 / 100, cy - b * 30 / 100, s * 14 / 100);
        dc.fillCircle(cx + a * 44 / 100, cy + b * 6 / 100, s * 18 / 100);
        dc.fillCircle(cx - a * 20 / 100, cy + b * 52 / 100, s * 16 / 100);
        dc.fillCircle(cx + a * 16 / 100, cy - b * 62 / 100, s * 9 / 100);
        dc.setColor(bellyColor(), Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx - a * 46 / 100, cy - b * 58 / 100, s * 12 / 100, s * 7 / 100);
        if (crack > 0) {
            dc.setColor(INK, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            var y = cy - b * 10 / 100;
            var step = a * 30 / 100;
            var x = cx - step * crack;
            var tooth = s * 12 / 100;
            for (var i = 0; i < crack * 2; i += 1) {
                var dy = tooth;
                if ((i % 2) == 1) {
                    dy = -tooth;
                }
                dc.drawLine(x, y, x + step, y + dy);
                x = x + step;
                y = y + dy;
            }
        }
    }

    // ---- small shared icons ------------------------------------------------
    function drawFlame(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                       size as Lang.Number, lit as Lang.Boolean) as Void {
        var outer = FLAME_OUT;
        var inner = FLAME_IN;
        if (!lit) {
            outer = 0x3A2A20;
            inner = 0x3A2A20;
        }
        dc.setColor(outer, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x - size * 50 / 100, y + size * 30 / 100],
                        [x - size * 46 / 100, y - size * 10 / 100],
                        [x - size * 10 / 100, y - size],
                        [x + size * 8 / 100, y - size * 40 / 100],
                        [x + size * 34 / 100, y - size * 62 / 100],
                        [x + size * 50 / 100, y + size * 26 / 100],
                        [x, y + size * 60 / 100]]);
        dc.setColor(inner, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x - size * 22 / 100, y + size * 30 / 100],
                        [x, y - size * 24 / 100],
                        [x + size * 22 / 100, y + size * 30 / 100],
                        [x, y + size * 52 / 100]]);
    }

    // A drawn heart, so it never depends on a font having the glyph.
    function drawHeart(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                       size as Lang.Number) as Void {
        dc.setColor(0xFF6B6B, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - size / 2, y - size / 3, size / 2 + 1);
        dc.fillCircle(x + size / 2, y - size / 3, size / 2 + 1);
        dc.fillPolygon([[x - size - 1, y - size / 4], [x + size + 1, y - size / 4],
                        [x, y + size]]);
    }

    function drawSparkle(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                         size as Lang.Number, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var thin = size * 28 / 100;
        if (thin < 1) {
            thin = 1;
        }
        dc.fillPolygon([[x, y - size], [x + thin, y - thin], [x + size, y],
                        [x + thin, y + thin], [x, y + size], [x - thin, y + thin],
                        [x - size, y], [x - thin, y - thin]]);
    }

    function drawShield(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                        size as Lang.Number, lit as Lang.Boolean) as Void {
        var color = 0x6EC1FF;
        if (!lit) {
            color = 0x26323C;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x - size, y - size], [x + size, y - size],
                        [x + size, y + size * 20 / 100], [x, y + size + size * 30 / 100],
                        [x - size, y + size * 20 / 100]]);
    }

    // Sky by mood weather (0 misty to 3 radiant); night swaps the sun for a moon.
    function drawSky(dc as Graphics.Dc, w as Lang.Number, h as Lang.Number,
                     weather as Lang.Number, night as Lang.Boolean,
                     frame as Lang.Number) as Void {
        var sunX = w * 22 / 100;
        var sunY = h * 21 / 100;
        var sunR = h * 40 / 1000;
        if (night) {
            dc.setColor(0xDCE6F2, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sunX, sunY, sunR);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sunX + sunR * 45 / 100, sunY - sunR * 25 / 100, sunR);
            var twinkle = frame % 12;
            drawSparkle(dc, w * 80 / 100, h * 17 / 100, 4 + ((twinkle < 4) ? 1 : 0), 0xDCE6F2);
            drawSparkle(dc, w * 73 / 100, h * 27 / 100, 3 + ((twinkle >= 8) ? 1 : 0), 0x9FB4C8);
        } else if (weather >= 2) {
            dc.setColor(0xF2D550, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sunX, sunY, sunR);
            dc.setPenWidth(3);
            var near = sunR + 5;
            var far = sunR + 11 + (((frame % 6) < 3) ? 2 : 0);
            var diag = near * 71 / 100;
            var diagFar = far * 71 / 100;
            dc.drawLine(sunX - far, sunY, sunX - near, sunY);
            dc.drawLine(sunX + near, sunY, sunX + far, sunY);
            dc.drawLine(sunX, sunY - far, sunX, sunY - near);
            dc.drawLine(sunX, sunY + near, sunX, sunY + far);
            dc.drawLine(sunX - diagFar, sunY - diagFar, sunX - diag, sunY - diag);
            dc.drawLine(sunX + diag, sunY - diag, sunX + diagFar, sunY - diagFar);
            dc.drawLine(sunX - diagFar, sunY + diagFar, sunX - diag, sunY + diag);
            dc.drawLine(sunX + diag, sunY + diag, sunX + diagFar, sunY + diagFar);
            if (weather >= 3) {
                var twinkle = frame % 12;
                drawSparkle(dc, w * 79 / 100, h * 18 / 100, 5 + ((twinkle < 4) ? 2 : 0), 0xFFF3B8);
                drawSparkle(dc, w * 85 / 100, h * 31 / 100, 4 + ((twinkle >= 6) ? 2 : 0), 0xFFF3B8);
                drawSparkle(dc, w * 14 / 100, h * 36 / 100,
                            3 + ((twinkle >= 3 && twinkle < 8) ? 2 : 0), 0xFFF3B8);
            }
        }
        if (weather == 1 && !night) {
            drawCloud(dc, w * 24 / 100, h * 22 / 100, h * 30 / 1000, 0x8FA6BC);
        }
        if (weather == 0 || (weather == 1 && !night)) {
            var drift = frame % 24;
            if (drift > 12) {
                drift = 24 - drift;
            }
            var color = 0x6F8496;
            if (weather == 0) {
                color = 0x55636F;
            }
            drawCloud(dc, w * 77 / 100 + drift, h * 21 / 100, h * 34 / 1000, color);
        }
        if (weather == 0) {
            dc.setColor(0x3A444C, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(w * 9 / 100, h * 38 / 100, w * 16 / 100, 6, 3);
            dc.fillRoundedRectangle(w * 76 / 100, h * 34 / 100, w * 15 / 100, 6, 3);
            dc.fillRoundedRectangle(w * 13 / 100, h * 45 / 100, w * 11 / 100, 6, 3);
        }
    }

    function drawCloud(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number,
                       r as Lang.Number, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - r, y + r * 30 / 100, r * 80 / 100);
        dc.fillCircle(x, y - r * 20 / 100, r);
        dc.fillCircle(x + r, y + r * 30 / 100, r * 80 / 100);
        dc.fillRectangle(x - r, y + r * 30 / 100, r * 2, r * 80 / 100);
    }
}
