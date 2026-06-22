# Appearance (composable sprites) & save-state transfer

How the pet is **rendered** (a stack of composable layers, not baked monolithic
sprites) and how a pet **moves between watches** (it's a tiny integer blob, not
image data). These two are one doc because they're the same fact seen twice: the
composable model makes a pet a short vector of indices, and *that vector is exactly
what transfers.* (2026-06-22)

> **Verdict.** Commit to the **composable layer model** now — it's near-free early
> and brutally expensive to retrofit, it directly serves identity divergence (the
> real retention lever, `05`), and it makes the pet a ~hundred-byte blob. Then both
> transfer questions become easy: a personal/no-backend transfer is feasible *if the
> app ships a serialize→export path*, and a paid ad-hoc backend transfer is a fully
> **deferrable** bolt-on. **Lock the architecture; defer the content volume** (how
> many parts per slot) as a kicked can, exactly like the evolution bands (`05`).

---

## Part 1 — The composable layer model

**You never store or transfer a sprite.** Every sprite lives in the app's compiled
resources, byte-identical on every install. What makes *your* pet is a small set of
**indices** that say which parts to composite. The renderer stacks z-ordered layers;
the save state is just the layer vector. This is the standard answer to a 768 KB heap
(`README` memory table) and it's not a gimmick — heap cost is the **sum** of layers
*currently loaded*, while distinct pets are the **product** of the slots.

### Schema — extends `state` from `05-progression.md §"How it plugs into the foundation"`

```js
state = {
  // ── Layer A — PERMANENT identity (set-once, gated behind confirm) ──
  id: {
    name:    "Spud",
    species: 2,        // base body silhouette → BODIES[2] + its anchors/parts_mask
    persona: 0,        // 07-personality voice-pack (NOT visual)
    basePal: 5,        // birth colorway — permanent "natural color"; palette swap = ~0 heap
    evo:     [1, 0],   // append-only branch history; band = evo.length, branch = evo[last]
                       //   → applies the evolution morph/overlay to the body
  },

  // ── Layer B — ACQUISITION (persistent; what you've EARNED) ──
  owned: {
    parts:  <bitset>,  // catalog ids unlocked: hats, capes, palettes…  (tens of bytes)
    emotes: <bitset>,  // unlocked emote/FX ids (the 02 greeting vocabulary)
  },

  // ── Layer C — ARRANGEMENT (fluid; free to change, costs nothing) ──
  look: {
    pal:  5,           // equipped colorway (defaults to id.basePal) → PALETTES[]
    head: 3,           // headwear slot   (0 = none)
    face: 0,           // face/eyewear    (0 = none)
    body: 7,           // cape/backpack   (0 = none)
    hold: 0,           // held item       (0 = none)
  },
  greet: [4, 1, 9],    // greeting routine = ordered emote ids (02): Layer-C arrangement of Layer-B owned.emotes

  ts: {...},
  v: 1,                // SCHEMA VERSION — the one field that makes import/transfer safe forever
}
```

The layer↔layer mapping is deliberate and reuses `05`'s three dials:
- **Layer A** (`id`) = permanent identity → species + birth palette + evolution morphs. Append-only, confirm-gated.
- **Layer B** (`owned`) = what you've earned → the bitsets of unlocked parts/emotes (acquisition persists).
- **Layer C** (`look`, `greet`) = arrangement → freely re-equippable; changing it costs nothing.

### Catalog (static, in `resources/`, identical on every install)

```js
BODIES   = [ {sprite, anchors, parts_mask}, … ]  // parts_mask = which slots this body supports
PALETTES = [ [c0…cN], … ]                        // color tables — applied at draw, ~0 extra heap
HEAD = [null, {sprite,anchor}, …]                // index 0 = none
FACE = […]   BODYACC = […]   HOLD = […]
EMOTES   = [ {frames|transform}, … ]
EVOS     = [ {band, branches:[{morph, look}]}, … ]   // from 05
```

### Render = composite a z-ordered stack (back → front)

```
1. body      BODIES[id.species] + evolution morph from id.evo      ← Layer A
   …drawn with PALETTES[look.pal || id.basePal]                    ← palette swap, ~0 heap
2. body-acc  BODYACC[look.body]   (cape/pack behind)               ← Layer C
3. face      FACE[look.face]                                       ← Layer C
4. head      HEAD[look.head]                                       ← Layer C
5. hold      HOLD[look.hold]                                       ← Layer C
6. pose/xform runtime, from mood/biometrics — NOT stored           ← ephemeral
7. emote FX  EMOTES[event | greet[i]] overlay — runtime            ← B unlocked / C arranged
```

### Why this beats the 768 KB heap

