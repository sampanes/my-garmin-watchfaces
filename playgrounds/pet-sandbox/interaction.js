// ═══════════════════════════════════════════════════════════════════════════════
// INTERACTION MODEL — behavior-first, one-primary-action pet
// ═══════════════════════════════════════════════════════════════════════════════
// Prototype of garmin-pet/08-watch-interaction-model.md in the browser.
//
// The watch has ONE primary button (the floating "●" on screen) plus page
// navigation. Everything maps to five device-independent behaviors, exactly like
// WatchUi.BehaviorDelegate would on the real device:
//
//   select  → primary action  (tap ● / tap screen / Enter)
//   back    → cancel / exit    (swipe right / Esc)   ← matches VA6 SWIPE_RIGHT=KEY_ESC
//   next    → next card        (swipe up   / ArrowDown)
//   prev    → previous card    (swipe down / ArrowUp)
//   menu    → action sheet     (hold ●     / M / Space)
//
// Mobile-first: swipes are the preferred input; the floating button stands in for
// the one physical select/start key. No four-way swipe grammar is required.
// ═══════════════════════════════════════════════════════════════════════════════

// ── Persona-voiced lines for the screens this layer owns ─────────────────────────
const BUDDY_LINES = {
  drill: {
    start: ["Sup. Let's go.", "No warmup talk. Move.", "Clock's running."],
    mark:  ["That's one. Don't celebrate.", "Logged. Again.", "Marginally acceptable."],
    end:   ["Done. You survived.", "That'll do. Barely.", "Rest. We go again tomorrow."],
  },
  hype: {
    start: ["YES let's GOOO!! 💪", "I'm SO ready, are YOU?!", "This is gonna be GREAT!!"],
    mark:  ["YESSS another one!!", "You're CRUSHING it!! ✨", "Look at you GO!!"],
    end:   ["You did AMAZING!! 💕", "SO proud of you!!", "Best session EVER!!"],
  },
  deadpan: {
    start: ["Oh. We're moving. Sure.", "Fine. Started.", "Riveting. Let's go."],
    mark:  ["One. Noted.", "Cool. Another.", "Counted. Thrilling."],
    end:   ["Done. Cool.", "That happened.", "We're stopping. Good."],
  },
  zen: {
    start: ["Begin when you're ready. 🍃", "One breath. Then move.", "Present. Let's flow."],
    mark:  ["Felt that. Nice.", "Steady. Good.", "One more, mindfully."],
    end:   ["Well moved. Rest now.", "You honored the effort.", "Be still. You earned it."],
  },
};

function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

// ── HOME card stack (the carousel) ───────────────────────────────────────────────
const HOME_CARDS = [
  { id: "status",   kind: "status",   actionLabel: "Start",   onSelect: "buddy" },
  { id: "nudge",    kind: "card",     actionLabel: "Let's go", onSelect: "buddy", skippable: true,
    title: "Today's nudge", body: "Two minutes. Move something. That's the whole ask." },
  { id: "care",     kind: "card",     actionLabel: "Open",    onSelect: "sheet",
    title: "Care", body: "Feed, play, rest, or clean — best right after effort." },
  { id: "progress", kind: "card",     actionLabel: "Peek",    onSelect: "progress",
    title: "Progress", body: "Effort feeds the next unlock. Keep showing up." },
];

const SHEET_ITEMS = [
  { id: "eat",   label: "🍗 Feed" },
  { id: "play",  label: "🎾 Play" },
  { id: "sleep", label: "💤 Rest" },
  { id: "clean", label: "✨ Clean" },
];

// ═══════════════════════════════════════════════════════════════════════════════
// MODULE
// ═══════════════════════════════════════════════════════════════════════════════

