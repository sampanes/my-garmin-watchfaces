"""Readable inventory of the watch's settings, from a backup-garmin-device.ps1 backup.

Decodes the settings, sport-profile, workout, goal and schedule FIT files in a
backup into one line per field, writes settings-inventory.txt into that backup,
and diffs it against the previous backup so a change made on the watch shows up
as a line. Read-only: nothing here writes to the watch, and nothing should, since
Garmin documents no restore path for these files besides its own Device Backup.

The output holds personal data (weight, birth year, heart-rate zones). Backups
live under bin/, which Git ignores; keep it that way.
"""

from __future__ import annotations

import argparse
import datetime
import json
import sys
from pathlib import Path

from garmin_fit_sdk import Decoder, Profile, Stream

# FIT file types that hold configuration rather than recorded activity.
CONFIG_TYPES = {"settings", "sport", "workout", "goals", "schedules", "device"}
# Folders read whatever their file_id says (FR265 keeps settings here).
CONFIG_FOLDERS = {"settings", "sports", "workouts", "goals", "schedules"}
# Fields that change on every save without a setting changing.
IGNORED_FIELDS = {"time_created", "timestamp"}
INVENTORY_NAME = "settings-inventory.txt"
DIFF_NAME = "settings-diff.txt"


class _Stop(Exception):
    pass


def garmin_root(path: Path) -> Path:
    """The GARMIN folder inside a backup, a storage copy, or GARMIN itself."""
    for candidate in (path / "Internal Storage" / "GARMIN", path / "GARMIN", path):
        if candidate.is_dir() and candidate.name.upper() == "GARMIN":
            return candidate
    raise FileNotFoundError(f"No GARMIN folder under {path}")


def file_type(data: bytes) -> str | None:
    """The file_id type, decoding only up to the first message."""
    seen: dict = {}

    def listener(mesg_num, message):
        if mesg_num == Profile["mesg_num"]["FILE_ID"]:
            seen.update(message)
            raise _Stop()

    try:
        Decoder(Stream.from_byte_array(bytearray(data))).read(
            mesg_listener=listener, enable_crc_check=False)
    except Exception:
        return None
    value = seen.get("type")
    return str(value) if value is not None else None


def format_value(value) -> str:
    if isinstance(value, (list, tuple)):
        return ", ".join(format_value(v) for v in value)
    if isinstance(value, datetime.datetime):
        return value.isoformat()
    if isinstance(value, float):
        return f"{value:.6g}"
    if isinstance(value, bytes):
        return value.hex()
    return str(value)


def fit_lines(relative: str, data: bytes) -> list[str]:
    decoder = Decoder(Stream.from_byte_array(bytearray(data)))
    if not decoder.is_fit():
        return [f"{relative} | ! not a FIT file"]
    messages, errors = decoder.read()
    lines = []
    if errors:
        lines.append(f"{relative} | ! decode error: {errors[0]}")
    for group in sorted(messages):
        name = group[:-6] if group.endswith("_mesgs") else f"message_{group}"
        for index, message in enumerate(messages[group]):
            for key in sorted(message, key=str):
                field = key if isinstance(key, str) else f"field_{key}"
                # file_id says what the file is; the rest of it is device identity.
                if field in IGNORED_FIELDS or (name == "file_id" and field != "type"):
                    continue
                value = message[key]
                if value is None:
                    continue
                lines.append(f"{relative} | {name}[{index}] | {field} = {format_value(value)}")
    return lines


def inventory(garmin: Path) -> list[str]:
    lines = []
    for path in sorted(garmin.rglob("*"), key=lambda p: str(p).lower()):
        if not path.is_file() or path.suffix.lower() != ".fit":
            continue
        relative = path.relative_to(garmin).as_posix()
        data = path.read_bytes()
        in_config_folder = path.parent.name.lower() in CONFIG_FOLDERS
        if not in_config_folder and file_type(data) not in CONFIG_TYPES:
            continue
        lines.extend(fit_lines(relative, data))
    return lines


def key_of(line: str) -> str:
    return line.split(" = ", 1)[0]


def diff(old: list[str], new: list[str]) -> list[str]:
    """Changed, added and removed fields, keyed by file | message[i] | field."""
    before = {key_of(line): line for line in old}
    after = {key_of(line): line for line in new}
    out = []
    for key in sorted(set(before) | set(after)):
        a, b = before.get(key), after.get(key)
        if a == b:
            continue
        if a is None:
            out.append(f"+ {b}")
        elif b is None:
            out.append(f"- {a}")
        else:
            out.append(f"~ {key} = {a.split(' = ', 1)[1]}  ->  {b.split(' = ', 1)[1]}")
    return out


def is_complete_backup(path: Path) -> bool:
    manifest = path / "manifest.json"
    if path.name.endswith(".partial") or not manifest.is_file():
        return False
    try:
        return json.loads(manifest.read_text(encoding="utf-8-sig")).get("backup_status") == "complete"
    except (OSError, ValueError):
        return False


def previous_backup(backup: Path) -> Path | None:
    """The newest complete backup beside this one that sorts before it."""
    siblings = sorted(p for p in backup.parent.iterdir()
                      if p.is_dir() and p.name < backup.name and is_complete_backup(p))
    return siblings[-1] if siblings else None


def latest_backup(root: Path) -> Path | None:
    backups = sorted(p for p in root.iterdir() if p.is_dir() and is_complete_backup(p))
    return backups[-1] if backups else None


def write_inventory(backup: Path) -> list[str]:
    saved = backup / INVENTORY_NAME
    lines = inventory(garmin_root(backup))
    saved.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return lines


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("backup", nargs="?", type=Path,
                        help="a backup folder; default: the newest complete one")
    parser.add_argument("--root", type=Path,
                        default=Path(__file__).resolve().parents[2] / "bin" / "garmin-device-backups")
    parser.add_argument("--against", type=Path,
                        help="the backup to diff against; default: the one before")
    args = parser.parse_args(argv)

    backup = args.backup or (latest_backup(args.root) if args.root.is_dir() else None)
    if backup is None:
        print(f"No complete backup under {args.root}. Run scripts/backup-garmin-device.ps1 first.")
        return 1
    lines = write_inventory(backup)
    files = len({line.split(" | ", 1)[0] for line in lines})
    print(f"[inventory] {len(lines)} settings from {files} files -> {backup / INVENTORY_NAME}")

    against = args.against or previous_backup(backup)
    if against is None:
        print("[diff] No earlier backup to compare with; this one is the baseline.")
        return 0
    changes = diff(write_inventory(against), lines)
    report = [f"# {against.name} -> {backup.name}", *changes]
    (backup / DIFF_NAME).write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"[diff] {len(changes)} changes since {against.name} -> {backup / DIFF_NAME}")
    for line in changes[:40]:
        print("  " + line)
    if len(changes) > 40:
        print(f"  ... {len(changes) - 40} more in {DIFF_NAME}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