- **Additive cost, multiplicative variety.** Heap = layers currently composited (a sum);
  distinct pets = the product of the slots. Illustrative: `6 bodies × 12 palettes × 6 heads
  × 4 faces × 5 body × 4 hold ≈ 34,000` visible pets from ~25 small part-sprites + 12 palette
  arrays. (Numbers are a placeholder, not a committed catalog — see kicked can below.)
- **Palette swap is the cheapest multiplier.** Store one grayscale/indexed sprite, draw it
  under N color tables. 12 colorways ≈ 12 tiny arrays, **not** 12 sprites. This is the single
  biggest "feel like we have way more" lever, at ~0 heap. (Pairs with the frame-bitmap
  guidance in `01-solo-game.md §Rendering` — limited palette, reuse frames, lazy-load.)
- **Procedural motion over frame sheets.** Squash/stretch/rotate/translate the *same* sprite
  (transforms) for the runtime pose/emote rather than storing frame-by-frame sheets — one
  asset animates instead of eight sitting in heap.
- **Cache the composite** in a `BufferedBitmap`; recomposite only when `id`/`look` changes.

### The real cost is art coherence, not heap

The labor and the style constraint live here, **not** in memory: every `HEAD` must anchor
correctly on every `BODY` (hence per-body `anchors`/`parts_mask`), every palette must read
well on every part. "34,000 combos" looks janky if the parts weren't designed to compose.
**This is the thing to stress-test in the `pet-sandbox`** — prove 3–4 parts per slot compose
cleanly before authoring a big catalog.

### It IS the wire format (free social + free transfer)

The visit snapshot (`05 §"Won't everyone end up identical"` → README + `02-async-social.md`
"handful of tiny integers") is literally:

```
{species, evo[], basePal, look{pal,head,face,body,hold}, greet[]}  →  ~10 ints + 2 short arrays
```

Under ~100 bytes. A visiting friend renders your exact pet from that because their app has
the same catalog. **And that same blob — `id` + `owned` + `look` + `greet` + `v` — is the
entire pet.** That's what makes Part 2 easy.

---

## Part 2 — Transferring a pet between watches

Frame it right: **there is no sprite to move** — only a versioned integer blob of a few
hundred bytes (`owned` bitsets are the biggest piece, still tens of bytes). Size is never
the problem. The only problem is **egress**: getting bytes out of one watch and into another.
The watch has **no arbitrary file export, no camera to scan, and bad text entry**. So every
route below is just "which channel carries the blob."

### Fork A — You / your wife, hacker skills, ZERO backend

**Feasible — but the app must expose a serialize→export path; you can't do it purely from
outside.** Connect IQ `Storage` is the app's private on-device store; it is **not** a
documented user-copyable file. (⚠️ The watch mounts as MTP and you *might* locate where
Storage persists and copy it old→new, but that's **undocumented, per-install fragile, and
breaks across firmware** — do not build on it.) Because the blob is tiny, put the channel in
the app instead:

- **Export (bulletproof):** the app renders the serialized blob as a short code on the watch
  screen (state is small enough to base-32 into a few dozen chars + a checksum). Read it with
  your eyes / photograph it. This direction is reliable because it doesn't depend on Garmin's
  settings-sync reflecting runtime writes.
- **Import:** define an "import code" **Property** (app setting). Type the code into the
  Connect IQ settings on the phone → it syncs to the new watch → the app reads it on next
  launch and rehydrates. Phone→device Property sync is the solid, well-trodden direction.
  - ⚠️ The reverse (a *runtime-written* Property surfacing back in the phone settings UI for
    you to copy) is **not reliable** — settings sync is dependable phone→device, less so the
    other way. That's why export goes via the on-screen code, not a Property.

Cost: ~two small app features (render-code, read-import-Property), no server, riding Garmin's
own settings sync + your eyeballs. **Catch:** the *old* watch's installed app must already
have the exporter. In the sideload world (`open-questions.md §C` Monetization = personal /
free / sideload) this is recoverable even as an afterthought — re-sideload a build that adds
the exporter, *then* export.

### Fork B — Sold a product, then *"oh shit"* spin up a backend ad hoc

**Yes — genuinely deferrable. You do NOT need a pre-planned backend.** Most "we need sync"
realizations are catastrophic; this one isn't, because (a) the payload is trivial — store a
blob, hand it back — and (b) `makeOAuthRequest` gives a free Garmin Connect identity to key
saves to a human, no accounts/auth to build (`open-questions.md §B`).

What "ad hoc later" actually requires:

1. **An app update, not just server work.** You cannot make an already-installed binary phone
   home if it shipped with no `Communications` permission / no network code. So the bolt-on is
   always *server + an app update that knows how to talk to it.* Sideload → hand users a new
   `.iq`; store → a normal Connect IQ Store update. User updates **both** watches; new version
   POSTs the blob keyed by Garmin OAuth id; new watch pulls it. Transfer works, after the fact.
