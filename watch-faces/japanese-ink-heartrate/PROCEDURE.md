# Japanese Ink Heartrate — Working Procedure

Last updated: 2026-11-02

**Purpose of this doc.** Capture the full code → build → push → capture → review → iterate loop for this watch face, with *explicit* roles for you (the human driver) and the LLM agent (Claude). Written so a cold-start session — yours or the agent's — can pick up and keep going without context loss.

This is the operational manual. For *what* we're trying to build and *why* prior attempts failed, see:

- [Project Vision](JAPANESE_INK_HEARTRATE.md) — the north star
- [Art Pipeline](ART_PIPELINE.md) — **the current methods doc**: offline complete-painting authoring, generator techniques, preview→port contract, device translation gaps
- [Renderer Plan](RENDERER_PLAN.md) — diagnosis, strategy, acceptance criteria (asset-family sections superseded by the 2026-06-10 pivot note)
- [HR Facts](ROOT_HR_FACTS.md) — Garmin heart-rate API behavior

---

## 1. One-minute orientation

- The watch face is at `watch-faces/japanese-ink-heartrate/`.
- The root jungle at `monkey.jungle` (repo root) points at it. That's the build target.
- The art is **pieces of the ChatGPT and Gemini sheets** in `art/sheets/` (2026-11-05 decision, top of ART_PIPELINE.md): the masses from `scripts/gen_shape_library.py`, the far range, mist and near hills from `scripts/bake_planes.py`, the foreground from `scripts/bake_foregrounds.py`, the ridge trees from `scripts/bake_trees.py`; only the paper grain is still script-made (`scripts/gen_ink_layers.py`). Layout is proven in `scripts/compose_preview.py` and placed by `drawScaledBitmap` calls. See ART_PIPELINE.md.
- **Iterate art in Python first** (gen → preview → Read the PNG); build for the watch only to verify the port.
- Each iteration makes **one coherent change**, then produces a **paired checkpoint** (`YYYY-MM-DD_HHMM_name.png` + `.md`) under `art/checkpoints/procedural/`.
- The `.md` is the review record: Intent, Changes, Key Code, Result, What Improved, What Got Worse, Deviation From Goal, Next Move.

---

## 2. Who does what

### Roles

| Role | Who | What they do |
|---|---|---|
| **Driver** | You | Start the sim, approve changes, make aesthetic judgment calls, decide when an asset needs hand-authoring |
| **Agent** | Claude (this session) | Edit code, run the build/push script, run the capture script, read the PNG, write the paired `.md`, propose the next iteration |

### Handoff points

The agent can do everything except two things:

1. **Launch the simulator once per session.** The agent's shell can invoke it but the GUI needs to actually appear and stay open; the simplest contract is "you open it, you keep it open."
2. **Aesthetic judgment when the agent is wrong.** If a checkpoint reads wrong to your eye but the agent thinks it's progress (or vice versa), your call wins.

Everything else — edits, builds, pushes, screenshots, writing the paired `.md` — is agent-driven via scripts already in the repo.

---

## 3. Session startup (do this once per work session)

**You:**

1. Open VS Code at the repository root.
2. Launch the simulator. In a shell, run:
   ```powershell
   $sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
   $sdk = Get-ChildItem $sdkRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   & (Join-Path $sdk.FullName "bin\connectiq.bat")
   ```
   A blank CIQ Simulator window appears. **Blank is correct** — it waits for a push. Leave this window open for the whole session; you do not re-launch per iteration.
3. Start (or resume) a Claude Code session in this repo.
4. Tell the agent what you want to work on. Usually: "continue iteration" or "try X next."

**Agent (at session start):**

1. Read `MEMORY.md` (auto-loaded).
2. If memory is thin on this project, read in order:
   - `watch-faces/japanese-ink-heartrate/RENDERER_PLAN.md`
   - `watch-faces/japanese-ink-heartrate/PROCEDURE.md` (this file)
   - The most recent two `.md` files in `watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/` (to learn where the iteration is).
3. Confirm with the user what iteration number they're on.

---

## 4. The iteration loop

One cycle changes one thing, captures it, annotates it, and proposes the next thing. Expected duration: 2–10 minutes of agent work plus your review time.

### Step 0 — Name the iteration

The agent decides on a short, descriptive, kebab-case name for this change. Examples: `iter2-body-wash-png`, `iter3-dual-descent`, `iter11b-inscription-shore-far`. The full checkpoint filename pattern is:

```
watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/YYYY-MM-DD_HHMM_<name>.png
watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/YYYY-MM-DD_HHMM_<name>.md
```

**`HHMM` (24h capture time) is mandatory** — added 2026-06-10 after same-day
captures with near-identical names became confusing. Every capture gets a
fresh timestamp; never overwrite an existing checkpoint PNG. If a capture
attempt fails and is retried, the retry gets the new time.

### Step 1 — Agent: make the change

Edit code in `watch-faces/japanese-ink-heartrate/`. Typical touchpoints:

- `source/JapaneseInkHeartrateScene.mc` — the renderer
- `source/JapaneseInkHeartrateView.mc` — the watch-face view (time, AOD, buffer orchestration)
- `resources/drawables/drawables.xml` — bitmap resource declarations
- `resources/drawables/*.png` — bitmap assets
- `scripts/gen-*.py` — asset generators (Python Pillow scripts, if used)

**Rules:**
- Keep scene composition under the hard caps in RENDERER_PLAN §8 (≤5 peaks, ≤2 descents, ≤2 crests, ≤2 mist strips, ≤2 trees).
- Never reintroduce anti-goals from RENDERER_PLAN §10 (hard bands, chart lines, stamp rows, etc.).
- If authoring a new PNG, register it in `drawables.xml` **with tuned-import settings**:
  ```xml
  <bitmap id="MyAssetTuned" filename="my_asset.png"
          dithering="none" automaticPalette="false"
          packingFormat="png" compress="false" />
  ```

### Step 2 — Agent: write the paired `.md` stub

Before building, write `art/checkpoints/procedural/YYYY-MM-DD_HHMM_<name>.md` with the first three sections filled in:

- **Intent** — what are we testing, what question does this iteration answer
- **Changes** — concrete diff summary
- **Key Code** — the 5–15 lines that matter

