"""Read, recover and apply the watch setup that lives in Garmin Connect.

    snapshot              save everything Garmin Connect holds about the account and
                          the watch (device settings, user settings, HR zones, goals)
    recover --wiped DATE  pull the settings recorded inside the last activity before
                          DATE and the first one after, and diff them: the lines that
                          differ are what the wipe reset
    apply [FILE] [--yes]  compare a desired-setup TOML with Garmin Connect, print every
                          difference, and with --yes write only those; the watch picks
                          them up on its next sync

Everything except apply --yes is read-only. Output and the desired-setup file hold
personal data and live under bin/, which Git ignores. Uses the unofficial
garminconnect library (Garmin's private web API), which Garmin can break.
"""

from __future__ import annotations

import argparse
import datetime
import io
import json
import sys
import tomllib
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # run with python -I
from garmin_login import connect  # noqa: E402
from settings_inventory import diff, fit_lines  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
OUT_ROOT = REPO / "bin" / "garmin-connect"
SETUP_FILE = REPO / "bin" / "watch-setup.toml"
WATCH_HINT = "265"
# Activity-file messages that record the workout itself rather than a setting.
ACTIVITY_DATA = frozenset({
    "record", "event", "lap", "length", "hrv", "device_info", "session", "activity",
    "split", "split_summary", "gps_metadata", "monitoring", "stress_level", "hr",
    "respiration_rate", "set", "time_in_zone", "file_creator", "developer_data_id",
    "field_description", "climb_pro", "jump", "segment_lap", "dive_summary",
})
MISSING = object()


def stamp() -> str:
    return datetime.datetime.now().strftime("%Y%m%d-%H%M%S")


def pick_watch(devices: list[dict], wanted: str | None = None) -> dict:
    """The FR265 among the account's devices (or the one named by --device)."""
    def label(d):
        return f"{d.get('productDisplayName', '')} {d.get('displayName', '')}"
    if wanted:
        hits = [d for d in devices if str(d.get("deviceId")) == wanted or wanted.lower() in label(d).lower()]
    else:
        hits = [d for d in devices if WATCH_HINT in label(d)] or (devices if len(devices) == 1 else [])
    if len(hits) != 1:
        names = "; ".join(f"{d.get('deviceId')}: {label(d).strip()}" for d in devices)
        raise SystemExit(f"[error] Pick the watch with --device. Devices: {names or 'none'}")
    return hits[0]


# --- snapshot ---------------------------------------------------------------

def snapshot(api, device_hint: str | None, out_root: Path = OUT_ROOT) -> Path:
    out = out_root / f"snapshot-{stamp()}"
    out.mkdir(parents=True)
    devices = api.get_devices() or []
    watch = pick_watch(devices, device_hint)
    reads = {
        "devices": api.get_devices,
        "device-settings": lambda: api.get_device_settings(watch["deviceId"]),
        "user-settings": api.get_user_profile,
        "userprofile-settings": api.get_userprofile_settings,
        "hr-zones": api.get_heart_rate_zones,
        "goals": api.get_user_goals,
    }
    for name, read in reads.items():
        try:
            value = read()
        except Exception as error:  # one missing endpoint should not lose the rest
            value = {"error": str(error)}
            print(f"[warn] {name}: {error}")
        (out / f"{name}.json").write_text(json.dumps(value, indent=2, default=str), encoding="utf-8")
    print(f"[snapshot] {watch.get('productDisplayName')} (device {watch['deviceId']}) -> {out}")
    return out


# --- recover ----------------------------------------------------------------

def activity_fit(api, activity_id) -> bytes:
    from garminconnect import Garmin

    blob = api.download_activity(activity_id, dl_fmt=Garmin.ActivityDownloadFormat.ORIGINAL)
    try:
        with zipfile.ZipFile(io.BytesIO(blob)) as archive:
            name = next(n for n in archive.namelist() if n.lower().endswith(".fit"))
            return archive.read(name)
    except zipfile.BadZipFile:
        return blob


def activity_settings(api, activity: dict) -> list[str]:
    data = activity_fit(api, activity["activityId"])
    return [line.split(" | ", 1)[1] for line in
            fit_lines("activity", data, skip=ACTIVITY_DATA, max_instances=20)]


