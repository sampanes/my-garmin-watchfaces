[Home](../MASTER_MAP.md) | [Compiler Facts](../language/COMPILER_FACTS.md)

# Home verify reports

One report per run of `scripts/home-verify.ps1` on the PC that has the
Connect IQ SDK and simulator, named `YYYY-MM-DD_HHMM_home-verify.md`. The
newest file by name is the current state of the tree. Each report records:

- the commit it checked, and whether the working tree was clean;
- every project and device it compiled (`monkeyc -w -l 2`), with result,
  warning count and PRG size; devices whose files are not installed show as
  skipped;
- every offline test (`scripts/test-*.ps1`, `watch-tools.ps1 test`);
- the Japanese Ink face in the simulator beside `compose_preview.py` at the
  same clock time, with the difference image (`*_ink-sim-vs-preview.png`);
- every compiler error and unique warning, with local paths removed.

## For a machine with no SDK

Before writing Monkey C, read [COMPILER_FACTS](../language/COMPILER_FACTS.md)
and the newest report. A warning listed there is the known baseline; a new
one you add will show up in the next run. When a report shows a failure or a
difference between the simulator and the preview, that is the next job.

## Running it (home PC)

From cmd at the repository root:

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\home-verify.ps1
```

Options: `-NoPull` (verify the local tree as it is), `-SkipSim`,
`-SkipTests`. It pulls with `--ff-only` by default, starts the simulator if
needed and leaves it open (`taskkill /IM simulator.exe` closes it), and
never commits. Review the report, then commit it.