Leave Result / What Improved / What Got Worse / Deviation / Next Move as "*(post-capture)*" placeholders.

Writing the stub **before** capture forces the agent to commit to an intent that the capture can then confirm or refute.

### Step 3 — Agent: build, push, and capture

One command:

```bash
bash scripts/build-and-run.sh "$PWD/watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/YYYY-MM-DD_HHMM_<name>.png"
```

This wraps `monkeyc` + `monkeydo` + `save-sim-capture.ps1`. It derives the repository path from the script, finds the newest installed SDK, and accepts `CONNECTIQ_SDK_PATH` and `MONKEYC_DEVELOPER_KEY` overrides. The tracked capture helper lives at `scripts/save-sim-capture.ps1`; `build-and-run.sh` retains the old gitignored checkpoint location only as a fallback for older checkouts. Expected output:

```
[build] monkeyc ... BUILD SUCCESSFUL
[push]  monkeydo -> fr265
[capture] <path>.png
```

The capture script drives the sim's **File → Save Screen Capture** menu via guarded keystroke automation. It requires one simulator window, verifies focus, refuses a pre-existing output, pastes the absolute path while preserving the clipboard, and waits for a newly written non-empty file.

The result is a tight watch-face-only PNG, identical to manually clicking File → Save Screen Capture.

**Without a path argument**, the script only builds and pushes — useful when you want to eyeball the sim before capturing.

**If the build fails** → fix and re-run. Do not proceed until `BUILD SUCCESSFUL`.

**If the push fails** → the sim isn't running, or it's running an incompatible device id. See §7 Troubleshooting.

**If the capture fails** → see §7 "Capture script says..." entries.

### Step 4 — Agent: read the PNG, annotate the `.md`

Read the saved PNG with the Read tool. Fill in the remaining `.md` sections:

- **Result** — describe what's actually rendered (elements, positions, tones)
- **What Improved** — compared to the last iteration
- **What Got Worse** — honesty matters more than optimism here
- **Deviation From Goal** — how far from the RENDERER_PLAN acceptance criteria (§11)
- **Next Move** — the specific question the next iteration should answer

### Step 5 — Human: review

You look at the PNG and the annotated `.md`. You either:

- **Agree** with the agent's read → tell it to proceed with the proposed Next Move
- **Disagree** → explain what you see differently; the agent updates the `.md` and re-proposes
- **Pause** → anything other than "proceed" stops the loop

### Step 6 — Loop

Back to Step 0 with the new iteration name.

---

## 5. File and folder layout

Only the parts that matter for this loop:

```
<repo-root>\
├── monkey.jungle                              build entry — points at the watch face manifest
├── bin/
│   └── mygarminwatchfaces.prg                 build output (rewritten each build)
├── scripts/
│   ├── build-and-run.sh                       monkeyc + monkeydo wrapper
│   └── save-sim-capture.ps1                   guarded simulator screenshot helper
└── watch-faces/
    └── japanese-ink-heartrate/
        ├── JAPANESE_INK_HEARTRATE.md          vision (stable)
        ├── RENDERER_PLAN.md                   strategy + acceptance criteria (stable)
        ├── PROCEDURE.md                       this doc
        ├── ROOT_HR_FACTS.md                   Garmin HR API reference
        ├── manifest.xml                       device + permission declarations
        ├── monkey.jungle                      face-local jungle (the root one inherits from this)
        ├── source/
        │   ├── JapaneseInkHeartrateApp.mc     app bootstrap
        │   ├── JapaneseInkHeartrateView.mc    watch-face view (time, AOD, buffer orchestration)
        │   ├── JapaneseInkHeartrateScene.mc   renderer (the main editing target)
        │   └── JapaneseInkHeartrateDelegate.mc   input delegate (unused for now)
        ├── resources/
        │   ├── drawables/
        │   │   ├── drawables.xml              bitmap registrations (tuned imports here)
        │   │   ├── launcher_icon.png
        │   │   └── vertical_fade_descent.png  tuned-import-validated asset
        │   └── strings/
        │       └── strings.xml
        └── art/
            ├── references/                    inspiration (not touched by the loop)
            └── checkpoints/
                └── procedural/
                    ├── PROCEDURAL_IMAGES.md   naming convention
                    ├── save-sim-capture.ps1   legacy ignored copy; tracked helper is under scripts/
                    └── YYYY-MM-DD_*.png/.md   paired checkpoints (the history)
```

---

## 6. Command reference

### Launch the sim (once per session, human)

```powershell
$sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
$sdk = Get-ChildItem $sdkRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
& (Join-Path $sdk.FullName "bin\connectiq.bat")
```

### Build + push (every iteration, agent)

```bash
bash scripts/build-and-run.sh
```

Contents: `monkeyc.bat -o <repo-root>/bin/mygarminwatchfaces.prg -f <repo-root>/monkey.jungle -y <developer-key> -d fr265 -w -l 2` then `monkeydo.bat <repo-root>/bin/mygarminwatchfaces.prg fr265`. Device id is `fr265`, **not** `fr265_sim` (see §7).

### Capture screenshot (every iteration, agent)

```powershell
& ".\scripts\save-sim-capture.ps1" -OutputPath "<absolute-output-path>.png"
# (or the gitignored copy under art\checkpoints\procedural\ on the PC that wrote it)
```

### Inspect simulator state (optional, human)

The sim supports simulated heart rate data via **Simulation → Data Fields → Heart Rate History** (or similar). Useful once we integrate real HR history.

### Manual build-only (rarely needed, agent)

```bash
export CONNECTIQ_SDK_PATH="C:/path/to/connectiq-sdk"
export MONKEYC_DEVELOPER_KEY="C:/path/to/developer_key"
"$CONNECTIQ_SDK_PATH/bin/monkeyc.bat" \
  -o "$PWD/bin/mygarminwatchfaces.prg" \
  -f "$PWD/monkey.jungle" \
  -y "$MONKEYC_DEVELOPER_KEY" \
  -d fr265 -w -l 2
```

### Manual push-only (if build hasn't changed)

```bash
"$CONNECTIQ_SDK_PATH/bin/monkeydo.bat" \
  "$PWD/bin/mygarminwatchfaces.prg" fr265
```

---

## 7. Troubleshooting