def recover(api, wiped: datetime.date, out_root: Path = OUT_ROOT, days: int = 60) -> Path:
    start = (wiped - datetime.timedelta(days=days)).isoformat()
    activities = api.get_activities_by_date(start, datetime.date.today().isoformat(), sortorder="asc") or []

    def day(a):
        return datetime.date.fromisoformat(str(a.get("startTimeLocal", ""))[:10])

    before = [a for a in activities if day(a) < wiped]
    after = [a for a in activities if day(a) >= wiped]
    if not before:
        raise SystemExit(f"[error] No activity in the {days} days before {wiped}; try --days.")
    out = out_root / f"recover-{wiped.isoformat()}"
    out.mkdir(parents=True, exist_ok=True)
    old = activity_settings(api, before[-1])
    (out / "before-wipe.txt").write_text("\n".join(old) + "\n", encoding="utf-8")
    print(f"[before] {before[-1].get('activityName')} {before[-1].get('startTimeLocal')}: {len(old)} settings")
    if after:
        new = activity_settings(api, after[0])
        (out / "after-wipe.txt").write_text("\n".join(new) + "\n", encoding="utf-8")
        changes = diff(old, new)
        (out / "wipe-diff.txt").write_text("\n".join(changes) + "\n", encoding="utf-8")
        print(f"[after]  {after[0].get('activityName')} {after[0].get('startTimeLocal')}: {len(changes)} differences")
        for line in changes[:40]:
            print("  " + line)
    else:
        print("[after]  No activity since the wipe yet; record a short one and run recover again.")
    print(f"[recover] -> {out}")
    return out


# --- apply ------------------------------------------------------------------

def leaves(value, path=()):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from leaves(child, path + (key,))
    else:
        yield path, value


def lookup(value, path):
    for key in path:
        if not isinstance(value, dict) or key not in value:
            return MISSING
        value = value[key]
    return value


def changes_between(desired: dict, current: dict) -> list[tuple[tuple, object, object]]:
    return [(path, lookup(current, path), want) for path, want in leaves(desired)
            if lookup(current, path) != want]


def merged(current, path, value):
    """A copy of current with value set at path, every sibling kept."""
    if not path:
        return value
    base = dict(current) if isinstance(current, dict) else {}
    base[path[0]] = merged(base.get(path[0]), path[1:], value)
    return base


def sections_to_send(current: dict, changes) -> dict:
    """Whole top-level sections with the changes applied, so a server that replaces
    a section instead of merging it still keeps every untouched sibling."""
    out: dict = {}
    for path, _, want in changes:
        top = path[0]
        out[top] = merged(out.get(top, current.get(top)), path[1:], want)
    return out


def show(label: str, changes) -> None:
    for path, have, want in changes:
        have_text = "(not set)" if have is MISSING else json.dumps(have)
        print(f"  {label}.{'.'.join(path)}: {have_text} -> {json.dumps(want)}")


def apply(api, setup: dict, write: bool, device_hint: str | None = None) -> int:
    planned = []
    if setup.get("user"):
        current = api.get_user_profile()
        changes = changes_between(setup["user"], current)
        show("user", changes)
        if changes:
            planned.append(lambda c=current, ch=changes: api.update_user_settings(sections_to_send(c, ch)))
    if setup.get("device"):
        watch = pick_watch(api.get_devices() or [], device_hint or setup.get("device_id"))
        current = api.get_device_settings(watch["deviceId"])
        changes = changes_between(setup["device"], current)
        show("device", changes)
        if changes:
            planned.append(lambda w=watch, c=current, ch=changes:
                           api.update_device_settings(w["deviceId"], sections_to_send(c, ch)))
    if setup.get("hr_zones"):
        current = {z.get("sport"): z for z in api.get_heart_rate_zones() or []}
        send = []
        for wanted in setup["hr_zones"]:
            sport = wanted.get("sport")
            have = current.get(sport, {})
            changes = changes_between(wanted, have)
            show(f"hr_zones[{sport}]", changes)
            if changes:
                send.append({**have, **wanted})
        if send:
            planned.append(lambda s=send: api.update_heart_rate_zones(s))
    if not planned:
        print("[apply] Garmin Connect already matches the setup file.")
        return 0
    if not write:
        print(f"[apply] {len(planned)} section(s) differ. Nothing written; run again with --yes to write them.")
        return 0
    for call in planned:
        call()
    print(f"[apply] Wrote {len(planned)} section(s). The watch takes them on its next sync.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--device", help="device id or name, when the account has several")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("snapshot", parents=[common])
    rec = sub.add_parser("recover", parents=[common])
    rec.add_argument("--wiped", required=True, type=datetime.date.fromisoformat, metavar="YYYY-MM-DD")
    rec.add_argument("--days", type=int, default=60)
    app = sub.add_parser("apply", parents=[common])
    app.add_argument("file", nargs="?", type=Path, default=SETUP_FILE)
    app.add_argument("--yes", action="store_true")
    args = parser.parse_args(argv)

    if args.command == "apply":
        if not args.file.is_file():
            print(f"[error] No setup file at {args.file}.")
            return 1
        with args.file.open("rb") as handle:
            setup = tomllib.load(handle)
        return apply(connect(), setup, args.yes, args.device)
    api = connect()
    if args.command == "snapshot":
        snapshot(api, args.device)
    else:
        recover(api, args.wiped, days=args.days)
    return 0


if __name__ == "__main__":
    sys.exit(main())
