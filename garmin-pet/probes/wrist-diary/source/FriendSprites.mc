using Toybox.Graphics;
using Toybox.Lang;

// The friend from its baked sprite strips (scripts/bake_friend_sprites.py,
// FriendSpriteTable.mc). All the art work is done on the PC: the colorway, the
// size, the cutout and every anchor are baked, so the watch loads one strip
// for the character it is showing and copies one rectangle of it per frame
// with setClip + drawBitmap. Nothing is scaled, tinted or blended here.
//
// The poses are painted without a face. The face is a second, small strip
// (one per character, the same for every colorway) copied over the point
// between the pose's eyes, so any pose can wear any face.
//
// One FriendSprites holds one size (home or card) and keeps its strips until
// the character or the colorway changes. scripts/friend_preview.py mirrors
// this class; `python scripts/friend_preview.py --check` compares the two.
class FriendSprites {
    const SLOT_IDLE = 0;
    const SLOT_BREATHE = 1;
    const SLOT_DROOP = 2;
    const SLOT_BACK = 3;
    const SLOT_CROUCH = 4;
    const SLOT_HOP = 5;
    const SLOT_CHEER = 6;
    const SLOT_FLEX = 7;
    const SLOT_RUN_A = 8;
    const SLOT_RUN_B = 9;
    const SLOT_EFFORT = 10;
    const SLOT_ASLEEP = 11;

    // The faces of a face strip, in sheet order. The two glances and the
    // surprised face that follow them are baked and not used yet.
    const LOOK_FAIR = 0;
    const LOOK_BLINK = 1;
    const LOOK_SUNNY = 2;
    const LOOK_RADIANT = 3;
    const LOOK_MISTY = 4;
    const LOOK_EFFORT = 5;
    const LOOK_SHOUT = 6;
    const LOOK_PROUD = 7;
    const LOOK_ASLEEP = 8;

    var mSmall as Lang.Boolean;
    var mStrip as Graphics.BitmapType?;
    var mStripKey as Lang.Number = -1;
    var mPet as Lang.Number = -1;
    var mCells as Lang.Array<Lang.Number> = [] as Lang.Array<Lang.Number>;
    var mFaces as Graphics.BitmapType?;
    var mFaceKey as Lang.Number = -1;
    var mFaceTiles as Lang.Array<Lang.Number>;
    var mEmblem as Graphics.BitmapType?;
    var mEmblemKey as Lang.Number = -1;

    function initialize(small as Lang.Boolean) {
        mSmall = small;
        mFaceTiles = friendFaceTiles(small);
    }

    // Which character a look is, or -1 when it has no sheet yet (the egg).
    // Every grown tier of a lane shows that lane's first grown form for now.
    function petFor(stage as Lang.Number, form as Lang.Number) as Lang.Number {
        if (stage == FriendLook.STAGE_BABY) { return 0; }
        if (stage == FriendLook.STAGE_CHILD) { return 1; }
        if (stage == FriendLook.STAGE_ADULT) { return 2 + form; }
        return -1;
    }

    // The pose a face, an action and an animation frame come to.
    function slotFor(face as Lang.Number, pose as Lang.Number,
                     frame as Lang.Number) as Lang.Number {
        if (pose == FriendLook.POSE_SLEEP) { return SLOT_ASLEEP; }
        if (pose == FriendLook.POSE_RUN) {
            return ((frame % 4) < 2) ? SLOT_RUN_A : SLOT_RUN_B;
        }
        if (pose == FriendLook.POSE_HOP) {
            var beat = frame % 8;
            return (beat == 0 || beat >= 6) ? SLOT_CROUCH : SLOT_HOP;
        }
        if (pose == FriendLook.POSE_FLEX) {
            return ((frame % 4) < 2) ? SLOT_CHEER : SLOT_FLEX;
        }
        if (pose == FriendLook.POSE_SPIN) {
            return ((frame % 4) < 2) ? SLOT_IDLE : SLOT_BACK;
        }
        if (pose == FriendLook.POSE_FLAMES || face == FriendLook.FACE_EFFORT) {
            return SLOT_EFFORT;
        }
        if (face == FriendLook.FACE_MISTY) { return SLOT_DROOP; }
        return ((frame % 12) < 6) ? SLOT_IDLE : SLOT_BREATHE;
    }

    // The face a mood, an action and an animation frame come to. Only the
    // open-eyed faces blink.
    function lookFor(face as Lang.Number, pose as Lang.Number,
                     frame as Lang.Number) as Lang.Number {
        if (pose == FriendLook.POSE_SLEEP || face == FriendLook.FACE_SLEEP) {
            return LOOK_ASLEEP;
        }
        if (pose == FriendLook.POSE_FLAMES || face == FriendLook.FACE_EFFORT) {
            return LOOK_EFFORT;
        }
        if (pose == FriendLook.POSE_FLEX) { return LOOK_PROUD; }
        if (face == FriendLook.FACE_JOY) {
            return (pose == FriendLook.POSE_HOP) ? LOOK_SHOUT : LOOK_RADIANT;
        }
        if (face == FriendLook.FACE_MISTY) { return LOOK_MISTY; }
        if (face == FriendLook.FACE_RADIANT) { return LOOK_RADIANT; }
        if ((frame % 23) == 22) { return LOOK_BLINK; }
        if (face == FriendLook.FACE_SUNNY) { return LOOK_SUNNY; }
        return LOOK_FAIR;
    }

