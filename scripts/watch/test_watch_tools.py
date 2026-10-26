"""Host tests for settings_inventory.py and workouts.py. No watch, no network."""

from __future__ import annotations

import datetime
import json
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

from garmin_fit_sdk import Encoder, Profile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import settings_inventory as inv  # noqa: E402
import workouts as wk  # noqa: E402

MESG = Profile["mesg_num"]


def fit_file(file_type: str, *messages: tuple[str, dict]) -> bytes:
    encoder = Encoder()
    encoder.on_mesg(MESG["FILE_ID"], {
        "type": file_type, "manufacturer": "garmin", "product": 4257, "serial_number": 99,
        "time_created": datetime.datetime(2026, 10, 26, tzinfo=datetime.timezone.utc)})
    for name, fields in messages:
        encoder.on_mesg(MESG[name], fields)
    return encoder.close()


def make_backup(root: Path, name: str, weight: float, backlight: str, extra_sport: bool) -> Path:
    backup = root / name
    garmin = backup / "Internal Storage" / "GARMIN"
    (garmin / "Settings").mkdir(parents=True)
    (garmin / "Sports").mkdir()
    (garmin / "Activity").mkdir()
    (garmin / "Settings" / "Settings.fit").write_bytes(fit_file(
        "settings",
        ("USER_PROFILE", {"weight": weight, "gender": "male", "resting_heart_rate": 52}),
        ("DEVICE_SETTINGS", {"backlight_mode": backlight})))
    (garmin / "Sports" / "Run.fit").write_bytes(fit_file(
        "sport", ("SPORT", {"sport": "running", "name": "Run"})))
    if extra_sport:
        (garmin / "Sports" / "Strength.fit").write_bytes(fit_file(
            "sport", ("SPORT", {"sport": "training", "name": "Strength"})))
    # Recorded activity is not configuration and stays out of the inventory.
    (garmin / "Activity" / "A1.fit").write_bytes(fit_file(
        "activity", ("SPORT", {"sport": "running", "name": "Morning run"})))
    (backup / "manifest.json").write_text(json.dumps({"backup_status": "complete"}))
    return backup


