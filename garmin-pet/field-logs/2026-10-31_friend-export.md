# Friend export, 2026-10-31 (anonymized)

One DEBUG DATA export from the FR265, Friend 0.6.0, export format 5. Times are
the date plus minutes:seconds from each session's start; time of day, epochs,
part number, firmware, pressure and distance were removed. `-1` = the watch
answered null. No crash log (`CIQ_LOG.YML`) was on the watch.

## What it shows

- **The 2026-10-30 workout is S2 then S3.** S2 ran 41:03 at HR 74/121/145 and was
  ended by the watch, not by Back: no button press reached Friend the whole time,
  and the screen went away 3 times. Friend did not crash (no crash log, a session
  row was saved). It was opened again 3:06 later (S3) and that run ended with Back
  after 4:20. Both are marked as one effort chapter each, cut short by the exit.
- **Both long sessions (S2, S5) ended with "watch closed it" and 3 hides.** S5 had
  its last press at 38:47 and closed 4:47 later. Which watch action closes Friend
  is still open; 0.7.0's export-on-exit will catch the next one.
- **T11 (beat intervals) partly answered.** Outside any recording, S2 delivered 698
  intervals, 94% different from the one before, 394-925 ms (65-152 bpm, matching
  its HR range): real, not interpolated. But sparse: about 14% of the ~4970 beats
  41 minutes at 121 bpm would have. S5 (43 minutes, same evening) got none, nor did
  the short sessions.
- **S6 was still open when DEBUG DATA ran**, so it has chapters and live rows but no
  session row. Its 4-hour HR and Body Battery read `-1` (null) at check-in.
- Exports since the 10/26 watch reset were lost because the log file was missing;
  this is the first one kept since then.

## Sessions

| Session | Date | Length | Ended by | Last press | Presses | Hides | HR min/avg/max | 4h HR avg | Steps | Battery % | RR count | RR vary % | RR min-max ms |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| S1 | 2026-10-27 | 0:01 | Back | 0:01 | 1 | 0 | 70/70/70 | 60 | 0 | 91->91 | 0 | - | - |
| S2 | 2026-10-30 | 41:03 | watch closed it | none | 0 | 3 | 74/121/145 | 70 | 776 | 95->94 | 698 | 94 | 394-925 |
| S3 | 2026-10-30 | 4:20 | Back | 4:20 | 3 | 0 | 100/106/115 | 81 | 155 | 94->94 | 0 | - | - |
| S4 | 2026-10-30 | 0:04 | Back | 0:04 | 4 | 0 | -1/-1/-1 | -1 | 0 | 100->100 | 0 | - | - |
| S5 | 2026-10-30 | 43:34 | watch closed it | 38:47 | 4 | 3 | 70/82/98 | 85 | 236 | 100->97 | 0 | - | - |
| S6 | 2026-10-31 | open at export | - | - | - | - | - | - | - | - | - | - | - |

## Effort chapters

| Session | Starts at | Length | Back ended it | Baseline | HR min/avg/max | Peak delta | Motion avg | Moving % | Steps | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| S2 | +0:00 | 41:03 | yes | 70 | 74/121/145 | 70 | 235 | 56 | 746 | both |
| S3 | +0:00 | 4:20 | yes | 81 | 100/107/115 | 31 | 377 | 74 | 155 | both |
| S5 | +10:40 | 9:20 | no | 85 | 77/87/98 | 9 | 190 | 50 | 112 | motion |
| S5 | +22:40 | 2:20 | no | 85 | 81/82/85 | -1 | 143 | 40 | 0 | motion |
| S5 | +35:20 | 8:15 | yes | 85 | 75/82/98 | 8 | 250 | 64 | 124 | motion |
| S6 | +0:00 | 10:00 | no | -1 | 76/85/96 | -1 | 221 | 55 | 95 | motion |
| S6 | +13:20 | 11:40 | no | -1 | 70/79/94 | -1 | 194 | 44 | 56 | motion |
| S6 | +33:00 | 0:40 | no | -1 | 71/72/77 | -1 | 274 | 69 | 0 | motion |
| S6 | +48:40 | 10:00 | no | -1 | 67/83/97 | -1 | 227 | 60 | 159 | motion |

## Check-in snapshots (taken at session start)

| Session | Date | Steps so far | Calories | Moderate/vigorous min | Stress | 4h HR min/avg/max | Body Battery | Respiration | Recovery h | SpO2 |
|---|---|---|---|---|---|---|---|---|---|---|
| S3 | 2026-10-30 | 2738 | 1154 | 11/10 | -1 | 52/81/138 | 59 | 12 | 0 | -1 |
| S4 | 2026-10-30 | 3251 | 1837 | 11/10 | -1 | -1/-1/-1 | -1 | -1 | 0 | -1 |
| S5 | 2026-10-30 | 3734 | 1949 | 11/10 | 77 | 78/85/105 | 22 | 19 | 0 | -1 |
| S6 | 2026-10-31 | 2274 | 1748 | 0/0 | 38 | -1/-1/-1 | -1 | -1 | 0 | -1 |

## Live records (the last 35 20-second rows, session S6)

```
elapsed_s,hr_min,hr_avg,hr_max,motion_avg,motion_peak,moving_pct,steps,stress,body_battery,chapter_state
3380,75,81,92,348,4542,76,2528,42,17,1
3400,92,94,95,315,2832,76,2577,51,17,1
3420,94,95,97,360,1736,79,2577,51,17,1
3440,88,92,97,231,2109,60,2577,91,17,1
3460,89,91,93,217,1158,71,2577,87,17,1
3480,85,88,92,184,1532,60,2577,69,17,1
3500,83,85,87,167,1099,49,2577,63,-1,1
3520,83,85,87,326,2619,69,2590,72,17,1
3540,74,77,83,24,128,0,2590,67,17,1
3560,72,73,75,17,56,0,2590,54,17,1
3580,74,74,76,19,105,0,2590,46,17,1
3600,75,75,77,20,64,0,2590,40,17,1
3620,73,74,75,21,100,0,2590,36,17,1
3640,73,74,75,19,80,0,2590,30,17,0
3660,73,74,75,19,93,0,2590,42,17,0
3680,74,74,75,34,670,4,2590,54,-1,0
3700,73,74,76,58,774,12,2590,42,17,0
3720,75,75,77,90,572,28,2590,42,17,0
3740,78,80,84,78,1109,15,2590,57,17,0
3760,71,73,77,24,70,0,2590,48,17,0
3780,70,70,71,24,105,0,2590,36,17,0
3800,70,76,81,28,127,0,2590,45,17,0
3820,74,75,78,84,1352,15,2590,60,17,0
3840,74,75,76,23,68,0,2590,64,17,0
3860,75,76,78,24,83,0,2590,67,-1,0
3880,73,75,77,24,77,0,2590,63,17,0
3900,73,74,75,23,64,0,2590,60,17,0
3920,74,75,76,24,73,0,2590,64,17,0
3940,75,75,77,37,389,4,2590,63,17,0
3960,74,75,77,16,45,0,2590,56,17,0
3980,74,74,75,16,45,0,2590,58,17,0
4000,75,78,83,151,3230,34,2590,70,17,0
4020,80,81,84,76,1117,14,2590,73,17,0
4040,75,76,79,39,1027,4,2590,62,-1,0
4042,75,75,75,47,328,6,2590,62,-1,0
```

