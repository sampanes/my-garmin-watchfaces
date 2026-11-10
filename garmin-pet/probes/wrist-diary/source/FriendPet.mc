using Toybox.Application;
using Toybox.Lang;
using Toybox.Math;
using Toybox.System;

// The pet's saved state and effort economy: garmin-pet/12-pet-state-and-economy.md.
// scripts/pet-model.ps1 is the host model of the same rules, and
// scripts/test-friend-pet.ps1 holds this file's integer math against it.
// Everything is settled from timestamps when Friend opens or a chapter closes:
// nothing ticks, and staying away never costs anything.
class FriendPet {
    const VERSION = 1;
    const SIZE = 32;
    const MAX_CHAPTERS = 60;    // WristDiaryView's chapter3 ring.

    // The whole pet is one array of numbers under the Storage key "pet".
    const P_V = 0;
    const P_BORN = 1;
    const P_TZ = 2;
    const P_MOOD = 3;
    const P_TS_SETTLE = 4;
    const P_TS_OPEN = 5;
    const P_XP = 6;
    const P_EVOS = 7;
    const P_TS_EVO = 8;
    const P_WARM = 9;
    const P_SHIELDS = 10;
    const P_LAST_ACTIVE_DAY = 11;
    const P_ACTIVE_DAYS = 12;
    const P_DAY_IDX = 13;
    const P_DAY_MIN = 14;       // Today's effort minutes x100.
    const P_DAY_BONUS = 15;
    const P_REUNION_OWED = 16;
    const P_LAST_CH_END = 17;
    const P_CH_TOTAL = 18;
    const P_CARE_DAY = 19;
    const P_CARE_MASK = 20;
    const P_PAL = 21;           // Layer A: birth colorway.
    const P_PERSONA = 22;       // Layer A: voice.
    const P_FORM = 23;          // Layer A: the branch kept at the last evolution.
    const P_EVO_HIST = 24;      // Every branch picked, two bits each, oldest lowest.
    const P_WALK_M = 25;
    const P_WALK_COUNT = 26;
    const P_OWED_POINTS = 27;   // A reward earned but not yet shown.
    const P_OWED_BAND = 28;
    const P_OWED_FLAMES = 29;   // 0 marks the hatch reward.
    const P_OWED_SECONDS = 30;
    const P_OWED_FLAGS = 31;    // 1 daily-first bonus, 2 reunion bonus.

    // Every number below is PROPOSED in doc 12 and mirrored in $PetConfig.
    const DAY_START_HOUR = 3;
    const MOOD_FLOOR = 35;
    const MOOD_MAX = 100;
    const MOOD_START = 60;
    const MOOD_PAUSE = 172800;
    const REUNION_GAP = 172800;
    const REUNION_MOOD = 70;
    const MOOD_TARGET_BASE = 40;
    const CHAPTER_MOOD_BUMP = 15;
    const CARE_MOOD_BUMP = 5;
    const FIRST_BONUS = 10;
    const REUNION_BONUS = 10;
    const BONUS_MIN_MINUTES = 5;
    const TAPER_FULL = 3000;    // Effort minutes x100.
    const TAPER_HALF = 6000;
    const HARD_DELTA = 30;
    const STEADY_DELTA = 15;
    const WARM_START = 20;
    const WARM_FLOOR = 20;
    const WARM_MAX = 100;
    const WARM_GAIN = 15;
    const COMEBACK_GAIN = 25;
    const COMEBACK_GAP_DAYS = 3;
    const WARM_DECAY = 8;
    const GRACE_DAYS = 1;
    const SHIELD_EVERY = 5;
    const SHIELD_MAX = 2;
    const EVO_EVERY = 3;
    const FIRST_EVO_AGE = 604800;       // 7 days.
    const LATER_EVO_GAP = 2592000;      // 30 days.

    var mS as Lang.Array<Lang.Number>;
    var mAlive as Lang.Boolean = false;
    var mLocked as Lang.Boolean = false;

    function initialize() {
        mS = blank();
        load();
    }

    function blank() as Lang.Array<Lang.Number> {
        var s = [] as Lang.Array<Lang.Number>;
        for (var i = 0; i < SIZE; i += 1) { s.add(0); }
        return s;
    }