2. **A dead-simple key-value service.** `PUT /save/{garminUserId}` / `GET /save/{garminUserId}`.
   The blob is opaque bytes; you don't even parse it. A weekend, not a quarter.
3. **The real cost is the privacy policy, not the code.** Per `open-questions.md §B`, the moment
   user data leaves the device you owe a published privacy policy + data-retention discipline.
   (This is exactly the obligation the sideload/personal stance currently dodges — `§C
   Monetization`. Flipping on a backend *ends* that exemption.)
4. **Foreground + BLE-phone** for the OAuth/web calls (`§B`) — fine for a deliberate
   "transfer my pet" button. This is also precisely the kind of thing the deferred **companion
   app** could front (`06-companion-app.md` — Tier-2, account management / richer flows).

### The unifying punchline

Both forks ride the **same serialized, versioned blob.** Fork A pipes it through Garmin's
settings-sync (manual, no server); Fork B pipes it through your server (seamless). The only
pre-planning that buys **both**, and it's nearly free, is to do at launch:

1. **Make `state` serialize/deserialize cleanly** (the composable model already wants a flat
   int vector — you get this for free).
2. **Stamp `v` (schema version)** so a future importer/backend can read an old save and migrate
   it. Skipping this is the one thing that makes a year-3 transfer painful.

Add the on-screen export code + import Property too and Fork A works for you and your wife on
day one. ~20 lines now future-proofs every transfer scenario, from "tried it a month" to "5
years, new watch, please."

---

## Decisions locked by this doc

- [x] **Composable layer model is the rendering architecture** — z-ordered stack of indexed
      parts (`body` + palette + `head`/`face`/`body`/`hold` + runtime pose/emote), not baked
      monolithic sprites. Locked now because it's cheap early, expensive to retrofit, and it
      serves identity divergence (the `05` retention lever). Heap cost is additive; variety is
      multiplicative; palette swap is the near-free multiplier.
- [x] **Appearance maps onto `05`'s three layers** — A = `id` (species/basePal/evo, permanent),
      B = `owned` bitsets (earned), C = `look`/`greet` (fluid arrangement). No new progression
      rules; it reuses the spine.
- [x] **The pet IS its save blob** — `{id, owned, look, greet, v}`, ~hundreds of bytes; the
      visit snapshot is the same indices. There is no sprite to transfer.
- [x] **Transfer-portability minimum, shipped at launch:** `state` serializes cleanly **and**
      carries a `v` schema-version field. This alone keeps both transfer forks open forever.
- [x] **Fork A (personal, no backend) is supported via an in-app export/import**, not external
      file-poking: on-screen short-code export + import-code Property. (MTP Storage file copy is
      ⚠️ undocumented/fragile — not a plan.)
- [x] **Fork B (paid ad-hoc backend) is deferrable** — a later app update + a trivial KV service
      keyed by `makeOAuthRequest` identity. The gating cost is the privacy-policy obligation
      (`§B`), not engineering.

## Still open / kicked can 🥫

- [ ] **Content volume — DEFERRED (like the evolution bands, `05`/`open-questions §C`).** How
      many parts per slot (bodies, palettes, head/face/body/hold), how many compose coherently,
      and which are Layer-B earnable vs day-one. The combinatorial *count* is illustrative until
      felt out in the `pet-sandbox` on real hardware. **Lock the architecture, not the catalog.**
- [ ] **Slot set final** — is `head/face/body/hold` the right four, or do species need
      slot-specific anchors that change the set? Resolve when art starts.
- [ ] **Serialization format** — base-32 short-code alphabet, checksum, and how `owned` bitsets
      pack into the wire blob (keep it tiny; the 32 KB-per-Storage-value cap is miles away but
      the on-screen code wants to stay human-transcribable).
- [ ] **Companion vs watch-only for Fork B** — if a backend transfer ever ships, does it front
      through the deferred companion app (`06`) or stay watch-only `makeWebRequest`? Tied to the
      still-open companion decision in `open-questions.md §C`.

## Cross-refs
- `05-progression.md` — the three-layer model this appearance schema extends; the wire-format / snapshot foundation
- `01-solo-game.md §Rendering` — frame-bitmap / palette / lazy-load guidance the composite obeys; `§Save state` shape
- `02-async-social.md` — the visit snapshot / canned wire format the appearance vector rides
- `06-companion-app.md` — the deferred Tier-2 companion that could front a Fork-B backend transfer
- `open-questions.md §B` (no server→watch push, OAuth, store/privacy), `§C` (sideload/monetization, kicked cans)
- `README` — 768 KB uniform heap table (why composable matters)
