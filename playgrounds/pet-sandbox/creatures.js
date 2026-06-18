// ═══════════════════════════════════════════════════════════════════════════════
// CREATURE DEFINITIONS — Pet Sandbox
// ═══════════════════════════════════════════════════════════════════════════════
//
// HOW TO ADD A NEW CREATURE
// ─────────────────────────
// 1. Write a `draw(ctx, x, y, size, anim)` function (see interface below).
// 2. Register it:  creatures.myCreature = { name: "My Creature", color: "#hex", draw };
// 3. It appears in the sidebar dropdown automatically.
//
// DRAW INTERFACE
// ──────────────
//   ctx   — CanvasRenderingContext2D (already translated/clipped to the watch circle)
//   x, y  — center position of the creature in canvas coords
//   size  — base radius in px (~30 baby, ~40 child, ~50 adult at 416 res)
//   anim  — object:
//     t              : number  — global time in seconds (use for continuous animation)
//     mood           : number  — 0 (miserable) → 1 (ecstatic)
//     stage          : string  — 'baby' | 'child' | 'adult'
//     action         : string|null — null | 'eat' | 'play' | 'clean' | 'sleep'
//     actionProgress : number  — 0→1 during an action (eased)
//     blink          : boolean — true when the eyes should be closed
//
// The creature draws itself centered at (x, y). Size is already stage-adjusted.
// Use whatever Canvas 2D calls you like — paths, gradients, arcs, beziers.
// Keep it self-contained: no imports, no external assets needed.
// ═══════════════════════════════════════════════════════════════════════════════

export const creatures = {};

// ─── HELPER: organic wobble offset ──────────────────────────────────────────
function wobble(t, i, amt) {
  return Math.sin(t * 1.4 + i * 2.17) * amt;
}

// ─── HELPER: ease-in-out for action progress ────────────────────────────────
function ease(p) {
  return p < 0.5 ? 2 * p * p : 1 - Math.pow(-2 * p + 2, 2) / 2;
}

// ═══════════════════════════════════════════════════════════════════════════════
// DITTO — the placeholder blob
// ═══════════════════════════════════════════════════════════════════════════════

