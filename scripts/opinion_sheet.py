"""Opinion sheet (the 2026-11-02 rounds with John): simulated four-hour HR windows, each row = the plain HR
graph | the face as worn (vermilion overlay on) | the art alone.

    python scripts/opinion_sheet.py <round> [case ...]   (cases from fidelity_test.CASES)

Writes ~/Downloads/ink-face-opinions-round-<round>.png (refuses to overwrite).
"""
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose_preview as cp  # noqa: E402
import fidelity_test as ft  # noqa: E402

TILE = 360
LABEL = 46
GAP = 8

# name -> (plain words, time of day, night)
PRESENT = {
    "flat_rest":      ("a quiet desk morning, 62 bpm the whole time", 11 * 60 + 5, False),
    "short_spike":    ("desk, then one flight of stairs (5 min at 125)", 15 * 60 + 20, False),
    "workout_oldest": ("gym first thing: 45 min at 135, then 3 h at a desk", 12 * 60 + 10, False),
    "workout_recent": ("3 h at a desk, then a 45 min workout just finished", 17 * 60 + 50, False),
    "long_walk":      ("a 90 min walk at 98 in the middle of the window", 14 * 60 + 30, False),
    "two_workouts":   ("two efforts: 30 min at 130 early, 30 min at 145 late", 10 * 60 + 40, False),
    "steady_climb":   ("a slow rise from 60 to 110 across the window", 16 * 60 + 15, False),
    "nap_dip":        ("75 awake, an hour asleep at 52, awake again", 13 * 60 + 25, False),
    "stress_plateau": ("evening: 70, then a tense two hours at 90 (night mode)", 22 * 60 + 40, True),
    "three_humps":    ("three moderate efforts: 100, 115, 105", 18 * 60 + 5, False),
    "intervals":      ("four 5 min intervals at 150 inside one hour", 9 * 60 + 30, False),
    "reboot_gap":     ("watch rebooted: no data for 90 min, then a workout", 12 * 60 + 45, False),
}


def main(argv):
    rnd = argv[1]
    names = argv[2:] or ["flat_rest", "short_spike", "workout_oldest", "workout_recent",
                         "long_walk", "two_workouts", "steady_climb", "nap_dip", "stress_plateau"]
    out_path = os.path.join(os.path.expanduser("~"), "Downloads",
                            "ink-face-opinions-round-%s.png" % rnd)
    if os.path.exists(out_path):
        sys.exit("refusing to overwrite " + out_path)
    cases = {name: (blurb, fn) for name, blurb, fn in ft.CASES}
    rows = []
    for k, name in enumerate(names):
        blurb, fn = cases[name]
        words, minute, night = PRESENT.get(name, (blurb, 14 * 60 + 42, False))
        seed = [n for n, _, _ in ft.CASES].index(name) + 1
        s = ft.score(ft.synthetic_rows(fn, seed=seed))
        worn = cp.compose(s["history"], minute_of_day=minute, hr_now=s["hr_now"],
                          night=night, trace=s["trace"])
        alone = cp.compose(s["history"], minute_of_day=minute, hr_now=s["hr_now"],
                           night=night, trace=None)
        rows.append((k + 1, name, words, s, ft.graph_tile(s), worn, alone))

    width = 3 * TILE + 4 * GAP
    header = 54
    sheet = Image.new("RGB", (width, header + len(rows) * (TILE + LABEL + GAP)), (252, 251, 248))
    d = ImageDraw.Draw(sheet)
    d.text((GAP, 8), "Ink face, round %s: what the four hours looked like  |  the face as worn (overlay on)  |  the art alone" % rnd,
           fill=(30, 30, 30), font=ft.font(17))
    d.text((GAP, 30), "The overlay is the true heart rate drawn on the mountains' own scale; the gap between red and ink is the art's departure from the data.",
           fill=(110, 110, 110), font=ft.font(13))
    y = header
    for num, name, words, s, graph, worn, alone in rows:
        d.text((GAP, y + 4), "%d. %s" % (num, words), fill=(20, 20, 20), font=ft.font(18))
        d.text((GAP, y + 26), "%s   r %s   peaks %d true / %d painted   overlay gap %s px" % (
            name, ft.fmt(s["r"], "%.2f"), s["true_peaks"], s["painted_peaks"],
            ft.fmt(s["gap_px"], "%.0f")), fill=(120, 120, 120), font=ft.font(13))
        ty = y + LABEL
        for i, img in enumerate((graph, worn.convert("RGB"), alone.convert("RGB"))):
            sheet.paste(img.resize((TILE, TILE), Image.LANCZOS), (GAP + i * (TILE + GAP), ty))
        y += TILE + LABEL + GAP
    sheet.save(out_path, optimize=True)
    print(out_path)


if __name__ == "__main__":
    main(sys.argv)
