#!/usr/bin/env python
"""The mask painter (2026-11-06): one HTML page, opened in a browser, where
John paints by hand where a cut is solid and where it is see-through
(scripts/hand_masks.py). No editor to install, no layers, no export
settings: three brushes over the real face.

    Solid         the painting as painted, its paper and snow included
    See-through   nothing: the face behind shows
    Auto          back to the cutter's own result

Every foreground, the lantern and the village are in it, each over what stands behind it
on the face (the mountains for a foreground, plain grey for the lantern).
Save writes <name>_mask.png into the browser's downloads; --pickup moves
those into art/edits, where the bakes find them.

    py -3.11 scripts/mask_painter.py            write ~/Downloads/ink-mask-painter.html
    py -3.11 scripts/mask_painter.py --pickup   move saved masks from ~/Downloads into art/edits
    then bake: bake_foregrounds.py, bake_props.py
"""
import base64
import glob
import io
import json
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hand_masks  # noqa: E402

DOWNLOADS = os.path.join(os.path.expanduser("~"), "Downloads")
OUT = os.path.join(DOWNLOADS, "ink-mask-painter.html")
EDIT_PX = 832          # a foreground is painted at twice the face
PROP_EDIT_H = {"lantern": 240, "village": 354}   # twice the face size
PAINTERS = {"b": "ChatGPT", "a": "Gemini", "c": "Gemini"}


def data_uri(img, fmt):
    buf = io.BytesIO()
    if fmt == "JPEG":
        img.convert("RGB").save(buf, "JPEG", quality=92)
        mime = "image/jpeg"
    else:
        img.save(buf, "PNG", optimize=True)
        mime = "image/png"
    return "data:%s;base64,%s" % (mime, base64.b64encode(buf.getvalue()).decode("ascii"))


def rgb_img(a):
    return Image.fromarray(np.round(np.clip(a, 0, 1) * 255).astype(np.uint8), "RGB")


KEYS = ((255, 0, 255), (0, 255, 0))   # two flat foregrounds: what differs is drawn over them


def face_with(fg):
    import compose_preview as cp
    data = cp.MOCK
    hist = cp.bucket_history(data, 16)
    trace = [(i / (len(data) - 1.0), cp.norm_hr(v)) for i, v in enumerate(data)]
    real = cp.foreground_image
    cp.foreground_image = lambda i, night: fg
    try:
        f = cp.compose(hist, 14 * 60 + 42, data[-1], False, trace, overlay=False, month=10, day=6,
                       resting=55, battery=100.0, hide=("village", "hiker", "geese", "swallow"))
    finally:
        cp.foreground_image = real
    return f.convert("RGB").resize((EDIT_PX, EDIT_PX), Image.LANCZOS)


def behind_and_front():
    """The face with no foreground (what a see-through gap shows), and what
    the face draws over the foreground (the time and the seal), as RGBA."""
    import compose_preview as cp
    behind = face_with(Image.new("RGBA", (cp.W, cp.H), (0, 0, 0, 0)))
    # difference matte: over two flat colors, a pixel drawn at opacity a
    # differs by (1 - a) times the colors' difference
    k1, k2 = (np.array(k, float) for k in KEYS)
    p1, p2 = (np.asarray(face_with(Image.new("RGBA", (cp.W, cp.H), k + (255,))), float) for k in KEYS)
    a = 1.0 - ((p1 - p2) * (k1 - k2)).sum(axis=2) / ((k1 - k2) ** 2).sum()
    a = np.clip(a, 0.0, 1.0)
    rgb = (p1 - k1 * (1.0 - a)[..., None]) / np.maximum(a, 1e-3)[..., None]
    a[a < 0.03] = 0.0
    front = np.dstack([np.clip(rgb, 0, 255), a * 255.0])
    return behind, Image.fromarray(np.round(front).astype(np.uint8), "RGBA")


def existing_mask(name):
    p = hand_masks.path_of(name)
    return data_uri(Image.open(p).convert("RGBA"), "PNG") if os.path.exists(p) else None