creatures.ditto = {
  name: "Ditto",
  color: "#c084e0",

  draw(ctx, x, y, size, anim) {
    const { t, mood, action, actionProgress, blink } = anim;
    const s = size;

    // ── Action-driven offsets ──
    let offY = 0, scaleX = 1, scaleY = 1, rot = 0;

    if (action === "eat") {
      // Lean forward, squish
      const p = ease(actionProgress);
      const chomp = Math.sin(p * Math.PI * 4); // chewing oscillation
      offY = Math.sin(p * Math.PI) * -s * 0.15;
      scaleX = 1 + chomp * 0.06;
      scaleY = 1 - chomp * 0.06;
    } else if (action === "play") {
      // Bounce! spin!
      const p = ease(actionProgress);
      offY = -Math.abs(Math.sin(p * Math.PI * 3)) * s * 0.7;
      rot = Math.sin(p * Math.PI * 2) * 0.3;
      scaleX = 1 + Math.sin(p * Math.PI * 6) * 0.08;
      scaleY = 1 - Math.sin(p * Math.PI * 6) * 0.08;
    } else if (action === "sleep") {
      // Settle down, flatten
      const p = ease(Math.min(actionProgress * 2, 1));
      offY = p * s * 0.2;
      scaleX = 1 + p * 0.2;
      scaleY = 1 - p * 0.25;
    } else if (action === "clean") {
      // Shake!
      const p = actionProgress;
      const shake = Math.sin(p * Math.PI * 16) * (1 - p);
      rot = shake * 0.2;
    } else {
      // Idle: gentle breathe
      const breathe = Math.sin(t * 2) * 0.04;
      scaleX = 1 + breathe;
      scaleY = 1 - breathe;
    }

    ctx.save();
    ctx.translate(x, y + offY);
    ctx.rotate(rot);
    ctx.scale(scaleX, scaleY);

    // ── BODY — blobby bezier shape ──
    const bodyHue = 280 + mood * 15;          // shift slightly warmer when happy
    const bodySat = 50 + mood * 20;
    const bodyLit = 65 + mood * 8;
    const bodyColor = `hsl(${bodyHue}, ${bodySat}%, ${bodyLit}%)`;
    const highlightColor = `hsl(${bodyHue}, ${bodySat + 10}%, ${bodyLit + 15}%)`;

    // Main blob
    ctx.fillStyle = bodyColor;
    ctx.beginPath();
    const w = (i) => wobble(t, i, s * 0.035);
    ctx.moveTo(0, s * 0.52 + w(0));
    ctx.bezierCurveTo(
      s * 0.45 + w(1),  s * 0.52 + w(2),
      s * 0.75 + w(3),  s * 0.3 + w(4),
      s * 0.72 + w(5),  -s * 0.05 + w(6)
    );
    ctx.bezierCurveTo(
      s * 0.7 + w(7),   -s * 0.4 + w(8),
      s * 0.45 + w(9),  -s * 0.62 + w(10),
      0 + w(11),        -s * 0.6 + w(12)
    );
    ctx.bezierCurveTo(
      -s * 0.45 + w(13), -s * 0.62 + w(14),
      -s * 0.7 + w(15),  -s * 0.4 + w(16),
      -s * 0.72 + w(17), -s * 0.05 + w(18)
    );
    ctx.bezierCurveTo(
      -s * 0.75 + w(19), s * 0.3 + w(20),
      -s * 0.45 + w(21), s * 0.52 + w(22),
      0,                  s * 0.52 + w(23)
    );
    ctx.fill();

    // Highlight (specular blob, upper-left)
    ctx.fillStyle = highlightColor;
    ctx.globalAlpha = 0.35;
    ctx.beginPath();
    ctx.ellipse(-s * 0.2, -s * 0.3, s * 0.22, s * 0.15, -0.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;

    // ── FACE ──
    const isSleeping = action === "sleep" && actionProgress > 0.3;
    const eyeY = -s * 0.12;
    const eyeSpacing = s * 0.22;
    const eyeR = s * 0.055;

    if (isSleeping || blink) {
      // Closed eyes — happy arcs when sleeping, flat lines when blinking
      ctx.strokeStyle = "#3a2a4a";
      ctx.lineWidth = Math.max(2, s * 0.04);
      ctx.lineCap = "round";

      if (isSleeping) {
        // Peaceful arcs
        [-1, 1].forEach(dir => {
          ctx.beginPath();
          ctx.arc(eyeSpacing * dir, eyeY, eyeR * 1.2, 0, Math.PI, false);
          ctx.stroke();
        });
      } else {
        // Blink lines
        [-1, 1].forEach(dir => {
          ctx.beginPath();
          ctx.moveTo(eyeSpacing * dir - eyeR, eyeY);
          ctx.lineTo(eyeSpacing * dir + eyeR, eyeY);
          ctx.stroke();
        });
      }
    } else {
      // Open eyes — dots
      ctx.fillStyle = "#3a2a4a";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir, eyeY, eyeR, 0, Math.PI * 2);
        ctx.fill();
      });

      // Eye shine
      ctx.fillStyle = "rgba(255,255,255,0.7)";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir - eyeR * 0.35, eyeY - eyeR * 0.35, eyeR * 0.35, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    // Mouth
    if (!isSleeping) {
      const mouthY = s * 0.1;
      const mouthW = s * 0.14;
      const curve = (mood - 0.4) * s * 0.22; // up when happy, down when sad
      const mouthOpen = action === "eat" ? Math.abs(Math.sin(actionProgress * Math.PI * 4)) * s * 0.08 : 0;

      ctx.strokeStyle = "#3a2a4a";
      ctx.lineWidth = Math.max(1.5, s * 0.03);
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-mouthW, mouthY);
      ctx.quadraticCurveTo(0, mouthY - curve, mouthW, mouthY);
      ctx.stroke();

      if (mouthOpen > 1) {
        ctx.fillStyle = "#5a3a6a";
        ctx.beginPath();
        ctx.ellipse(0, mouthY + mouthOpen * 0.3, mouthW * 0.6, mouthOpen, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // ── BLUSH (when happy) ──
    if (mood > 0.6) {
      const blushAlpha = (mood - 0.6) * 2;
      ctx.fillStyle = `rgba(255, 120, 150, ${blushAlpha * 0.25})`;
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.ellipse(eyeSpacing * dir * 1.3, eyeY + s * 0.12, s * 0.1, s * 0.06, 0, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    ctx.restore();
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KIRB — round puffball (Kirby-inspired)
// ═══════════════════════════════════════════════════════════════════════════════

creatures.kirb = {
  name: "Kirb",
  color: "#ff8faf",

  draw(ctx, x, y, size, anim) {
    const { t, mood, action, actionProgress, blink, stage } = anim;
    const s = size;

    let offY = 0, scaleX = 1, scaleY = 1, rot = 0;
    if (action === "eat") {
      // Inflate!
      const p = ease(actionProgress);
      scaleX = 1 + Math.sin(p * Math.PI) * 0.35;
      scaleY = 1 + Math.sin(p * Math.PI) * 0.25;
    } else if (action === "play") {
      offY = -Math.abs(Math.sin(ease(actionProgress) * Math.PI * 3)) * s * 0.8;
      rot = Math.sin(ease(actionProgress) * Math.PI * 4) * 0.4;
    } else if (action === "sleep") {
      const p = ease(Math.min(actionProgress * 2, 1));
      offY = p * s * 0.15;
      scaleY = 1 - p * 0.2;
      scaleX = 1 + p * 0.15;
    } else if (action === "clean") {
      rot = Math.sin(actionProgress * Math.PI * 14) * 0.15 * (1 - actionProgress);
    } else {
      const b = Math.sin(t * 1.8) * 0.03;
      scaleX = 1 + b; scaleY = 1 - b;
    }

    ctx.save();
    ctx.translate(x, y + offY);
    ctx.rotate(rot);
    ctx.scale(scaleX, scaleY);

    // Body — near-perfect circle
    const hue = 340 + mood * 15;
    ctx.fillStyle = `hsl(${hue}, 80%, 75%)`;
    ctx.beginPath();
    ctx.arc(0, 0, s * 0.6, 0, Math.PI * 2);
    ctx.fill();

    // Highlight
    ctx.fillStyle = `hsla(${hue}, 90%, 88%, 0.5)`;
    ctx.beginPath();
    ctx.ellipse(-s * 0.15, -s * 0.2, s * 0.2, s * 0.13, -0.3, 0, Math.PI * 2);
    ctx.fill();

    // Feet — two little ovals at the bottom
    ctx.fillStyle = `hsl(${hue - 15}, 70%, 55%)`;
    [-1, 1].forEach(dir => {
      ctx.beginPath();
      ctx.ellipse(dir * s * 0.25, s * 0.5, s * 0.15, s * 0.08, dir * 0.2, 0, Math.PI * 2);
      ctx.fill();
    });

    // Arms — little stubs
    const armWave = Math.sin(t * 3 + (action === "play" ? actionProgress * 20 : 0)) * 0.3;
    ctx.fillStyle = `hsl(${hue}, 80%, 75%)`;
    [-1, 1].forEach(dir => {
      ctx.save();
      ctx.translate(dir * s * 0.5, s * 0.05);
      ctx.rotate(dir * (0.5 + armWave));
      ctx.beginPath();
      ctx.ellipse(0, 0, s * 0.12, s * 0.08, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    });

    // Eyes
    const eyeY = -s * 0.08;
    const eyeSpacing = s * 0.18;
    const eyeH = blink || (action === "sleep" && actionProgress > 0.3) ? s * 0.01 : s * 0.12;
    ctx.fillStyle = "#1a1040";
    [-1, 1].forEach(dir => {
      ctx.beginPath();
      ctx.ellipse(eyeSpacing * dir, eyeY, s * 0.07, eyeH, 0, 0, Math.PI * 2);
      ctx.fill();
    });
    if (eyeH > s * 0.05) {
      ctx.fillStyle = "rgba(255,255,255,0.8)";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir - s * 0.02, eyeY - s * 0.04, s * 0.025, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    // Mouth — small happy curve
    const mouthCurve = (mood - 0.3) * s * 0.18;
    ctx.strokeStyle = "#2a1040";
    ctx.lineWidth = Math.max(1.5, s * 0.025);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(-s * 0.08, s * 0.12);
    ctx.quadraticCurveTo(0, s * 0.12 - mouthCurve, s * 0.08, s * 0.12);
    ctx.stroke();

    // Blush
    if (mood > 0.5) {
      ctx.fillStyle = `rgba(255, 80, 120, ${(mood - 0.5) * 0.4})`;
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.ellipse(eyeSpacing * dir * 1.5, eyeY + s * 0.12, s * 0.07, s * 0.04, 0, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    ctx.restore();
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SLIMO — teardrop slime (Dragon Quest-inspired)
// ═══════════════════════════════════════════════════════════════════════════════

creatures.slimo = {
  name: "Slimo",
  color: "#40b8f0",

  draw(ctx, x, y, size, anim) {
    const { t, mood, action, actionProgress, blink } = anim;
    const s = size;

    let offY = 0, scaleX = 1, scaleY = 1;
    if (action === "eat") {
      scaleX = 1 + Math.sin(actionProgress * Math.PI * 5) * 0.1;
      scaleY = 1 - Math.sin(actionProgress * Math.PI * 5) * 0.08;
    } else if (action === "play") {
      // Massive squash-and-stretch bouncing
      const p = ease(actionProgress);
      offY = -Math.abs(Math.sin(p * Math.PI * 3)) * s * 0.9;
      const squash = Math.sin(p * Math.PI * 3);
      scaleX = 1 + (squash > 0 ? -squash * 0.15 : -squash * 0.25);
      scaleY = 1 + (squash > 0 ? squash * 0.2 : squash * 0.15);
    } else if (action === "sleep") {
      const p = ease(Math.min(actionProgress * 2, 1));
      scaleY = 1 - p * 0.35;
      scaleX = 1 + p * 0.25;
      offY = p * s * 0.2;
    } else if (action === "clean") {
      // Jiggle
      scaleX = 1 + Math.sin(actionProgress * Math.PI * 12) * 0.1 * (1 - actionProgress);
      scaleY = 1 - Math.sin(actionProgress * Math.PI * 12) * 0.08 * (1 - actionProgress);
    } else {
      // Idle: constant gentle bounce
      const bounce = Math.sin(t * 2.5);
      offY = bounce * s * 0.04;
      scaleX = 1 + bounce * 0.03;
      scaleY = 1 - bounce * 0.03;
    }

    ctx.save();
    ctx.translate(x, y + offY);
    ctx.scale(scaleX, scaleY);

    // Body — teardrop: wide bottom, pointy top
    const hue = 200 + mood * 20;
    const bodyGrad = ctx.createLinearGradient(0, -s * 0.7, 0, s * 0.5);
    bodyGrad.addColorStop(0, `hsl(${hue}, 75%, 70%)`);
    bodyGrad.addColorStop(0.5, `hsl(${hue}, 80%, 55%)`);
    bodyGrad.addColorStop(1, `hsl(${hue}, 70%, 45%)`);
    ctx.fillStyle = bodyGrad;

    ctx.beginPath();
    ctx.moveTo(0, -s * 0.7 + wobble(t, 0, s * 0.03)); // pointy top
    ctx.bezierCurveTo(
      s * 0.15 + wobble(t, 1, s * 0.02), -s * 0.55,
      s * 0.6 + wobble(t, 2, s * 0.02), -s * 0.15,
      s * 0.6 + wobble(t, 3, s * 0.02), s * 0.15
    );
    ctx.bezierCurveTo(
      s * 0.6 + wobble(t, 4, s * 0.02), s * 0.45,
      s * 0.3, s * 0.55,
      0, s * 0.55
    );
    ctx.bezierCurveTo(
      -s * 0.3, s * 0.55,
      -s * 0.6 + wobble(t, 5, s * 0.02), s * 0.45,
      -s * 0.6 + wobble(t, 6, s * 0.02), s * 0.15
    );
    ctx.bezierCurveTo(
      -s * 0.6 + wobble(t, 7, s * 0.02), -s * 0.15,
      -s * 0.15 + wobble(t, 8, s * 0.02), -s * 0.55,
      0, -s * 0.7 + wobble(t, 9, s * 0.03)
    );
    ctx.fill();

    // Specular highlight
    ctx.fillStyle = "rgba(255,255,255,0.3)";
    ctx.beginPath();
    ctx.ellipse(-s * 0.18, -s * 0.1, s * 0.15, s * 0.22, -0.2, 0, Math.PI * 2);
    ctx.fill();

    // Eyes — large, friendly
    const eyeY = s * 0.0;
    const eyeSpacing = s * 0.2;
    const isSleeping = action === "sleep" && actionProgress > 0.3;

    if (blink || isSleeping) {
      ctx.strokeStyle = "#1a3060";
      ctx.lineWidth = Math.max(2, s * 0.035);
      ctx.lineCap = "round";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir, eyeY, s * 0.06, 0, Math.PI, isSleeping);
        ctx.stroke();
      });
    } else {
      ctx.fillStyle = "#1a3060";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir, eyeY, s * 0.07, 0, Math.PI * 2);
        ctx.fill();
      });
      ctx.fillStyle = "rgba(255,255,255,0.85)";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir + s * 0.02, eyeY - s * 0.03, s * 0.03, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    // Mouth — big happy grin
    if (!isSleeping) {
      const grin = (mood - 0.2) * s * 0.25;
      ctx.strokeStyle = "#1a3060";
      ctx.lineWidth = Math.max(1.5, s * 0.03);
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-s * 0.14, s * 0.18);
      ctx.quadraticCurveTo(0, s * 0.18 - grin, s * 0.14, s * 0.18);
      ctx.stroke();
    }

    ctx.restore();
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// KODAMA — forest spirit (Mononoke-inspired)
// ═══════════════════════════════════════════════════════════════════════════════

creatures.kodama = {
  name: "Kodama",
  color: "#c8e8d0",

  draw(ctx, x, y, size, anim) {
    const { t, mood, action, actionProgress, blink } = anim;
    const s = size;

    let offY = 0, rot = 0, scaleX = 1, scaleY = 1;
    // Head rattle — the classic kodama tilt
    const rattle = Math.sin(t * 1.2) * 0.12;

    if (action === "eat") {
      rot = Math.sin(actionProgress * Math.PI * 6) * 0.15;
    } else if (action === "play") {
      offY = -Math.abs(Math.sin(ease(actionProgress) * Math.PI * 2)) * s * 0.5;
      rot = Math.sin(ease(actionProgress) * Math.PI * 6) * 0.3;
    } else if (action === "sleep") {
      const p = ease(Math.min(actionProgress * 2, 1));
      offY = p * s * 0.1;
      rot = p * 0.2;
    } else if (action === "clean") {
      rot = Math.sin(actionProgress * Math.PI * 10) * 0.2 * (1 - actionProgress);
    }

    ctx.save();
    ctx.translate(x, y + offY);

    // Body — small, pale, vaguely humanoid
    const bodyAlpha = 0.85 + mood * 0.15;
    ctx.fillStyle = `rgba(210, 230, 215, ${bodyAlpha})`;

    // Torso
    ctx.beginPath();
    ctx.moveTo(-s * 0.2, s * 0.5);
    ctx.bezierCurveTo(-s * 0.25, s * 0.1, -s * 0.2, -s * 0.1, -s * 0.15, -s * 0.15);
    ctx.lineTo(s * 0.15, -s * 0.15);
    ctx.bezierCurveTo(s * 0.2, -s * 0.1, s * 0.25, s * 0.1, s * 0.2, s * 0.5);
    ctx.closePath();
    ctx.fill();

    // Arms — little sticks
    ctx.strokeStyle = `rgba(190, 215, 195, ${bodyAlpha})`;
    ctx.lineWidth = Math.max(2, s * 0.04);
    ctx.lineCap = "round";
    const armSwing = Math.sin(t * 2) * 0.2;
    [-1, 1].forEach(dir => {
      ctx.beginPath();
      ctx.moveTo(dir * s * 0.2, s * 0.1);
      ctx.lineTo(dir * s * 0.38, s * 0.25 + Math.sin(t * 1.5 + dir) * s * 0.05);
      ctx.stroke();
    });

    // Head — large, round, tilting
    ctx.save();
    ctx.translate(0, -s * 0.15);
    ctx.rotate(rattle + rot);

    ctx.fillStyle = `rgba(220, 240, 225, ${bodyAlpha})`;
    ctx.beginPath();
    ctx.arc(0, -s * 0.15, s * 0.32, 0, Math.PI * 2);
    ctx.fill();

    // Face — hollow dark marks
    const isSleeping = action === "sleep" && actionProgress > 0.3;
    const eyeY = -s * 0.18;

    if (isSleeping || blink) {
      ctx.strokeStyle = "rgba(40, 60, 50, 0.6)";
      ctx.lineWidth = Math.max(1.5, s * 0.03);
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.moveTo(dir * s * 0.07, eyeY);
        ctx.lineTo(dir * s * 0.15, eyeY);
        ctx.stroke();
      });
    } else {
      // Dark hollow eyes
      ctx.fillStyle = "rgba(30, 50, 40, 0.7)";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.ellipse(dir * s * 0.12, eyeY, s * 0.04, s * 0.055, 0, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    // Mouth — small triangle or circle
    if (!isSleeping) {
      ctx.fillStyle = "rgba(30, 50, 40, 0.5)";
      ctx.beginPath();
      ctx.arc(0, -s * 0.05, s * 0.035 + mood * s * 0.02, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore(); // head transform

    // Subtle glow — spirits are luminous
    ctx.fillStyle = `rgba(200, 255, 210, ${0.05 + mood * 0.05})`;
    ctx.beginPath();
    ctx.arc(0, -s * 0.1, s * 0.5, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// DRACO — tiny dragon/salamander
// ═══════════════════════════════════════════════════════════════════════════════

creatures.draco = {
  name: "Draco",
  color: "#f08040",

  draw(ctx, x, y, size, anim) {
    const { t, mood, action, actionProgress, blink } = anim;
    const s = size;

    let offY = 0, scaleX = 1, scaleY = 1, rot = 0;
    if (action === "eat") {
      // Fire breath! (head tilts back then forward)
      const p = ease(actionProgress);
      rot = Math.sin(p * Math.PI) * -0.2;
    } else if (action === "play") {
      offY = -Math.abs(Math.sin(ease(actionProgress) * Math.PI * 2.5)) * s * 0.6;
      rot = Math.sin(ease(actionProgress) * Math.PI * 3) * 0.25;
    } else if (action === "sleep") {
      const p = ease(Math.min(actionProgress * 2, 1));
      offY = p * s * 0.15;
      scaleY = 1 - p * 0.15;
    } else if (action === "clean") {
      rot = Math.sin(actionProgress * Math.PI * 12) * 0.15 * (1 - actionProgress);
    } else {
      const b = Math.sin(t * 2.2) * 0.025;
      scaleX = 1 + b; scaleY = 1 - b;
    }

    ctx.save();
    ctx.translate(x, y + offY);
    ctx.rotate(rot);
    ctx.scale(scaleX, scaleY);

    const hue = 20 + mood * 15;

    // Tail — wavy line behind
    const tailWag = Math.sin(t * 3) * 0.4;
    ctx.strokeStyle = `hsl(${hue}, 70%, 50%)`;
    ctx.lineWidth = Math.max(3, s * 0.06);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(-s * 0.3, s * 0.15);
    ctx.quadraticCurveTo(
      -s * 0.6, s * 0.1 + Math.sin(t * 3) * s * 0.1,
      -s * 0.75, -s * 0.05 + Math.sin(t * 3 + 1) * s * 0.15
    );
    ctx.stroke();

    // Body — rounded rectangle-ish, warm orange
    const bodyGrad = ctx.createLinearGradient(0, -s * 0.4, 0, s * 0.5);
    bodyGrad.addColorStop(0, `hsl(${hue}, 75%, 60%)`);
    bodyGrad.addColorStop(1, `hsl(${hue}, 65%, 45%)`);
    ctx.fillStyle = bodyGrad;
    ctx.beginPath();
    ctx.ellipse(0, s * 0.05, s * 0.4, s * 0.38, 0, 0, Math.PI * 2);
    ctx.fill();

    // Belly — lighter patch
    ctx.fillStyle = `hsl(${hue + 15}, 60%, 75%)`;
    ctx.beginPath();
    ctx.ellipse(0, s * 0.15, s * 0.25, s * 0.2, 0, 0, Math.PI * 2);
    ctx.fill();

    // Legs — two little stubs at bottom
    ctx.fillStyle = `hsl(${hue}, 70%, 50%)`;
    [-1, 1].forEach(dir => {
      ctx.beginPath();
      ctx.ellipse(dir * s * 0.25, s * 0.4, s * 0.1, s * 0.07, dir * 0.3, 0, Math.PI * 2);
      ctx.fill();
    });

    // Head — slightly larger circle on top
    ctx.fillStyle = `hsl(${hue}, 75%, 58%)`;
    ctx.beginPath();
    ctx.arc(0, -s * 0.25, s * 0.28, 0, Math.PI * 2);
    ctx.fill();

    // Horns — two small triangles
    ctx.fillStyle = `hsl(${hue - 5}, 50%, 40%)`;
    [-1, 1].forEach(dir => {
      ctx.beginPath();
      ctx.moveTo(dir * s * 0.12, -s * 0.48);
      ctx.lineTo(dir * s * 0.2, -s * 0.62);
      ctx.lineTo(dir * s * 0.06, -s * 0.45);
      ctx.closePath();
      ctx.fill();
    });

    // Eyes
    const isSleeping = action === "sleep" && actionProgress > 0.3;
    const eyeY = -s * 0.28;
    const eyeSpacing = s * 0.13;

    if (blink || isSleeping) {
      ctx.strokeStyle = "#3a1a10";
      ctx.lineWidth = Math.max(1.5, s * 0.03);
      ctx.lineCap = "round";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.moveTo(eyeSpacing * dir - s * 0.04, eyeY);
        ctx.lineTo(eyeSpacing * dir + s * 0.04, eyeY);
        ctx.stroke();
      });
    } else {
      // Fierce little eyes
      ctx.fillStyle = "#3a1a10";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir, eyeY, s * 0.05, 0, Math.PI * 2);
        ctx.fill();
      });
      // Glint
      ctx.fillStyle = `rgba(255, 200, 100, 0.8)`;
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir + s * 0.015, eyeY - s * 0.02, s * 0.02, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    // Snout / nostrils
    ctx.fillStyle = "#3a1a10";
    [-1, 1].forEach(dir => {
      ctx.beginPath();
      ctx.arc(dir * s * 0.06, -s * 0.15, s * 0.015, 0, Math.PI * 2);
      ctx.fill();
    });

    // Mouth — slight grin
    if (!isSleeping) {
      ctx.strokeStyle = "#3a1a10";
      ctx.lineWidth = Math.max(1.5, s * 0.025);
      ctx.lineCap = "round";
      const grin = (mood - 0.3) * s * 0.15;
      ctx.beginPath();
      ctx.moveTo(-s * 0.1, -s * 0.1);
      ctx.quadraticCurveTo(0, -s * 0.1 - grin, s * 0.1, -s * 0.1);
      ctx.stroke();
    }

    // Fire puff when eating
    if (action === "eat" && actionProgress > 0.3 && actionProgress < 0.8) {
      const fireAlpha = Math.sin((actionProgress - 0.3) / 0.5 * Math.PI) * 0.7;
      for (let i = 0; i < 4; i++) {
        const fx = s * 0.3 + i * s * 0.15;
        const fy = -s * 0.2 + Math.sin(t * 8 + i) * s * 0.08;
        const fr = (s * 0.08 - i * s * 0.015);
        ctx.fillStyle = `hsla(${30 - i * 10}, 100%, ${60 + i * 8}%, ${fireAlpha * (1 - i * 0.2)})`;
        ctx.beginPath();
        ctx.arc(fx, fy, fr, 0, Math.PI * 2);
        ctx.fill();
      }
    }

    ctx.restore();
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// SPROUT — plant creature (Oddish/Korok-inspired)
// ═══════════════════════════════════════════════════════════════════════════════

creatures.sprout = {
  name: "Sprout",
  color: "#60c040",

  draw(ctx, x, y, size, anim) {
    const { t, mood, action, actionProgress, blink, stage } = anim;
    const s = size;

    let offY = 0, rot = 0, scaleX = 1, scaleY = 1;
    if (action === "eat") {
      scaleY = 1 + Math.sin(actionProgress * Math.PI * 5) * 0.06;
    } else if (action === "play") {
      offY = -Math.abs(Math.sin(ease(actionProgress) * Math.PI * 2)) * s * 0.4;
      rot = Math.sin(ease(actionProgress) * Math.PI * 5) * 0.2;
    } else if (action === "sleep") {
      const p = ease(Math.min(actionProgress * 2, 1));
      offY = p * s * 0.1;
      rot = p * 0.15;
    } else if (action === "clean") {
      rot = Math.sin(actionProgress * Math.PI * 10) * 0.12 * (1 - actionProgress);
    } else {
      // Gentle sway like a plant
      rot = Math.sin(t * 1.0) * 0.06;
      const b = Math.sin(t * 1.5) * 0.02;
      scaleY = 1 + b;
    }

    ctx.save();
    ctx.translate(x, y + offY);
    ctx.rotate(rot);
    ctx.scale(scaleX, scaleY);

    const hue = 100 + mood * 30;

    // Roots / feet — little brown nubs
    ctx.fillStyle = `hsl(30, 40%, 35%)`;
    [-1, 0, 1].forEach(dir => {
      ctx.beginPath();
      ctx.ellipse(dir * s * 0.15, s * 0.5, s * 0.06, s * 0.04, dir * 0.3, 0, Math.PI * 2);
      ctx.fill();
    });

    // Body — round, green
    const bodyGrad = ctx.createRadialGradient(0, 0, 0, 0, 0, s * 0.45);
    bodyGrad.addColorStop(0, `hsl(${hue}, 55%, 55%)`);
    bodyGrad.addColorStop(1, `hsl(${hue - 10}, 50%, 38%)`);
    ctx.fillStyle = bodyGrad;
    ctx.beginPath();
    ctx.arc(0, s * 0.1, s * 0.4, 0, Math.PI * 2);
    ctx.fill();

    // Face mask — lighter area
    ctx.fillStyle = `hsl(${hue + 10}, 40%, 70%)`;
    ctx.beginPath();
    ctx.ellipse(0, s * 0.12, s * 0.28, s * 0.22, 0, 0, Math.PI * 2);
    ctx.fill();

    // Eyes
    const isSleeping = action === "sleep" && actionProgress > 0.3;
    const eyeY = s * 0.05;
    const eyeSpacing = s * 0.12;

    if (blink || isSleeping) {
      ctx.strokeStyle = "#2a4020";
      ctx.lineWidth = Math.max(1.5, s * 0.03);
      ctx.lineCap = "round";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir, eyeY, s * 0.04, 0, Math.PI, isSleeping);
        ctx.stroke();
      });
    } else {
      ctx.fillStyle = "#2a4020";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir, eyeY, s * 0.045, 0, Math.PI * 2);
        ctx.fill();
      });
      ctx.fillStyle = "rgba(255,255,255,0.7)";
      [-1, 1].forEach(dir => {
        ctx.beginPath();
        ctx.arc(eyeSpacing * dir - s * 0.015, eyeY - s * 0.02, s * 0.018, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    // Mouth
    if (!isSleeping) {
      const mCurve = (mood - 0.3) * s * 0.12;
      ctx.strokeStyle = "#2a4020";
      ctx.lineWidth = Math.max(1.5, s * 0.025);
      ctx.lineCap = "round";
      ctx.beginPath();
      ctx.moveTo(-s * 0.06, s * 0.18);
      ctx.quadraticCurveTo(0, s * 0.18 - mCurve, s * 0.06, s * 0.18);
      ctx.stroke();
    }

    // Leaf/sprout on top!
    const leafSway = Math.sin(t * 1.8) * 0.15;
    ctx.save();
    ctx.translate(0, -s * 0.3);
    ctx.rotate(leafSway);

    // Stem
    ctx.strokeStyle = `hsl(${hue - 10}, 60%, 40%)`;
    ctx.lineWidth = Math.max(2, s * 0.04);
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(0, -s * 0.3);
    ctx.stroke();

    // Leaves
    ctx.fillStyle = `hsl(${hue + 15}, 65%, 50%)`;
    [-1, 1].forEach(dir => {
      ctx.beginPath();
      ctx.moveTo(0, -s * 0.15);
      ctx.quadraticCurveTo(
        dir * s * 0.25, -s * 0.35,
        dir * s * 0.05, -s * 0.32
      );
      ctx.closePath();
      ctx.fill();
    });

    // Top leaf
    ctx.fillStyle = `hsl(${hue + 20}, 70%, 55%)`;
    ctx.beginPath();
    ctx.moveTo(0, -s * 0.28);
    ctx.quadraticCurveTo(s * 0.12, -s * 0.5, 0, -s * 0.45);
    ctx.quadraticCurveTo(-s * 0.12, -s * 0.5, 0, -s * 0.28);
    ctx.fill();

    ctx.restore(); // leaf transform

    ctx.restore();
  }
};

// ═══════════════════════════════════════════════════════════════════════════════
// REGISTRY helpers
// ═══════════════════════════════════════════════════════════════════════════════

export function getCreature(id) {
  return creatures[id] || creatures.ditto;
}

export function getCreatureNames() {
  return Object.entries(creatures).map(([id, c]) => ({ id, name: c.name }));
}
