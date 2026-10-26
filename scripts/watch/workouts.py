"""Strength workouts kept as TOML files and pushed to the watch through Garmin Connect.

    check            parse every workout file and resolve each exercise (offline)
    find TERM        search Garmin's exercise catalog by display name (offline)
    show NAME        print the JSON Garmin Connect would receive (offline)
    push [NAME...]   create or update each workout in Garmin Connect and send it
                     to the watch; --schedule DATE puts it on the calendar instead

Pushing uses the unofficial garminconnect library (Garmin's private web API), so
it can break when Garmin changes that API. A workout that already exists in
Garmin Connect under the same name is updated in place, never duplicated.
Login tokens are saved in ~/.garminconnect after the first login.
"""

from __future__ import annotations

import argparse
import getpass
import json
import sys
import tomllib
from pathlib import Path

from garminconnect import exercises
from garminconnect.workout import (
    StrengthWorkout, WorkoutSegment, create_strength_rest_step, create_strength_set,
    create_strength_timed_set,
)

WORKOUT_DIR = Path(__file__).resolve().parent / "workouts"
TOKEN_DIR = "~/.garminconnect"
STRENGTH = {"sportTypeId": 5, "sportTypeKey": "strength_training", "displayOrder": 5}


class WorkoutError(ValueError):
    pass


def _letters(text: str) -> str:
    """Lowercase letters and digits only, so "push up" matches "Push-up"."""
    return "".join(c for c in text.lower() if c.isalnum())


def find_exercises(term: str) -> list[dict]:
    """Names containing the whole term; failing that, those sharing the most words."""
    needle = _letters(term)
    hits = [e for e in exercises.EXERCISES if needle in _letters(e["name"])]
    if hits:
        return hits
    words = [_letters(w) for w in term.split() if len(_letters(w)) >= 3]
    scored = [(sum(w in _letters(e["name"]) for w in words), e) for e in exercises.EXERCISES]
    best = max((score for score, _ in scored), default=0)
    return [e for score, e in scored if best and score == best]


def resolve_exercise(name: str, where: str) -> dict:
    entry = exercises.resolve(name)
    if entry is not None:
        return entry
    exact = [e for e in exercises.EXERCISES if _letters(e["name"]) == _letters(name)]
    if len(exact) == 1:
        return exact[0]
    close = [e["name"] for e in find_exercises(name)][:8]
    hint = f" Close matches: {', '.join(close)}." if close else " Try: watch-tools.ps1 find <word>."
    raise WorkoutError(f"{where}: '{name}' is not in Garmin's exercise catalog.{hint}")


def build(spec: dict, where: str = "workout") -> StrengthWorkout:
    """A StrengthWorkout from one parsed TOML file."""
    name = spec.get("name")
    if not isinstance(name, str) or not name.strip():
        raise WorkoutError(f"{where}: needs a name")
    blocks = spec.get("block", [])
    if not blocks:
        raise WorkoutError(f"{where}: needs at least one [[block]]")
    steps = []
    order = 1
    estimate = 0
    for number, block in enumerate(blocks, start=1):
        at = f"{where} block {number}"
        rest = float(block.get("rest", 0))
        if "exercise" not in block:
            if rest <= 0:
                raise WorkoutError(f"{at}: needs an exercise, or rest on its own")
            steps.append(create_strength_rest_step(rest, order))
            order += 1
            estimate += rest
            continue
        entry = resolve_exercise(block["exercise"], at)
        sets = int(block.get("sets", 1))
        if sets < 1:
            raise WorkoutError(f"{at}: sets must be at least 1")
        common = dict(exercise_name=entry["exercise"], weight_kg=block.get("weight_kg"),
                      description=block.get("note"))
        if ("reps" in block) == ("seconds" in block):
            raise WorkoutError(f"{at}: give reps or seconds, not both or neither")
        if "reps" in block:
            steps.append(create_strength_set(entry["category"], order, sets, int(block["reps"]),
                                             rest, **common))
            estimate += sets * (3 * int(block["reps"]) + rest)
        else:
            seconds = float(block["seconds"])
            steps.append(create_strength_timed_set(entry["category"], order, sets, seconds,
                                                   rest, **common))
            estimate += sets * (seconds + rest)
        order += 3
    return StrengthWorkout(
        workoutName=name.strip(),
        description=spec.get("note"),
        estimatedDurationInSecs=int(estimate),
        workoutSegments=[WorkoutSegment(segmentOrder=1, sportType=dict(STRENGTH),
                                        workoutSteps=steps)],
    )