### "Unable to connect to simulator" on `monkeydo`

The simulator is not running. Launch it via `connectiq.bat` (§3 step 2) and retry.

### "Unable to load device fr265_sim" popup in the sim

You built or pushed with `-d fr265_sim`. From the CLI, use `-d fr265`. `fr265_sim` is a VS Code extension F5-only target; the running sim binds to `fr265` (the device cache folder name at `~/AppData/Roaming/Garmin/ConnectIQ/Devices/fr265/`).

### Capture script says "Simulator window not found"

The simulator is not running, has no main window, or multiple simulator windows are open.

Fixes, in order:
1. Ensure the simulator has finished opening a real window.
2. Close extra CIQ Simulator instances; the helper deliberately refuses an ambiguous target.
3. Retry. The helper restores and focuses the single window before sending keys.

(2026-06-10: the script now restores + force-foregrounds the sim via Win32
`ShowWindow`/`SetForegroundWindow` before sending keys, so a minimized or
background sim no longer silently eats the keystrokes.)

### Capture PNG shows a black screen with a blue/teal play triangle

That is the simulator's "no app running" screen, photographed mid-push. The
`build-and-run.sh` capture step can race the backgrounded `monkeydo` if the
sim is slow to (re)load the app. Not a crash. Fix: re-run `monkeydo` (or just
wait a few seconds) and re-capture **to a new timestamped filename**.

### Capture script runs but writes to wrong folder

The sim's Save Screen Capture dialog may have "remembered" a different default folder. The script types the *absolute* path into the dialog, so it should override. If it doesn't, try raising `-DialogDelayMs` (default 1000) — the typing might be starting before the dialog is ready.

### Build hangs or produces a watchdog timeout on the watch

Scene render is too heavy. Check that nothing in `renderScene` does a per-pixel loop (`drawPoint` over thousands of coords). All rendering should be stamps + polygons + rectangles into the buffered bitmap. See RENDERER_PLAN §8 hard caps.

### "Member '$.X' is untyped" warning

Informational only. Fix by adding a Lang type annotation (`var mX as SomeType = ...`) if it nags; ignore otherwise.

### Checkpoint PNG renders as all black or all paper (no renderer elements)

Something in `renderScene` is throwing an exception and the buffered bitmap is never populated. Check `System.println` output in the sim's console, or temporarily wrap calls to narrow down the faulting function.

### Sim keeps showing the OLD version after push

- Confirm `monkeydo` returned without error.
- Confirm the sim window refreshed — usually it auto-reloads. If not, File → Reload (or close + relaunch).

---

## 8. Resuming after interruption

### Short break (same day, same Claude session)

Just pick up: "What were we on?" The agent reads the latest checkpoint `.md` and reports.

### Cold start (new day, new Claude session)

Tell the new agent:

> We're working on the Japanese ink heartrate watch face. Read `watch-faces/japanese-ink-heartrate/PROCEDURE.md` and the two most recent checkpoints in `art/checkpoints/procedural/`, then tell me where we are and what iteration N should test.

The agent should:

1. Read PROCEDURE.md (this file).
2. Read RENDERER_PLAN.md.
3. `ls` the procedural checkpoints folder, sort by filename (date-prefixed), read the two most recent `.md` files.
4. Summarize: "Last iteration was X. Outcome was Y. Proposed next move was Z. Do you want to do Z, or change direction?"

### After a long interruption (weeks+)

Same cold-start, plus: look at whether `RENDERER_PLAN.md` needs updating. If several iterations revealed that one of its assumptions was wrong, update the plan **before** starting the next iteration. The plan is supposed to be the current authoritative thinking, not a historical snapshot.

---

## 9. Asset authoring rules (when iterations require new PNGs)

### The tuned-import contract

Every new bitmap registered in `drawables.xml` **must** use the tuned import settings. Default imports quantize alpha and wreck softness. The only asset currently proven to survive the Garmin bitmap pipeline is `VerticalFadeDescentTuned`, imported as:

```xml
<bitmap id="VerticalFadeDescentTuned" filename="vertical_fade_descent.png"
        dithering="none" automaticPalette="false"
        packingFormat="png" compress="false" />
```

Replicate this attribute set for every new asset.

### Author lighter than you think

Repeated placement darkens. If the source PNG looks "right" in isolation, it will look muddy when stamped. Author at ~60–70% of intended final darkness.

### Never repeat the same asset at the same scale in one scene

Part of the "no visible primitive" rule. Vary scale by ≥15% between placements, or flip horizontally.

### Source file location

Commit source PNGs to `watch-faces/japanese-ink-heartrate/resources/drawables/`.

If generated by a Pillow script, commit the script to `scripts/gen-<assetname>.py` so regeneration is deterministic.

---

## 10. Current state (updated 2026-11-05)

