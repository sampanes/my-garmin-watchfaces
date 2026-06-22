# Pet Sandbox

Mobile-first browser playground for the Garmin pet look-and-feel work **and** the
behavior-first interaction model.

## Interaction model (prototype)

Prototypes the control scheme from `garmin-pet/08-watch-interaction-model.md`:
**one primary action + page navigation**, mobile-first with swipes preferred. The floating
**●** button stands in for the watch's single physical select/start key.

| Behavior | Touch (preferred) | Floating ● | Keyboard |
|----------|-------------------|------------|----------|
| **Select** (start / mark / accept / choose) | tap the screen | tap ● | Enter |
| **Back** (cancel / exit) | swipe **→** | — | Esc |
| **Next card** | swipe **↑** | — | ↓ |
| **Prev card** | swipe **↓** | — | ↑ |
| **Skip** (dismiss a nudge) | swipe **←** | — | — |
| **Action menu** (Feed / Play / Rest / Clean) | — | **hold** ● | M / Space |

Swipe-right is deliberately Back, mirroring the VA6 where `SWIPE_RIGHT` fires `KEY_ESC` at
the OS level — right swipe is never a game verb.

Screens: **Home** (card carousel: status · nudge · care · progress) → **Buddy Mode**
(relative-effort readout — live HR vs the ~4 h baseline, mark sets) → **Reward** (effort
snack + XP) → **Action sheet**. Mirrors the MVP interaction spec in `08`.

The control panel below the watch is a **dev / look-and-feel knob set** (creature, stage,
**progress**, resolution, mood, persona, anim speed) — not the game UI.

### Progress (dev) — fast-forward evolution

One XP track drives the pet's life stage **and** its unlocks (emotes / powers / phrases /
look), per `garmin-pet/05-progression.md`. The **Progress (dev)** slider + `−`/`+` buttons
scrub that track so you can watch the pet evolve in seconds instead of earning it over real
days — no shaking the phone daily. The `+` button simulates a session's worth of effort;
`−` is a **dev rewind only** (you never lose progression IRL). The ladder lives in
`progression.js` (illustrative pacing, not a balanced economy).

The same accumulator is fed by real play: finishing a **Buddy Mode** session calls
`gainXp()` with the session reward, so the dev slider is just fast-forwarding what actual
effort would earn. The Home **Progress** card shows the live XP bar and next unlock.

> The phone is the truth test. Open it on a handset and play it with your thumb before
> trusting that the one-button model feels right.

## Dev server identity

The dev server should be identifiable when multiple Vite playgrounds are running.

- Browser title: `Pet Sandbox`
- Package name: `pet-sandbox`
- Dev script: `vite --host`
- Console/window title used by helper scripts: `Pet Sandbox`

The BAT helpers intentionally use the same name so a local port/process dashboard does not
show a generic Vite listener when this sandbox is running.

## Helpers

- `start-pet-sandbox.bat` - starts the Vite server in a console titled `Pet Sandbox`.
- `status-pet-sandbox.bat` - checks the titled window and the port listener.
- `stop-pet-sandbox.bat` - stops the titled window, then falls back to killing the port
  listener if the title changed.

The scripts default to port `5173`, matching Vite's first-choice dev port.
