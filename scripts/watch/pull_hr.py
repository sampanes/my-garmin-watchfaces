r"""Real four-hour heart-rate windows from Garmin Connect, for the ink face's fidelity test.

    .\scripts\watch-tools.ps1 hr                     last 14 days, pick 8 varied windows
    .\scripts\watch-tools.ps1 hr --days 30 --pick 12
    .\scripts\watch-tools.ps1 hr --window 2026-11-01T08:00 --window 2026-11-04T17:30
    .\scripts\watch-tools.ps1 hr --from-watch             from the newest watch backup instead

Pulls each day's all-day heart rate (Connect keeps one sample every two
minutes), or with --from-watch reads it straight from the watch's own
monitoring files (GARMIN\Monitor\*.FIT in a backup-garmin-device.ps1 backup,
no Connect sync needed), and writes, into bin\hr\ (ignored by Git; this is personal data):

    all-hr.csv   every sample: epoch,hr
    picked-hr.csv    the chosen windows: epoch,hr,window_start

Without --window it picks windows that differ from each other: the most
active four hours, then windows spread from calm to busy, and one with a hole
in it if any (the watch off the wrist or rebooting). Then:

    py -3.11 scripts\fidelity_test.py --real bin\hr\picked-hr.csv

The report labels them real-1, real-2 ... with no dates; the key from real-N
to the day and hour is printed here and written to bin\hr\picked-key.txt.
"""

from __future__ import annotations

import argparse
import csv
import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "bin" / "hr"
WINDOW = 4 * 3600
STEP = 1800                  # candidate windows start every half hour
SAMPLE = 120                 # Connect's all-day spacing, seconds
FULL = 0.8                   # a window this covered counts as whole
HOLEY = 0.4                  # ... this covered, but not FULL, is the one with a hole


