"""Host tests for settings_inventory.py and workouts.py. No watch, no network."""

from __future__ import annotations

import datetime
import io
import json
import sys
import tempfile
import tomllib
import unittest
import zipfile
from pathlib import Path

from garmin_fit_sdk import Encoder, Profile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import connect_setup as cs  # noqa: E402
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


def activity_zip(backlight: str, rest_hr: int) -> bytes:
    """An activity download: per-second records plus the settings the watch embeds."""
    records = [("RECORD", {"heart_rate": 100 + i}) for i in range(30)]
    fit = fit_file("activity", ("USER_PROFILE", {"resting_heart_rate": rest_hr}),
                   ("DEVICE_SETTINGS", {"backlight_mode": backlight}), *records)
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("123_ACTIVITY.fit", fit)
    return buffer.getvalue()


class FakeConnect:
    def __init__(self):
        self.writes = []
        self.device = {"activityTracking": {"moveAlertEnabled": False, "autoGoal": True},
                       "alarms": [], "backlight": {"mode": "AUTO"}}
        self.user = {"userData": {"measurementSystem": "statute_us", "weight": 80000},
                     "userSleep": {"sleepTime": 79200, "wakeTime": 21600}}
        self.zones = [{"sport": "DEFAULT", "trainingMethod": "HR_MAX", "maxHeartRateUsed": 190,
                       "zone1Floor": 95}]

    def get_devices(self):
        return [{"deviceId": 7, "productDisplayName": "Index S2 Scale"},
                {"deviceId": 42, "productDisplayName": "Forerunner 265"}]

    def get_device_settings(self, device_id):
        assert device_id == 42
        return self.device

    def get_user_profile(self):
        return self.user

    def get_userprofile_settings(self):
        raise RuntimeError("endpoint moved")

    def get_heart_rate_zones(self):
        return self.zones

    def get_user_goals(self):
        return [{"goalType": "steps", "goalValue": 8000}]

    def update_user_settings(self, settings):
        self.writes.append(("user", settings))

    def update_device_settings(self, device_id, settings):
        self.writes.append(("device", device_id, settings))

    def update_heart_rate_zones(self, zones):
        self.writes.append(("zones", zones))

    def get_activities_by_date(self, start, end, sortorder=None):
        return [{"activityId": 1, "activityName": "Old run", "startTimeLocal": "2026-10-20 07:00:00"},
                {"activityId": 2, "activityName": "New walk", "startTimeLocal": "2026-10-26 18:00:00"}]

    def download_activity(self, activity_id, dl_fmt=None):
        return activity_zip("auto_brightness", 50) if activity_id == 1 else activity_zip("manual", 50)


class ConnectSetupTest(unittest.TestCase):
    def test_picks_the_watch_not_the_scale(self):
        self.assertEqual(cs.pick_watch(FakeConnect().get_devices())["deviceId"], 42)
        with self.assertRaises(SystemExit):
            cs.pick_watch([{"deviceId": 1, "productDisplayName": "A"}, {"deviceId": 2, "productDisplayName": "B"}])

    def test_snapshot_keeps_going_past_a_failed_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = cs.snapshot(FakeConnect(), None, Path(tmp))
            names = sorted(p.name for p in out.iterdir())
            self.assertEqual(names, ["device-settings.json", "devices.json", "goals.json",
                                     "hr-zones.json", "user-settings.json", "userprofile-settings.json"])
            self.assertIn("error", json.loads((out / "userprofile-settings.json").read_text()))

    def test_recover_diffs_the_settings_inside_activities(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = cs.recover(FakeConnect(), datetime.date(2026, 10, 25), Path(tmp))
            before = (out / "before-wipe.txt").read_text(encoding="utf-8")
            self.assertIn("device_settings[0] | backlight_mode = auto_brightness", before)
            self.assertNotIn("record[", before)
            changes = (out / "wipe-diff.txt").read_text(encoding="utf-8").splitlines()
            self.assertIn("~ device_settings[0] | backlight_mode = auto_brightness  ->  manual", changes)
            self.assertFalse(any("resting_heart_rate" in c for c in changes))

    def test_apply_is_a_dry_run_without_yes(self):
        api = FakeConnect()
        setup = {"user": {"userData": {"measurementSystem": "metric"}},
                 "device": {"activityTracking": {"moveAlertEnabled": True}},
                 "hr_zones": [{"sport": "DEFAULT", "maxHeartRateUsed": 186}]}
        cs.apply(api, setup, write=False)
        self.assertEqual(api.writes, [])
        cs.apply(api, setup, write=True)
        user, device, zones = api.writes
        self.assertEqual(user[1]["userData"], {"measurementSystem": "metric", "weight": 80000})
        self.assertEqual(device[1:], (42, {"activityTracking": {"moveAlertEnabled": True, "autoGoal": True}}))
        self.assertEqual(zones[1], [{"sport": "DEFAULT", "trainingMethod": "HR_MAX",
                                     "maxHeartRateUsed": 186, "zone1Floor": 95}])

    def test_apply_writes_nothing_when_already_matching(self):
        api = FakeConnect()
        cs.apply(api, {"device": {"backlight": {"mode": "AUTO"}}}, write=True)
        self.assertEqual(api.writes, [])


if __name__ == "__main__":
    unittest.main(verbosity=1)