- **2026-11-05 the numerals are from the sheets.** `scripts/bake_glyphs.py`
  replaced gen_ink_font.py's script-brushed glyphs with John's picks from
  round 9: ChatGPT's minute digits and seal digits, Gemini's hour kanji
  (both wrote all twelve correctly; John found Gemini's the better kanji and
  ChatGPT's digits less machine-made). Same line metrics, so the View is
  unchanged; `gen_halo.py` remade the halos from the new atlases. The work
  seal is now a rectangle (`seal_rect`, props2-b's square seal widened to
  52x34) so three digits fit; rectangular seals are canon.

- **2026-11-05 the signals plan (agreed, not built).** John agreed the
  same evening that the face shows a busy data face's facts as pieces that
  appear only while something is out of the ordinary, one meaning each.
  Weather owns the sky slot in place of the sun or moon: the sun in mist
  for overcast, fog, haze or smoke (ground fog in the valley at night until
  there is a moon in mist), cloud wisps beside the sun for partly cloudy,
  rain for rain, gathering clouds for rain within three hours (piece
  wanted); the sun follows the real sunrise and sunset. A heron when the
  move bar fills (sat too long), a deer for body battery 75+ in the
  morning, the torii for the weekly intensity goal, a pagoda for the floors
  goal, a small swallow (24 px) for unread notifications (not the crane: it
  looked too like the heron), a boat on the lake when the phone is out of
  reach, the seal turned enso (HR inside) for do-not-disturb, a bridge for
  a calendar event within the hour (Complications, last). Slots keep it
  quiet: one sky piece, two birds, one valley piece (mountains win it; the
  filler drops first), the hiker, the lantern, the seal. Stale weather
  (over 3 hours, or no phone) shows the plain sun or moon. Left off:
  temperature, stress (the mountains already say it), seasonal fillers.
  The gate is `Toybox.Weather` on a face at a home build. The missing
  pieces are asked for in PROMPTS.md round 9.
  **Each piece gets its own on/off toggle** in the watch's Customize menu,
  below "True HR line" (John, 11-05), e.g. "Lantern = Low Batt", "Swallow
  = Notifications", "Deer = High Body Batt", "Heron = No Movement", "Hiker
  = Workout Summit".
  Also "Hour in kanji": off draws the hour in the same brush digits as the
  minutes. The date comes back as John's "Red seal = HR" toggle (11-05):
  off, the seal carries the date instead, month over day stacked in the
  square seal (props2-b 13 at 42x42), as a four-character seal is laid
  out. Proposed with it: the seal digits baked a little crooked (each
  glyph turned a few degrees, scaled a little, lifted or dropped a px,
  one side shaved as if cropped wrong) plus a fixed nudge per position,
  so the HR and the date stop reading as computer type. John picked the
  crooked-plus-nudged look; built in 83efe87 (bake_glyphs CROOKED, mock
  draw_nudged / SEAL_NUDGE, View drawSealText / SEAL_NUDGE_X/Y, setting
  `sealHr`, prop seal_square), unbuilt at home.

- **2026-11-05 the weather is painted over the scene (round 10).** One
  whole-face painting per kind, one copy sized to the face, never tiled or
  mirrored (John), drawn behind the grasses: after the masses and the air
  props, before the near hills, the mist and the foreground
  (`bake_weather.py`, mock `compose(weather=)`, Scene `readWeather` /
  `weatherForCondition`). John's picks: light rain = ChatGPT's sparse rain
  (rain2-b, "the rain aint it": the first rain was too dense) at 80%,
  rain = the same doubled, a faded copy shifted across the face over it
  (John's pick: turned 180 "looks like rain is shooting back up"), storm = ChatGPT's storm
  faded to 55% (the lightning comes with it), snow = Gemini's fuller snow (snowfall2-a) over a 22%
  grey sky wash by day, wind = ChatGPT's second wind, wind2-b (a few leaves on long streaks; John:
  "new wind is def better" than Gemini's busier leaves; a windy forecast or
  wind over 8 m/s; "leaves mean wind"). Rain, storm and snow replace the
  sun or moon; wind does not. Nothing is kept clear for the clock: the
  paper halos fade whatever lies under the time (a blank corner "looks
  like we missed a spot"). An observation over 3 hours old shows nothing.
  New setting "Weather" (on). The seal halos now follow each seal's own
  outline (`gen_halo.py` from the baked seal props): the old square halo
  showed around the oval. On a snow day the time's paper halo is a
  light patch on the grey wash, kept as is (John: "the snow is cool").
  Open: winter and spring leaves are not painted
  yet (the maple blows all year). Unverified at a build: `Toybox.Weather`
  on a face and every `CONDITION_*` name.

- **2026-11-05 the seal is from the sheet, and its shape tells effort.**
  The red square the View drew under the time is gone: `bake_props.py`
  bakes props2-b's two seals, the oval (turned on its side so three digits
  fit) and the square, and the View draws one centered where the square was,
  the live HR on it in the seal digits as before. John's rule: the **oval**
  while the HR rests near the baseline, the **rectangle** once it
  stands `SEAL_WORK` (30) bpm over it, back to the oval `SEAL_HYST` (8) bpm under
  that line so it does not flicker (Scene `sealWork`, mock `seal_shape`).
  The baseline is the profile's resting HR (`UserProfile`, a new manifest
  permission), else the window's floor. The hiker lost the grass and level
  ground baked under him, which stuck out sideways from a sloped summit
  (`TRIM` in bake_props), and he now stands just below the summit
  (`HIKER_SINK` 12 px) so what is left of his ground sits inside the
  mountain. Unverified at a
  build: the `UserProfile` permission and `restingHeartRate` on a face.