    // A field a newer build added reads as 0 here. A save written by a newer
    // schema is used but never written back, so an old build cannot damage it.
    function load() as Void {
        var value = Application.Storage.getValue("pet");
        if (!(value instanceof Lang.Array)) { return; }
        var stored = value as Lang.Array<Lang.Number>;
        if (stored.size() < 1) { return; }
        for (var i = 0; i < SIZE && i < stored.size(); i += 1) {
            mS[i] = stored[i];
        }
        mAlive = true;
        mLocked = (mS[P_V] > VERSION);
    }

    function save() as Void {
        if (!mAlive || mLocked) { return; }
        try {
            Application.Storage.setValue("pet", mS as Application.Storage.ValueType);
        } catch (e) {
            System.println("FRIEND_PET_SAVE_ERROR," + e.getErrorMessage());
        }
    }

    function exists() as Lang.Boolean { return mAlive; }
    function xp() as Lang.Number { return mS[P_XP]; }
    function evos() as Lang.Number { return mS[P_EVOS]; }
    function palette() as Lang.Number { return mS[P_PAL]; }
    function persona() as Lang.Number { return mS[P_PERSONA]; }
    function form() as Lang.Number { return mS[P_FORM]; }
    function shields(now as Lang.Number) as Lang.Number { return momentum(dayOf(now, mS[P_TZ]))[1]; }
    function warmth(now as Lang.Number) as Lang.Number { return momentum(dayOf(now, mS[P_TZ]))[0]; }
    function memories() as Lang.Number { return mS[P_CH_TOTAL]; }
    function reunionOwed() as Lang.Boolean { return mS[P_REUNION_OWED] == 1; }
    function trailMeters() as Lang.Number { return mS[P_WALK_M]; }
    function trailWalks() as Lang.Number { return mS[P_WALK_COUNT]; }
    function owedPoints() as Lang.Number { return mS[P_OWED_POINTS]; }
    function owedBand() as Lang.Number { return mS[P_OWED_BAND]; }
    function owedFlames() as Lang.Number { return mS[P_OWED_FLAMES]; }
    function owedSeconds() as Lang.Number { return mS[P_OWED_SECONDS]; }
    function owedFlags() as Lang.Number { return mS[P_OWED_FLAGS]; }

    function ageDays(now as Lang.Number) as Lang.Number {
        var age = (now - mS[P_BORN]) / 86400;
        return (age < 0) ? 1 : (age + 1);
    }

    function offsetNow() as Lang.Number {
        return System.getClockTime().timeZoneOffset;
    }

    // A local day runs 03:00 to 03:00, so a late session belongs to its evening.
    function dayOf(epoch as Lang.Number, offset as Lang.Number) as Lang.Number {
        return (epoch + offset - DAY_START_HOUR * 3600) / 86400;
    }

    // ------------------------------------------------------------ momentum
    // [warmth, shields, missed days] as of a local day. Warmth and shields are
    // stored as of the last active day; reading them never changes state.
    function momentum(today as Lang.Number) as Lang.Array<Lang.Number> {
        var warm = mS[P_WARM];
        if (warm < WARM_FLOOR) { warm = WARM_FLOOR; }
        var last = mS[P_LAST_ACTIVE_DAY];
        if (last < 0 || today <= last) {
            return [warm, mS[P_SHIELDS], 0] as Lang.Array<Lang.Number>;
        }
        var missed = today - last - 1;
        var billable = missed - GRACE_DAYS;
        if (billable < 0) { billable = 0; }
        var spend = mS[P_SHIELDS];
        if (spend > billable) { spend = billable; }
        warm = mS[P_WARM] - WARM_DECAY * (billable - spend);
        if (warm < WARM_FLOOR) { warm = WARM_FLOOR; }
        return [warm, mS[P_SHIELDS] - spend, missed] as Lang.Array<Lang.Number>;
    }

    // The first credited chapter of a local day warms the pet; later ones do not.
    function noteActiveDay(today as Lang.Number) as Void {
        var last = mS[P_LAST_ACTIVE_DAY];
        if (last >= 0 && today <= last) { return; }
        var current = momentum(today);
        var gain = WARM_GAIN;
        if (last >= 0 && current[2] >= COMEBACK_GAP_DAYS) { gain = COMEBACK_GAIN; }
        var warm = current[0] + gain;
        if (warm > WARM_MAX) { warm = WARM_MAX; }
        mS[P_WARM] = warm;
        mS[P_SHIELDS] = current[1];
        mS[P_ACTIVE_DAYS] = mS[P_ACTIVE_DAYS] + 1;
        if ((mS[P_ACTIVE_DAYS] % SHIELD_EVERY) == 0 && mS[P_SHIELDS] < SHIELD_MAX) {
            mS[P_SHIELDS] = mS[P_SHIELDS] + 1;
        }
        mS[P_LAST_ACTIVE_DAY] = today;
    }

