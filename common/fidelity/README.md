[Home](../MASTER_MAP.md) | [Compiler Facts](../language/COMPILER_FACTS.md)

# Ink face fidelity reports

Does the Japanese Ink landscape show the heart-rate graph? Each report here
is one run of `scripts/fidelity_test.py`: a set of four-hour HR windows fed
through `scripts/compose_preview.py` (the 1:1 offline mock of the watch
recipe), with the painted skyline of the two landmark planes (host + guest)
read column by column along the face's time axis and scored against the
true curve. Newest file = current state. Python 3 + Pillow only; no Garmin
SDK needed, so any machine can score a recipe change before it is built.

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

The contact sheet shows each case as: the plain HR graph | the face as
composed | the painted skyline (ink line, gray fill) with the data on the
crest scale (red, exactly where the overlay draws it) and the crests circled.

## Cases

Thirteen synthetic windows (once-a-minute samples, deterministic noise, a
fake epoch so no real date appears): flat rest, a workout in the middle, at
the end and at the start, two workouts, intervals, a steady climb, a nap dip,
a stress plateau, a short stair spike, a long walk, a reboot gap, and three
humps. Add a case to `CASES` in the script when a real window surprises you.
