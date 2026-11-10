using Toybox.Lang;

// The friend's voice pack (garmin-pet/07-personality.md): one table of canned
// lines per event, four personas each. Swapping a persona swaps the lines and
// nothing else. Lines roast the effort gap, never the person, and every line
// fits one row of the round screen (friend_preview.py --check measures them).
class FriendVoice {
    const E_MORNING = 0;
    const E_DAY = 1;
    const E_EVENING = 2;
    const E_NIGHT = 3;
    const E_REUNION = 4;
    const E_EFFORT = 5;         // 5 easy, 6 steady, 7 hard.
    const E_REWARD = 8;         // 8 easy, 9 steady, 10 hard.
    const E_GREW = 11;
    const E_PET = 12;
    const E_WALK_START = 13;
    const E_WALK_DONE = 14;
    const E_FULL = 15;
    const E_DRAINED = 16;
    const E_IDLE = 17;
    const E_EVO_READY = 18;
    const E_HATCH = 19;
    const E_WAKE = 20;

    // mLines[event][persona][variant]; persona 0 Drill Sergeant, 1 Hype
    // Cheerleader, 2 Deadpan, 3 Zen. An event with one pool is said by everyone.
    var mLines as Lang.Array<Lang.Array<Lang.Array<Lang.String>>>;
    var mNames as Lang.Array<Lang.String>;
    var mSamples as Lang.Array<Lang.String>;

    function initialize() {
        mNames = ["DRILL SGT", "CHEERLEADER", "DEADPAN", "ZEN"] as Lang.Array<Lang.String>;
        mSamples = ["Sup. Let's go.", "You've got this!!", "Oh. We're doing this.",
                    "Whenever you're ready."] as Lang.Array<Lang.String>;
        mLines = [
            // 0 morning
            [["Morning. Move.", "Up. Good."],
             ["Good morning!!", "New day, yay!"],
             ["Morning. Allegedly.", "Ah. Daylight."],
             ["Morning. Breathe.", "A fresh day."]],
            // 1 day
            [["Sup. Let's go.", "You're here. Good."],
             ["Hi hi hi!", "There you are!!"],
             ["Oh. It's you.", "Hello, I suppose."],
             ["Hey. Welcome.", "Good to see you."]],
            // 2 evening
            [["Evening shift. Go.", "Late. Still counts."],
             ["Evening, star!", "Still going! Wow!"],
             ["Evening. Bold.", "Still up, I see."],
             ["Evening. Easy now.", "Day's winding down."]],
            // 3 night
            [["It's late. Quick.", "Night ops. Fine."],
             ["Night owl!!", "Shh... hi!!"],
             ["It is night.", "Sleep is a myth."],
             ["Quiet hours.", "Soft steps."]],
            // 4 reunion
            [["Look who's back.", "You remembered me."],
             ["I missed you!!", "You're back! Yay!"],
             ["You exist. Noted.", "Oh. A visitor."],
             ["Welcome back.", "No guilt. Hello."]],
            // 5 effort, easy
            [["Moving. Finally.", "Keep it going."],
             ["Go go go!", "Yes!! Moving!"],
             ["Motion detected.", "We move. Okay."],
             ["With you.", "Easy rhythm."]],
            // 6 effort, steady
            [["Now we're working.", "Don't stop now."],
             ["You're on fire!", "Look at you go!"],
             ["Heart rate: rude.", "This is effort."],
             ["Strong and steady.", "With you."]],
            // 7 effort, hard
            [["Heart says work.", "That's the stuff."],
             ["BEAST MODE!!", "Unstoppable!!"],
             ["Ow. On your behalf.", "Truly excessive."],
             ["Breathe. Strong.", "Big effort. Good."]],
            // 8 reward, easy
            [["Counts. Barely.", "A start. Fine."],
             ["Every bit counts!", "Yay, a snack!"],
             ["Technically effort.", "A snack. Thanks."],
             ["A gentle one. Good.", "Small and kind."]],
            // 9 reward, steady
            [["Not bad.", "Solid. Again soon."],
             ["So proud of you!", "That was great!!"],
             ["Didn't hate it.", "Adequate. Tasty."],
             ["Nicely done.", "Good, honest work."]],
            // 10 reward, hard
            [["Fine. That was good.", "Earned. Rest up."],
             ["INCREDIBLE!!", "You crushed it!!"],
             ["Impressive. Ugh.", "I felt that. Ow."],
             ["Strong. Now rest.", "You gave a lot."]],
            // 11 grew
            [["Earned it.", "Bigger. Stronger."],
             ["LOOK AT ME!!", "We did this!!"],
             ["I am taller now.", "Growth. Weird."],
             ["We grow slowly.", "Like a tree."]],
            // 12 petted
            [["Hey. ...Fine.", "One pat. That's it."],
             ["Hehe!! Again!", "Best pats ever!"],
             ["Ah. Affection.", "If you must."],
             ["Mm. Thank you.", "That's nice."]],
            // 13 walk start
            [["March.", "Move out."],
             ["Walkies!!", "Adventure time!"],
             ["Outside. Wow.", "A walk. Sure."],
             ["Let's wander.", "One step, then one."]],
            // 14 walk done
            [["Good march.", "Ground covered."],
             ["Best walk ever!", "We went so far!"],
             ["We went. We returned.", "Legs: used."],
             ["Lovely walk.", "The air was good."]],
            // 15 full: 30 effort minutes today
            [["Fed. Dismissed.", "Rations: full."],
             ["So full! Yay!", "Yum yum yum!"],
             ["I am full. Stop.", "Enough snack."],
             ["Full and calm.", "Plenty for today."]],
            // 16 drained: the wearer's Body Battery is low
            [["You're spent. Sit.", "Low tank. Easy day."],
             ["Rest is okay too!", "Be gentle today!"],
             ["Do less. Survive.", "Battery: sad."],
             ["Rest is training.", "Go softly today."]],
            // 17 idle
            [["Waiting on you.", "Tap me. I dare you."],
             ["Tap me!", "I'm right here!"],
             ["Still here.", "Tap me. Or don't."],
             ["No rush.", "I'm here."]],
            // 18 evolution ready
            [["I feel different...", "Something's coming."]],
            // 19 hatched
            [["I heard it all."]],
            // 20 woken by a tap
            [["Mm. I'm up."], ["Oh! Hi!!"], ["...What."], ["Mm. Hello."]]
        ] as Lang.Array<Lang.Array<Lang.Array<Lang.String>>>;
    }