    // ---------------------------------------------------------------- mood
    // Mood is weather. [mood, mood before a reunion lift, 1 if this is a reunion].
    // It drifts toward a calm middle with a 24 h half-life, stops drifting after
    // 48 h away, and never goes below the floor.
    function moodAt(now as Lang.Number) as Lang.Array<Lang.Number> {
        var elapsed = now - mS[P_TS_SETTLE];
        if (elapsed < 0) { elapsed = 0; }
        if (elapsed > MOOD_PAUSE) { elapsed = MOOD_PAUSE; }
        var warm = momentum(dayOf(now, mS[P_TZ]))[0];
        var target = MOOD_TARGET_BASE + warm.toFloat() / 5.0;
        var start = mS[P_MOOD];
        if (start < MOOD_FLOOR) { start = MOOD_FLOOR; }
        if (start > MOOD_MAX) { start = MOOD_MAX; }
        var factor = Math.pow(0.5, elapsed.toFloat() / 86400.0).toFloat();
        var raw = target + (start.toFloat() - target) * factor;
        if (raw < MOOD_FLOOR) { raw = MOOD_FLOOR.toFloat(); }
        if (raw > MOOD_MAX) { raw = MOOD_MAX.toFloat(); }
        var rawMood = (raw + 0.5).toNumber();
        var mood = rawMood;
        var away = now - mS[P_TS_OPEN];
        var reunion = (away >= REUNION_GAP) ? 1 : 0;
        if (reunion == 1 && mood < REUNION_MOOD) { mood = REUNION_MOOD; }
        return [mood, rawMood, reunion] as Lang.Array<Lang.Number>;
    }

    function moodNow(now as Lang.Number) as Lang.Number {
        return moodAt(now)[0];
    }

    // 0 misty, 1 fair, 2 sunny, 3 radiant. None of them is a bad state.
    function weather(mood as Lang.Number) as Lang.Number {
        if (mood >= 85) { return 3; }
        if (mood >= 70) { return 2; }
        if (mood >= 50) { return 1; }
        return 0;
    }

    // Settles mood on a visit. True when the visit is a reunion (48 h or more away).
    function open(now as Lang.Number) as Lang.Boolean {
        if (!mAlive) { return false; }
        mS[P_TZ] = offsetNow();
        var settled = moodAt(now);
        mS[P_MOOD] = settled[0];
        if (now > mS[P_TS_SETTLE]) { mS[P_TS_SETTLE] = now; }
        if (now > mS[P_TS_OPEN]) { mS[P_TS_OPEN] = now; }
        if (settled[2] == 1) { mS[P_REUNION_OWED] = 1; }
        save();
        return settled[2] == 1;
    }

    // ------------------------------------------------------- effort credit
    // 100 easy, 125 steady, 150 hard: this chapter's heart rate against the
    // wearer's own four-hour baseline. Missing heart rate is easy, never zero.
    function effortLevel(baseline as Lang.Number, hrAvg as Lang.Number) as Lang.Number {
        if (hrAvg < 0 || baseline < 0) { return 100; }
        var delta = hrAvg - baseline;
        if (delta >= HARD_DELTA) { return 150; }
        if (delta >= STEADY_DELTA) { return 125; }
        return 100;
    }

    function flameCount(level as Lang.Number) as Lang.Number {
        if (level >= 150) { return 3; }
        if (level >= 125) { return 2; }
        return 1;
    }

    function overlap(before as Lang.Number, after as Lang.Number,
                     low as Lang.Number, high as Lang.Number) as Lang.Number {
        var a = (before > low) ? before : low;
        var b = (after < high) ? after : high;
        return (b > a) ? (b - a) : 0;
    }