- **2026-11-05 the props: one rule each.** John chose the rules the same
  evening: a prop always means something. `scripts/bake_props.py` bakes nine
  pieces of the ChatGPT prop sheets at the size they are drawn (1:1), day
  and night, and the mock (`compose_preview.prop_rules`) and the Scene
  (`drawCelestial`, `drawValleyProp`, `drawAirProps`, step 6b) place them:
  the **sun** (06:00-18:00) and the **moon** by its real phase (full within
  1.85 days of full, none within 1.85 days of new, else the waxing or the
  mirrored waning crescent) on the arc, in place of the code-drawn discs;
  **geese** when today's step goal is met (`ActivityMonitor.getInfo`), on
  the side of the sky away from the sun or moon; a **village** (even days)
  or **hut** (odd) in a window with a horizon and no mountain, in the valley
  under the far range; a **hiker** on the highest summit standing 30 bpm
  over the floor whose figure is clear of the time column (John: "idk
  maybe", so it is on the sheet for a verdict); a stone **lantern** on the
  foreground's ground under 30% battery (`System.getSystemStats`). The
  inputs are read once per five-minute scene job. Masses carry their
  elevation now (`M_ELEV`, the mock's `"elev"`). 0.06 MB. Not built: rain
  (weather), the fishing boat, and the leftover props. **Wanted next (John,
  11-05): the sun in mist (props 02) as a weather teller**, in place of the
  plain sun when the weather is misty or overcast (needs the watch's
  weather read on a watch face, unverified). Unverified at a
  build: `ActivityMonitor.getInfo().steps`/`stepGoal` and the battery read on
  a watch face, and the moon arithmetic in single-precision floats (the
  phase is a day count of about 9,800, so a float keeps it to about a
  minute).

- **2026-11-05 the far range, mist and near hills are sheet pieces.**
  `scripts/bake_planes.py` bakes five strips of the ChatGPT strip sheet
  (`art/sheets/2026-11-05_strips-b.png`, PROMPTS.md 4.2) into the planes
  the Scene already placed, day and night: the far range (`horizon.png`)
  from the soft far hills, cropped to its ink so every column of the face
  has a horizon (the palest strip, far_pale, all but vanished at 416 px);
  the two mist bands from the dense mist and the wisps, their grey wash read
  as mist density and colored paper (black at night), each baked at the size
  the Scene draws it; the near hills as 2:1 windows of the pine ridge (outer
  thirds) and the bare ridge (middle), paper-backed like the library, their
  feet fading over the bottom 40% and their cut sides dissolving over 30% of
  the width. RGBA, not a palette: 256 colors banded the soft feathers. Ten
  bitmaps, 0.26 MB (the old planes were about the same). Sizes, crests and
  loaders are generated (`source/JapaneseInkHeartratePlanes.mc`,
  `resources/drawables/planes.xml`, `scripts/plane_table.json`); the
  Scene's own `HORIZON_*` and `MIST_*` constants and its hand-measured
  near-hill crests are gone, the placement is unchanged.
  `scripts/bake_cutouts.py` is retired, and `gen_ink_layers.py` now makes
  only the paper grain (byte-identical). Every script-made plane PNG left
  `resources/drawables` (also the round-6 masses no build had used since
  11-03). Fidelity (`common/fidelity/2026-11-05_1331`): `r` 0.83 over all
  cases, 0.90 non-flat (0.84 and 0.91 with the level script horizon), a
  10 px overlay gap (5) and 28 px of flat-rest relief (1): the far range
  is real hills now, not a level line. The mock's `--probe` card loads the
  library's renamed peak and spire again (broken since the library
  commit). Unverified at a build: the generated constants (globals now,
  not class constants) and the new loaders.

- **2026-11-05 the foreground is a whole-face painting from the sheets.**
  `scripts/bake_foregrounds.py` bakes the ten picks of rounds 6 and 7
  (`art/sheets/PROMPTS.md`: ChatGPT's five seasons, Gemini's five, one
  place through the seasons) at the face's size, day and night (night at
  full alpha in pale ink, the red dimmed to 60%: round 4's "night
  foregrounds are too faint" and round 6's loud red), as 256-color palette
  PNGs: 20 bitmaps, 0.32 MB. Which one shows
  (`compose_preview.foreground_index`, the Scene's `foregroundIndex`): the
  season from the month (Dec-Feb winter, Mar-May spring, Jun-Aug summer,
  Sep-Nov autumn) unless the new "foreground" setting names a scene (1..5:
  spring, summer, autumn, winter, mountain pass; a row in the watch's
  Customize menu and in settings.xml), and the painter alternating with the
  day of the month (even ChatGPT, odd Gemini). It is loaded per render and
  drawn over everything but the grain (`drawScaledBitmap` to the screen; the
  bake is 416 px square). The two script-painted foreground masses
  (`fg_left`, `fg_right`, sized by the window's oldest and newest hour) are
  gone from the Scene, the mock, `drawables.xml` and `gen_ink_layers.py`.
  The mock takes `--month`, `--day` and `--scene`. Unverified at a build:
  `Time.Gregorian.info(..., FORMAT_SHORT).month` read as a Number (the
  Scene falls back to January if it is a String), the palette PNGs (as the
  library's), and the Customize row. Still script-made then: the far range,
  both mist bands, the near hills and the grain (the next entry above).

- **2026-11-05 the library is the 24 ChatGPT mountains.** Per the art
  decision (top of ART_PIPELINE.md) `scripts/gen_shape_library.py` no longer
  paints: it takes the two ChatGPT mountain sheets' cutouts
  (`art/cuts/mountains-b`, `mountains2-b`; `cut_art_kit.py` cuts them
  unbacked now), scales each by 1.2 (one factor, so the sheet's relative
  sizes survive; the fit's r was the same at 1.0, 1.2 and 1.4, and the bytes
  grow with the square), keeps 70% of the ink and pulls the rest to paper
  (the sheets' solid black read too heavy beside the pale far range; the
  trees and the foreground stay darker, nearer), paper-backs it with a skirt
  down to 300 px (the body under the ridge hides what stands behind, fading
  over the bottom 30%, as before), and packs each cutout as a 256-color
  palette PNG: 48 bitmaps, 0.66 MB (RGBA would be 3.7 MB; the painted
  library was 3.3 MB). The fit now stretches width: per shape ONE candidate,
  its columns over the far bank spanning the run (0.67x to 1.5x,
  `FIT_STRETCH`; the height never changes; `drawScaledBitmap` already drew
  `m[2]`), in `compose_preview.fit_shape` and the Scene's `scoreFitShape`
  together (`mFitBestStretch`, `FIT_STRETCH_LO/HI`). A float32
  transliteration of the Scene's fit picked the mock's shape in 131 of 133
  windows, 133 in float64: the two are near ties. Fidelity
  (`common/fidelity/2026-11-05_1059_fidelity.md`): mean r 0.84 over all 13
  cases, 0.91 over the twelve non-flat ones (the 10:41 report, the painted
  library plus trees: 0.74 and 0.80), gap 5 px, peaks 11/13. The §13 probe
  uses `shape_peak` and `shape_spire`. Unverified at a build: a palette PNG
  with alpha through the resource compiler (if the mountains come out wrong,
  bake with `PALETTE = 0`, 3.7 MB), the 48-branch `loadShapeBitmap`, and
  the stretch's cost in the fit chunk (32 extra reads per shape).

- **Wash study (2026-11-04).** The shape-library generator then baked
  low-frequency ink pooling and finer dry-paper variation into the color of
  each mountain. The cutout alpha and its measured skyline are unchanged;
  this adds no on-watch draw calls. Day and night mock comparisons are in
  `common/fidelity/2026-11-04_wash-comparison.png`. These are synthetic
  previews, not a wrist or simulator capture. A rougher-ridge experiment was
  rejected after it lowered the synthetic mean correlation from 0.72 to 0.71.
  The textured FR265 build is about 4.0 MB (formerly 1.89 MB); installation
  and appearance on the physical watch still need verification.

- **2026-11-03 the shape fit is spread across updates.** The first watch-side
  shape-library render tripped `Code Executed Too Long`: one `onUpdate` did
  history setup, up to 26 shapes x 6 placements x 58 samples for every run,
  and the final bitmap paint. A scene refresh is now a small state machine:
  one update gathers history/runs/samples/base costs, later updates score at
  most 8 complete shapes (48 placements). The last scoring chunk sorts the
  masses and lays out the near hills; the next update paints the replacement
  buffer. Shape,
  placement, sample, and strict first-on-tie order are unchanged, so the
  winning shapes are unchanged. The old buffer stays visible during a refresh;
  first launch shows paper, celestial mark, and horizon until the fit is ready.
  FR265 AMOLED low power intentionally pauses Scene work. Wake resumes the
  coherent pending job even after a five-minute boundary, then on the next
  active update schedules the newest key after that frame commits; short wrist glances cannot
  starve the fit by repeatedly restarting it. Once an old scene exists, its
  day/night palette remains displayed until the replacement buffer is committed.
  `FIT_SHAPES_PER_UPDATE = 8` is the safety/latency knob; lowering it changes
  refresh latency, not fit results.
  Verification on 2026-11-03: `monkeyc -d fr265 -w -l 2` builds it (about
  1.89 MB; the size moves a few bytes with the output path, which the PRG
  records). With the simulator window up it ran 6 min 43 s across a
  scene-key boundary with an empty console (no watchdog, no out-of-memory),
  the masses drawn within 20 s of launch, 41 of 124 KB heap. Still open: the
  simulator's low-power toggle and a simulator-vs-preview capture.
  The bitmap budget on the FR265 itself
  (`common/home-verify/2026-11-03_1933_bitmap-budget-watch.md`): 200 of 200
  cutout-sized planes loaded, median 57 ms and slowest 227 ms each (the
  simulator: 16 ms), 48 held at once with no failure (the probe's cap), about
  334 bytes of app heap per held plane. The library's 52 bitmaps fit; a
  render that loads a handful of shapes costs a few hundred ms once per
  scene key.

- **2026-11-03 later: the shape library replaces the stretched planes.**
  A shan shui study (assembling mountains from brush primitives, John:
  "200 primitives smashed into a bespoke shape is actually worse than 50
  known shapes") and a fit test over 93 windows led here: each mass is one
  whole painted mountain CHOSEN from a library and drawn at its baked size,
  its crest sunk onto the run's peak, never stretched.
  `scripts/gen_shape_library.py` paints 26 shapes with `render_plane`
  (spire, peak, dome, lean left/right, plateau, ridge, wide left/right,
  ramp up/down, in 2–3 widths; all 300 px tall, skirt at the bottom; ONE
  summit each), bakes day and night cutouts (52 bitmaps, about 2 MB of
  PNG), and writes the profile table twice: `scripts/shape_table.json` for
  the mock and `source/JapaneseInkHeartrateShapes.mc` plus
  `resources/drawables/shapes.xml` for the watch (`--check` says when they
  are stale). The fit (`compose_preview.fit_shape`, Scene `scoreFitShape` plus
  the staged job methods): per
  run, every shape with its crest on the peak, its apex at the run's
  summit or 12/24 px either side, or centered on the run; scored on the
  trace samples under it (distance to the data, heavier on high ground,
  2x where the ink stands over the data, 1 per px of apex off the summit);
  a shape whose bottom would show above 0.80 H is skipped. A float32
  transliteration of the Monkey C picked the same shape at the same place
  as the mock in 133 of 133 windows. Fidelity (13 cases, same test):
  mean overlay gap 7 px (round 6: 11), mean r 0.72 (0.57). All masses use
  the dark ink now (no pale twins). The round-6 spire/broad/wide cutouts
  left the watch; `bake_cutouts.py` bakes only the near hills; the §13
  probe uses `shape_peak_300` and `shape_spire_180`. Watch for at the
  build: the generated `loadShapeBitmap` (52 branches), typed locals
  `var x as T? = null`, and the fit's cost per refresh. The watchdog fix above
  preserves all six placements and slices the 26-shape search across updates.

- **2026-11-03 the round-6 relief ported to the Scene, blind.** On 11-02
  John judged six opinion rounds (`scripts/opinion_sheet.py N` →
  `~/Downloads/ink-face-opinions-round-N.png`; the mock led, the Scene
  waited). His verdicts, kept as rules: no level bands, no line on a
  hilltop or over a mountain, no zigzag horizon, no nubbin hills, one
  summit per workout, never an exposed foot; the far line straight and
  hidden; a fat mountain whose peak and flat line up with the data; a
  nearer third layer to balance. The Scene now does what
  `compose_preview.mid_plane_layout` does (a Python transliteration of the
  Monkey C matched it within 0.01 px on all 13 fidelity windows):
  full-width `axisX`; the crest scale 0.58..0.26 H; `horizon.png` level at
  the floor (third-lowest bucket); runs 6 bpm over the floor split at
  8 bpm valleys, kept at 15 bpm, each a mass on the 0.87 H base at its
  plane's native aspect (spire ≤ 2 buckets, broad 3–5, wide ≥ 6, the host
  dark and the rest pale; the wide summit 0.2 into the run from its higher
  end, mirrored by a baked `_flip` twin); a near hill per empty third; the
  mist at 0.66..0.88 H. Masses and near hills are paper cutouts baked by
  `scripts/bake_cutouts.py` (`--check` says when a regenerated plane needs
  re-baking) and loaded per render then dropped, so the pool holds only
  the five fixed planes plus one. `far_range`, `host_mountain` and
  `guest_mountain` left `drawables.xml`; the §13 probe uses the broad plane
  and the pale spire instead. Watch for at the build: `Lang.ResourceId`-free
  `loadPlane` (an untyped local holding `Rez.Drawables.*`), block-scoped
  `var`s reused across sibling loops in the relief-job methods, the PRG growing by
  about 650 KB of PNG. Same day: an on-watch Customize menu
  (`JapaneseInkHeartrateSettings.mc`, `getSettingsView`), because Garmin
  Connect only offers Customize for store installs, never a USB sideload.
- **2026-11-03 the bitmap budget probe.** `scripts/bitmap-budget.ps1` at
  home builds `watch-faces/bitmap-budget-probe/` (a throwaway fr265 watch
  face) with 0, 50, 100, 200, 400 generated copies of the baked cutouts,
  runs each in the simulator and writes
  `common/home-verify/<stamp>_bitmap-budget.md`: whether it built, the PRG
  size, every plane loaded and dropped (the install budget), how many held
  at once (the pool budget). `-Watch` then `-ReadWatch` get the watch's own
  answer. That number decides how many more planes the art may use.

- The 2026-06 complete-painting kit (two blurred towers) was sideloaded and
  looked bad on the wrist and in the sim alike (John).
- **2026-10-27 pivot: baked benchmark planes.** `scripts/gen_ink_layers.py`
  ports `playgrounds/ink-sandbox/main.js` (the renderer whose output John
  accepted as shanshui) and bakes seven planes: far haze, guest, host, two
  dark foreground masses, mist (+lite), grain. The Scene places them; the
  oldest and newest HR buckets now size the foreground masses, the hairline
  "memory ridge" and the shore asset are gone. Preview reads right
  (`~/Downloads/ink-face-preview-before.png` vs `-after.png`). The preview
  compositor's alpha bug (squared alpha) was fixed the same day.
- **2026-10-27 typography.** The inscription and the seal's HR are baked
  BMFont pairs (`scripts/gen_ink_font.py` → `resources/fonts/`, registered
  in `fonts.xml` as `InkDigits` / `SealDigits`); `FONT_LARGE` and
  `FONT_XTINY` are gone from the View, the seal grew to 8.5% of width so
  three HR digits fit, and the "4h" caption is gone. Preview
  `~/Downloads/ink-face-preview-font.png`, glyph sheet
  `~/Downloads/ink-digits-sheet.png`. Method: ART_PIPELINE.md §2.
- **2026-10-28 fidelity and night.** Both landmarks now share one time axis
  (`axisX`, 0.36..0.80 of the width) and the guest apex is floored at x 0.34
  so it never rises into the digits. A true-HR overlay (setting, default on)
  draws every raw sample on that axis and the host's own height scale, with
  rings on the painting's two apexes, so the art's deviation from the data
  is a glance. Night mode (settings, default 21:00–06:00) swaps to black
  paper and the `*_night.png` pale-ink set. Settings are edited from the
  Connect IQ phone app (face settings) and repaint at once. Previews:
  `~/Downloads/ink-face-preview-day-overlay.png`, `-night.png`.
- **2026-10-29 overlay rebuilt as a silhouette.** The hairline was plotted
  against the top of the host's bitmap rectangle, so it floated in the sky
  100 px above the paint and read as a stock chart, not a comparison. The
  crest inside each plane was measured (host 31% down its bitmap, guest
  12%); the data is now a translucent vermilion wash under a brush edge on
  the host's crest scale, floor hugging the lowest sample, dots on the two
  painted crests. ≤ 58 columns because `fillPolygon` caps at 64 points. The
  guest crest x constant moved 0.42 → 0.46 (measured). Previews:
  `~/Downloads/ink-face-overlay-day.png`, `-night.png`, and the before/after
  `ink-face-overlay-before-after.png`. Method: ART_PIPELINE.md §4.
- **2026-10-29 the painting on real heart rate.** `compose_preview.py --data
  hr.csv [--end YYYY-MM-DDTHH:MM]` composes a real window (`epoch,hr_avg,
  hr_max` rows, binned by time exactly as `refreshHistory`; the clock is the
  window's end in Arizona). John's 2026-08..09 Friend logs gave 60 rows of
  5-minute HR (`~/Downloads/ink-face-real-hr-2026-10-29.csv`, personal data,
  not committed); the longest unbroken stretch is 109 min, so every real
  window starts empty. Two defects the mock could not show, both fixed in
  the Scene and the preview: the guest picker accepted an EMPTY bucket (a
  full-size mountain where the data says unknown), and the guest's own
  higher base let it out-top the host even at a lower rate. Now: no guest
  without a data bucket an hour away; the guest crest on the host's crest
  scale, 3% lower. Previews `~/Downloads/ink-face-real-0916-day.png`,
  `-night.png`, `ink-face-real-0922-day.png`, and the 2×3 before/after
  `ink-face-landmarks-before-after.png` (mock, 09-16, 09-22). Not fixable
  from here: the on-watch Storage `.DAT` copied 10-22 is encrypted (no
  known epoch appears in either byte order), so the full 700-row ring is
  unreadable off the watch.
- **2026-10-29 the §13 blend probe, written blind.** `const PROBE = false;`
  in `JapaneseInkHeartrateScene.mc` (the comment above it is the spec).
  True, it replaces the painting with a card of four comparisons (A: 8-bit
  alpha into a FULL buffer | a PARTIAL buffer | the screen; B: the host by
  `drawScaledBitmap` | `drawBitmap2` + `AffineTransform` scale + bilinear;
  C: `mist_band_lite` as baked | `mist_band` under a 50% white `:tintColor`;
  D: two guests overlapping, source-over | `BLEND_MODE_MULTIPLY`), each
  call under `has` and try/catch so a refused API prints `n/a` or `ERR` in
  its tile instead of killing the face; the title carries the firmware's
  API level and whether `ALPHA_BLENDING_FULL` was accepted for the scene
  buffer. Day planes always (multiply onto black is black). The expected
  card, same geometry with each right-hand tile rendered as the API
  promises: `python scripts/compose_preview.py --probe out.png` (a copy at
  `~/Downloads/ink-face-probe-expected.png`). At home: flip the const,
  `bash scripts/build-and-run.sh` (the sim's answer is not the hardware's,
  but a crash there is a bug here), sideload, photograph the wrist, judge
  each row against the expected card (a right tile that matches it = the
  row survives; one that matches its LEFT neighbor = a no-op; a word = a
  refusal), write the verdicts into RENDERER_PLAN §13's Status column,
  flip the const back. Never commit it true. One fact from the docs while
  writing it: `ALPHA_BLENDING_FULL` is the DEFAULT buffer surface, so the
  §13 row-1 "fix" was always a no-op; row A measures FULL | PARTIAL |
  screen instead, which is what actually separates the hypotheses.
- **Compiled and staged 2026-10-29.** SDK 9.1.0 produced the FR265 PRG
  successfully (`367196` bytes), and that fresh file was staged over MTP.
  That build predates the overlay, real-HR and probe entries above; rebuild
  before judging them. On-watch processing and visual/runtime validation
  remain. Watch for: pixel budget (450k px decoded, up from 300k; the
  night set is the same size again but only one set is loaded), any
  cut-out look (RENDERER_PLAN §13 row 1), barcode sharpening of strokes
  (§13 row 2), the fonts (the compiler must accept the generated `.fnt`,
  text format, one page, `Rez.Fonts.*` ids, and `antialias="true"` must give
  soft glyphs, not a 1-bit mask), and the settings (`Application.Properties`
  keys from `resources/settings/properties.xml`; `onSettingsChanged` in the
  App). Then John's taste pass in the sim via `compose_preview.py`.
- **2026-10-30 home build of the overlay, real-HR and probe commits.** The
  overlay did not compile (`fillPolygon` wants `Array<Graphics.Point2D>`),
  and once it did, the simulator showed no crest dots: `setFill` takes
  `0xAARRGGBB`, so the bare `0xRRGGBB` edge color filled at alpha 0. Both
  fixed; the build with the overlay was sideloaded to the FR265. The
  simulator supplies its own HR history (a level line near 80 bpm), so it
  takes the real-data path, not the mock. From now on run
  `scripts/home-verify.ps1` at home: it builds everything, runs the offline
  tests and writes the simulator beside `compose_preview.py` into
  `common/home-verify/`. Read the newest report there and
  `common/language/COMPILER_FACTS.md` before working blind.
- **2026-11-02 the fidelity test's first baseline, read on a PC without the SDK.**
  Home's `scripts/fidelity_test.py` (thirteen synthetic four-hour windows
  through `compose_preview.py`, the painted host + guest skyline scored per
  column; reports in `common/fidelity/`) scored the 10-31 recipe at mean r
  0.43 with the peak count right in 2 of 13 windows: a guest appeared in 12
  of 13, a flat 62 bpm window included, because any data bucket an hour
  from the host qualified and noise always supplies one. Fixed in both
  `landmark_peaks` and `landmarkPeaks` (the Scene side blind): a guest also
  needs `GUEST_PROMINENCE` (8 bpm) over the lowest data bucket between it
  and the host, candidates tried strongest first, so the host's own
  shoulder (steady_climb, long_walk) and resting noise are not a second
  landmark. The 08:51 report: peak counts right in 9 of 13, mean r 0.48
  (steady_climb 0.30 to 0.97). The three misses are by design: the
  two-plane cap (three_humps), the 15-minute bucket resolution (four 5-min
  intervals read as one episode) and nap_dip, where two 75 bpm plateaus
  around a 52 bpm hour paint two mountains, a fair reading. The mean
  overlay-to-ink gap ROSE, 34 to 41 px: the metric scores a column with no
  mid-plane ink at the planes' foot, and the quiet hours of a one-episode
  window now hold mist instead of an invented mountain. A far ridge placed
  at the window's resting level would fill those columns on the crest
  scale; that is a change for the eye and was not taken. Also unchanged:
  the crest scale moves 27 px for 60 to 100 bpm, so the mountain's own
  ~100 px of relief outweighs the data's; a steeper `hostHeight` is the
  knob, left alone because the current look is the one being worn.
- **2026-10-30 the first simulator sheet, read on a PC without the SDK.** The
  `08:20` report's simulator-beside-preview sheet was split and measured:
  the paper color, the foreground masses (best alignment within 2 px), the
  mountains and the crest dots all agree with `compose_preview.py`, so the
  mock's geometry is confirmed 1:1. One preview defect: the sun's 0x40 halo
  and 0xCC core, and the seal's 235 alpha, were drawn by Pillow's
  `ImageDraw` straight onto the RGBA base, which REPLACES pixels (alpha
  included), and the final circle mask then showed them opaque. They now
  go through a transparent layer and `alpha_composite` (`blend_ellipse`);
  the sun's pixels match the simulator to within 6 units. Also blind, for
  the next build: the eight plane members are typed `Graphics.BitmapType?`
  (they were untyped, which made every draw call "Passing 'Any'": 20 of the
  28 warnings) and every draw site copies the plane to a local first; the
  next home-verify report should show the face's warning count fall to the
  launcher-icon line alone. If it shows a type error instead, the cast
  `WatchUi.loadResource(...) as Graphics.BitmapType` is the line to doubt.
- **2026-10-28 compile-readiness pass (on a PC without the SDK).** Before the
  successful 2026-10-29 home-PC build, the three source files
  and every resource XML were read against the type checker at `-l 2`
  (`project.typecheck = informative`). One hazard fixed: the seal's HR text
  called `format` on a nullable member; it now copies to a local first
  (the checker narrows locals after a null test, not members). Patterns
  proven by the June build and left alone: uninitialized non-null members
  (`var mScene as ...;`), the `compress`/`packingFormat` bitmap attributes,
  `createColor`/`setFill`. The home-only capture helper was hardened and moved
  to tracked `scripts/save-sim-capture.ps1` on 2026-10-29; the ignored copy is
  retained only as a historical fallback.
- **2026-10-28 kanji hour.** The hour is now a column of brush kanji
  numerals (John's March idea) in a third baked font, `KanjiHours`
  (〇一二三四五六七八九十廿, cap 36): one or two glyphs stacked above the
  minutes, twenty written as 廿 so the column never needs a third line.
  The minutes moved to y 37.5% and the seal to 46.5% to make room under the
  bezel. Previews `~/Downloads/ink-face-preview-kanji-{day,night,24h}.png`,
  sheet `~/Downloads/ink-kanji-sheet.png`; `compose_preview.py` gained
  `--time HH:MM` and `--24h`, and a preview-only bug was fixed (the celestial
  code shadowed the night flag, so day renders after 18:00 drew pale ink).
  New at the build: non-ASCII `char id`s in a `.fnt`, a `<font>` without
  `filter`, and `Number.toChar().toString()` for the one-glyph strings.
  Same day, the digit knots: the 5's stem now lands under the bar instead
  of pressing onto it, and the 8 lands moving with a thinner waist so the
  crossing stays open; the other nine digits rebaked pixel-identical (each
  glyph has its own seed, so a skeleton edit never touches its neighbors).
  The seal font shares the skeletons, so its 5 and 8 followed.