export function initInteraction(api) {
  const frame   = document.querySelector(".watch-frame");
  const elTop   = document.getElementById("screen-top");
  const elCard  = document.getElementById("screen-card");
  const elDots  = document.getElementById("screen-dots");
  const elLabel = document.getElementById("press-label");
  const pressBtn = document.getElementById("press-btn");
  const hint    = document.getElementById("gesture-hint");

  // ── Screen state ──────────────────────────────────────────────────────────────
  const ui = {
    screen: "home",     // home | buddy | reward | sheet
    cardIndex: 0,
    sheetIndex: 0,
    buddy: { baseline: 68, hr: 68, reps: 0, effort: 0, seconds: 0, timer: null },
    reward: { reps: 0, snack: 0, xp: 0 },
  };

  // ── Behavior dispatch ─────────────────────────────────────────────────────────
  // "skip" (swipe ←) is a soft behavior: dismiss a skippable card, else fall to back.
  function behave(b) {
    if (b === "skip") {
      if (ui.screen === "home" && HOME_CARDS[ui.cardIndex].skippable) {
        api.say(pick(["Fine. Later.", "Skipped. I noticed.", "Sure, dodge it."]));
        ui.cardIndex = (ui.cardIndex + 1) % HOME_CARDS.length;
        render();
        return;
      }
      b = "back";
    }
    switch (ui.screen) {
      case "home":   return homeBehave(b);
      case "buddy":  return buddyBehave(b);
      case "reward": return rewardBehave(b);
      case "sheet":  return sheetBehave(b);
    }
  }

  function homeBehave(b) {
    const card = HOME_CARDS[ui.cardIndex];
    if (b === "next") { ui.cardIndex = (ui.cardIndex + 1) % HOME_CARDS.length; }
    else if (b === "prev") { ui.cardIndex = (ui.cardIndex - 1 + HOME_CARDS.length) % HOME_CARDS.length; }
    else if (b === "menu") { openSheet(); }
    else if (b === "back") { api.say(pick(["Still here.", "Not going anywhere.", "I'll wait."])); }
    else if (b === "select") {
      if (card.onSelect === "buddy") startBuddy();
      else if (card.onSelect === "sheet") openSheet();
      else if (card.onSelect === "progress") {
        const p = api.progress ? api.progress() : null;
        api.say(p && p.next
          ? `${p.next.xp - p.xp} XP to ${p.next.name}. Keep going.`
          : "Maxed out. Show-off.");
      }
    }
    render();
  }

  function buddyBehave(b) {
    if (b === "select") { markSet(); }
    else if (b === "back" || b === "menu") { endBuddy(); }
    // next/prev intentionally inert during a session (no card stack here)
    render();
  }

  function rewardBehave(b) {
    if (b === "select" || b === "back") { ui.screen = "home"; }
    render();
  }

  function sheetBehave(b) {
    if (b === "next") { ui.sheetIndex = (ui.sheetIndex + 1) % SHEET_ITEMS.length; }
    else if (b === "prev") { ui.sheetIndex = (ui.sheetIndex - 1 + SHEET_ITEMS.length) % SHEET_ITEMS.length; }
    else if (b === "back") { ui.screen = "home"; }
    else if (b === "select") {
      api.triggerCare(SHEET_ITEMS[ui.sheetIndex].id);
      ui.screen = "home";
    }
    render();
  }

  // ── Buddy Mode (relative-effort demo, per 04-activity-sensing.md) ───────────────
  function startBuddy() {
    ui.screen = "buddy";
    ui.buddy = { baseline: 64 + Math.floor(Math.random() * 8), hr: 66, reps: 0, effort: 0, seconds: 0, timer: null };
    ui.buddy.hr = ui.buddy.baseline + 2;
    api.setBuddyActive(true);
    api.say(pick(BUDDY_LINES[api.persona()].start));
    ui.buddy.timer = setInterval(tickBuddy, 250);
  }

  function tickBuddy() {
    const s = ui.buddy;
    s.seconds += 0.25;
    // HR drifts up toward a working band, with noise — the "more than your normal" signal.
    const target = s.baseline + 26 + Math.sin(s.seconds * 0.6) * 6;
    s.hr += (target - s.hr) * 0.06 + (Math.random() - 0.5) * 1.2;
    s.effort = Math.max(0, Math.min(1, (s.hr - s.baseline) / 42));
    render();
  }

  function markSet() {
    const s = ui.buddy;
    s.reps += 1;
    s.hr += 4; // a set spikes HR
    api.say(pick(BUDDY_LINES[api.persona()].mark));
  }

  function endBuddy() {
    const s = ui.buddy;
    if (s.timer) clearInterval(s.timer);
    api.setBuddyActive(false);
    ui.reward = {
      reps: s.reps,
      snack: Math.max(1, Math.round(s.reps * 1.5 + s.effort * 6)),
      xp: Math.max(5, Math.round(s.seconds * 0.8 + s.reps * 3)),
    };
    if (api.gainXp) api.gainXp(ui.reward.xp); // effort feeds the progression ladder
    api.say(pick(BUDDY_LINES[api.persona()].end));
    ui.screen = "reward";
  }

  function openSheet() { ui.screen = "sheet"; ui.sheetIndex = 0; }

  // ── Contextual top line for Home/status ─────────────────────────────────────────
  function statusContext() {
    const hour = new Date().getHours();
    const steps = 3000 + Math.floor(Math.random() * 6000);
    const tod = hour < 11 ? "morning" : hour < 17 ? "afternoon" : "evening";
    return `${steps.toLocaleString()} steps · calm this ${tod}`;
  }
  let cachedContext = statusContext();

  // ═════════════════════════════════════════════════════════════════════════════
  // RENDER the HTML overlay for the current screen
  // ═════════════════════════════════════════════════════════════════════════════
  function render() {
    frame.dataset.screen = ui.screen;
    elTop.textContent = "";
    elCard.innerHTML = "";
    elDots.innerHTML = "";

    if (ui.screen === "home") {
      const card = HOME_CARDS[ui.cardIndex];
      elTop.textContent = ui.cardIndex === 0 ? cachedContext : "";
      if (card.kind === "card") {
        elCard.innerHTML =
          `<div class="card-panel"><h2>${card.title}</h2>` +
          (card.id === "progress" ? progressCardBody() : `<p>${card.body}</p>`) +
          (card.skippable ? `<span class="card-skip">swipe ← to skip</span>` : "") +
          `</div>`;
      }
      renderDots(HOME_CARDS.length, ui.cardIndex);
      setLabel(card.actionLabel);
    }

    else if (ui.screen === "buddy") {
      const s = ui.buddy;
      const delta = Math.round(s.hr - s.baseline);
      const over = delta > 8;
      elTop.innerHTML =
        `<span class="hr ${over ? "hr--up" : ""}">♥ ${Math.round(s.hr)}` +
        `<span class="hr-delta">${delta >= 0 ? "▲" : "▼"}${Math.abs(delta)} over ${s.baseline}</span></span>`;
      elCard.innerHTML =
        `<div class="buddy-readout">` +
        `<div class="effort-bar"><span style="width:${Math.round(s.effort * 100)}%"></span></div>` +
        `<div class="buddy-stats">reps <b>${s.reps}</b> · effort <b>${Math.round(s.effort * 100)}%</b></div>` +
        `</div>`;
      setLabel("Mark set");
    }

    else if (ui.screen === "reward") {
      const r = ui.reward;
      elCard.innerHTML =
        `<div class="card-panel reward"><h2>Nice.</h2>` +
        `<p>+${r.snack} effort snack · +${r.xp} XP${r.reps ? ` · ${r.reps} sets` : ""}</p></div>`;
      setLabel("Accept");
    }

    else if (ui.screen === "sheet") {
      elTop.textContent = "Care";
      elCard.innerHTML =
        `<ul class="sheet">` +
        SHEET_ITEMS.map((it, i) =>
          `<li class="${i === ui.sheetIndex ? "is-sel" : ""}">${it.label}</li>`).join("") +
        `</ul>`;
      setLabel("Choose");
    }
  }

  // Live XP bar for the Home "Progress" card — reads the shared accumulator.
  function progressCardBody() {
    const p = api.progress ? api.progress() : null;
    if (!p) return `<p>Effort feeds the next unlock. Keep showing up.</p>`;
    const span = p.next ? p.next.xp - p.band.xp : 1;
    const fill = p.next ? Math.round(((p.xp - p.band.xp) / span) * 100) : 100;
    const line = p.next
      ? `${p.next.xp - p.xp} XP → ${p.next.name}`
      : `Maxed — fully evolved`;
    return `<p class="prog-band">${p.band.name}</p>` +
      `<div class="effort-bar prog-bar"><span style="width:${fill}%"></span></div>` +
      `<p class="prog-next">${line}</p>`;
  }

  function renderDots(n, active) {
    for (let i = 0; i < n; i++) {
      const d = document.createElement("span");
      d.className = "dot" + (i === active ? " is-active" : "");
      elDots.appendChild(d);
    }
  }

  function setLabel(text) { elLabel.textContent = text; }

  // ═════════════════════════════════════════════════════════════════════════════
  // INPUT — swipe (preferred), floating button, keyboard
  // ═════════════════════════════════════════════════════════════════════════════
  const SWIPE_MIN = 28; // px

  // --- Swipe / tap on the watch face ---
  let down = null;
  frame.addEventListener("pointerdown", (e) => {
    if (e.target.closest(".press-btn")) return; // button owns its own gesture
    down = { x: e.clientX, y: e.clientY, t: performance.now() };
  });
  frame.addEventListener("pointerup", (e) => {
    if (!down) return;
    const dx = e.clientX - down.x, dy = e.clientY - down.y;
    const adx = Math.abs(dx), ady = Math.abs(dy);
    down = null;
    if (adx < SWIPE_MIN && ady < SWIPE_MIN) { behave("select"); return; } // whole-screen tap
    if (adx > ady) { behave(dx > 0 ? "back" : "skip"); }                  // → back · ← skip
    else { behave(dy < 0 ? "next" : "prev"); }                            // ↑ next · ↓ prev
    flashHint();
  });
  frame.addEventListener("pointercancel", () => { down = null; });

  // --- Floating button: tap = select, hold = menu ---
  let holdTimer = null, held = false;
  pressBtn.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    held = false;
    holdTimer = setTimeout(() => { held = true; behave("menu"); }, 450);
  });
  const endPress = () => {
    if (holdTimer) { clearTimeout(holdTimer); holdTimer = null; }
    if (!held) behave("select");
  };
  pressBtn.addEventListener("pointerup", endPress);
  pressBtn.addEventListener("pointerleave", () => {
    if (holdTimer) { clearTimeout(holdTimer); holdTimer = null; }
  });

  // --- Keyboard (desktop), per 08's sandbox mapping ---
  window.addEventListener("keydown", (e) => {
    if (e.target.matches("input, select, textarea")) return;
    const map = {
      Enter: "select", Escape: "back", Backspace: "back",
      ArrowDown: "next", ArrowUp: "prev",
      KeyM: "menu", Space: "menu",
    };
    const b = map[e.code];
    if (b) { e.preventDefault(); behave(b); }
  });

  // --- One-time fading gesture hint ---
  let hintShown = false;
  function flashHint() {
    if (hintShown || !hint) return;
    hintShown = true;
    hint.classList.add("is-fading");
    setTimeout(() => hint.remove(), 1200);
  }
  setTimeout(() => { if (!hintShown) flashHint(); }, 7000);

  render();
}