    // Points x100 for a day's running total moving from one value to another
    // (effort minutes x100): the first 30 at full rate, the next 30 at half,
    // everything after at a quarter. Never zero.
    function taperedCenti(before as Lang.Number, after as Lang.Number) as Lang.Number {
        return overlap(before, after, 0, TAPER_FULL) +
               overlap(before, after, TAPER_FULL, TAPER_HALF) / 2 +
               overlap(before, after, TAPER_HALF, 2000000000) / 4;
    }

    // What a chapter earns, without changing anything:
    // [points, level x100, bonus, 1 if the reunion bonus is in it, local day,
    //  the day's effort minutes x100 afterward, 1 once the daily-first bonus is paid].
    // Nothing the pet owns or feels is an input: momentum never multiplies effort.
    function creditFor(startEpoch as Lang.Number, durationS as Lang.Number,
                       baseline as Lang.Number,
                       hrAvg as Lang.Number) as Lang.Array<Lang.Number> {
        var day = dayOf(startEpoch, mS[P_TZ]);
        var before = 0;
        var bonusPaid = 0;
        if (mS[P_DAY_IDX] == day) {
            before = mS[P_DAY_MIN];
            bonusPaid = mS[P_DAY_BONUS];
        }
        var level = effortLevel(baseline, hrAvg);
        var seconds = (durationS < 0) ? 0 : durationS;
        var minutes = seconds * level / 60;
        var centi = taperedCenti(before, before + minutes);
        var bonus = 0;
        var reunionUsed = 0;
        if (bonusPaid == 0 && minutes >= BONUS_MIN_MINUTES * 100) {
            bonus = FIRST_BONUS;
            if (mS[P_REUNION_OWED] == 1) {
                bonus += REUNION_BONUS;
                reunionUsed = 1;
            }
            bonusPaid = 1;
        }
        var points = (centi + bonus * 100 + 50) / 100;
        if (points < 1) { points = 1; }
        return [points, level, bonus, reunionUsed, day, before + minutes,
                bonusPaid] as Lang.Array<Lang.Number>;
    }

    // Applies one finished chapter. The watermark makes it safe to offer the
    // same chapter twice. Returns the points earned, 0 for a repeat.
    function creditChapter(startEpoch as Lang.Number, endEpoch as Lang.Number,
                           durationS as Lang.Number, baseline as Lang.Number,
                           hrAvg as Lang.Number, persist as Lang.Boolean) as Lang.Number {
        if (!mAlive || endEpoch <= mS[P_LAST_CH_END]) { return 0; }
        var bandBefore = band();
        var settled = moodAt(endEpoch);
        var mood = settled[1] + CHAPTER_MOOD_BUMP;
        if (mood > MOOD_MAX) { mood = MOOD_MAX; }
        mS[P_MOOD] = mood;
        if (endEpoch > mS[P_TS_SETTLE]) { mS[P_TS_SETTLE] = endEpoch; }

        var credit = creditFor(startEpoch, durationS, baseline, hrAvg);
        mS[P_XP] = mS[P_XP] + credit[0];
        mS[P_DAY_IDX] = credit[4];
        mS[P_DAY_MIN] = credit[5];
        mS[P_DAY_BONUS] = credit[6];
        if (credit[3] == 1) { mS[P_REUNION_OWED] = 0; }
        noteActiveDay(credit[4]);
        mS[P_LAST_CH_END] = endEpoch;
        mS[P_CH_TOTAL] = mS[P_CH_TOTAL] + 1;

        // The reward card shows everything earned since the last one was seen.
        if (mS[P_OWED_POINTS] == 0) {
            mS[P_OWED_BAND] = bandBefore;
            mS[P_OWED_FLAMES] = 0;
            mS[P_OWED_SECONDS] = 0;
            mS[P_OWED_FLAGS] = 0;
        }
        mS[P_OWED_POINTS] = mS[P_OWED_POINTS] + credit[0];
        mS[P_OWED_SECONDS] = mS[P_OWED_SECONDS] + ((durationS < 0) ? 0 : durationS);
        var lit = flameCount(credit[1]);
        if (lit > mS[P_OWED_FLAMES]) { mS[P_OWED_FLAMES] = lit; }
        var flags = mS[P_OWED_FLAGS];
        if (credit[2] > 0 && (flags % 2) == 0) { flags += 1; }
        if (credit[3] == 1 && flags < 2) { flags += 2; }
        mS[P_OWED_FLAGS] = flags;

        if (persist) {
            System.println("FRIEND_XP," + endEpoch + "," + credit[0] + "," + credit[1] +
                           "," + credit[2] + "," + mS[P_XP] + "," + band());
            save();
        }
        return credit[0];
    }

