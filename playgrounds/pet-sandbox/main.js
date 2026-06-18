import { getCreature, getCreatureNames } from "./creatures.js";

// ═══════════════════════════════════════════════════════════════════════════════
// CANVAS SETUP
// ═══════════════════════════════════════════════════════════════════════════════

const canvas = document.getElementById("watch-canvas");
const ctx = canvas.getContext("2d");
const watchFrame = canvas.closest(".watch-frame");
const controlSheet = document.getElementById("control-sheet");
const controlMeta = document.getElementById("control-meta");
const wideLayoutQuery = window.matchMedia("(min-width: 900px)");
const forceControlsOpen = new URLSearchParams(window.location.search).get("controls") === "open";
let RES = 416;

// ── PIXEL DENSITY NOTES ──────────────────────────────────────────────────────
// All three target watches are nearly identical PPI:
//   FR265   416px / 1.3"  ≈ 320 PPI
//   FR265S  360px / 1.1"  ≈ 327 PPI
//   VA6     390px / 1.2"  ≈ 325 PPI
//
// We render the canvas at 1:1 CSS pixels (canvas.width = CSS width = RES).
// On a ~440 PPI phone held at arm's length this is a close physical match.
// On a desktop monitor (~96-144 PPI) it will look larger than the real watch —
// that's fine, it's a design tool. The phone preview is the truth test.
// ─────────────────────────────────────────────────────────────────────────────

let truePixels = false;