    // True when the strips for this character and colorway are loaded: its
    // poses and its faces. Strips the watch refuses are asked for once, not
    // every frame.
    function ready(pet as Lang.Number, pal as Lang.Number) as Lang.Boolean {
        if (pet < 0 || pet >= FRIEND_PETS) { return false; }
        var key = pet * FriendLook.PALETTE_COUNT + pal;
        if (key != mStripKey) {
            var bmp = null;
            try {
                bmp = loadFriendStrip(pet, pal, mSmall);
            } catch (ex) {
                bmp = null;
            }
            mStrip = bmp;
            mStripKey = key;
            mPet = pet;
            mCells = friendCells(pet, mSmall);
        }
        if (pet != mFaceKey) {
            var faces = null;
            try {
                faces = loadFriendFace(pet);
            } catch (ex) {
                faces = null;
            }
            mFaces = faces;
            mFaceKey = pet;
        }
        return mStrip != null && mFaces != null &&
               mCells.size() >= FRIEND_SLOTS * FRIEND_SLOT_FIELDS;
    }

    // Half the height of the standing pose: the sprite's stand-in for the
    // drawn friend's body radius.
    function unit() as Lang.Number {
        if (mPet < 0) { return 0; }
        return friendHeights(mSmall)[mPet] / 2;
    }

    // One pose, its feet centered on footX and standing on footY.
    function draw(dc as Graphics.Dc, footX as Lang.Number, footY as Lang.Number,
                  slot as Lang.Number) as Void {
        var strip = mStrip;
        if (strip == null) { return; }
        var i = slot * FRIEND_SLOT_FIELDS;
        var w = mCells[i + 2];
        var h = mCells[i + 3];
        var left = footX - mCells[i + 4];
        var top = footY - h;
        dc.setClip(left, top, w, h);
        dc.drawBitmap(left - mCells[i], top - mCells[i + 1], strip);
        dc.clearClip();
    }

    // A face (LOOK_*) on the same pose. The back view has no face.
    function drawFace(dc as Graphics.Dc, footX as Lang.Number, footY as Lang.Number,
                      slot as Lang.Number, look as Lang.Number) as Void {
        var faces = mFaces;
        if (faces == null) { return; }
        var i = slot * FRIEND_SLOT_FIELDS;
        if (mCells[i + 7] < 0) { return; }
        var t = mPet * FRIEND_FACE_FIELDS;
        var w = mFaceTiles[t];
        var h = mFaceTiles[t + 1];
        var left = footX - mCells[i + 4] + mCells[i + 7] - mFaceTiles[t + 2];
        var top = footY - mCells[i + 3] + mCells[i + 8] - mFaceTiles[t + 3];
        dc.setClip(left, top, w, h);
        dc.drawBitmap(left - (look % FRIEND_FACE_COLS) * w,
                      top - mFaceTiles[t + 4] - (look / FRIEND_FACE_COLS) * h, faces);
        dc.clearClip();
    }

    // The belly emblem (1 to FRIEND_EMBLEMS; 0 is a bare belly) over the same
    // pose, at a brightness level. Poses that hide the belly have no anchor.
    function drawEmblem(dc as Graphics.Dc, footX as Lang.Number, footY as Lang.Number,
                        slot as Lang.Number, pal as Lang.Number, emblem as Lang.Number,
                        level as Lang.Number) as Void {
        if (emblem < 1 || emblem > FRIEND_EMBLEMS) { return; }
        var i = slot * FRIEND_SLOT_FIELDS;
        if (mCells[i + 5] < 0) { return; }
        if (emblem != mEmblemKey) {
            var loaded = null;
            try {
                loaded = loadFriendEmblem(emblem);
            } catch (ex) {
                loaded = null;
            }
            mEmblem = loaded;
            mEmblemKey = emblem;
        }
        var bmp = mEmblem;
        if (bmp == null) { return; }
        var tile = FRIEND_EMBLEM_TILE;
        var row = level * tile;
        if (mSmall) {
            tile = FRIEND_EMBLEM_TILE_SMALL;
            row = FRIEND_EMBLEM_LEVELS * FRIEND_EMBLEM_TILE + level * tile;
        }
        var left = footX - mCells[i + 4] + mCells[i + 5] - tile / 2;
        var top = footY - mCells[i + 3] + mCells[i + 6] - tile / 2;
        dc.setClip(left, top, tile, tile);
        dc.drawBitmap(left - pal * tile, top - row, bmp);
        dc.clearClip();
    }
}