    // Credits every stored chapter newer than the watermark, oldest first, and
    // saves once. Normally none: it catches a chapter whose credit was lost.
    function creditStored() as Lang.Number {
        var count = readNumber("chapter3_count", 0);
        var next = readNumber("chapter3_next", 0);
        if (count < 1) { return 0; }
        // The ring is in time order, so one read of its newest row usually
        // shows there is nothing to do.
        var newest = Application.Storage.getValue(
            "chapter3_" + ((next + MAX_CHAPTERS - 1) % MAX_CHAPTERS));
        if (newest instanceof Lang.Array) {
            var last = newest as Lang.Array<Lang.Number>;
            if (last.size() >= 2 && last[1] <= mS[P_LAST_CH_END]) { return 0; }
        }
        var start = next - count;
        while (start < 0) { start += MAX_CHAPTERS; }
        var credited = 0;
        for (var i = 0; i < count; i += 1) {
            var value = Application.Storage.getValue("chapter3_" + ((start + i) % MAX_CHAPTERS));
            if (!(value instanceof Lang.Array)) { continue; }
            var row = value as Lang.Array<Lang.Number>;
            if (row.size() < 7) { continue; }
            if (creditChapter(row[0], row[1], row[2], row[4], row[6], false) > 0) {
                credited += 1;
            }
        }
        if (credited > 0) { save(); }
        return credited;
    }

    function oldestStoredStart(fallback as Lang.Number) as Lang.Number {
        var count = readNumber("chapter3_count", 0);
        if (count < 1) { return fallback; }
        var start = readNumber("chapter3_next", 0) - count;
        while (start < 0) { start += MAX_CHAPTERS; }
        var value = Application.Storage.getValue("chapter3_" + start);
        if (!(value instanceof Lang.Array)) { return fallback; }
        var row = value as Lang.Array<Lang.Number>;
        if (row.size() < 1 || row[0] <= 0 || row[0] > fallback) { return fallback; }
        return row[0];
    }

    // The egg hatches. The pet was listening the whole time: it is born at the
    // oldest chapter Friend still holds, and every stored chapter is credited.
    // Returns how many chapters it remembered.
    function hatch(now as Lang.Number, color as Lang.Number,
                   voice as Lang.Number) as Lang.Number {
        mS = blank();
        var born = oldestStoredStart(now);
        mS[P_V] = VERSION;
        mS[P_BORN] = born;
        mS[P_TZ] = offsetNow();
        mS[P_MOOD] = MOOD_START;
        mS[P_TS_SETTLE] = born;
        mS[P_TS_OPEN] = born;
        mS[P_TS_EVO] = born;
        mS[P_WARM] = WARM_START;
        mS[P_LAST_ACTIVE_DAY] = -1;
        mS[P_DAY_IDX] = -1;
        mS[P_PAL] = color;
        mS[P_PERSONA] = voice;
        mAlive = true;
        mLocked = false;
        var remembered = creditStored();
        // Each remembered chapter was a visit, so hatching is not a reunion.
        if (mS[P_LAST_CH_END] > mS[P_TS_OPEN]) { mS[P_TS_OPEN] = mS[P_LAST_CH_END]; }
        mS[P_OWED_FLAMES] = 0;
        System.println("FRIEND_HATCH," + remembered + "," + mS[P_XP] + "," + band());
        open(now);
        return remembered;
    }

    function clearOwed() as Void {
        if (mS[P_OWED_POINTS] == 0) { return; }
        mS[P_OWED_POINTS] = 0;
        mS[P_OWED_BAND] = 0;
        mS[P_OWED_FLAMES] = 0;
        mS[P_OWED_SECONDS] = 0;
        mS[P_OWED_FLAGS] = 0;
        save();
    }

    // -------------------------------------------------------------- stages
    function bandThreshold(index as Lang.Number) as Lang.Number {
        if (index <= 0) { return 0; }
        if (index <= 9) { return 60 * index * index + 40 * index; }
        return 5220 + (index - 9) * 1100;
    }

