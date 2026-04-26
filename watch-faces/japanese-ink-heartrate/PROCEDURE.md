# Japanese Ink Heartrate — Working Procedure

Last updated: 2026-04-22

**Purpose of this doc.** Capture the full code → build → push → capture → review → iterate loop for this watch face, with *explicit* roles for you (the human driver) and the LLM agent (Claude). Written so a cold-start session — yours or the agent's — can pick up and keep going without context loss.

This is the operational manual. For *what* we're trying to build and *why* prior attempts failed, see:

- [Project Vision](JAPANESE_INK_HEARTRATE.md) — the north star
- [Renderer Plan](RENDERER_PLAN.md) — diagnosis, strategy, asset family, draw recipe, teardown list
- [HR Facts](ROOT_HR_FACTS.md) — Garmin heart-rate API behavior

---

## 1. One-minute orientation

- The watch face is at `watch-faces/japanese-ink-heartrate/`.
- The root jungle at `monkey.jungle` (repo root) points at it. That's the build target.
- The art grammar is asset-driven: small tuned-import grayscale+alpha PNGs placed by a tiny HR descriptor. Not procedural polygons. See RENDERER_PLAN §4.
- Each iteration makes **one coherent change**, then produces a **paired checkpoint** (`YYYY-MM-DD_name.png` + `.md`) under `art/checkpoints/procedural/`.
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

1. Open VS Code in `c:\Users\John\Documents\Personal_Projects\my-garmin-watchfaces\`.
2. Launch the simulator. In a shell, run:
   ```powershell
   & "C:\Users\John\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b\bin\connectiq.bat"
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

The agent decides on a short, descriptive, kebab-case name for this change. Examples: `iter2-body-wash-png`, `iter3-dual-descent`, `iter7-hr-descriptor-mocked`. The full checkpoint filename pattern is:

```
watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/YYYY-MM-DD_<name>.png
watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/YYYY-MM-DD_<name>.md
```

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

Before building, write `art/checkpoints/procedural/YYYY-MM-DD_<name>.md` with the first three sections filled in:

- **Intent** — what are we testing, what question does this iteration answer
- **Changes** — concrete diff summary
- **Key Code** — the 5–15 lines that matter

Leave Result / What Improved / What Got Worse / Deviation / Next Move as "*(post-capture)*" placeholders.

Writing the stub **before** capture forces the agent to commit to an intent that the capture can then confirm or refute.

### Step 3 — Agent: build, push, and capture

One command:

```bash
bash scripts/build-and-run.sh "c:/Users/John/Documents/Personal_Projects/my-garmin-watchfaces/watch-faces/japanese-ink-heartrate/art/checkpoints/procedural/YYYY-MM-DD_<name>.png"
```

This wraps `monkeyc` + `monkeydo` + `save-sim-capture.ps1` with all paths hardcoded. Expected output:

```
[build] monkeyc ... BUILD SUCCESSFUL
[push]  monkeydo -> fr265
[capture] <path>.png
```

The capture script drives the sim's **File → Save Screen Capture** menu via keystroke automation — focuses the CIQ Simulator window, sends `Alt+F`, `S`, types the absolute output path, then `Enter`. Throws if the file doesn't appear.

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
c:\Users\John\Documents\Personal_Projects\my-garmin-watchfaces\
├── monkey.jungle                              build entry — points at the watch face manifest
├── bin/
│   └── mygarminwatchfaces.prg                 build output (rewritten each build)
├── scripts/
│   └── build-and-run.sh                       monkeyc + monkeydo wrapper
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
                    ├── save-sim-capture.ps1   screenshot helper
                    └── YYYY-MM-DD_*.png/.md   paired checkpoints (the history)
```

---

## 6. Command reference

### Launch the sim (once per session, human)

```powershell
& "C:\Users\John\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b\bin\connectiq.bat"
```

### Build + push (every iteration, agent)

```bash
bash scripts/build-and-run.sh
```

Contents: `monkeyc.bat -o bin/mygarminwatchfaces.prg -f monkey.jungle -y C:/Users/John/MonkeyC/developer_key -d fr265 -w -l 2` then `monkeydo.bat bin/mygarminwatchfaces.prg fr265`. Device id is `fr265`, **not** `fr265_sim` (see §7).

### Capture screenshot (every iteration, agent)

```powershell
& "c:\Users\John\Documents\Personal_Projects\my-garmin-watchfaces\watch-faces\japanese-ink-heartrate\art\checkpoints\procedural\save-sim-capture.ps1" -OutputPath "<absolute-output-path>.png"
```

### Inspect simulator state (optional, human)

The sim supports simulated heart rate data via **Simulation → Data Fields → Heart Rate History** (or similar). Useful once we integrate real HR history.

### Manual build-only (rarely needed, agent)

```bash
"C:/Users/John/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b/bin/monkeyc.bat" \
  -o "c:/Users/John/Documents/Personal_Projects/my-garmin-watchfaces/bin/mygarminwatchfaces.prg" \
  -f "c:/Users/John/Documents/Personal_Projects/my-garmin-watchfaces/monkey.jungle" \
  -y "C:/Users/John/MonkeyC/developer_key" \
  -d fr265 -w -l 2
```

### Manual push-only (if build hasn't changed)

```bash
"C:/Users/John/AppData/Roaming/Garmin/ConnectIQ/Sdks/connectiq-sdk-win-9.1.0-2026-03-09-6a872a80b/bin/monkeydo.bat" \
  "c:/Users/John/Documents/Personal_Projects/my-garmin-watchfaces/bin/mygarminwatchfaces.prg" fr265
```

---

## 7. Troubleshooting

### "Unable to connect to simulator" on `monkeydo`

The simulator is not running. Launch it via `connectiq.bat` (§3 step 2) and retry.

### "Unable to load device fr265_sim" popup in the sim

You built or pushed with `-d fr265_sim`. From the CLI, use `-d fr265`. `fr265_sim` is a VS Code extension F5-only target; the running sim binds to `fr265` (the device cache folder name at `~/AppData/Roaming/Garmin/ConnectIQ/Devices/fr265/`).

### Capture script says "Simulator window not found"

Window title changed or sim is minimized.

Fixes, in order:
1. Click the sim window once so it has focus.
2. Check the title bar — update the `-WindowTitles` default array in `save-sim-capture.ps1` if Garmin renamed it.
3. Ensure only one CIQ Simulator instance is running.

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

## 10. Current state (as of this writing)

- **Iteration 1** complete: baseline stripped scene with paper + celestial + a flat gray placeholder rectangle. Clean build, sim push, screenshot saved. See `art/checkpoints/procedural/2026-04-22_iter1-baseline.md`.
- **Iteration 2** pending: replace the placeholder rectangle with an authored `body_wash_soft.png`.

The `RENDERER_PLAN.md` §12 build order remains the roadmap beyond iteration 2.