def pull(days: int) -> list[tuple[int, int]]:
    from garmin_login import connect

    api = connect()
    today = datetime.date.today()
    rows: dict[int, int] = {}
    for k in range(days, -1, -1):
        day = (today - datetime.timedelta(days=k)).isoformat()
        try:
            values = (api.get_heart_rates(day) or {}).get("heartRateValues") or []
        except Exception as exc:   # one bad day should not lose the rest
            print(f"  {day}: skipped ({exc})")
            continue
        n = 0
        for ms, bpm in values:
            if bpm:
                rows[int(ms) // 1000] = int(bpm)
                n += 1
        print(f"  {day}: {n} samples")
    return sorted(rows.items())


FIT_EPOCH = 631065600         # 1989-12-31 00:00 UTC, where FIT time starts


def monitor_rows(folder: Path) -> list[tuple[int, int]]:
    """Every heart-rate sample in the watch's monitoring files under a backup.

    Most samples carry only timestamp_16, the low 16 bits of the FIT time;
    the full time comes from the last message that had one.
    """
    from garmin_fit_sdk import Decoder, Stream

    files = [f for f in folder.rglob("*") if f.suffix.lower() == ".fit" and f.parent.name.lower() == "monitor"]
    rows: dict[int, int] = {}
    for f in sorted(files):
        messages, errors = Decoder(Stream.from_file(str(f))).read(convert_datetimes_to_dates=False)
        if errors:
            print(f"  {f.name}: {errors[0]}")
        last = None
        for m in messages.get("monitoring_mesgs", []):
            if m.get("timestamp") is not None:
                last = int(m["timestamp"])
                t = last
            elif m.get("timestamp_16") is not None and last is not None:
                t = last + ((int(m["timestamp_16"]) - (last & 0xFFFF)) & 0xFFFF)
            else:
                continue
            bpm = m.get("heart_rate")
            if bpm and 0 < bpm < 255:
                rows[t + FIT_EPOCH] = int(bpm)
    print(f"  {len(files)} monitoring files, {len(rows)} samples")
    return sorted(rows.items())


def newest_backup() -> Path:
    root = REPO / "bin" / "garmin-device-backups"
    found = sorted((p for p in root.glob("*") if p.is_dir()), key=lambda p: p.stat().st_mtime) if root.exists() else []
    if not found:
        raise SystemExit(f"No watch backup under {root}; run scripts" + "\\" + "backup-garmin-device.ps1 first.")
    return found[-1]


def windows(rows: list[tuple[int, int]]) -> list[dict]:
    """Every half-hour-aligned four-hour window with its spread and coverage."""
    if not rows:
        return []
    out, lo = [], 0
    start = rows[0][0] - rows[0][0] % STEP
    while start + WINDOW <= rows[-1][0] + SAMPLE:
        while lo < len(rows) and rows[lo][0] <= start:
            lo += 1
        hi = lo
        while hi < len(rows) and rows[hi][0] <= start + WINDOW:
            hi += 1
        hrs = sorted(b for _, b in rows[lo:hi])
        if hrs:
            out.append({
                "start": start,
                "cover": len(hrs) * SAMPLE / WINDOW,
                "spread": hrs[int(0.95 * (len(hrs) - 1))] - hrs[int(0.10 * (len(hrs) - 1))],
            })
        start += STEP
    return out


def pick(cands: list[dict], k: int) -> list[dict]:
    """The busiest window, then windows spread across calm..busy, plus one with a hole."""
    chosen: list[dict] = []

    def free(c):
        return all(abs(c["start"] - o["start"]) >= WINDOW for o in chosen)

    full = sorted((c for c in cands if c["cover"] >= FULL), key=lambda c: c["spread"])
    holey = [c for c in cands if HOLEY <= c["cover"] < FULL]
    if holey:
        chosen.append(max(holey, key=lambda c: c["spread"]))
    if full:
        chosen.append(full[-1])
    slots = max(k - len(chosen), 0)
    for i in range(slots):
        target = full[int(i * (len(full) - 1) / max(slots - 1, 1))]["spread"] if full else 0
        best = None
        for c in full:
            if free(c) and (best is None or abs(c["spread"] - target) < abs(best["spread"] - target)):
                best = c
        if best is None:
            break
        chosen.append(best)
    return sorted(chosen[:k], key=lambda c: c["start"])


def label(epoch: int) -> str:
    return datetime.datetime.fromtimestamp(epoch).strftime("%a %Y-%m-%d %H:%M")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--days", type=int, default=14, help="how far back to pull (default 14)")
    ap.add_argument("--pick", type=int, default=8, help="how many windows to choose (default 8)")
    ap.add_argument("--window", action="append", default=[], metavar="YYYY-MM-DDTHH:MM",
                    help="a window START you want (local time); repeatable; skips the automatic pick")
    ap.add_argument("--from-watch", nargs="?", const="", metavar="BACKUP",
                    help="read the watch's monitoring files from a backup (default: the newest)")
    ap.add_argument("--offline", action="store_true", help=r"re-pick from bin\hr\all-hr.csv, no pull")
    a = ap.parse_args(argv)

    OUT.mkdir(parents=True, exist_ok=True)
    every = OUT / "all-hr.csv"
    if a.from_watch is not None:
        folder = Path(a.from_watch) if a.from_watch else newest_backup()
        print(f"Reading heart rate from {folder} ...")
        rows = monitor_rows(folder)
    elif a.offline:
        with every.open(newline="") as fh:
            rows = [(int(d["epoch"]), int(d["hr"])) for d in csv.DictReader(fh)]
    else:
        days = a.days
        if a.window:   # reach back far enough for the oldest window asked for
            oldest = min(datetime.date.fromisoformat(w[:10]) for w in a.window)
            days = max(days, (datetime.date.today() - oldest).days + 1)
        print(f"Pulling {days} days of heart rate from Garmin Connect ...")
        rows = pull(days)
    if not a.offline:
        with every.open("w", newline="") as fh:
            w = csv.writer(fh)
            w.writerow(["epoch", "hr"])
            w.writerows(rows)
    if not rows:
        print("No heart-rate samples came back.")
        return 1

    cands = windows(rows)
    if a.window:
        chosen = []
        for w in a.window:
            s = int(datetime.datetime.fromisoformat(w).timestamp())
            match = [c for c in windows([r for r in rows if s <= r[0] <= s + WINDOW]) if c["start"] == s]
            chosen.append(match[0] if match else {"start": s, "cover": 0.0, "spread": 0})
    else:
        chosen = pick(cands, a.pick)

    picked, key = OUT / "picked-hr.csv", OUT / "picked-key.txt"
    lines = []
    with picked.open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["epoch", "hr", "window_start"])
        for n, c in enumerate(chosen, 1):
            s = c["start"]
            w.writerows((t, b, s) for t, b in rows if s <= t <= s + WINDOW)
            lines.append(f"real-{n}  {label(s)} +4h  spread {c['spread']:>3} bpm  covered {c['cover']:.0%}")
    key.write_text("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\n{picked}")
    print(r"next: py -3.11 scripts\fidelity_test.py --real bin\hr\picked-hr.csv")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