    function line(event as Lang.Number, persona as Lang.Number,
                  pick as Lang.Number) as Lang.String {
        if (event < 0 || event >= mLines.size()) { return ""; }
        var byVoice = mLines[event];
        var voice = (persona < 0) ? 0 : persona;
        var pool = byVoice[voice % byVoice.size()];
        var variant = (pick < 0) ? 0 : pick;
        return pool[variant % pool.size()];
    }

    // The greeting follows the wearer's real clock.
    function hello(hour as Lang.Number, persona as Lang.Number,
                   pick as Lang.Number) as Lang.String {
        if (hour >= 5 && hour < 11) { return line(E_MORNING, persona, pick); }
        if (hour >= 11 && hour < 18) { return line(E_DAY, persona, pick); }
        if (hour >= 18 && hour < 22) { return line(E_EVENING, persona, pick); }
        return line(E_NIGHT, persona, pick);
    }

    function reunion(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_REUNION, persona, pick);
    }

    function effort(flames as Lang.Number, persona as Lang.Number,
                    pick as Lang.Number) as Lang.String {
        return line(E_EFFORT + level(flames), persona, pick);
    }

    function reward(flames as Lang.Number, persona as Lang.Number,
                    pick as Lang.Number) as Lang.String {
        return line(E_REWARD + level(flames), persona, pick);
    }

    function level(flames as Lang.Number) as Lang.Number {
        if (flames >= 3) { return 2; }
        if (flames == 2) { return 1; }
        return 0;
    }

    function grew(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_GREW, persona, pick);
    }

    function petted(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_PET, persona, pick);
    }

    function walkStart(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_WALK_START, persona, pick);
    }

    function walkDone(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_WALK_DONE, persona, pick);
    }

    function full(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_FULL, persona, pick);
    }

    function drained(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_DRAINED, persona, pick);
    }

    function idle(persona as Lang.Number, pick as Lang.Number) as Lang.String {
        return line(E_IDLE, persona, pick);
    }

    function evoReady(pick as Lang.Number) as Lang.String {
        return line(E_EVO_READY, 0, pick);
    }

    function hatched() as Lang.String {
        return line(E_HATCH, 0, 0);
    }

    function woke(persona as Lang.Number) as Lang.String {
        return line(E_WAKE, persona, 0);
    }

    function voiceName(persona as Lang.Number) as Lang.String {
        return mNames[((persona < 0) ? 0 : persona) % mNames.size()];
    }

    function voiceSample(persona as Lang.Number) as Lang.String {
        return mSamples[((persona < 0) ? 0 : persona) % mSamples.size()];
    }

    function voiceCount() as Lang.Number {
        return mNames.size();
    }
}