function resize(r) {
  RES = Number.parseInt(r, 10);
  canvas.width = RES;
  canvas.height = RES;

  const deviceScale = window.devicePixelRatio || 1;
  const cssSize = truePixels ? Math.max(1, Math.round(RES / deviceScale)) : RES;
  watchFrame.style.setProperty("--watch-size", `${cssSize}px`);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════════

const state = {
  creature: "ditto",
  stage: "adult",
  mood: 0.7,
  animSpeed: 1,
  persona: "drill",
  // action
  action: null,
  actionTime: 0,
  actionDuration: 1.5,
  // speech
  speechText: "",
  speechTimer: 0,
  // blink
  blinkTimer: 0,
  nextBlink: 2 + Math.random() * 4,
  // wander
  petX: 0, // offset from center, -1 to 1
  petTargetX: 0,
  wanderTimer: 3,
  isWalking: false,
};

// ═══════════════════════════════════════════════════════════════════════════════
// PERSONA LINES
// ═══════════════════════════════════════════════════════════════════════════════

const LINES = {
  drill: {
    idle: ["Sup.", "You gonna do something or what?", "Standing around isn't a workout.", "I'm waiting."],
    eat:  ["...Fine. That was edible.", "Twelve bites. Barely acceptable.", "Chew faster."],
    play: ["Don't let it go to your head.", "Again.", "Not bad. For you."],
    sleep: ["Finally. Rest up.", "Don't oversleep. We train at dawn."],
    clean: ["About time.", "Was starting to notice.", "Noted. Marginally less gross."],
  },
  hype: {
    idle: ["You're doing AMAZING just being here!!", "I believe in you SO MUCH!", "Just LOOK at us!! 💕"],
    eat:  ["YUMMY!! Thank you!!", "You're literally the BEST provider!! 🍗", "Nom nom nom!!"],
    play: ["WHEEE!! This is THE BEST!!", "SO much fun!! ✨", "AGAIN AGAIN AGAIN!!"],
    sleep: ["Sweet dreams, you absolute ANGEL! 🌙", "Rest up, superstar!"],
    clean: ["Sparkly clean!! LOVE IT! ✨", "So fresh and so clean clean!!"],
  },
  deadpan: {
    idle: ["...hey.", "Oh. We're doing this. Fine.", "I'm here. Riveting.", "Yep."],
    eat:  ["Food. Cool.", "Didn't hate it.", "Chewing. Thrilling."],
    play: ["Whee. Or whatever.", "That was... something.", "Fun. Allegedly."],
    sleep: ["Consciousness was overrated.", "Night.", "Zzz. Probably."],
    clean: ["Hygiene. Great.", "Marginally less gross. Congrats.", "Wet. Wonderful."],
  },
  zen: {
    idle: ["Whenever you're ready.", "Just breathing. It's enough.", "Present. Peaceful.", "🍃"],
    eat:  ["Nourishment. Thank you.", "Grateful for this.", "Mindful bite."],
    play: ["Joy in the moment.", "Nicely done.", "Pure play. Beautiful."],
    sleep: ["Rest now. You've earned it.", "Let go. Be still. 🌙"],
    clean: ["Fresh start.", "Clean body, clear mind.", "Renewed."],
  },
};

function getLine(persona, event) {
  const pool = LINES[persona]?.[event] || LINES.drill.idle;
  return pool[Math.floor(Math.random() * pool.length)];
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENVIRONMENT: STARS
// ═══════════════════════════════════════════════════════════════════════════════

const stars = Array.from({ length: 80 }, () => ({
  x: Math.random(),
  y: Math.random() * 0.55,
  r: Math.random() * 1.3 + 0.4,
  speed: Math.random() * 1.5 + 0.8,
  phase: Math.random() * Math.PI * 2,
}));

function drawStars(t) {
  for (const s of stars) {
    const a = 0.15 + 0.45 * (0.5 + 0.5 * Math.sin(t * s.speed + s.phase));
    ctx.fillStyle = `rgba(220, 220, 255, ${a})`;
    ctx.beginPath();
    ctx.arc(s.x * RES, s.y * RES, s.r * (RES / 416), 0, Math.PI * 2);
    ctx.fill();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENVIRONMENT: PARTICLES (fireflies / mood particles)
// ═══════════════════════════════════════════════════════════════════════════════

const particles = Array.from({ length: 30 }, () => spawnParticle());

function spawnParticle() {
  return {
    x: Math.random(),
    y: 0.3 + Math.random() * 0.5,
    vx: (Math.random() - 0.5) * 0.01,
    vy: -Math.random() * 0.008 - 0.002,
    life: Math.random(),
    maxLife: 3 + Math.random() * 4,
    size: Math.random() * 2 + 1,
  };
}

function updateParticles(dt) {
  for (let i = 0; i < particles.length; i++) {
    const p = particles[i];
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.life += dt;
    if (p.life > p.maxLife || p.y < 0 || p.x < -0.1 || p.x > 1.1) {
      particles[i] = spawnParticle();
      particles[i].life = 0;
    }
  }
}

function drawParticles(t, mood) {
  for (const p of particles) {
    const fade = 1 - p.life / p.maxLife;
    const pulse = 0.5 + 0.5 * Math.sin(t * 3 + p.x * 20);
    const alpha = fade * pulse * 0.5 * (0.3 + mood * 0.7);

    // Warm when happy, cool when sad
    const hue = mood > 0.5 ? 40 + mood * 20 : 200 + (1 - mood) * 30;
    const sat = 70 + mood * 30;

    ctx.fillStyle = `hsla(${hue}, ${sat}%, 70%, ${alpha})`;
    ctx.beginPath();
    ctx.arc(p.x * RES, p.y * RES, p.size * (RES / 416), 0, Math.PI * 2);
    ctx.fill();

    // Glow
    if (alpha > 0.15) {
      ctx.fillStyle = `hsla(${hue}, ${sat}%, 70%, ${alpha * 0.3})`;
      ctx.beginPath();
      ctx.arc(p.x * RES, p.y * RES, p.size * 3 * (RES / 416), 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENVIRONMENT: GROUND
// ═══════════════════════════════════════════════════════════════════════════════

function drawGround(t, mood) {
  const groundY = RES * 0.67;
  const scale = RES / 416;

  // Ground body
  const gHue = 100 + mood * 40;
  const gSat = 15 + mood * 20;
  const grad = ctx.createLinearGradient(0, groundY, 0, RES);
  grad.addColorStop(0, `hsl(${gHue}, ${gSat}%, 12%)`);
  grad.addColorStop(0.5, `hsl(${gHue}, ${gSat - 5}%, 7%)`);
  grad.addColorStop(1, `hsl(${gHue}, ${gSat - 10}%, 3%)`);

  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.moveTo(0, RES);
  for (let x = 0; x <= RES; x += 3) {
    const wave = Math.sin(x * 0.015 + t * 0.4) * 3 * scale
               + Math.sin(x * 0.04 + 1.5) * 1.5 * scale;
    ctx.lineTo(x, groundY + wave);
  }
  ctx.lineTo(RES, RES);
  ctx.closePath();
  ctx.fill();

  // Ground edge highlight
  ctx.strokeStyle = `hsla(${gHue}, ${gSat + 20}%, 25%, 0.5)`;
  ctx.lineWidth = 1.5 * scale;
  ctx.beginPath();
  for (let x = 0; x <= RES; x += 3) {
    const wave = Math.sin(x * 0.015 + t * 0.4) * 3 * scale
               + Math.sin(x * 0.04 + 1.5) * 1.5 * scale;
    if (x === 0) ctx.moveTo(x, groundY + wave);
    else ctx.lineTo(x, groundY + wave);
  }
  ctx.stroke();

  // Grass tufts
  ctx.strokeStyle = `hsla(${gHue + 20}, ${gSat + 15}%, 22%, 0.7)`;
  ctx.lineWidth = 1 * scale;
  ctx.lineCap = "round";
  for (let i = 0; i < 40; i++) {
    const gx = (i / 40 + 0.012) * RES;
    const baseWave = Math.sin(gx * 0.015 + t * 0.4) * 3 * scale
                   + Math.sin(gx * 0.04 + 1.5) * 1.5 * scale;
    const gy = groundY + baseWave;
    const angle = -Math.PI / 2 + Math.sin(t * 1.5 + i * 0.7) * 0.25;
    const len = (4 + Math.sin(i * 3.7) * 3) * scale;
    ctx.beginPath();
    ctx.moveTo(gx, gy);
    ctx.lineTo(gx + Math.cos(angle) * len, gy + Math.sin(angle) * len);
    ctx.stroke();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENVIRONMENT: MOOD LIGHTING
// ═══════════════════════════════════════════════════════════════════════════════

function drawMoodLight(mood) {
  const cx = RES / 2, cy = RES * 0.55;
  const r = RES * 0.5;

  // Warm glow from below when happy, cool dim when sad
  const hue = mood > 0.5 ? 30 + mood * 30 : 220;
  const alpha = 0.03 + mood * 0.06;

  const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
  grad.addColorStop(0, `hsla(${hue}, 60%, 50%, ${alpha})`);
  grad.addColorStop(1, `hsla(${hue}, 60%, 50%, 0)`);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, RES, RES);
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATUS HUD — stat arcs along the top
// ═══════════════════════════════════════════════════════════════════════════════

const STATS = [
  { key: "hunger",    icon: "🍗", color: "#60d060" },
  { key: "happiness", icon: "😊", color: "#f0c040" },
  { key: "energy",    icon: "⚡",  color: "#40a0f0" },
  { key: "hygiene",   icon: "✨",  color: "#40e0d0" },
  { key: "health",    icon: "❤️",  color: "#f06060" },
];

function drawStatusHud(mood) {
  const scale = RES / 416;
  const cx = RES / 2, cy = RES / 2;
  const arcR = RES / 2 - 14 * scale;
  const arcLen = 0.08; // radians per stat arc
  const gap = 0.015;
  const totalSpan = STATS.length * arcLen + (STATS.length - 1) * gap;
  const startAngle = -Math.PI / 2 - totalSpan / 2;

  // Derive stat values from mood for demo purposes
  const statVals = {
    hunger: Math.max(0, Math.min(1, mood + Math.sin(mood * 3) * 0.1)),
    happiness: mood,
    energy: Math.max(0, Math.min(1, mood * 0.8 + 0.2)),
    hygiene: Math.max(0, Math.min(1, mood * 0.7 + 0.15)),
    health: Math.max(0, Math.min(1, mood * 0.6 + 0.35)),
  };

  STATS.forEach((stat, i) => {
    const a0 = startAngle + i * (arcLen + gap);
    const a1 = a0 + arcLen;
    const val = statVals[stat.key];

    // Background arc
    ctx.strokeStyle = "rgba(255,255,255,0.08)";
    ctx.lineWidth = 5 * scale;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(cx, cy, arcR, a0, a1);
    ctx.stroke();

    // Filled arc
    ctx.strokeStyle = stat.color;
    ctx.lineWidth = 5 * scale;
    ctx.beginPath();
    ctx.arc(cx, cy, arcR, a0, a0 + (a1 - a0) * val);
    ctx.stroke();

    // Icon
    const iconAngle = (a0 + a1) / 2;
    const iconR = arcR - 14 * scale;
    const ix = cx + Math.cos(iconAngle) * iconR;
    const iy = cy + Math.sin(iconAngle) * iconR;
    ctx.font = `${10 * scale}px serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(stat.icon, ix, iy);
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEECH BUBBLE
// ═══════════════════════════════════════════════════════════════════════════════

function drawSpeechBubble(text, petScreenX, petScreenY, opacity) {
  if (!text || opacity <= 0) return;

  const scale = RES / 416;
  ctx.save();
  ctx.globalAlpha = opacity;

  const fontSize = 11 * scale;
  ctx.font = `500 ${fontSize}px Inter, sans-serif`;

  // Word wrap
  const maxW = RES * 0.55;
  const words = text.split(" ");
  const lines = [];
  let line = "";
  for (const word of words) {
    const test = line ? line + " " + word : word;
    if (ctx.measureText(test).width > maxW) {
      if (line) lines.push(line);
      line = word;
    } else {
      line = test;
    }
  }
  if (line) lines.push(line);

  const lineH = fontSize * 1.5;
  const padX = 10 * scale, padY = 7 * scale;
  const bubbleW = Math.min(maxW, Math.max(...lines.map(l => ctx.measureText(l).width))) + padX * 2;
  const bubbleH = lines.length * lineH + padY * 2;
  const bubbleX = Math.max(padX, Math.min(RES - bubbleW - padX, petScreenX - bubbleW / 2));
  const bubbleY = petScreenY - bubbleH - 16 * scale;
  const r = 8 * scale;

  // Bubble bg
  ctx.fillStyle = "rgba(20, 20, 40, 0.88)";
  ctx.beginPath();
  ctx.moveTo(bubbleX + r, bubbleY);
  ctx.lineTo(bubbleX + bubbleW - r, bubbleY);
  ctx.arcTo(bubbleX + bubbleW, bubbleY, bubbleX + bubbleW, bubbleY + r, r);
  ctx.lineTo(bubbleX + bubbleW, bubbleY + bubbleH - r);
  ctx.arcTo(bubbleX + bubbleW, bubbleY + bubbleH, bubbleX + bubbleW - r, bubbleY + bubbleH, r);
  ctx.lineTo(bubbleX + r, bubbleY + bubbleH);
  ctx.arcTo(bubbleX, bubbleY + bubbleH, bubbleX, bubbleY + bubbleH - r, r);
  ctx.lineTo(bubbleX, bubbleY + r);
  ctx.arcTo(bubbleX, bubbleY, bubbleX + r, bubbleY, r);
  ctx.closePath();
  ctx.fill();

  // Pointer triangle
  const px = petScreenX;
  ctx.beginPath();
  ctx.moveTo(px - 6 * scale, bubbleY + bubbleH);
  ctx.lineTo(px, bubbleY + bubbleH + 8 * scale);
  ctx.lineTo(px + 6 * scale, bubbleY + bubbleH);
  ctx.closePath();
  ctx.fill();

  // Border
  ctx.strokeStyle = "rgba(192, 132, 224, 0.35)";
  ctx.lineWidth = 1 * scale;
  ctx.stroke();

  // Text
  ctx.fillStyle = "#e0e0f0";
  ctx.textAlign = "left";
  ctx.textBaseline = "top";
  lines.forEach((l, i) => {
    ctx.fillText(l, bubbleX + padX, bubbleY + padY + i * lineH);
  });

  ctx.restore();
}

function getSpeechOpacity(timer) {
  if (timer <= 0) return 0;
  if (timer < 0.3) return timer / 0.3;
  if (timer > 2.7) return (3 - timer) / 0.3;
  return 1;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTION EFFECTS (food item, sparkles, zzz)
// ═══════════════════════════════════════════════════════════════════════════════

function drawActionEffects(action, progress, petX, petY, petSize, t) {
  if (!action) return;
  const scale = RES / 416;
  const s = petSize;

  if (action === "eat") {
    // Food item that gets smaller as eaten
    const remaining = 1 - progress;
    if (remaining > 0.05) {
      const fx = petX + s * 0.6;
      const fy = petY + s * 0.15;
      ctx.font = `${(14 + remaining * 8) * scale}px serif`;
      ctx.textAlign = "center";
      ctx.globalAlpha = remaining;
      ctx.fillText("🍗", fx, fy);
      ctx.globalAlpha = 1;
    }
  }

  if (action === "play") {
    // Star bursts
    const count = 6;
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * Math.PI * 2 + t * 2;
      const dist = s * (0.6 + progress * 0.8);
      const alpha = (1 - progress) * (0.4 + 0.4 * Math.sin(t * 5 + i));
      const sx = petX + Math.cos(angle) * dist;
      const sy = petY - s * 0.2 + Math.sin(angle) * dist * 0.6;
      ctx.fillStyle = `hsla(${50 + i * 30}, 90%, 70%, ${alpha})`;
      ctx.beginPath();
      ctx.arc(sx, sy, 2.5 * scale, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  if (action === "clean") {
    // Sparkles rising
    for (let i = 0; i < 8; i++) {
      const phase = progress * 3 + i * 0.7;
      const sparkX = petX + Math.sin(phase * 2 + i) * s * 0.8;
      const sparkY = petY - progress * s * 1.5 - i * 8 * scale;
      const alpha = Math.max(0, 1 - progress * 1.3) * (0.5 + 0.5 * Math.sin(phase * 4));
      ctx.fillStyle = `rgba(160, 230, 255, ${alpha})`;
      ctx.font = `${8 * scale}px serif`;
      ctx.fillText("✦", sparkX, sparkY);
    }
  }

  if (action === "sleep") {
    // Zzz floating up
    const zCount = 3;
    for (let i = 0; i < zCount; i++) {
      const zProgress = (progress * 2 + i * 0.3) % 1;
      const zx = petX + s * 0.5 + i * 10 * scale;
      const zy = petY - s * 0.5 - zProgress * s * 1.2;
      const alpha = Math.sin(zProgress * Math.PI) * 0.7;
      ctx.fillStyle = `rgba(150, 170, 255, ${alpha})`;
      ctx.font = `${(10 + i * 3) * scale}px Inter, sans-serif`;
      ctx.textAlign = "center";
      ctx.fillText("z", zx, zy);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PET SHADOW + GLOW
// ═══════════════════════════════════════════════════════════════════════════════

function drawPetShadow(x, y, size, mood) {
  const scale = RES / 416;
  const groundY = RES * 0.67;

  // Shadow on the ground
  const shadowY = groundY + 2 * scale;
  ctx.fillStyle = "rgba(0, 0, 0, 0.3)";
  ctx.beginPath();
  ctx.ellipse(x, shadowY, size * 0.6, size * 0.12, 0, 0, Math.PI * 2);
  ctx.fill();

  // Ambient glow behind pet
  const creature = getCreature(state.creature);
  const glowR = size * 1.2;
  const grad = ctx.createRadialGradient(x, y, 0, x, y, glowR);
  grad.addColorStop(0, `${creature.color}18`);
  grad.addColorStop(1, `${creature.color}00`);
  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.arc(x, y, glowR, 0, Math.PI * 2);
  ctx.fill();
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDER ORCHESTRATION
// ═══════════════════════════════════════════════════════════════════════════════

let globalTime = 0;

function render(dt) {
  globalTime += dt * state.animSpeed;
  const t = globalTime;
  const mood = state.mood;

  // ── Update systems ──
  updateParticles(dt * state.animSpeed);
  updateBlink(dt * state.animSpeed);
  updateWander(dt * state.animSpeed);
  updateAction(dt * state.animSpeed);
  updateSpeech(dt * state.animSpeed);

  // ── Clear + clip to round watch ──
  ctx.clearRect(0, 0, RES, RES);
  ctx.save();
  ctx.beginPath();
  ctx.arc(RES / 2, RES / 2, RES / 2, 0, Math.PI * 2);
  ctx.clip();

  // Background
  ctx.fillStyle = "#08080f";
  ctx.fillRect(0, 0, RES, RES);

  // Layers
  drawStars(t);
  drawMoodLight(mood);
  drawParticles(t, mood);
  drawGround(t, mood);

  // ── Pet ──
  const scale = RES / 416;
  const stageSize = { baby: 32, child: 42, adult: 52 }[state.stage] * scale;
  const groundY = RES * 0.67;
  const petScreenX = RES / 2 + state.petX * RES * 0.2;
  const petScreenY = groundY - stageSize * 0.5;

  drawPetShadow(petScreenX, petScreenY, stageSize, mood);

  const creature = getCreature(state.creature);
  const actionProg = state.action ? Math.min(1, state.actionTime / state.actionDuration) : 0;
  creature.draw(ctx, petScreenX, petScreenY, stageSize, {
    t,
    mood,
    stage: state.stage,
    action: state.action,
    actionProgress: actionProg,
    blink: state.blinkTimer > 0,
  });

  drawActionEffects(state.action, actionProg, petScreenX, petScreenY, stageSize, t);

  // HUD + speech
  drawStatusHud(mood);

  drawSpeechBubble(
    state.speechText,
    petScreenX,
    petScreenY - stageSize * 0.7,
    getSpeechOpacity(state.speechTimer),
  );

  // Bezel ring
  ctx.strokeStyle = "rgba(255,255,255,0.06)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.arc(RES / 2, RES / 2, RES / 2 - 1, 0, Math.PI * 2);
  ctx.stroke();

  ctx.restore();
}

// ═══════════════════════════════════════════════════════════════════════════════
// UPDATE SYSTEMS
// ═══════════════════════════════════════════════════════════════════════════════

function updateBlink(dt) {
  if (state.blinkTimer > 0) {
    state.blinkTimer -= dt;
    if (state.blinkTimer <= 0) {
      state.nextBlink = 2 + Math.random() * 5;
    }
  } else {
    state.nextBlink -= dt;
    if (state.nextBlink <= 0) {
      state.blinkTimer = 0.15;
    }
  }
}

function updateWander(dt) {
  if (state.action) return; // don't wander during actions

  state.wanderTimer -= dt;
  if (state.wanderTimer <= 0) {
    state.petTargetX = (Math.random() - 0.5) * 1.5;
    state.wanderTimer = 3 + Math.random() * 5;
    state.isWalking = true;
  }

  const dx = state.petTargetX - state.petX;
  if (Math.abs(dx) > 0.02) {
    state.petX += Math.sign(dx) * Math.min(Math.abs(dx), dt * 0.4);
  } else {
    state.isWalking = false;
  }
}

function updateAction(dt) {
  if (!state.action) return;
  state.actionTime += dt;
  if (state.actionTime >= state.actionDuration) {
    state.action = null;
    state.actionTime = 0;
    enableActionButtons(true);
  }
}

function updateSpeech(dt) {
  if (state.speechTimer > 0) {
    state.speechTimer -= dt;
    if (state.speechTimer <= 0) {
      state.speechText = "";
    }
  }
}

function triggerAction(actionId) {
  if (state.action) return;

  state.action = actionId;
  state.actionTime = 0;
  state.actionDuration = actionId === "sleep" ? 2.5 : 1.5;
  enableActionButtons(false);

  // Trigger speech for the action
  state.speechText = getLine(state.persona, actionId);
  state.speechTimer = 3;
}

function triggerSpeak() {
  const event = state.action || "idle";
  state.speechText = getLine(state.persona, event);
  state.speechTimer = 3;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANIMATION LOOP
// ═══════════════════════════════════════════════════════════════════════════════

let lastTimestamp = 0;

function frame(timestamp) {
  const dt = lastTimestamp ? Math.min((timestamp - lastTimestamp) / 1000, 0.1) : 0.016;
  lastTimestamp = timestamp;
  render(dt);
  requestAnimationFrame(frame);
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLS
// ═══════════════════════════════════════════════════════════════════════════════

function enableActionButtons(enabled) {
  document.querySelectorAll(".btn-action").forEach(b => b.disabled = !enabled);
}

function formatStage(stage) {
  return stage.charAt(0).toUpperCase() + stage.slice(1);
}

function updateControlMeta() {
  if (!controlMeta) return;

  const creature = getCreature(state.creature);
  controlMeta.textContent = `${creature.name} - ${formatStage(state.stage)}`;
}

function syncControlSheetForViewport() {
  if (!controlSheet) return;
  controlSheet.open = wideLayoutQuery.matches || forceControlsOpen;
  updateControlSheetStateClass();
}

function updateControlSheetStateClass() {
  if (!controlSheet) return;
  document.documentElement.classList.toggle("controls-open", controlSheet.open);
}

function initControls() {
  // Creature select
  const creatureSel = document.getElementById("creature-select");
  getCreatureNames().forEach(({ id, name }) => {
    const opt = document.createElement("option");
    opt.value = id;
    opt.textContent = name;
    creatureSel.appendChild(opt);
  });
  creatureSel.value = state.creature;
  creatureSel.addEventListener("change", () => {
    state.creature = creatureSel.value;
    updateControlMeta();
  });

  // Resolution
  const resSel = document.getElementById("res-select");
  resSel.addEventListener("change", () => resize(Number.parseInt(resSel.value, 10)));

  // 1:1 pixel toggle
  const pixelToggle = document.getElementById("pixel-toggle");
  pixelToggle.addEventListener("change", () => {
    truePixels = pixelToggle.checked;
    resize(RES);
  });

  // Stage
  document.querySelectorAll('input[name="stage"]').forEach(radio => {
    radio.addEventListener("change", () => {
      state.stage = radio.value;
      updateControlMeta();
    });
  });

  // Mood
  const moodSlider = document.getElementById("mood-slider");
  const moodValue = document.getElementById("mood-value");
  moodSlider.addEventListener("input", () => {
    state.mood = Number.parseInt(moodSlider.value, 10) / 100;
    moodValue.textContent = moodSlider.value + "%";
  });

  // Speed
  const speedSlider = document.getElementById("speed-slider");
  const speedValue = document.getElementById("speed-value");
  speedSlider.addEventListener("input", () => {
    state.animSpeed = Number.parseInt(speedSlider.value, 10) / 100;
    speedValue.textContent = state.animSpeed.toFixed(1) + "x";
  });

  // Persona
  const personaSel = document.getElementById("persona-select");
  personaSel.addEventListener("change", () => { state.persona = personaSel.value; });

  // Actions
  document.querySelectorAll(".btn-action").forEach(btn => {
    btn.addEventListener("click", () => triggerAction(btn.dataset.action));
  });

  // Speak
  document.getElementById("speak-btn").addEventListener("click", triggerSpeak);

  updateControlMeta();
}

// ═══════════════════════════════════════════════════════════════════════════════
// INIT
// ═══════════════════════════════════════════════════════════════════════════════

resize(416);
initControls();
syncControlSheetForViewport();
controlSheet?.addEventListener("toggle", updateControlSheetStateClass);
wideLayoutQuery.addEventListener("change", syncControlSheetForViewport);
window.addEventListener("resize", () => resize(RES));
requestAnimationFrame(frame);