def subjects():
    import bake_foregrounds as bf
    import bake_props as bp
    out = []
    behind, front = behind_and_front()
    behind, front = data_uri(behind, "JPEG"), data_uri(front, "PNG")
    face = bf.FACE_PX
    bf.FACE_PX = EDIT_PX
    try:
        for season, letter in bf.PICKS:
            name = bf.name_of(season, letter)
            cut = Image.open(os.path.join(bf.cut_dir(season, letter), "01_fg.png")).convert("RGBA")
            cut = cut.resize((EDIT_PX, EDIT_PX), Image.LANCZOS)
            auto, _ = bf.bake_one(season, letter, masked=False)
            out.append({"name": name, "label": "%s, %s" % (season, PAINTERS[letter]),
                        "w": EDIT_PX, "h": EDIT_PX,
                        "paint": data_uri(rgb_img(hand_masks.on_paper(cut)), "JPEG"),
                        "auto": data_uri(auto.convert("RGBA"), "PNG"),
                        "behind": behind, "front": front, "mask": existing_mask(name)})
            print("painter: %s" % name, flush=True)
    finally:
        bf.FACE_PX = face
    for name, h in PROP_EDIT_H.items():
        row = [p for p in bp.PROPS if p[0] == name][0]
        auto, _ = bp.bake_plain(row[0], row[1], ("h", h), *row[3:])
        grey = Image.new("RGB", auto.size, (120, 120, 120))
        out.append({"name": name, "label": "%s (prop)" % name, "w": auto.width, "h": auto.height,
                    "paint": data_uri(rgb_img(hand_masks.on_paper(auto)), "JPEG"),
                    "auto": data_uri(auto, "PNG"), "behind": data_uri(grey, "JPEG"),
                    "front": None, "mask": existing_mask(name)})
        print("painter: %s" % name, flush=True)
    return out


def pickup():
    """Move <name>_mask.png (and "<name>_mask (2).png" repeats; the newest
    wins) from ~/Downloads into art/edits."""
    found = {}
    for p in glob.glob(os.path.join(DOWNLOADS, "*_mask*.png")):
        m = re.match(r"^(\w+)_mask(?: \(\d+\))?\.png$", os.path.basename(p))
        if not m:
            continue
        found.setdefault(m.group(1), []).append(p)
    if not found:
        print("no saved masks in", DOWNLOADS)
        return 1
    os.makedirs(hand_masks.EDITS, exist_ok=True)
    for name, paths in sorted(found.items()):
        paths.sort(key=os.path.getmtime)
        dest = hand_masks.path_of(name)
        shutil.move(paths[-1], dest)
        for old in paths[:-1]:
            os.remove(old)
        print("mask %s -> %s" % (name, os.path.relpath(dest, os.path.join(HERE, ".."))))
    return 0


