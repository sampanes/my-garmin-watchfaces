const canvas = document.querySelector("#canvas");
const ctx = canvas.getContext("2d");
const rerollButton = document.querySelector("#reroll");

const W = 416, H = 416;
const HR_MIN = 45, HR_MAX = 160;
let seed = 1;

// ─── PRNG ─────────────────────────────────────────────────────────────────────

// Mulberry32 — seeded, used to drive HR data and peak placement
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

// ─── 1D VALUE NOISE ───────────────────────────────────────────────────────────

function VNoise(s) {
  const r = PRNG(s), N = 512;
  const t = Array.from({ length: N + 2 }, () => r.next());
  return x => {
    x = ((x % N) + N) % N;
    const i = x | 0, f = x - i, sf = f * f * (3 - 2 * f);
    return t[i] * (1 - sf) + t[(i + 1) % N] * sf;
  };
}

function oNoise(fn, x, oct, p) {
  let v = 0, a = 1, tot = 0;
  for (let o = 0; o < oct; o++) { v += fn(x) * a; tot += a; a *= p; x *= 2.13; }
  return v / tot;
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
// Each peak sits at an evenly-spaced X position; its height is driven by the
// local HR value. High HR → tall peak; resting HR → gentle hill.
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
// Gaussian peak summation + multi-octave noise for roughness.
// Returns a Float32Array of Y values, one per horizontal pixel.

function profile(peaks, yBase, amp, rough, s) {
  const n1 = VNoise(s), n2 = VNoise(s + 777), n3 = VNoise(s + 1234);
  const h = new Float32Array(W);
  for (let x = 0; x < W; x++) {
    const nx = x / W;
    let v = 0;
    for (const p of peaks) {
      const d = nx - p.nx;
      v = Math.max(v, p.h * Math.exp(-(d * d) / (2 * p.s * p.s)));
    }
    v += oNoise(n1, nx * 14, 5, .52) * rough
       + oNoise(n2, nx * 38 + 5, 3, .50) * rough * .35
       + oNoise(n3, nx * 110 + 2, 2, .48) * rough * .12;
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
// `dark` is the base RGB value; ink color warms slightly downward.

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

// ─── CUN STROKES (皴法) ────────────────────────────────────────────────────────
// Scattered short brush marks inside the mountain body — the traditional
// texture technique for suggesting rock faces and foliage mass.

function cun(dc, h, count, ink, s) {
  const rng = PRNG(s);
  dc.save();
  dc.lineCap = 'round';
  for (let i = 0; i < count; i++) {
    const x = rng.next() * W, xi = Math.min(W - 1, x | 0);
    const t = Math.pow(rng.next(), 1.6);
    const y = h[xi] + (H - h[xi]) * t * .82;
    if (y < h[xi] + 1 || y > H * .97) continue;
    const ang = (.35 + rng.next() * .55) * Math.PI;
    dc.strokeStyle = `rgba(10,7,4,${(.18 + rng.next() * .55) * ink})`;
    dc.lineWidth = .4 + rng.next() * 1.4;
    dc.beginPath();
    dc.moveTo(x, y);
    dc.lineTo(x + Math.cos(ang) * (3 + rng.next() * 14), y + Math.sin(ang) * (3 + rng.next() * 14));
    dc.stroke();
  }
  dc.restore();
}

// ─── FLYING WHITE (飛白) ───────────────────────────────────────────────────────
// Dry-brush texture near the ridge: the brush thins and the white of the
// paper shows through. Done with dashed strokes at very low opacity.

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
// Radial-gradient micro-blobs scattered along the ridge, simulating ink
// wicking into paper fibers at the brush edge.

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

// ─── PINE TREES ───────────────────────────────────────────────────────────────

function pine(dc, x, y, sz, rng) {
  dc.save();
  dc.lineCap = 'round';
  dc.strokeStyle = `rgba(8,5,3,${.75 + rng.next() * .20})`;
  dc.lineWidth = Math.max(.6, sz * .12);
  dc.beginPath(); dc.moveTo(x, y); dc.lineTo(x + (rng.next() - .5) * sz * .1, y - sz * .28); dc.stroke();
  const levels = 3 + (sz > 12 ? 1 : 0);
  for (let i = 0; i < levels; i++) {
    const ly = y - sz * (.25 + i * .20);
    const sp = sz * (.36 - i * .06) * (.85 + rng.next() * .3);
    const dp = sz * .09 * (1 - i * .18);
    dc.lineWidth = Math.max(.35, sz * (.08 - i * .015));
    dc.beginPath(); dc.moveTo(x, ly); dc.quadraticCurveTo(x - sp * .5, ly + dp, x - sp, ly - sz * .07); dc.stroke();
    dc.beginPath(); dc.moveTo(x, ly); dc.quadraticCurveTo(x + sp * .5, ly + dp, x + sp, ly - sz * .07); dc.stroke();
  }
  dc.restore();
}

function ridgeTrees(dc, h, prob, s) {
  const rng = PRNG(s);
  for (let x = 6; x < W - 6; x++) {
    if (rng.next() > prob) continue;
    const y = h[x];
    if (!y || y > H * .87 || y < 12) continue;
    pine(dc, x + (rng.next() - .5) * 3, y, 6 + rng.next() * 12, rng);
  }
}

// ─── ORGANIC MIST ─────────────────────────────────────────────────────────────
// Three-pass mist: noise-displaced band + overlapping cloud puffs + thin wisps.
// Each technique addresses a different scale of the fog character.

function organicMist(yCenter, thickness, alpha, s) {
  const rng = PRNG(s);
  const n1 = VNoise(s), n2 = VNoise(s + 400), n3 = VNoise(s + 800);
  const col = '246,242,234';

  ctx.save();

  // Pass 1: noise-displaced filled band
  {
    const topPts = [], botPts = [], step = 3;
    for (let x = 0; x <= W; x += step) {
      const nx = x / W;
      const topOff = oNoise(n1, nx * 9,    4, .55) * thickness * .62
                   + oNoise(n2, nx * 28 + 3, 3, .50) * thickness * .17
                   + oNoise(n3, nx * 70 + 7, 2, .48) * thickness * .06;
      const botOff = oNoise(n2, nx * 7 + 2,  3, .52) * thickness * .28
                   + oNoise(n1, nx * 22 + 9, 2, .48) * thickness * .10;
      topPts.push([x, yCenter - thickness * .5 + topOff]);
      botPts.push([x, yCenter + thickness * .5 + botOff]);
    }
    const g = ctx.createLinearGradient(0, yCenter - thickness * .75, 0, yCenter + thickness * .75);
    g.addColorStop(0,   `rgba(${col},0)`);
    g.addColorStop(.25, `rgba(${col},${alpha * .6})`);
    g.addColorStop(.5,  `rgba(${col},${alpha})`);
    g.addColorStop(.75, `rgba(${col},${alpha * .5})`);
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

  // Mid layer drives 4 peaks from the HR trace (main artistic response to data)
  const midPeaks  = hrToPeaks(hrData, 4, 1.00, 0.14, rng);
  // Far range: 3 peaks, compressed amplitude (feels distant)
  const farPeaks  = hrToPeaks(hrData, 3, 0.52, 0.17, rng);
  // Ghost: very gentle humps, barely a suggestion of mountains in the sky
  const ghostPeaks = hrToPeaks(hrData, 3, 0.30, 0.19, rng);

  // Foreground layers are compositional (dark anchor masses at left and right).
  // Their heights loosely echo the start and end of the HR trace.
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
  // Seeds are offset from main seed so roughness varies independently of peaks
  const ls = seed & 0xffff; // stable layer seed suffix
  const bgLayers = [
    { peaks: ghostPeaks, yBase: H*.57, amp: H*.17, rough: .12, ink: .07, fade: 0, blur: 10, trees: 0,    cun: 0,   bleed: .02, s: ls+101 },
    { peaks: farPeaks,   yBase: H*.62, amp: H*.26, rough: .18, ink: .14, fade: 0, blur:  5, trees: 0,    cun: 0,   bleed: .04, s: ls+202 },
    { peaks: midPeaks,   yBase: H*.70, amp: H*.44, rough: .27, ink: .48, fade: 0, blur:  1, trees: .030, cun: 120, bleed: .14, s: ls+303 },
  ];

  // ── Background layers (behind mist) ───────────────────────────────────────
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
