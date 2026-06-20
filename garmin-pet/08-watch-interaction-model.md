# Watch interaction model - one-primary-action pet

Status: design decision captured after the 2026-06-18 watch-input review.

## Verdict

Do not build this like a tiny touchscreen Tamagotchi menu.

Build it as a **one-primary-action companion**:

1. The app opens with the pet centered and alive.
2. The pet reads current/recent body context.
3. The pet asks one useful question: "Are we doing something?"
4. One select/tap/start action begins the foreground buddy session.
5. Back always backs out.
6. Up/down pages through big cards.
7. Any care/menu actions happen through full-screen cards or an action sheet.

The game should be engaging because the pet reacts to the wearer's real body signals,
not because the watch has many clickable controls.

## Non-negotiables

- **No tiny touch targets.** Touch is optional convenience, not the interaction model.
- **No required four-way swipe grammar.** On touchscreen devices (including VA6), SWIPE_RIGHT
  fires `KEY_ESC` at the OS level before your app sees it as a swipe event — it is not
  available as a game verb. Do not make right swipe mean anything.
- **Back is sacred.** Back means back/cancel/exit, always.
- **One primary action.** Select/tap/Start means yes, start, continue, accept, or mark.
- **Full-screen choices.** One visible card or action at a time.
- **VA6-class input is the baseline.** FR265's 5 buttons are shortcuts, not requirements.
- **Live sensing is foreground.** High-rate movement sensing is for an open buddy session,
  not silent all-day background classification.

## Garmin input reality

Use `WatchUi.BehaviorDelegate` as the first abstraction, because it maps device-specific
inputs into device-independent behaviors. Raw `InputDelegate` events are available, but
the product should be written around behaviors first.

Recommended behavior mapping:

| Behavior | Product meaning | Notes |
|---|---|---|
| `onSelect()` | Primary action: yes / start / confirm / continue | Start button, Enter, or tap depending on device. |
| `onBack()` | Back / cancel / exit | Garmin docs note some devices interpret `SWIPE_RIGHT` as `KEY_ESC`; do not overload this. |
| `onNextPage()` | Next card | Typically down button or swipe up. |
| `onPreviousPage()` | Previous card | Typically up button or swipe down. |
| `onActionMenu()` / action-style trigger | Open action sheet | Useful for Vivoactive 6 / Action Notch style devices where supported. |
| raw `onSwipe()` | Optional flavor only | Fine for shortcuts, bad as the only way to play. |
| raw `onTap()` | Whole-screen tap only | Never require tapping a small icon. |

FR265 can expose extra buttons as accelerators. Vivoactive 6 style devices need the
app to work with effectively one primary action plus Back and page navigation.

## The watch can support these verbs

The user should be able to do this without hunting on the touchscreen:

1. **Open the app.** The pet is centered and reacts to today's state.
2. **Start Buddy Mode.** One primary press answers "yes, we're active."
3. **Move.** The app reads movement and heart rate while foregrounded.
4. **Mark a moment.** One primary press can mean "that was a set," "continue," or
   "feed this effort."
5. **Accept the reward.** Effort becomes food, mood, XP, a line of dialogue, or an unlock.
6. **Check today's nudge.** A single full-screen card offers one suggested action.
7. **Do one care action.** Feed/play/rest/clean lives in a big action sheet or card.
8. **Leave cleanly.** Back exits or cancels without ambiguity.

Everything else is optional polish.

## State model

### 1. Home / idle companion

Default first screen.

- Pet is visually dominant in the center circle.
- One short contextual line appears.
- Select starts the obvious current action.
- Up/down browses cards.
- Back exits.

The pet can comment on recent steps, live HR, time of day, prior sessions, and whether
motion/HR suggests the user is about to be active.

### 2. Launch nudge

If current signals suggest activity, the pet asks a binary question:

> "Are we moving?"

Controls:

- Select/tap/Start: begin Buddy Mode.
- Back: not now / exit.
- Up/down: browse other cards if the user does not want the prompt.

Do not put a grid of workout choices here. The absence of setup friction is part of
the personality.

### 3. Buddy Mode

Foreground live session. The pet watches the body.

Inputs:

- Heart rate, **compared against the trailing ~4h HR baseline** so the pet reads *relative*
  effort (e.g. live 89 vs a 69 baseline = "up 20 over your normal") even when it can't classify
  the move. See `04-activity-sensing.md §Relative effort & baselines`.
- Accelerometer / motion samples.
- Elapsed time.
- Optional declared intent ("starting a light workout") as the launch action.
- Optional one-press set marker.

Outputs:

- Effort meter.
- Rep/set guesses when confidence is good enough.
- Dialogue when confidence is low.
- Recovery/rest comments.
- Rewardable session summary.

Important product stance: inaccurate classification should not feel like failure.
Confidence becomes character.

Examples:

- High confidence: "Squats. Twelve. Keep moving."
- Low confidence: "No idea what that was. It counts."
- Motion unclear but HR rising: "Wrist says nothing. Heart says work."

### 4. Reward summary

After a session, show one clean payoff:

- Effort snack gained.
- Mood/energy bump.
- One line of pet reaction.
- Progress toward an unlock.

Select continues. Back exits. No spreadsheet.

### 5. Daily card carousel

Up/down moves through a short stack of full-screen cards:

- Pet status.
- Today's nudge.
- Effort reward.
- Care action.
- Unlock/progress.
- Settings/debug only if needed.

Each card has one primary action. The user never chooses from a dense menu.

### 6. Action sheet

Menu/ActionMenu opens a large, simple action sheet:

- Feed
- Play
- Rest
- Clean

It should be navigable by next/previous/select/back. Touch can tap the big rows, but
touch should not be required.

## Four-swipe decision

Do **not** make "swipe left/right/up/down" the core control scheme.

Recommended use:

- Up/down: card navigation through `onNextPage()` / `onPreviousPage()`.
- Right: avoid as a game verb because it can collide with Back/Esc semantics.
- Left: optional "later/skip" only if testing shows it is safe and discoverable.

The robust model is page navigation plus one primary action.

## Engagement model

The sticky loop should be simple:

1. Notice body context.
2. Ask for a tiny active commitment.
3. Watch effort live.
4. React with personality.
5. Convert effort into visible pet progress.
6. Unlock a new capability, expression, or line type.

The watch is not strong at complex UI. It is strong at being present on the body.
Use that.

### Mechanics worth building

- **Effort snack.** Any meaningful movement/HR effort gives the pet something to eat.
- **Pet perception ladder.** The pet gradually learns to detect more: generic effort,
  squats, push-ups, watch-arm curls, rest pauses, HR-gassed fallback, run/walk summaries.
- **Confidence dialogue.** Uncertain sensing becomes banter instead of error.
- **One daily nudge.** One tiny challenge per day, not a quest board.
- **Mood as weather.** Mood changes expression/dialogue. It is not a punishment bar.
- **Post-effort care ritual.** Care actions feel best after effort, not as constant chores.
- **Idle return story.** On open, the pet digests today's aggregate activity and gives a
  small story/reward.

### What to avoid

- A grid of tiny Feed/Play/Clean/Sleep buttons as the main interface.
- Four mandatory swipe directions.
- A punishment spiral for missed days.
- A to-do list that makes the pet feel like another obligation.
- Overclaiming all-day automatic exercise detection.
- Free-text watch input.
- Making the user choose workout type before every session unless the classifier really
  needs it.

## MVP interaction spec

Prototype this first:

| Screen | Select | Back | Up/down | Action menu |
|---|---|---|---|---|
| Home | Start Buddy / primary card action | Exit app | Change card | Open action sheet |
| Buddy | Mark set / continue | End session prompt | Cycle session lens if needed | Pause/end options |
| Reward | Accept / continue | Exit | Previous/next summary card | N/A |
| Card carousel | Do card action | Home/exit | Browse cards | Open action sheet |
| Action sheet | Choose row | Close sheet | Move row | Close sheet |

This can be simulated in the web sandbox with keyboard controls:

- Enter = Select
- Escape = Back
- ArrowUp/ArrowDown = previous/next card
- M or Space = action sheet

That sandbox model should come before any Monkey C implementation, because it will expose
whether the game is actually playable with one primary action.

## UI layout rules

- The pet/circle is the focus on mobile and watch-sized previews.
- Controls collapse below the watch preview in the sandbox.
- The watch UI itself shows one clear action, not a console.
- Text must fit inside the round display.
- Buttons in the sandbox can expand/collapse; buttons on the watch become behaviors.
- Do not use visible instructional copy as a crutch. The interaction should be obvious
  from the current card and primary action.

## Implementation notes for Monkey C

- Start with `WatchUi.BehaviorDelegate`.
- Add raw `InputDelegate` handlers only for optional shortcuts.
- Treat `onBack()` as untouchable navigation.
- Keep foreground buddy sessions short to protect battery and AMOLED.
- Use `Toybox.Sensor` during active sessions for live HR/motion.
- Use aggregate sources on app open for "you moved today" rewards.
- Store decay/progression by timestamp, not ticking timers.
- Keep all strings canned and indexed so the watch does not need free-text input.

## Open implementation questions

- Exact VA6 Action Notch behavior on hardware. **MVP fallback:** do not depend on
  `onActionMenu()` — make the action sheet reachable via `onSelect()` on a dedicated
  card instead, so the app is fully playable even if the Action Notch doesn't fire.
- Whether `onActionMenu()` or an action-view pattern is the best hook on VA6 (unverified
  on real hardware — needs a device test).
- How much raw swipe behavior survives after `BehaviorDelegate` consumes page/back actions.
- The first three card types for MVP.
- Whether the first buddy mode starts fully generic or asks for one coarse lens:
  Generic / Push-ups / Squats.

## Research sources

- Garmin `WatchUi.BehaviorDelegate`:
  https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/BehaviorDelegate.html
- Garmin `WatchUi.InputDelegate`:
  https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi/InputDelegate.html
- Garmin `WatchUi` swipe constants:
  https://developer.garmin.com/connect-iq/api-docs/Toybox/WatchUi.html
- Garmin `Toybox.Sensor`:
  https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor.html
- Game progression: horizontal options vs vertical scale:
  https://www.gamedeveloper.com/design/the-fundamentals-of-game-progression
- Player motivation / autonomy / competence / relatedness:
  https://doi.org/10.1007/s11031-006-9051-8

## Locked decision

The product stance is now:

> Behavior-first, one-primary-action, full-screen-card pet companion. The activity buddy
> is the heart of the game; the care menu is secondary.
