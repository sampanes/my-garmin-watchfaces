[Home](../MASTER_MAP.md) | [Compiler Facts](../language/COMPILER_FACTS.md)

# Ink face fidelity reports

Does the Japanese Ink landscape show the heart-rate graph? Each report here
is one run of `scripts/fidelity_test.py`: a set of four-hour HR windows fed
through `scripts/compose_preview.py` (the 1:1 offline mock of the watch
recipe), with the painted skyline of the relief (horizon + masses) read
column by column along the face's time axis and scored against the
true curve. Newest file = current state. Python 3 + Pillow only; no Garmin
SDK needed, so any machine can score a recipe change before it is built.

## View or recreate on another computer

The generator, compositor, synthetic cases, baseline report, and baseline PNG
are tracked on `origin/main`. After cloning or pulling the repository:

```text
python -m pip install Pillow
python scripts/fidelity_test.py --out bin/fidelity/local
```

On Windows, `py -3.11` can replace `python`. The explicit ignored `--out`
directory keeps a local experiment from creating a new tracked report. To view
the shared baseline without running anything, open the newest
`common/fidelity/*_fidelity-sheet.png` from the checkout.

```
py -3.11 scripts\fidelity_test.py                  synthetic cases -> common\fidelity\
py -3.11 scripts\fidelity_test.py --real hr.csv    adds real windows -> bin\fidelity\ (ignored)
```

`--real` takes any CSV with an `epoch` column and `hr_avg` or `hr` (Friend's
`live.csv`, a Connect export). It is cut into consecutive four-hour windows
labeled `real-1`, `real-2`, ... with no timestamps. Real runs write to the
ignored `bin\fidelity\` unless `--out` says otherwise, so personal data is
only committed on purpose.

## Metrics

| Column | Meaning | Ideal |
|---|---|---|
| r | Pearson correlation between the painted skyline height and the true HR, per screen column on the time axis | 1.00 |
| Peak off (min) | Minutes between the true highest moment (2.5-min smoothed) and the host crest | 0 |
| Peaks true / painted | Peaks with at least 12 bpm prominence, 20 min apart, vs painted crests (host + guest) | equal |
| Overlay gap (px) | Mean vertical distance between the red overlay's edge and the painted skyline | 0 |
| True range / painted relief | The window's HR range in bpm vs the skyline's height range in px | proportional |

## Current milestone targets

Whole library mountains stay the painted silhouette (decision, 2026-11-05;
see RENDERER_PLAN.md). The lightly smoothed sixteen-bucket HR profile is the
reference they are fitted and scored against, not a ridge drawn on its own.
Any partial real history remains partial; mock data is reserved for explicit
simulator/tests.

Where it stands: the newest report (2026-11-03, the shape library: every
run of buckets over the window's floor is one whole library mountain sunk
onto the run's peak) measures mean r 0.72, peak count right in 11 of 13
cases, a 7 px mean gap, a 10 min mean peak-timing error, and 1 px of
flat-rest relief. The gap, timing and flat-rest targets below are met; the
first 2026-11-01 baseline was r 0.43, 2 of 13, 34 px and 98 px.

A/B prototyping starts with these provisional targets:

- mean non-flat skyline `r >= 0.80` across the core synthetic cases
- mean overlay-to-ink gap `<= 12 px`
- mean dominant-peak timing error `<= 15 min` on cases with a prominent peak
- prominent-episode precision and recall each `>= 0.80` within `+/-15 min`
- `flat_rest` relief is `<= 15 px` with no prominent painted peak
- repeated runs are deterministic and unknown spans are not bridged

Before the watch build, the contact sheet should show the committed
baseline (the newest report) and candidate side by side. The current script measures
one recipe per run, counts the known host/guest landmarks instead of detecting
painted skyline peaks, and does not yet assert determinism or gap preservation.
Adding those measurements is part of this milestone. The prototype report will
calibrate and lock the binding gates before the Monkey C port is installed.

The contact sheet shows each case as: the plain HR graph | the face as
composed | the painted skyline (ink line, gray fill) with the data on the
crest scale (red, exactly where the overlay draws it) and the crests circled.

## Cases

Thirteen core synthetic windows (once-a-minute samples, deterministic noise, a
fake epoch so no real date appears): flat rest, a workout in the middle, at
the end and at the start, two workouts, intervals, a steady climb, a nap dip,
a stress plateau, a short stair spike, a long walk, a reboot gap, and three
humps. Add a case to `CASES` in the script when a real window surprises you.