class SettingsInventoryTest(unittest.TestCase):
    def test_inventory_and_diff_between_backups(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            old = make_backup(root, "20261026-100000-fr265-a", 80.5, "auto_brightness", False)
            new = make_backup(root, "20261027-100000-fr265-b", 79.0, "manual", True)
            partial = make_backup(root, "20261028-100000-fr265-c.partial", 70.0, "manual", True)
            self.assertFalse(inv.is_complete_backup(partial))
            self.assertEqual(inv.latest_backup(root), new)
            self.assertEqual(inv.previous_backup(new), old)

            lines = inv.inventory(inv.garmin_root(new))
            self.assertIn("Settings/Settings.fit | user_profile[0] | weight = 79", lines)
            self.assertIn("Sports/Strength.fit | sport[0] | name = Strength", lines)
            self.assertFalse(any(line.startswith("Activity/") for line in lines))
            self.assertFalse(any("time_created" in line or "serial_number" in line for line in lines))

            self.assertEqual(inv.main([str(new), "--root", str(root)]), 0)
            self.assertTrue((new / inv.INVENTORY_NAME).is_file())
            changes = (new / inv.DIFF_NAME).read_text(encoding="utf-8").splitlines()
            self.assertIn("~ Settings/Settings.fit | user_profile[0] | weight = 80.5  ->  79", changes)
            self.assertIn("~ Settings/Settings.fit | device_settings[0] | backlight_mode = auto_brightness  ->  manual", changes)
            self.assertIn("+ Sports/Strength.fit | sport[0] | name = Strength", changes)
            self.assertEqual(len(changes), 1 + 2 + 3)  # header, two changes, strength file_id/sport lines

    def test_first_backup_is_the_baseline(self):
        with tempfile.TemporaryDirectory() as tmp:
            only = make_backup(Path(tmp), "20261026-100000-fr265-a", 80.5, "manual", False)
            self.assertEqual(inv.main(["--root", tmp]), 0)
            self.assertTrue((only / inv.INVENTORY_NAME).is_file())
            self.assertFalse((only / inv.DIFF_NAME).exists())

    def test_corrupt_fit_is_reported_not_fatal(self):
        with tempfile.TemporaryDirectory() as tmp:
            backup = make_backup(Path(tmp), "20261026-100000-fr265-a", 80.5, "manual", False)
            (backup / "Internal Storage" / "GARMIN" / "Settings" / "Broken.fit").write_bytes(b"not fit")
            lines = inv.inventory(inv.garmin_root(backup))
            self.assertIn("Settings/Broken.fit | ! not a FIT file", lines)


class FakeGarmin:
    def __init__(self, existing):
        self.existing = existing
        self.calls = []

    def get_workouts(self, start, limit):
        return self.existing[start:start + limit]

    def upload_workout(self, body):
        self.calls.append(("upload", body["workoutName"]))
        return {"workoutId": 900}

    def update_workout(self, workout_id, body):
        self.calls.append(("update", workout_id, body["workoutName"]))

    def push_workout_to_device(self, workout_id):
        self.calls.append(("send", workout_id))

    def schedule_workout(self, workout_id, date):
        self.calls.append(("schedule", workout_id, date))


class WorkoutsTest(unittest.TestCase):
    def test_repo_workouts_build(self):
        workouts = wk.load_all()
        self.assertIn("Mat basics", workouts)
        body = workouts["Mat basics"].to_dict()
        self.assertEqual(body["sportType"]["sportTypeKey"], "strength_training")
        first = body["workoutSegments"][0]["workoutSteps"][1]
        self.assertEqual(first["type"], "RepeatGroupDTO")
        self.assertEqual(first["numberOfIterations"], 3)
        exercise, rest = first["workoutSteps"]
        self.assertEqual((exercise["category"], exercise["exerciseName"]), ("PUSH_UP", "PUSH_UP"))
        self.assertEqual(exercise["endConditionValue"], 12)
        self.assertEqual(rest["stepType"]["stepTypeKey"], "rest")
        orders = []

        def collect(steps):
            for step in steps:
                orders.append(step["stepOrder"])
                collect(step.get("workoutSteps", []))
        collect(body["workoutSegments"][0]["workoutSteps"])
        self.assertEqual(len(orders), len(set(orders)), "every stepOrder is unique")

    def test_names_are_forgiving_and_mistakes_are_explained(self):
        self.assertEqual(wk.resolve_exercise("push up", "t")["exercise"], "PUSH_UP")
        with self.assertRaisesRegex(wk.WorkoutError, "Close matches: .*Plank"):
            wk.resolve_exercise("plank thing", "t")
        spec = tomllib.loads('name = "x"\n[[block]]\nexercise = "Plank"\nreps = 5\nseconds = 30\n')
        with self.assertRaisesRegex(wk.WorkoutError, "reps or seconds"):
            wk.build(spec)
        with self.assertRaisesRegex(wk.WorkoutError, "needs a name"):
            wk.build({"block": [{"rest": 30}]})
        rest_only = wk.build(tomllib.loads('name = "r"\n[[block]]\nrest = 90\n')).to_dict()
        self.assertEqual(rest_only["workoutSegments"][0]["workoutSteps"][0]["stepType"]["stepTypeKey"], "rest")

    def test_push_updates_by_name_and_never_duplicates(self):
        workouts = wk.load_all()
        filler = [{"workoutName": f"other {i}", "workoutId": i} for i in range(1, 101)]
        api = FakeGarmin(filler + [{"workoutName": "Mat basics", "workoutId": 555}])
        report = wk.push(api, list(workouts.values()))
        self.assertEqual(api.calls, [("update", 555, "Mat basics"), ("send", 555)])
        self.assertIn("[updated] Mat basics", report[0])

        api = FakeGarmin([])
        wk.push(api, list(workouts.values()), schedule="2026-10-27")
        self.assertEqual(api.calls, [("upload", "Mat basics"), ("schedule", 900, "2026-10-27")])


if __name__ == "__main__":
    unittest.main(verbosity=1)