    function xpBand() as Lang.Number {
        var reached = 0;
        while (bandThreshold(reached + 1) <= mS[P_XP]) { reached += 1; }
        return reached;
    }

    // The band the pet shows. Every third band is an evolution, and the pet
    // waits one band below it until the wearer has chosen who it becomes.
    function band() as Lang.Number {
        var reached = xpBand();
        var gate = EVO_EVERY * (mS[P_EVOS] + 1);
        return (reached >= gate) ? (gate - 1) : reached;
    }

    // Enough effort banked and old enough: 7 days for the first evolution,
    // 30 days after the previous one for each later one. It never expires.
    function evoReady(now as Lang.Number) as Lang.Boolean {
        if (!mAlive || xpBand() < EVO_EVERY * (mS[P_EVOS] + 1)) { return false; }
        if (mS[P_EVOS] == 0) { return (now - mS[P_BORN]) >= FIRST_EVO_AGE; }
        return (now - mS[P_TS_EVO]) >= LATER_EVO_GAP;
    }

    // The deliberate, permanent choice. Confirming opens every band the banked
    // effort already covers.
    function evolve(now as Lang.Number, picked as Lang.Number) as Lang.Boolean {
        if (!evoReady(now)) { return false; }
        var shift = 1;
        for (var i = 0; i < mS[P_EVOS] && i < 14; i += 1) { shift *= 4; }
        mS[P_EVO_HIST] = mS[P_EVO_HIST] + picked * shift;
        mS[P_EVOS] = mS[P_EVOS] + 1;
        mS[P_TS_EVO] = now;
        mS[P_FORM] = picked;
        System.println("FRIEND_EVOLVE," + mS[P_EVOS] + "," + picked + "," + band());
        save();
        return true;
    }

    // Dogfood escape hatch: the colorway and voice can be picked again.
    function setLook(color as Lang.Number, voice as Lang.Number) as Void {
        mS[P_PAL] = color;
        mS[P_PERSONA] = voice;
        save();
    }

    // ------------------------------------------------------- small readouts
    // Today's effort minutes: the pet's snack. Resets at the 03:00 day start.
    function dayMinutes(now as Lang.Number) as Lang.Number {
        if (mS[P_DAY_IDX] != dayOf(now, mS[P_TZ])) { return 0; }
        return mS[P_DAY_MIN] / 100;
    }

    // Petting is the one care action: +5 mood, once a day, never owed.
    function petted(now as Lang.Number) as Lang.Boolean {
        if (!mAlive) { return false; }
        var day = dayOf(now, mS[P_TZ]);
        if (mS[P_CARE_DAY] != day) {
            mS[P_CARE_DAY] = day;
            mS[P_CARE_MASK] = 0;
        }
        if ((mS[P_CARE_MASK] % 2) == 1) { return false; }
        var mood = moodAt(now)[1] + CARE_MOOD_BUMP;
        if (mood > MOOD_MAX) { mood = MOOD_MAX; }
        mS[P_MOOD] = mood;
        if (now > mS[P_TS_SETTLE]) { mS[P_TS_SETTLE] = now; }
        mS[P_CARE_MASK] = mS[P_CARE_MASK] + 1;
        save();
        return true;
    }

    function addWalk(meters as Lang.Number) as Void {
        if (!mAlive || meters <= 0) { return; }
        mS[P_WALK_M] = mS[P_WALK_M] + meters;
        mS[P_WALK_COUNT] = mS[P_WALK_COUNT] + 1;
        save();
    }

    // The next landmark on the trail, in meters walked together.
    function trailGoal() as Lang.Number {
        var walked = mS[P_WALK_M];
        if (walked < 1000) { return 1000; }
        if (walked < 5000) { return 5000; }
        if (walked < 10000) { return 10000; }
        if (walked < 21097) { return 21097; }
        if (walked < 42195) { return 42195; }
        return (walked / 50000 + 1) * 50000;
    }

    function exportLine() as Lang.String {
        var line = "FRIEND_PET";
        for (var i = 0; i < SIZE; i += 1) { line += "," + mS[i]; }
        return line;
    }

    function readNumber(key as Lang.String, fallback as Lang.Number) as Lang.Number {
        var value = Application.Storage.getValue(key);
        return (value instanceof Lang.Number) ? (value as Lang.Number) : fallback;
    }
}