def load_all(folder: Path = WORKOUT_DIR) -> dict[str, StrengthWorkout]:
    workouts: dict[str, StrengthWorkout] = {}
    for path in sorted(folder.glob("*.toml")):
        with path.open("rb") as handle:
            workout = build(tomllib.load(handle), path.name)
        if workout.workoutName in workouts:
            raise WorkoutError(f"{path.name}: another file already uses the name '{workout.workoutName}'")
        workouts[workout.workoutName] = workout
    return workouts


def pick(workouts: dict[str, StrengthWorkout], names: list[str]) -> list[StrengthWorkout]:
    if not names:
        return list(workouts.values())
    missing = [n for n in names if n not in workouts]
    if missing:
        raise WorkoutError(f"No workout named {', '.join(missing)}. Have: {', '.join(workouts)}")
    return [workouts[n] for n in names]


def push(api, chosen: list[StrengthWorkout], schedule: str | None = None) -> list[str]:
    """Create or update each workout, then send it to the watch or the calendar."""
    existing = {}
    start = 0
    while True:
        page = api.get_workouts(start, 100) or []
        for item in page:
            existing.setdefault(item.get("workoutName"), item.get("workoutId"))
        if len(page) < 100:
            break
        start += 100
    report = []
    for workout in chosen:
        body = workout.to_dict()
        workout_id = existing.get(workout.workoutName)
        if workout_id:
            api.update_workout(workout_id, body)
            action = "updated"
        else:
            workout_id = api.upload_workout(body)["workoutId"]
            action = "created"
        if schedule:
            api.schedule_workout(workout_id, schedule)
            where = f"scheduled for {schedule}"
        else:
            api.push_workout_to_device(workout_id)
            where = "sent to the watch"
        report.append(f"[{action}] {workout.workoutName} (id {workout_id}), {where}")
    return report


def connect():
    """A logged-in Garmin client; asks for credentials only when no saved token works."""
    from garminconnect import Garmin

    try:
        api = Garmin()
        api.login(TOKEN_DIR)
        return api
    except Exception:
        pass
    print("Garmin Connect login (the token is saved in ~/.garminconnect; the password is not).")
    email = input("Email: ").strip()
    password = getpass.getpass("Password: ")
    api = Garmin(email, password, prompt_mfa=lambda: input("MFA code: ").strip())
    api.login(TOKEN_DIR)
    return api


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("check")
    find = sub.add_parser("find")
    find.add_argument("term")
    show = sub.add_parser("show")
    show.add_argument("name")
    send = sub.add_parser("push")
    send.add_argument("names", nargs="*")
    send.add_argument("--schedule", metavar="YYYY-MM-DD")
    args = parser.parse_args(argv)

    try:
        if args.command == "find":
            found = find_exercises(args.term)
            for entry in found:
                print(f"{entry['name']:<48} {entry['category']} / {entry['exercise']}")
            if not found:
                print(f"No exercise in Garmin's catalog matches '{args.term}'.")
            return 0
        workouts = load_all()
        if args.command == "check":
            for name, workout in workouts.items():
                minutes = workout.estimatedDurationInSecs / 60
                print(f"[ok] {name}: {len(workout.workoutSegments[0].workoutSteps)} blocks, ~{minutes:.0f} min")
            return 0
        if args.command == "show":
            print(json.dumps(pick(workouts, [args.name])[0].to_dict(), indent=2))
            return 0
        chosen = pick(workouts, args.names)
        for line in push(connect(), chosen, args.schedule):
            print(line)
        return 0
    except WorkoutError as error:
        print(f"[error] {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
