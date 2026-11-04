# Bitmap budget on the watch 2026-11-03_1933

Written by `scripts/bitmap-budget.ps1 -ReadWatch`. The probe ran on the FR265 itself with 200 generated planes (copies of the ink face's baked cutouts).

- Heap at start: 16960 of 126928 bytes
- Load time per plane: fastest 43 ms, median 57 ms, slowest 227 ms
- App heap per held plane: 334 bytes (the pixels live in the graphics pool, not the app heap)
- Sweep (load, draw, drop each): **200 of 200 loaded**, 0 failed; slowest 227 ms, total 15965 ms
- Held at once: **48** (the probe stops at 48)
- Before this run the log also holds the end of an earlier one (planes 117 to 199
  loaded, none failed; its start rotated out of the 5 KB log). The watch restarted
  the face while a walk was recorded, and the probe started over and finished.
- The face felt laggy on the wrist during the hold pass, which redraws every held
  plane each time one joins (up to 48 scaled draws per plane); the ink face never does.

Last log lines:

```
BUDGET_HOLD,42,31320,1
BUDGET_HOLD,43,31656,1
BUDGET_HOLD,44,32000,1
BUDGET_HOLD,45,32336,1
BUDGET_HOLD,46,32680,1
BUDGET_HOLD,47,33024,1
BUDGET_HOLD,48,33360,1
BUDGET_DONE,200,200,0,227,15965,48
```
