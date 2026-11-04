# Friend export, 2026-11-03 (anonymized)

The automatic export Friend 0.7.1 wrote when S8 ended with Back (export
format 5, with the 0.7.1 hide/show lines). Times are the date plus
minutes:seconds from each session's start; time of day, epochs, part number,
firmware, pressure and distance were removed. `-1` = the watch answered null.
No crash log (`CIQ_LOG.YML`) was on the watch. S1 to S5 are the same sessions
as in [the 2026-10-31 export](2026-10-31_friend-export.md).

## What it shows

- **Export on exit works.** S8 (39 minutes, ended with Back) wrote this export
  by itself; no DEBUG DATA press was needed.
- **S8 was a workout:** HR 90/108/142, one effort chapter over the whole
  session (motion and HR, peak 69 bpm over the baseline).
- **T11 beat intervals, best catch so far:** 1745 intervals, 95% different
  from the one before, 409-802 ms (75-147 bpm, matching the HR range). At
  about 108 bpm, 39 minutes is about 4200 beats, so roughly 40% coverage
  (S2's workout: about 14%). The lower-HR sessions S5, S6 and S7 still got
  none; so far only the two workouts (S2, S8) delivered any.
- **What the 7 hides were:** the timeline below shows the screen away for
  5, 14, 30, 21, 30, 30 and 16 seconds, then back each time. Short glances
  away (a notification or the display timing out), not exits.
- **S6, open at the last export, ended normally:** 67 minutes, Back.

## Sessions

| Session | Date | Length | Ended by | Last press | Presses | Hides | HR min/avg/max | 4h HR avg | Steps | Battery % | RR count | RR vary % | RR min-max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S1 | 2026-10-27 | 0:01 | Back | 0:01 | 1 | 0 | 70/70/70 | 60 | 0 | 91->91 | 0 | - | - |
| S2 | 2026-10-30 | 41:03 | watch closed it | none | 0 | 3 | 74/121/145 | 70 | 776 | 95->94 | 698 | 94 | 394-925 |
| S3 | 2026-10-30 | 4:20 | Back | 4:20 | 3 | 0 | 100/106/115 | 81 | 155 | 94->94 | 0 | - | - |
| S4 | 2026-10-30 | 0:04 | Back | 0:04 | 4 | 0 | -1/-1/-1 | -1 | 0 | 100->100 | 0 | - | - |
| S5 | 2026-10-30 | 43:34 | watch closed it | 38:47 | 4 | 3 | 70/82/98 | 85 | 236 | 100->97 | 0 | - | - |
| S6 | 2026-10-31 | 67:24 | Back | 67:24 | 10 | 5 | 66/79/97 | -1 | 316 | 90->87 | 0 | - | - |
| S7 | 2026-11-02 | 15:51 | Back | 15:51 | 10 | 1 | 72/93/117 | 76 | 904 | 87->85 | 0 | - | - |
| S8 | 2026-11-03 | 38:58 | Back | 38:58 | 3 | 7 | 90/108/142 | 72 | 536 | 94->94 | 1745 | 95 | 409-802 |

## Effort chapters

| Session | Starts at | Length | Back ended it | Baseline | HR min/avg/max | Peak delta | Motion avg | Moving % | Steps | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| S3 | +0:00 | 4:20 | yes | 81 | 100/107/115 | 31 | 377 | 74 | 155 | both |
| S5 | +10:40 | 9:20 | no | 85 | 77/87/98 | 9 | 190 | 50 | 112 | motion |
| S5 | +22:40 | 2:20 | no | 85 | 81/82/85 | -1 | 143 | 40 | 0 | motion |
| S5 | +35:20 | 8:15 | yes | 85 | 75/82/98 | 8 | 250 | 64 | 124 | motion |
| S6 | +0:00 | 10:00 | no | -1 | 76/85/96 | -1 | 221 | 55 | 95 | motion |
| S6 | +13:20 | 11:40 | no | -1 | 70/79/94 | -1 | 194 | 44 | 56 | motion |
| S6 | +33:00 | 0:40 | no | -1 | 71/72/77 | -1 | 274 | 69 | 0 | motion |
| S6 | +48:40 | 10:00 | no | -1 | 67/83/97 | -1 | 227 | 60 | 159 | motion |
| S7 | +0:00 | 12:00 | no | 76 | 78/97/117 | 35 | 231 | 66 | 842 | both |
| S8 | +0:00 | 38:59 | yes | 72 | 90/108/142 | 69 | 183 | 37 | 536 | both |

## Check-in snapshots (taken at session start)

| Session | Date | Steps so far | Calories | Moderate/vigorous min | Stress | 4h HR min/avg/max | Body Battery | Respiration | Recovery h | SpO2 |
|---|---|---|---|---|---|---|---|---|---|---|
| S5 | 2026-10-30 | 3734 | 1949 | 11/10 | 77 | 78/85/105 | 22 | 19 | 0 | -1 |
| S6 | 2026-10-31 | 2274 | 1748 | 0/0 | 38 | -1/-1/-1 | -1 | -1 | 0 | -1 |
| S7 | 2026-11-02 | 2704 | 1323 | 0/0 | -1 | 57/76/106 | 48 | -1 | 0 | -1 |
| S8 | 2026-11-03 | 2315 | 1226 | 0/0 | -1 | 55/72/105 | 54 | 15 | 0 | -1 |

## Live records (the last 35 20-second rows, session S8)

```
elapsed_s,hr_min,hr_avg,hr_max,motion_avg,motion_peak,moving_pct,steps,stress,body_battery,chapter_state
1660,96,97,100,16,82,0,2851,99,-1,1
1680,97,97,98,18,81,0,2851,99,-1,1
1700,97,98,100,58,4543,1,2851,99,50,1
1720,97,98,99,17,88,0,2851,99,50,1
1740,97,98,102,75,545,20,2851,99,50,1
1760,101,101,103,68,758,15,2851,99,50,1
1780,99,100,103,39,257,3,2851,99,50,1
1800,96,98,101,35,268,3,2851,99,50,1
1820,102,103,105,21,142,0,2851,99,50,1
1840,97,98,102,22,222,1,2851,99,-1,1
1860,96,97,98,17,248,0,2851,99,-1,1
1880,96,97,99,22,170,0,2851,99,50,1
1900,97,97,99,19,113,0,2851,99,50,1
1920,97,99,102,31,294,4,2851,99,50,1
1940,96,97,99,48,372,9,2851,99,50,1
1960,94,96,99,20,115,0,2851,99,50,1
1980,96,98,102,23,152,0,2851,99,50,1
2000,96,97,99,20,58,0,2851,99,50,1
2020,96,96,98,17,52,0,2851,99,-1,1
2040,97,97,99,23,165,1,2851,99,-1,1
2060,96,97,98,34,395,5,2851,99,50,1
2080,96,97,98,56,352,8,2851,99,50,1
2100,97,97,99,69,739,18,2851,99,50,1
2120,95,95,98,112,1074,30,2851,99,50,1
2140,95,98,102,107,653,31,2851,99,50,1
2160,95,100,104,69,669,17,2851,99,50,1
2180,95,96,98,21,56,0,2851,99,50,1
2200,94,95,97,32,363,5,2851,99,-1,1
2220,94,94,96,17,49,0,2851,99,-1,1
2240,95,95,98,20,206,0,2851,99,49,1
2260,94,96,99,26,211,1,2851,99,49,1
2280,93,94,95,90,968,25,2851,99,49,1
2300,91,92,95,58,553,13,2851,99,49,1
2320,90,91,93,93,1524,21,2851,99,49,1
2339,92,92,94,159,1898,41,2851,99,49,1
```

## Hide/show timeline (log lines, elapsed seconds of the session)

`FRIEND_SHOW,<s>`, `FRIEND_HIDE,<s>,<hide count>`, `FRIEND_EXIT,<reason>,<s>,<last press s>,<presses>`.

```
FRIEND_SHOW,0
FRIEND_HIDE,137,1
FRIEND_SHOW,142
FRIEND_HIDE,143,2
FRIEND_SHOW,157
FRIEND_HIDE,158,3
FRIEND_SHOW,188
FRIEND_HIDE,232,4
FRIEND_SHOW,253
FRIEND_HIDE,254,5
FRIEND_SHOW,284
FRIEND_HIDE,490,6
FRIEND_SHOW,520
FRIEND_HIDE,1695,7
FRIEND_SHOW,1711
FRIEND_EXIT,1,2338,2338,3
FRIEND_HIDE,2338,8
```

