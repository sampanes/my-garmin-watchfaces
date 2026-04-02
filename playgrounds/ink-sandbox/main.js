const canvas = document.querySelector("#canvas");
const ctx = canvas.getContext("2d");
const rerollButton = document.querySelector("#reroll");

const W = 416, H = 416;
const HR_MIN = 45, HR_MAX = 160;
let seed = 1;

// ─── PRNG ─────────────────────────────────────────────────────────────────────

// Mulberry32 — seeded, drives HR data and peak placement
function mulberry32(a) {
  return function () {
    let t = (a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// LCG — fast, used for per-pixel texture work (cun, trees, grain)
function PRNG(s) {
  let v = ((s * 1664525 + 1013904223) & 0xffffffff) >>> 0 || 1;
  return { next() { v = (v * 1664525 + 1013904223) & 0xffffffff; return (v >>> 0) / 4294967295; } };
}

// ─── SIMPLEX NOISE ────────────────────────────────────────────────────────────
// 2D simplex noise — replaces the 1D VNoise table lookup.
// More isotropic than value noise; no directional grain artifacts.

class SimplexNoise {
  constructor(seed = 12345) {
    this.grad3 = [
      [1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],
      [1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],
      [0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1]
    ];
    this.perm = new Uint8Array(512);
    const p = new Uint8Array(256);
    for (let i = 0; i < 256; i++) p[i] = i;
    let s = (seed | 0) || 1; // avoid zero
    for (let i = 255; i > 0; i--) {
      s = (s * 16807 + 0) % 2147483647;
      const j = s % (i + 1);
      [p[i], p[j]] = [p[j], p[i]];
    }
    for (let i = 0; i < 512; i++) this.perm[i] = p[i & 255];
  }

  noise2D(xin, yin) {
    const F2 = 0.5 * (Math.sqrt(3) - 1);
    const G2 = (3 - Math.sqrt(3)) / 6;
    const s = (xin + yin) * F2;
    const i = Math.floor(xin + s);
    const j = Math.floor(yin + s);
    const t = (i + j) * G2;
    const x0 = xin - (i - t);
    const y0 = yin - (j - t);
    const i1 = x0 > y0 ? 1 : 0;
    const j1 = x0 > y0 ? 0 : 1;
    const x1 = x0 - i1 + G2;
    const y1 = y0 - j1 + G2;
    const x2 = x0 - 1 + 2 * G2;
    const y2 = y0 - 1 + 2 * G2;
    const ii = i & 255;
    const jj = j & 255;
    const dot = (g, x, y) => g[0] * x + g[1] * y;
    let n0 = 0, n1 = 0, n2 = 0;
    let t0 = 0.5 - x0 * x0 - y0 * y0;
    if (t0 >= 0) { t0 *= t0; n0 = t0 * t0 * dot(this.grad3[this.perm[ii + this.perm[jj]] % 12], x0, y0); }
    let t1 = 0.5 - x1 * x1 - y1 * y1;
    if (t1 >= 0) { t1 *= t1; n1 = t1 * t1 * dot(this.grad3[this.perm[ii + i1 + this.perm[jj + j1]] % 12], x1, y1); }
    let t2 = 0.5 - x2 * x2 - y2 * y2;
    if (t2 >= 0) { t2 *= t2; n2 = t2 * t2 * dot(this.grad3[this.perm[ii + 1 + this.perm[jj + 1]] % 12], x2, y2); }
    return 70 * (n0 + n1 + n2);
  }
}

// ─── FRACTAL BROWNIAN MOTION ──────────────────────────────────────────────────
// Layered noise: sum(amplitude^i * noise(frequency^i * pos)) over N octaves.
// Replaces oNoise. Lacunarity and gain are explicit parameters.

function fbm(noise, x, y, octaves = 6, lacunarity = 2.0, gain = 0.5) {
  let value = 0, amplitude = 1, frequency = 1, maxVal = 0;
  for (let i = 0; i < octaves; i++) {
    value += amplitude * noise.noise2D(x * frequency, y * frequency);
    maxVal += amplitude;
    amplitude *= gain;
    frequency *= lacunarity;
  }
  return value / maxVal; // normalized to approx [-1, 1]
}

// ─── TURBULENCE ───────────────────────────────────────────────────────────────
// Absolute-value fBm — produces veiny, craggy texture.
// Good for rock face detail and micro-crags at the ridge.

function turbulence(noise, x, y, octaves = 5) {
  let value = 0, amplitude = 1, frequency = 1, maxVal = 0;
  for (let i = 0; i < octaves; i++) {
    value += amplitude * Math.abs(noise.noise2D(x * frequency, y * frequency));
    maxVal += amplitude;
    amplitude *= 0.5;
    frequency *= 2.0;
  }
  return value / maxVal; // [0, 1]
}

// ─── DOMAIN WARPING ───────────────────────────────────────────────────────────
// Nested fBm: f(p + fbm(p + fbm(p))). Distorts sample coords so the output
// has a "folded rock" quality — organic creases, not smooth bumps.

function domainWarp(noise, x, y, scale = 1, strength = 0.4) {
  const q0 = fbm(noise, x * scale, y * scale, 4);
  const q1 = fbm(noise, (x + 5.2) * scale, (y + 1.3) * scale, 4);
  const r0 = fbm(noise, (x + strength * q0 + 1.7) * scale, (y + strength * q1 + 9.2) * scale, 4);
  const r1 = fbm(noise, (x + strength * q0 + 8.3) * scale, (y + strength * q1 + 2.8) * scale, 4);
  return fbm(noise, (x + strength * r0) * scale, (y + strength * r1) * scale, 4);
}

// ─── HR DATA ──────────────────────────────────────────────────────────────────

function generateHRData(rng) {
  const count = 180 + Math.floor(rng() * 40);
  const numCtrl = 10 + Math.floor(rng() * 5);
  const ctrl = [];
  let hr = 55 + rng() * 20;
  ctrl.push(hr);
  for (let i = 1; i < numCtrl; i++) {
    hr = Math.max(HR_MIN + 4, Math.min(HR_MAX - 4, hr + (rng() - 0.42) * 75));
    ctrl.push(hr);
  }
  const data = [];
  for (let i = 0; i < count; i++) {
    const t = (i / (count - 1)) * (numCtrl - 1);
    const idx = Math.min(Math.floor(t), numCtrl - 2);
    const f = t - idx, sf = f * f * (3 - 2 * f);
    let val = ctrl[idx] * (1 - sf) + ctrl[idx + 1] * sf;
    val += (rng() - 0.5) * 8;
    data.push(Math.max(HR_MIN, Math.min(HR_MAX, val)));
  }
  return data;
}

function smooth(data, w) {
  const half = Math.floor(w / 2);
  return data.map((_, i) => {
    let s = 0, n = 0;
    for (let j = Math.max(0, i - half); j <= Math.min(data.length - 1, i + half); j++) { s += data[j]; n++; }
    return s / n;
  });
}

// Extract N Gaussian peak descriptors from the HR array.
// High HR → tall peak; resting HR → gentle hill.
function hrToPeaks(hrData, count, heightScale, spread, rng) {
  const windowSize = Math.max(8, Math.floor(hrData.length / (count * 1.8)));
  const sm = smooth(hrData, windowSize);
  return Array.from({ length: count }, (_, i) => {
    const t = (i + 0.5) / count;
    const idx = Math.floor(t * (sm.length - 1));
    const hrNorm = (sm[idx] - HR_MIN) / (HR_MAX - HR_MIN);
    return {
      nx: t + (rng() - 0.5) * 0.04,
      h:  0.35 + hrNorm * 0.65 * heightScale,
      s:  spread + rng() * 0.04,
    };
  });
}

// ─── MOUNTAIN PROFILE ─────────────────────────────────────────────────────────
// HR-driven Gaussian peak summation as the base shape, with three scales of
// noise on top: domain-warped low-freq (folded rock edges), mid-freq fBm
// (hill-scale variation), high-freq turbulence (micro-crags).

function profile(peaks, yBase, amp, rough, s) {
  const noise = new SimplexNoise(s);
  const h = new Float32Array(W);
  for (let x = 0; x < W; x++) {
    const nx = x / W;
    // Gaussian peak summation — HR-driven base shape
    let v = 0;
    for (const p of peaks) {
      const d = nx - p.nx;
      v = Math.max(v, p.h * Math.exp(-(d * d) / (2 * p.s * p.s)));
    }
    // Domain-warped noise for "folded rock" edge quality
    const warp   = domainWarp(noise, nx * 3.5, 0.5, 1.0, 0.3) * rough;
    // Mid-freq fBm for hill-scale variation
    const detail = fbm(noise, nx * 12.0, 1.7, 4, 2.0, 0.5)    * rough * 0.35;
    // High-freq turbulence for craggy micro-texture
    const micro  = turbulence(noise, nx * 38.0, 2.5, 3)         * rough * 0.12;
    v += warp + detail + micro;
    h[x] = yBase - Math.max(0, v) * amp;
  }
  return h;
}

// ─── OFF-SCREEN HELPER ────────────────────────────────────────────────────────

function offscreen() {
  const c = document.createElement('canvas');
  c.width = W; c.height = H;
  return { c, x: c.getContext('2d') };
}

// ─── FILL MOUNTAIN ────────────────────────────────────────────────────────────
// Rapid-falloff gradient: most ink at the ridge, nearly gone by 40% depth.

function fillMtn(dc, h, inkMax, fade, dark) {
  let peakY = H;
  for (let x = 0; x < W; x++) if (h[x] < peakY) peakY = h[x];

  dc.beginPath();
  dc.moveTo(0, H + 2);
  for (let x = 0; x < W; x++) dc.lineTo(x, h[x]);
  dc.lineTo(W, H + 2);
  dc.closePath();

  const d = dark;
  const g = dc.createLinearGradient(0, peakY, 0, H);
  g.addColorStop(0,   `rgba(${d},${d-3},${d-5},${inkMax})`);
  g.addColorStop(.15, `rgba(${d+7},${d+4},${d+1},${inkMax * .88})`);
  g.addColorStop(.38, `rgba(${d+13},${d+10},${d+6},${inkMax * .55})`);
  g.addColorStop(.65, `rgba(${d+19},${d+16},${d+11},${inkMax * .20})`);
  g.addColorStop(.88, `rgba(${d+23},${d+19},${d+14},${inkMax * .05})`);
  g.addColorStop(1,   `rgba(${d+25},${d+21},${d+16},${fade})`);
  dc.fillStyle = g;
  dc.fill();
}

// ─── PRESSURE-VARYING BRUSH STROKE ───────────────────────────────────────────
// Bell-curve pressure formula: sin(πt)^0.6 * (1 + 0.3 * noiseModulation).
// Drawn segment-by-segment so lineWidth and alpha vary along the stroke length.
// Thin at entry/exit, full at midpoint — traditional calligraphic character.

function drawBrushStroke(dc, x0, y0, x1, y1, wMin, wMax, alpha, noise) {
  const dx = x1 - x0, dy = y1 - y0;
  const steps = Math.max(4, Math.ceil(Math.hypot(dx, dy) / 2));
  dc.save();
  dc.lineCap = 'round';
  for (let i = 0; i < steps; i++) {
    const t0 = i / steps, t1 = (i + 1) / steps;
    const tmid = (t0 + t1) * 0.5;
    const px = x0 + dx * tmid, py = y0 + dy * tmid;
    // fBm gives a smooth, correlated noise modulation in [-1, 1]
    const nv = fbm(noise, px * 0.04, py * 0.04, 2, 2.0, 0.5);
    const pressure = Math.pow(Math.sin(Math.PI * tmid), 0.6) * (1 + 0.3 * nv);
    const w = wMin + (wMax - wMin) * Math.max(0, Math.min(1, pressure));
    dc.lineWidth = w;
    dc.strokeStyle = `rgba(10,7,4,${alpha * Math.max(0.15, pressure)})`;
    dc.beginPath();
    dc.moveTo(x0 + dx * t0, y0 + dy * t0);
    dc.lineTo(x0 + dx * t1, y0 + dy * t1);
    dc.stroke();
  }
  dc.restore();
}

// ─── CUN STROKES (皴法) ────────────────────────────────────────────────────────
// Scattered short brush marks inside the mountain body.
// Now uses pressure-varying drawBrushStroke instead of uniform lineWidth.

function cun(dc, h, count, ink, s) {
  const rng = PRNG(s);
  const noise = new SimplexNoise(s * 7 + 13);
  for (let i = 0; i < count; i++) {
    const x = rng.next() * W, xi = Math.min(W - 1, x | 0);
    const t = Math.pow(rng.next(), 1.6);
    const y = h[xi] + (H - h[xi]) * t * 0.82;
    if (y < h[xi] + 1 || y > H * 0.97) continue;
    const ang = (0.35 + rng.next() * 0.55) * Math.PI;
    const len = 3 + rng.next() * 14;
    const alpha = (0.18 + rng.next() * 0.55) * ink;
    const wMax = 0.4 + rng.next() * 1.4;
    drawBrushStroke(dc,
      x, y,
      x + Math.cos(ang) * len, y + Math.sin(ang) * len,
      0.2, wMax, alpha, noise);
  }
}

// ─── FLYING WHITE (飛白) ───────────────────────────────────────────────────────
// Dry-brush texture near the ridge: brush thins and paper shows through.

function flyWhite(dc, h, ink, s) {
  const rng = PRNG(s);
  dc.save();
  dc.lineCap = 'round';
  for (let i = 0; i < W * .4; i++) {
    const x = rng.next() * W, xi = Math.min(W - 1, x | 0);
    const y = h[xi] + (rng.next() - .5) * 7;
    if (y < 4 || y > H * .95) continue;
    dc.strokeStyle = `rgba(8,5,3,${rng.next() * .16 * ink})`;
    dc.lineWidth = .3 + rng.next();
    dc.setLineDash([rng.next() * 4, 1 + rng.next() * 6]);
    dc.beginPath();
    dc.moveTo(x, y);
    dc.lineTo(x + (rng.next() - .5) * (4 + rng.next() * 15), y + (rng.next() - .3) * 4);
    dc.stroke();
  }
  dc.setLineDash([]);
  dc.restore();
}

// ─── INK BLEED EDGE ───────────────────────────────────────────────────────────
// Garmin-compatible ink diffusion approximation: radial micro-blobs at the
// ridge simulate ink wicking into paper fibers.
// Pixel-level anisotropic bleeding (getImageData/putImageData) is not used —
// no equivalent exists on Garmin's Dc. bleedEdge radial gradients translate
// directly to dc.fillCircle calls on device.

function bleedEdge(dc, h, alpha, s) {
  const rng = PRNG(s);
  dc.save();
  for (let x = 0; x < W; x++) {
    if (rng.next() > .28) continue;
    const y = h[x], sz = .8 + rng.next() * 4.5;
    const ox = x + (rng.next() - .5) * 5, oy = y - rng.next() * sz * 1.4;
    const g = dc.createRadialGradient(ox, oy, 0, ox, oy, sz * 2.6);
    g.addColorStop(0, `rgba(10,7,4,${alpha * (.3 + rng.next() * .7)})`);
    g.addColorStop(1, 'rgba(10,7,4,0)');
    dc.fillStyle = g;
    dc.beginPath();
    dc.ellipse(ox, oy, sz, sz * (1.1 + rng.next() * .8), rng.next() * .5, 0, Math.PI * 2);
    dc.fill();
  }
  dc.restore();
}

// ─── DRY BRUSH TEXTURE ────────────────────────────────────────────────────────
// Near-horizontal dashed marks inside the mountain body, simulating the
// texture of a dry brush dragged across washi — ink only where bristles land.

function dryBrush(dc, h, ink, s) {
  const rng = PRNG(s);
  dc.save();
  dc.lineCap = 'round';
  for (let i = 0; i < W * 0.3; i++) {
    const x = rng.next() * W, xi = Math.min(W - 1, x | 0);
    const depthT = Math.pow(rng.next(), 0.8) * 0.35; // concentrate near ridgeline
    const y = h[xi] + (H - h[xi]) * depthT;
    if (y < 4 || y > H * 0.95) continue;
    const len = 5 + rng.next() * 22;
    const ang = (rng.next() - 0.5) * 0.25; // near-horizontal
    dc.setLineDash([rng.next() * 3, 0.8 + rng.next() * 5]);
    dc.strokeStyle = `rgba(8,5,3,${rng.next() * 0.07 * ink})`;
    dc.lineWidth = 0.3 + rng.next() * 0.7;
    dc.beginPath();
    dc.moveTo(x, y);
    dc.lineTo(x + Math.cos(ang) * len, y + Math.sin(ang) * len);
    dc.stroke();
  }
  dc.setLineDash([]);
  dc.restore();
}

// ─── FOLIAGE CLUSTER ──────────────────────────────────────────────────────────
// Simplex-perturbed filled polygons at branch tips. Irregular blob outline
// rather than circles — the noise distortion gives a brushed-on quality.

function drawFoliageCluster(dc, cx, cy, radius, noise, rng) {
  const blobCount = 3 + ((rng.next() * 5) | 0);
  dc.save();
  for (let b = 0; b < blobCount; b++) {
    const bx = cx + (rng.next() - 0.5) * radius * 2.0;
    const by = cy - radius * 0.3 + (rng.next() - 0.5) * radius * 1.5;
    const br = radius * (0.25 + rng.next() * 0.4);
    if (br < 1) continue;
    const alpha = 0.35 + rng.next() * 0.45;
    const pts = 10 + ((rng.next() * 6) | 0);
    dc.beginPath();
    for (let j = 0; j <= pts; j++) {
      const ang = (j / pts) * Math.PI * 2;
      // fBm-perturbed radius — fbm output is in [-1, 1]
      const r = br * (0.65 + 0.35 * fbm(noise,
        Math.cos(ang) * 1.2 + bx * 0.08,
        Math.sin(ang) * 1.2 + by * 0.08,
        2, 2.0, 0.5
      ));
      const px = bx + Math.cos(ang) * Math.max(0.5, r);
      const py = by + Math.sin(ang) * Math.max(0.5, r);
      if (j === 0) dc.moveTo(px, py); else dc.lineTo(px, py);
    }
    dc.closePath();
    dc.fillStyle = `rgba(8,5,3,${alpha})`;
    dc.fill();
  }
  dc.restore();
}

// ─── RECURSIVE BRANCH ─────────────────────────────────────────────────────────
// Pressure-varying trunk and branches with fBm-guided angle deviation.
// Foliage clusters drawn at terminal depth (depth === 1).

function generateBranch(dc, x, y, angle, length, width, depth, noise, rng) {
  if (depth <= 0 || length < 1.5) return;
  const steps = Math.max(3, Math.ceil(length / 3));
  let cx = x, cy = y;
  dc.save();
  dc.lineCap = 'round';
  for (let i = 0; i < steps; i++) {
    const t = (i + 0.5) / steps;
    const pressure = Math.pow(Math.sin(Math.PI * t), 0.6);
    const w = Math.max(0.3, width * (1 - t * 0.65) * pressure);
    // fBm-guided angle keeps branches curving naturally
    const noiseAngle = fbm(noise, cx * 0.03, cy * 0.03, 2, 2.0, 0.5) * 0.4;
    const nx = cx + Math.cos(angle + noiseAngle) * (length / steps);
    const ny = cy + Math.sin(angle + noiseAngle) * (length / steps);
    dc.lineWidth = w;
    dc.strokeStyle = `rgba(8,5,3,${0.60 + rng.next() * 0.35})`;
    dc.beginPath(); dc.moveTo(cx, cy); dc.lineTo(nx, ny); dc.stroke();
    cx = nx; cy = ny;
  }
  dc.restore();

  if (depth === 1) {
    drawFoliageCluster(dc, cx, cy, length * 0.9, noise, rng);
    return;
  }

  const angleNoise = fbm(noise, cx * 0.05, cy * 0.05, 2, 2.0, 0.5) * 0.15;
  const spread = 0.30 + rng.next() * 0.35;
  generateBranch(dc, cx, cy, angle - spread + angleNoise, length * (0.60 + rng.next() * 0.15), width * 0.60, depth - 1, noise, rng);
  generateBranch(dc, cx, cy, angle + spread + angleNoise, length * (0.60 + rng.next() * 0.15), width * 0.60, depth - 1, noise, rng);
  // Occasional central sub-branch for denser canopy
  if (rng.next() > 0.60 && depth > 2) {
    generateBranch(dc, cx, cy, angle + angleNoise * 0.5, length * (0.45 + rng.next() * 0.10), width * 0.50, depth - 2, noise, rng);
  }
}

// ─── RIDGE TREES ──────────────────────────────────────────────────────────────

function ridgeTrees(dc, h, prob, s) {
  const rng = PRNG(s);
  const noise = new SimplexNoise(s * 11 + 31);
  for (let x = 6; x < W - 6; x++) {
    if (rng.next() > prob) continue;
    const y = h[x];
    if (!y || y > H * 0.87 || y < 12) continue;
    const sz = 6 + rng.next() * 12;
    generateBranch(dc, x + (rng.next() - 0.5) * 3, y, -Math.PI / 2, sz, sz * 0.14, 3, noise, rng);
  }
}

// ─── ORGANIC MIST ─────────────────────────────────────────────────────────────
// Three-pass mist: fBm-displaced band + overlapping cloud puffs + thin wisps.
// fBm replaces the old VNoise/oNoise calls; SimplexNoise seeded from s.

function organicMist(yCenter, thickness, alpha, s) {
  const rng = PRNG(s);
  const noise = new SimplexNoise(s);
  const col = '246,242,234';

  ctx.save();

  // Pass 1: fBm-displaced filled band
  {
    const topPts = [], botPts = [], step = 3;
    for (let x = 0; x <= W; x += step) {
      const nx = x / W;
      const topOff = fbm(noise, nx * 4.5, 0.1, 4, 2.0, 0.55) * thickness * 0.62
                   + fbm(noise, nx * 14 + 3, 0.2, 3, 2.0, 0.50) * thickness * 0.17
                   + fbm(noise, nx * 35 + 7, 0.3, 2, 2.0, 0.48) * thickness * 0.06;
      const botOff = fbm(noise, nx * 3.5 + 2, 0.15, 3, 2.0, 0.52) * thickness * 0.28
                   + fbm(noise, nx * 11 + 9,  0.25, 2, 2.0, 0.48) * thickness * 0.10;
      topPts.push([x, yCenter - thickness * 0.5 + topOff]);
      botPts.push([x, yCenter + thickness * 0.5 + botOff]);
    }
    const g = ctx.createLinearGradient(0, yCenter - thickness * 0.75, 0, yCenter + thickness * 0.75);
    g.addColorStop(0,   `rgba(${col},0)`);
    g.addColorStop(.25, `rgba(${col},${alpha * 0.6})`);
    g.addColorStop(.5,  `rgba(${col},${alpha})`);
    g.addColorStop(.75, `rgba(${col},${alpha * 0.5})`);
    g.addColorStop(1,   `rgba(${col},0)`);
    ctx.beginPath();
    ctx.moveTo(topPts[0][0], topPts[0][1]);
    for (const [px, py] of topPts) ctx.lineTo(px, py);
    for (let i = botPts.length - 1; i >= 0; i--) ctx.lineTo(botPts[i][0], botPts[i][1]);
    ctx.closePath();
    ctx.fillStyle = g;
    ctx.fill();
  }

  // Pass 2: cloud puffs
  const puffCount = 8 + (rng.next() * 7) | 0;
  for (let i = 0; i < puffCount; i++) {
    const px = rng.next() * W, py = yCenter + (rng.next() - .5) * thickness * .75;
    const rw = 40 + rng.next() * 110, rh = 10 + rng.next() * 32;
    const ang = (rng.next() - .5) * .25, a = alpha * (.28 + rng.next() * .50);
    const g = ctx.createRadialGradient(px, py, 0, px, py, rw);
    g.addColorStop(0,   `rgba(${col},${a})`);
    g.addColorStop(.45, `rgba(${col},${(a * .55).toFixed(3)})`);
    g.addColorStop(.78, `rgba(${col},${(a * .15).toFixed(3)})`);
    g.addColorStop(1,   `rgba(${col},0)`);
    ctx.save(); ctx.translate(px, py); ctx.rotate(ang); ctx.scale(1, rh / rw);
    ctx.beginPath(); ctx.arc(0, 0, rw, 0, Math.PI * 2);
    ctx.fillStyle = g; ctx.fill(); ctx.restore();
  }

  // Pass 3: wisps
  const wispCount = 5 + (rng.next() * 4) | 0;
  for (let i = 0; i < wispCount; i++) {
    const wx = rng.next() * W * 1.2 - W * .1, wy = yCenter + (rng.next() - .5) * thickness * .55;
    const wl = 70 + rng.next() * 190, wh = 5 + rng.next() * 16;
    const a = alpha * (.10 + rng.next() * .22), ang = (rng.next() - .5) * .15;
    const g = ctx.createRadialGradient(wx, wy, 0, wx, wy, wl);
    g.addColorStop(0,  `rgba(${col},${a})`);
    g.addColorStop(.5, `rgba(${col},${(a * .4).toFixed(3)})`);
    g.addColorStop(1,  `rgba(${col},0)`);
    ctx.save(); ctx.translate(wx, wy); ctx.rotate(ang); ctx.scale(1, wh / wl);
    ctx.beginPath(); ctx.arc(0, 0, wl, 0, Math.PI * 2);
    ctx.fillStyle = g; ctx.fill(); ctx.restore();
  }

  ctx.restore();
}

// ─── PAPER GRAIN ──────────────────────────────────────────────────────────────

function paperGrain() {
  const rng = PRNG(9999);
  ctx.save();
  for (let i = 0; i < W * H * .0004; i++) {
    const x = rng.next() * W, y = rng.next() * H;
    const len = 2 + rng.next() * 14;
    ctx.strokeStyle = `rgba(140,120,90,${.008 + rng.next() * .022})`;
    ctx.lineWidth = .3 + rng.next() * .7;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineTo(x + (rng.next() - .5) * len * 2, y + (rng.next() - .5) * len * .25);
    ctx.stroke();
  }
  ctx.restore();
}

// ─── SEAL ─────────────────────────────────────────────────────────────────────

function seal(x, y, s) {
  ctx.save();
  ctx.fillStyle = '#9e1515'; ctx.fillRect(x, y, s, s);
  ctx.fillStyle = 'rgba(170,28,28,.4)'; ctx.fillRect(x, y, s * .5, s * .5);
  ctx.strokeStyle = 'rgba(242,222,192,.88)'; ctx.lineWidth = s * .055; ctx.lineCap = 'square';
  ctx.strokeRect(x + s * .1, y + s * .1, s * .8, s * .8);
  const cx = x + s / 2, cy = y + s / 2;
  ctx.lineWidth = s * .09;
  ctx.beginPath(); ctx.moveTo(cx, y + s * .2); ctx.lineTo(cx, y + s * .8); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(x + s * .22, cy - s * .12); ctx.lineTo(x + s * .78, cy - s * .12); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(x + s * .22, cy + s * .18); ctx.lineTo(x + s * .78, cy + s * .18); ctx.stroke();
  ctx.restore();
}

// ─── RENDER ───────────────────────────────────────────────────────────────────

function render() {
  const rng = mulberry32(seed);

  ctx.clearRect(0, 0, W, H);
  ctx.save();

  // Clip to watch-face circle
  ctx.beginPath();
  ctx.arc(W / 2, H / 2, W / 2 - 1, 0, Math.PI * 2);
  ctx.clip();

  // ── Paper ──────────────────────────────────────────────────────────────────
  const pg = ctx.createLinearGradient(0, 0, W * .25, H);
  pg.addColorStop(0, '#f8f3e9'); pg.addColorStop(.5, '#f4efe3'); pg.addColorStop(1, '#ece7da');
  ctx.fillStyle = pg; ctx.fillRect(0, 0, W, H);

  const sl = ctx.createRadialGradient(W * .18, H * .12, 0, W * .18, H * .12, W * .7);
  sl.addColorStop(0, 'rgba(255,250,235,.16)'); sl.addColorStop(1, 'rgba(200,185,155,0)');
  ctx.fillStyle = sl; ctx.fillRect(0, 0, W, H);

  // ── HR data → Gaussian peaks for the mid layer ────────────────────────────
  const hrData = generateHRData(rng);

  // Mid layer: 4 peaks, main artistic response to HR data
  const midPeaks   = hrToPeaks(hrData, 4, 1.00, 0.14, rng);
  // Far range: 3 peaks, compressed amplitude (feels distant)
  const farPeaks   = hrToPeaks(hrData, 3, 0.52, 0.17, rng);
  // Ghost: barely a suggestion of mountains in the upper sky
  const ghostPeaks = hrToPeaks(hrData, 3, 0.30, 0.19, rng);

  // Foreground layers: compositional dark anchor masses at left and right.
  // Heights loosely echo the start and end of the HR trace.
  const hrStart = (hrData[0] - HR_MIN) / (HR_MAX - HR_MIN);
  const hrEnd   = (hrData[hrData.length - 1] - HR_MIN) / (HR_MAX - HR_MIN);
  const fgLeft  = [
    { nx: -.03, h: .88 + hrStart * .12, s: .14 },
    { nx: .14,  h: .82 + hrStart * .14, s: .16 },
    { nx: .28,  h: .65 + hrStart * .12, s: .12 },
    { nx: .42,  h: .45,                 s: .10 },
  ];
  const fgRight = [
    { nx: .60,  h: .40,                s: .10 },
    { nx: .73,  h: .62 + hrEnd * .14,  s: .12 },
    { nx: .87,  h: .82 + hrEnd * .10,  s: .13 },
    { nx: 1.04, h: .70 + hrEnd * .12,  s: .10 },
  ];

  // ── Layer config ──────────────────────────────────────────────────────────
  const ls = seed & 0xffff;
  const bgLayers = [
    { peaks: ghostPeaks, yBase: H*.57, amp: H*.17, rough: .12, ink: .07, fade: 0, blur: 10, trees: 0,    cun: 0,   bleed: .02, s: ls+101 },
    { peaks: farPeaks,   yBase: H*.62, amp: H*.26, rough: .18, ink: .14, fade: 0, blur:  5, trees: 0,    cun: 0,   bleed: .04, s: ls+202 },
    { peaks: midPeaks,   yBase: H*.70, amp: H*.44, rough: .27, ink: .48, fade: 0, blur:  1, trees: .030, cun: 120, bleed: .14, s: ls+303 },
  ];

  // ── Background layers (ghost + far, rendered behind first mist pass) ───────
  for (const L of bgLayers.slice(0, 2)) {
    const { c: oc, x: ox } = offscreen();
    const h = profile(L.peaks, L.yBase, L.amp, L.rough, L.s);
    fillMtn(ox, h, L.ink, L.fade, 12);
    if (L.bleed > 0) bleedEdge(ox, h, L.bleed * L.ink, L.s + 20);
    ctx.save();
    ctx.filter = `blur(${L.blur}px)`;
    ctx.drawImage(oc, 0, 0, W, H);
    ctx.filter = 'none';
    ctx.restore();
  }

  // ── Mist — first pass (between ghost and far) ─────────────────────────────
  organicMist(H * .440, 80, .68, 1001);
  organicMist(H * .518, 68, .56, 2002);
  organicMist(H * .592, 52, .44, 3003);

  // ── Mid layer (HR-driven) ─────────────────────────────────────────────────
  {
    const L = bgLayers[2];
    const { c: oc, x: ox } = offscreen();
    const h = profile(L.peaks, L.yBase, L.amp, L.rough, L.s);
    fillMtn(ox, h, L.ink, L.fade, 12);
    dryBrush(ox, h, L.ink, L.s + 75);
    cun(ox, h, L.cun, L.ink, L.s);
    flyWhite(ox, h, L.ink, L.s + 55);
    ridgeTrees(ox, h, L.trees, L.s + 10);
    bleedEdge(ox, h, L.bleed * L.ink, L.s + 20);
    ctx.save();
    if (L.blur > 0) ctx.filter = `blur(${L.blur}px)`;
    ctx.drawImage(oc, 0, 0, W, H);
    ctx.filter = 'none';
    ctx.restore();
  }

  // ── Mist — second pass (between mid and foreground) ───────────────────────
  organicMist(H * .672, 48, .40, 4004);
  organicMist(H * .728, 36, .28, 5005);

  // ── Foreground left ───────────────────────────────────────────────────────
  {
    const { c: oc, x: ox } = offscreen();
    const h = profile(fgLeft, H * .88, H * .72, .30, ls + 404);
    fillMtn(ox, h, .90, .03, 11);
    dryBrush(ox, h, .90, ls + 475);
    cun(ox, h, 360, .90, ls + 404);
    flyWhite(ox, h, .90, ls + 459);
    ridgeTrees(ox, h, .072, ls + 414);
    bleedEdge(ox, h, .24, ls + 424);
    ctx.drawImage(oc, 0, 0, W, H);
  }

  // ── Foreground right ──────────────────────────────────────────────────────
  {
    const { c: oc, x: ox } = offscreen();
    const h = profile(fgRight, H * .88, H * .64, .28, ls + 505);
    fillMtn(ox, h, .86, .02, 11);
    dryBrush(ox, h, .86, ls + 585);
    cun(ox, h, 320, .86, ls + 505);
    flyWhite(ox, h, .86, ls + 560);
    ridgeTrees(ox, h, .060, ls + 515);
    bleedEdge(ox, h, .21, ls + 525);
    ctx.drawImage(oc, 0, 0, W, H);
  }

  // ── Final mist along mountain bases ───────────────────────────────────────
  organicMist(H * .798, 40, .32, 6006);

  // ── Water ─────────────────────────────────────────────────────────────────
  const wg = ctx.createLinearGradient(0, H * .76, 0, H);
  wg.addColorStop(0, 'rgba(238,233,222,0)');
  wg.addColorStop(.35, 'rgba(238,233,222,.44)');
  wg.addColorStop(1, 'rgba(232,227,216,.76)');
  ctx.fillStyle = wg; ctx.fillRect(0, H * .76, W, H * .24);

  // Ripples
  const rng2 = PRNG(7777 + (seed & 0xffff));
  ctx.save(); ctx.lineCap = 'round';
  for (let i = 0; i < 16; i++) {
    const wy = H * .815 + i * (H * .14 / 16) + (rng2.next() - .5) * 3;
    const x1 = rng2.next() * W * .50, x2 = x1 + rng2.next() * W * .38;
    ctx.strokeStyle = `rgba(26,20,14,${.025 + rng2.next() * .06})`;
    ctx.lineWidth = .3 + rng2.next() * .5;
    ctx.beginPath(); ctx.moveTo(x1, wy); ctx.lineTo(x2, wy); ctx.stroke();
  }
  ctx.restore();

  organicMist(H * .858, 30, .22, 7007);

  // ── Paper grain ───────────────────────────────────────────────────────────
  paperGrain();

  // ── Sky brightening at top ────────────────────────────────────────────────
  const sky = ctx.createLinearGradient(0, 0, 0, H * .36);
  sky.addColorStop(0, 'rgba(252,248,242,.20)'); sky.addColorStop(1, 'rgba(252,248,242,0)');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, W, H * .36);

  // ── Seal ──────────────────────────────────────────────────────────────────
  seal(W - 58, H - 62, 36);

  // ── Vignette ──────────────────────────────────────────────────────────────
  const vig = ctx.createRadialGradient(W / 2, H / 2, H * .28, W / 2, H / 2, W * .68);
  vig.addColorStop(0, 'rgba(0,0,0,0)'); vig.addColorStop(1, 'rgba(12,8,4,.10)');
  ctx.fillStyle = vig; ctx.fillRect(0, 0, W, H);

  ctx.restore(); // end circle clip
}

// ─── CONTROLS ─────────────────────────────────────────────────────────────────

rerollButton.addEventListener('click', () => {
  seed = (Math.random() * 1_000_000) | 0;
  render();
});

render();