PAGE = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>ink mask painter</title>
<style>
 body { margin: 0; background: #1b1b1b; color: #e6dccb; font: 14px/1.4 Segoe UI, Arial, sans-serif; }
 #bar { position: sticky; top: 0; z-index: 2; background: #262626; padding: 8px 12px; display: flex;
        flex-wrap: wrap; gap: 8px 14px; align-items: center; border-bottom: 1px solid #3a3a3a; }
 button, select { background: #333; color: #e6dccb; border: 1px solid #555; border-radius: 4px;
                  padding: 5px 10px; font: inherit; cursor: pointer; }
 button.on { background: #7a2a22; border-color: #c0483a; color: #fff; }
 button.save { background: #2d5a2d; border-color: #4f9a4f; }
 #wrap { padding: 14px; overflow: auto; }
 canvas#view { image-rendering: pixelated; cursor: none; display: block; }
 #help { color: #a9a090; font-size: 13px; padding: 0 14px 10px; }
 #cursor { position: fixed; pointer-events: none; border: 1px solid #fff; outline: 1px solid #000;
           border-radius: 50%; display: none; z-index: 3; }
 #status { color: #9fd49f; min-width: 12em; }
</style></head><body>
<div id="bar">
 <select id="subject"></select>
 <span>Brush:</span>
 <button id="t-solid" class="on" title="1">1 Solid</button>
 <button id="t-clear" title="2">2 See-through</button>
 <button id="t-auto" title="3">3 Auto</button>
 <span>Size <input id="size" type="range" min="2" max="120" value="24"> <b id="sizev">24</b></span>
 <span>Zoom <select id="zoom"><option selected>1</option><option>2</option><option>3</option><option>4</option><option>6</option></select></span>
 <span>Behind <select id="bg"><option value="scene">the face</option><option value="checker">checker</option><option value="magenta">magenta</option><option value="black">black</option></select></span>
 <button id="showmask" title="M">M Show my strokes</button>
 <button id="before" title="hold B">B Before</button>
 <button id="undo" title="Ctrl+Z">Undo</button>
 <button id="reset">Wipe my strokes</button>
 <button id="save" class="save">Save mask</button>
 <span id="status"></span>
</div>
<div id="help">Paint <b>Solid</b> on trunks, rocks and snow so nothing shows through them; paint <b>See-through</b> between branches; <b>Auto</b> puts the cutter's own result back. Keys: 1 2 3 brushes, [ ] size, M strokes, hold B for before, Ctrl+Z undo. <b>Save mask</b> once per painting you touched; the files land in Downloads as <i>name</i>_mask.png.</div>
<div id="wrap"><canvas id="view"></canvas></div>
<div id="cursor"></div>
<script>
const SUBJECTS = __SUBJECTS__;
const $ = id => document.getElementById(id);
let S = null, W = 0, H = 0, paint, auto, behind, front, mask, maskCtx, view, viewCtx, img;
let tool = "solid", size = 24, zoom = 1, showMask = false, before = false, bg = "scene";
let drawing = false, last = null, undo = [], dirty = {};
const cache = {};

function loadImg(src) {
  return new Promise(r => { if (!src) return r(null); const i = new Image(); i.onload = () => r(i); i.src = src; });
}
function pixels(im, w, h) {
  const c = document.createElement("canvas"); c.width = w; c.height = h;
  const x = c.getContext("2d"); if (im) x.drawImage(im, 0, 0, w, h);
  return x.getImageData(0, 0, w, h).data;
}
function bgPixels(w, h) {
  if (bg === "scene") return behind;
  const out = new Uint8ClampedArray(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4; let v;
    if (bg === "checker") { const k = ((x >> 4) + (y >> 4)) & 1; v = k ? [200, 200, 200] : [140, 140, 140]; }
    else if (bg === "magenta") v = [230, 0, 200]; else v = [0, 0, 0];
    out[i] = v[0]; out[i + 1] = v[1]; out[i + 2] = v[2]; out[i + 3] = 255;
  }
  return out;
}
let backPx = null;

async function pick(k) {
  S = SUBJECTS[k]; W = S.w; H = S.h;
  if (!cache[S.name]) {
    const [p, a, b, m, f] = await Promise.all([loadImg(S.paint), loadImg(S.auto), loadImg(S.behind), loadImg(S.mask), loadImg(S.front)]);
    const mc = document.createElement("canvas"); mc.width = W; mc.height = H;
    if (m) mc.getContext("2d").drawImage(m, 0, 0, W, H);
    cache[S.name] = { paint: pixels(p, W, H), auto: pixels(a, W, H), behind: pixels(b, W, H),
                      front: f ? pixels(f, W, H) : null, mask: mc, undo: [] };
  }
  const c = cache[S.name];
  paint = c.paint; auto = c.auto; behind = c.behind; front = c.front; mask = c.mask; undo = c.undo;
  maskCtx = mask.getContext("2d");
  view = $("view"); view.width = W; view.height = H; viewCtx = view.getContext("2d");
  img = viewCtx.createImageData(W, H);
  backPx = bgPixels(W, H);
  setZoom(); render(0, 0, W, H); status("");
}

function render(x0, y0, x1, y1) {
  x0 = Math.max(0, x0 | 0); y0 = Math.max(0, y0 | 0); x1 = Math.min(W, Math.ceil(x1)); y1 = Math.min(H, Math.ceil(y1));
  if (x1 <= x0 || y1 <= y0) return;
  const m = maskCtx.getImageData(x0, y0, x1 - x0, y1 - y0).data;
  const d = img.data;
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) {
    const i = (y * W + x) * 4, j = ((y - y0) * (x1 - x0) + (x - x0)) * 4;
    let s = 0, c = 0;
    if (!before) { const ma = m[j + 3] / 255, wh = m[j] / 255; s = ma * wh; c = ma * (1 - wh); }
    const keep = Math.max(0, 1 - s - c), aa = auto[i + 3] / 255 * keep, a = aa + s;
    for (let ch = 0; ch < 3; ch++) {
      let v = auto[i + ch] * aa + paint[i + ch] * s + backPx[i + ch] * (1 - a);
      if (front && bg === "scene") { const fa = front[i + 3] / 255; v = v * (1 - fa) + front[i + ch] * fa; }
      if (showMask && !before) v = v * (1 - 0.45 * (s + c)) + (ch === 1 ? 220 : 0) * 0.45 * s + (ch === 0 ? 230 : 0) * 0.45 * c;
      d[i + ch] = v;
    }
    d[i + 3] = 255;
  }
  viewCtx.putImageData(img, 0, 0, x0, y0, x1 - x0, y1 - y0);
}

function setZoom() { view.style.width = (W * zoom) + "px"; view.style.height = (H * zoom) + "px"; moveCursor(); }
function status(t) { $("status").textContent = t; }
function setTool(t) { tool = t; for (const k of ["solid", "clear", "auto"]) $("t-" + k).classList.toggle("on", k === t); }

function stroke(p, q) {
  maskCtx.save();
  if (tool === "auto") { maskCtx.globalCompositeOperation = "destination-out"; maskCtx.strokeStyle = maskCtx.fillStyle = "#000"; }
  else { maskCtx.globalCompositeOperation = "source-over"; maskCtx.strokeStyle = maskCtx.fillStyle = tool === "solid" ? "#fff" : "#000"; }
  maskCtx.lineWidth = size; maskCtx.lineCap = "round"; maskCtx.lineJoin = "round";
  maskCtx.beginPath(); maskCtx.moveTo(p[0], p[1]); maskCtx.lineTo(q[0], q[1]); maskCtx.stroke();
  maskCtx.beginPath(); maskCtx.arc(q[0], q[1], size / 2, 0, 7); maskCtx.fill();
  maskCtx.restore();
  const r = size / 2 + 2;
  render(Math.min(p[0], q[0]) - r, Math.min(p[1], q[1]) - r, Math.max(p[0], q[0]) + r, Math.max(p[1], q[1]) + r);
  dirty[S.name] = true; status("unsaved");
}
function at(e) { const b = view.getBoundingClientRect(); return [(e.clientX - b.left) / zoom, (e.clientY - b.top) / zoom]; }
let mouse = null;
function moveCursor() {
  const c = $("cursor"); if (!mouse) { c.style.display = "none"; return; }
  const px = size * zoom; c.style.display = "block"; c.style.width = c.style.height = px + "px";
  c.style.left = (mouse[0] - px / 2) + "px"; c.style.top = (mouse[1] - px / 2) + "px";
}

view = $("view");
view.addEventListener("pointerdown", e => {
  if (e.button !== 0) return;
  undo.push(maskCtx.getImageData(0, 0, W, H)); if (undo.length > 30) undo.shift();
  drawing = true; last = at(e); view.setPointerCapture(e.pointerId); stroke(last, last);
});
view.addEventListener("pointermove", e => {
  mouse = [e.clientX, e.clientY]; moveCursor();
  if (!drawing) return; const p = at(e); stroke(last, p); last = p;
});
view.addEventListener("pointerup", () => { drawing = false; });
view.addEventListener("pointerleave", () => { mouse = null; moveCursor(); });

$("subject").innerHTML = SUBJECTS.map((s, i) => `<option value="${i}">${s.label}${s.mask ? " (has a mask)" : ""}</option>`).join("");
$("subject").onchange = e => pick(+e.target.value);
$("t-solid").onclick = () => setTool("solid"); $("t-clear").onclick = () => setTool("clear"); $("t-auto").onclick = () => setTool("auto");
$("size").oninput = e => { size = +e.target.value; $("sizev").textContent = size; moveCursor(); };
$("zoom").onchange = e => { zoom = +e.target.value; setZoom(); };
$("bg").onchange = e => { bg = e.target.value; backPx = bgPixels(W, H); render(0, 0, W, H); };
$("showmask").onclick = () => { showMask = !showMask; $("showmask").classList.toggle("on", showMask); render(0, 0, W, H); };
$("before").onpointerdown = () => { before = true; render(0, 0, W, H); };
$("before").onpointerup = $("before").onpointerleave = () => { if (before) { before = false; render(0, 0, W, H); } };
function doUndo() { const u = undo.pop(); if (u) { maskCtx.putImageData(u, 0, 0); render(0, 0, W, H); status("unsaved"); } }
$("undo").onclick = doUndo;
$("reset").onclick = () => { if (!confirm("Wipe every stroke on " + S.label + "?")) return;
  undo.push(maskCtx.getImageData(0, 0, W, H)); maskCtx.clearRect(0, 0, W, H); render(0, 0, W, H); status("unsaved"); };
$("save").onclick = () => mask.toBlob(b => {
  const a = document.createElement("a"); a.href = URL.createObjectURL(b); a.download = S.name + "_mask.png"; a.click();
  dirty[S.name] = false; status("saved " + S.name + "_mask.png");
}, "image/png");
document.addEventListener("keydown", e => {
  if (e.target.tagName === "SELECT" || e.target.tagName === "INPUT") return;
  if (e.key === "1") setTool("solid"); else if (e.key === "2") setTool("clear"); else if (e.key === "3") setTool("auto");
  else if (e.key === "[") { size = Math.max(2, size - 4); $("size").value = size; $("sizev").textContent = size; moveCursor(); }
  else if (e.key === "]") { size = Math.min(120, size + 4); $("size").value = size; $("sizev").textContent = size; moveCursor(); }
  else if (e.key === "m" || e.key === "M") $("showmask").click();
  else if ((e.key === "b" || e.key === "B") && !before) { before = true; render(0, 0, W, H); }
  else if (e.key === "z" && (e.ctrlKey || e.metaKey)) { e.preventDefault(); doUndo(); }
});
document.addEventListener("keyup", e => { if ((e.key === "b" || e.key === "B") && before) { before = false; render(0, 0, W, H); } });
window.addEventListener("beforeunload", e => { if (Object.values(dirty).some(Boolean)) { e.preventDefault(); e.returnValue = ""; } });
pick(0);
</script></body></html>
"""


def main(argv):
    if "--pickup" in argv:
        return pickup()
    page = PAGE.replace("__SUBJECTS__", json.dumps(subjects()))
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    print("%s (%.1f MB)" % (OUT, os.path.getsize(OUT) / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
