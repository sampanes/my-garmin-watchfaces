# Friend export, 2026-11-10 (anonymized)

The automatic export Friend 0.7.1 wrote when S13 ended with Back, plus the
rotated log before it. Times are the date plus minutes:seconds from each
session's start; time of day, epochs, part number, firmware, pressure and daily
distance were removed. `-1` = the watch answered null. No crash log
(`CIQ_LOG.YML`) was on the watch. S1 to S8 are in
[the 2026-11-03 export](2026-11-03_friend-export.md).

This read is what Friend 0.8.0 (the pet layer) was designed against.

## What it shows

- **Every open is a workout or a walk.** 13 sessions in 15 days, 16 to 89
  minutes, and in every session from S7 on one effort chapter covers the whole
  session. The friend's screen said `WITH YOU` from the first minute to Back,
  and Back left at once: there was never a moment that paid the effort off.
  0.8.0 adds that moment (the reward card after Back) and shows the payoff
  building during the chapter.
- **The watch does not close Friend for being idle.** S9 ran 89 minutes with a
  single press (the Back that ended it), and S6 67 minutes. Every session since
  2026-10-31 ended with Back. The two watch-closed sessions of 2026-10-30 have
  not recurred, so the "about 30 minutes without input" guess in
  `open-questions.md` is wrong.
- **The four-hour baseline is there almost every time** (12 of 13 sessions), so
  the effort level in `12-pet-state-and-economy.md` §4.1 can do its job. But its
  proposed thresholds were too low: chapter HR sat 13 to 36 bpm over the
  baseline, so "hard" at +20 would have put three flames on 6 of the 10 newest
  chapters, a 21-minute walk included. 0.8.0 uses +15 steady and +30 hard:
  2 hard, 4 steady, 4 easy on the same chapters.
- **A stray walk reached Garmin Connect.** At the end of S12 a Friend Walk was
  started, ended and saved inside 5 seconds: 4 m, no GPS fix, saved as an
  activity. 0.8.0 offers to drop a walk under a minute and under 50 m instead
  of saving it, and a screen tap no longer acts as START.
- **Friend Walk works as a real walk.** S13 was a 21:25 walk of about 1.1 km
  with 818 GPS fixes, saved with START.
- **T11 inside a recording:** S13 logged 228 beat intervals, 96% different from
  the one before, 537-992 ms, all of them while the walk was recording. That is
  about 12% of the beats, the same thin coverage as outside a recording.
  S9 (no recording) is the best catch yet: 2497 intervals, 98% varying,
  321-1112 ms, about a third of the beats.
- **Cost stays small.** 0 to 3 battery points a session (2 for the GPS walk),
  peak app memory 31 KB of 768 KB.

## Sessions (new since 2026-11-03)

| Session | Date | Length | Ended by | Presses | Hides | HR min/avg/max | 4h HR avg | Steps | Battery % | Chapters | RR count | RR vary % | RR min-max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S9 | 2026-11-04 | 89:07 | Back | 1 | 8 | 63/89/129 | 65 | 1042 | 99->98 | 1 | 2497 | 98 | 321-1112 |
| S10 | 2026-11-04 | 40:28 | Back | 6 | 5 | 61/82/107 | 78 | 2070 | 96->93 | 3 | 0 | - | - |
| S11 | 2026-11-05 | 23:07 | Back | 1 | 1 | 75/99/127 | 75 | 442 | 84->84 | 1 | 519 | 93 | 437-897 |
| S12 | 2026-11-09 | 19:28 | Back | 8 | 2 | 84/97/109 | 63 | 1353 | 81->80 | 1 | 171 | 97 | 472-784 |
| S13 | 2026-11-10 | 21:28 | Back | 6 | 2 | 63/89/112 | 67 | 1449 | 71->69 | 1 | 228 | 96 | 537-992 |

Body Battery at the check-in: -1, 34, 58, 74, 69. Stress and respiration were
null at every check-in; SpO2 was null.

## Effort chapters (the 10 newest), and what the pet economy makes of them

Level and XP are `scripts/pet-model.ps1` replaying the chapters in order, at
the thresholds 0.8.0 ships (+15 steady, +30 hard). "Delta" is the chapter's
average HR over the four-hour baseline.

| Date | Length | Baseline | HR min/avg/max | Delta | Evidence | Level | XP |
|---|---|---|---|---|---|---|---|
| 2026-10-31 | 10:00 | -1 | 67/83/97 | - | motion | easy | +9 |
| 2026-11-02 | 12:00 | 76 | 78/97/117 | 21 | both | steady | +25 |
| 2026-11-03 | 38:59 | 72 | 90/108/142 | 36 | both | hard | +54 |
| 2026-11-04 | 89:08 | 65 | 63/89/129 | 24 | both | steady | +68 |
| 2026-11-04 | 20:40 | 78 | 86/91/107 | 13 | both | easy | +5 |
| 2026-11-04 | 0:40 | 78 | 68/71/76 | -7 | motion | easy | +1 |
| 2026-11-04 | 5:29 | 78 | 68/82/93 | 4 | both | easy | +1 |
| 2026-11-05 | 23:08 | 75 | 75/99/127 | 24 | both | steady | +39 |
| 2026-11-09 | 19:29 | 63 | 84/96/109 | 33 | both | hard | +39 |
| 2026-11-10 | 21:29 | 67 | 69/90/112 | 23 | both | steady | +37 |

Replaying all 18 chapters the watch holds (the eight oldest from the earlier
logs, their times of day approximate) gives about **370 XP: band 2, Trainee**,
on 8 active days. That is what the egg should hatch into on this watch; the
watch credits its own stored rows, so its number is the exact one.

What the replay says about the proposed numbers:

- **The taper bites hard on a second session.** The 20-minute afternoon chapter
  on 2026-11-04 earned +5 after the 89-minute morning one (decision 4 in
  doc 12 §9).
- **Warmth saturates fast.** It reached 100 on the fifth active day and stayed
  there (decision 8).
- **Mood sits at the top.** Each chapter adds 15, so a session that splits into
  three chapters adds 45; mood was 80 to 100 after every session. Weather will
  read sunny or radiant nearly always for this wearer. Credit is
  split-invariant; mood is not.

## Walk and hide/show lines (elapsed seconds of the session)

`FRIEND_WALK_START,<epoch>,<GPS quality>`,
`FRIEND_WALK_END,<reason>,<saved>,<seconds>,<meters>,<fixes>`.

S12, the stray walk (epoch removed):

```
FRIEND_SHOW,0
FRIEND_HIDE,452,1
FRIEND_SHOW,482
FRIEND_HIDE,587,2
FRIEND_SHOW,617
FRIEND_WALK_START,-,3
FRIEND_WALK_END,1,1,5,4,0
FRIEND_EXIT,1,1168,1168,8
```

S13, the real walk, started two seconds after opening:

```
FRIEND_SHOW,0
FRIEND_WALK_START,-,1
FRIEND_HIDE,644,1
FRIEND_SHOW,674
FRIEND_HIDE,1281,2
FRIEND_SHOW,1283
FRIEND_WALK_END,1,1,1285,1102,818
FRIEND_EXIT,1,1288,1288,6
```
