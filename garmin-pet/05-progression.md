# Progression & ownership — the three-layer model

How the pet "scales up" without becoming either a paralyzing skill-tree or an
ownerless treadmill. This doc decides **where choices live, how permanent they are,
and why** — and it's the answer to every future "should this be a player choice?"
question. Grounded in game-design + choice-psychology research (2026-06-15, sources
at the bottom; confidence tagged).

> **The design question, in one image.** Sylvia Plath's fig-tree (*The Bell Jar*, ch. 7):
> a person sits in the fork of a tree where each fig is a different possible life, unable
> to choose, and the figs blacken and drop one by one. The standard reading: she starves
> from **not choosing**, not from choosing *wrong* — and the paralysis comes from three
> false premises she loads onto the choice. Those three premises are exactly the dials
> we tune below.

---

## The core principle: three dials, tuned per layer

Every progression mechanic is some setting of three independent dials:

| Dial | Open skill-tree (paralysis) | Single track (treadmill) | What we do |
|------|------------------------------|---------------------------|------------|
| **Simultaneity** — how many choices face you at once | All at once | One at a time, forced | **Serialize** — daily/seasonal cadence; show a small ripe slice, never the whole tree |
| **Exclusivity** — does picking one forfeit others | Mutually exclusive | N/A (no choice) | **Additive** — you get everything *eventually*; order/emphasis is the expression |
| **Permanence** — can you take it back | Permanent (regret) | Permanent (no stakes) | **Split** — a *few* permanent **identity** choices (ownership); everything else reversible |

The fig tree rots because Plath's narrator assumes **simultaneous + exclusive + permanent**
all at once. A daily, cozy, evolving pet is structurally the *opposite* of all three — so
the medium itself is the antidote. We lean into that, and inject permanence **only where it
creates attachment** (Layer A).

---

## Why both extremes fail (and the research name for it)

The open-vs-guided tension is a **named collision** in self-determination theory (Deci &
Ryan; the games-specific **PENS** model, Rigby & Ryan, *Glued to Games*): **autonomy vs.
competence.**

- Too **open** → starves *competence*: the player feels lost. **= fig-tree paralysis.**
- Too **structured** → starves *autonomy*: the player feels railroaded. **= ownerless treadmill.**

The literature's resolution is **graduated scaffolding** (guided *first* to build competence,
opening up *as you go* to deliver autonomy) — sequence, not either/or. See Onboarding below.

**Two distinct cautionary failure modes — avoid importing either:**
- **Breadth overload** — *Path of Exile*'s ~1,300-node tree. The tell: players get so
  paralyzed they copy an external build guide, which *defeats* the customization the system
  promised. [confirmed]
- **Permanence regret** — *Diablo II* (original, no respec): a wrong early pick "gimped" a
  40-hour character; respec was added a decade later because permanence drove churn. [confirmed]

Both are "all figs, at once, forever." Neither belongs in a cozy daily game.

---

## The three layers

### Layer A — Identity: FEW + PERMANENT. *This is where ownership lives.*

A small handful of one-time, committed choices: the pet's **name**, its **species at birth**,
its **persona/temperament** (the asshole-vs-sycophant axis — full system in `07-personality.md`),
and the **branch chosen at each evolution**. Spaced out so you never face more than one at a
time (simultaneity dial = serialized). Persona is **orthogonal to species/look** (any creature
can be any temperament) and, like the evolution branch, is re-pickable only *at evolution*.

**Why permanent, counter-intuitively:** Gilbert & Ebert (*JPSP* 2002, the photography-class
study) found people who made an **irreversible** choice ended up *liking it more* than those
who could swap — commitment triggers the mind's rationalization ("psychological immune
system"), which manufactures attachment. **Permanence breeds love.** [direction solid; exact
figures unverified]

This is the resolution to "single track has no ownership": **ownership doesn't come from a
sprawling editable tree — it comes from a *few* choices you genuinely can't take back.**
That's why a single track feels ownerless (zero permanent identity choices) and a giant tree
feels anxious (too many permanent choices at once). The sweet spot is **~3–4 identity
commitments**, far apart.

### Layer B — Progression: EVERYTHING EVENTUALLY, order is yours.

The tracks (`fit` / `house` / `gift`-quality, etc.) are **not mutually exclusive — you will
max them all eventually.** This is the cozy-games model (*Animal Crossing*, *Stardew Valley*:
"no wrong way to play"; missed seasonal content "comes back next year"). Exclusivity dial =
additive → **no fig rots, because nothing is forgone, only not-yet.**

What's *yours* is the **sequence and emphasis** — gym-first or mansion-first, which power you
main, how you arrange the place. Expressive without loss. This kills fig-tree FOMO at the
progression level entirely.

### Layer C — Daily: SMALL + TELEGRAPHED + REVERSIBLE.

Each day surfaces only a **few ripe options**, never the whole catalog (the *Slay the Spire* /
*Hades* trick — bounded choice drawn from a huge space defeats overload). **Telegraph** what
each option unlocks *before* committing (*PoE 2* added node-previews precisely to de-paralyze
the same tree; Sid Meier: a choice is only "interesting" if you can partly *predict* its
outcome — a blind gamble is anxiety, not agency).

Daily/tactical choices are **freely recoverable** — rearrange the house anytime. Reversibility
costs *nothing here* because the meaningful, persistent thing is the **acquisition** (earned
over days, à la *Destiny* gear), while the **arrangement** stays fluid. (Heed the *Diablo III*
dilution warning: if *everything* is instantly free to undo, nothing feels owned — which is
exactly why the permanent stuff lives in Layer A, not here.)

---

## What "power" means — and the track quadrant

The progression tracks aren't four flavors of one thing; each has **one distinct job.**
Two are about the *pet*, two about the *world*:

|  | The pet | The world |
|---|---|---|
| **grows with effort** | **fit** — its body mirroring your training | **power** — its *capabilities* (what it can sense / say / do) |
| **expresses identity** | *persona* (`07`, Layer A) | **house** — your stage · **gift** — social exchange |

The track that needed defining was **power.** This game has **no combat**, so a power is
**never a stat multiplier** ("effort counts 1.3×" — invisible, and exactly the PoE/Diablo
number-grind trap flagged above). Instead:

> **A power is a capability — something the pet can now *sense, say, or do* that it
> couldn't before.** Powers make the *world bigger*, not the *numbers bigger.* Horizontal,
> discrete, felt, and earned from your real effort (the pet gets smarter as you train).

Powers split in two:
- **Functional powers** — change what the loop *does*: a newly-sensed exercise (the `04`
  sensing roadmap, *paced out* instead of dumped on day one), the proactive nag (`06`),
  "challenge of the day," streak-shields, small idle returns. **Consequence.**
- **Expressive powers / emotes** — change how it *feels/looks*, **zero consequence** (ACNH
  reactions — the pointless ones are the most loved): burst into flames, flex, faceplant.
  Same earn-with-effort economy; they're the raw material for the visitor-greeting routine
  (`02`).

Both are earned the same way and both feed the "scaling up" fantasy; they differ only on
whether they touch game state.

**Gifts/items, by contrast, are expression — never capability.** They decorate (the `house`
stage) and flow between friends as a love-language (`02`); at most they trigger *flavor* (a
cute animation, a transient mood bump). "Better gifts" means *prettier/rarer*, not *stronger*
— which keeps **single-player complete** (you never need a friend's gift to progress) and
kills pay/social-to-win. This is forced by the locked cozy guardrails (no FOMO) + Layer B's
everything-eventually.

---

## The one *real* fig — and why it doesn't rot

Keep exactly **one** weighty, committed fork: **the evolution branch.** When the pet evolves,
you pick one of ~3 paths and live with it — real stakes, real ownership.

The rot-defuser is *Hades*'s insight: **breadth is meant to be sampled across runs.** Across
this pet's future evolutions (or a second pet later), you taste the other branches. So it's a
**fig that regrows** — commitment without permanent loss. You get the meaningful fork you want,
and you never starve. Evolution is also the **meta-track / infinite height** (no dead end): max
a band, evolve, a higher band opens, plus a badge friends can see.

---

## "Won't everyone end up identical if they get everything?"

No — at any *snapshot* two pets diverge hard on:
1. **Permanent identity** — species + evolution branch (genuinely diverge between players;
   *never* converge).
2. **Current arrangement** — equipped cosmetics, what's on display.
3. **Where they are on the journey** — a fitness-first player looks/plays nothing like a
   house-first player, even though both *eventually* get both.

Convergence is theoretical and years out; identity divergence is permanent. And this drops
straight into the **tier-index wire format** (see README + `02-async-social.md`): a visiting
friend sees your distinct identity + current emphasis, rendered from a handful of tiny
integers. The foundation already carries it.

---

## Onboarding: guided → open (the scaffolding sequence)

Per the SDT resolution, don't open the whole thing on day one:
- **Week ~1 (guided):** one obvious daily goal, loud positive feedback that the pet is
  thriving. Builds *competence* and the habit. Few/no branching choices.
- **Then progressively open** Layer B emphasis and Layer A's first evolution as the player
  gains footing — so openness arrives *as autonomy*, not as paralysis.

---

## Cozy guardrails (don't undo the coziness)

From the Project Horseshoe 2017 cozy-games report — coziness = **Safety** (no impending
loss/threat) + **Abundance** + **Softness**:
- **No fail state, no pet "death," no neglect punishment.** Decay is gentle and pauses/forgives
  missed days (never a loss spiral). Effort always yields **visible positive change.**
- **No FOMO mechanics.** Limited-time-or-lose-forever loops *negate* coziness — "a dark pattern
  in a soft cardigan." Seasonal content must **come back** (Stardew's "next year").
- **Let things reach genuine "done/satisfied" states.** Lean on the urge to *resume* (Ovsiankina
  effect) — not an always-incomplete checklist (the battle-pass/MMO obligation trap). The
  Zeigarnik *memory* effect is largely a myth [meta-analysis ≈ chance] — don't build on it.

---

## Momentum & consistency — reward the *gain*, never weaponize the *loss*

(2026-06-22) "Momentum" = the feeling that showing up regularly makes effort matter more.
Powerful — but the obvious implementation is **the one this doc already vetoed**: a hidden
effort multiplier ("effort counts 1.3×", see §"What 'power' means" — invisible *and* grind-y).
And the most *engaging* version in the wild is the **loss-framed streak** (don't-break-the-chain),
which loss aversion makes ~2× as potent (Kahneman-Tversky, §Sources) — and which is exactly the
**FOMO / punishment spiral the cozy guardrails forbid.** So the stance:

> **Momentum is a visible, gently-decaying *state* that brings good things *sooner* — never a
> hidden number, and never something you're punished for losing.** Harness its gain; refuse its
> loss frame. Optimize for *durable, guilt-free return*, not raw engagement (the dark-pattern target).

Four mechanisms, all reusing systems already specced — no new subsystems:

1. **Warmed-up / "in the zone" state.** Consecutive active days visibly raise the pet's energy
   (posture, more emotes, sharper banter); a lapse drifts it to "rusty but fine," decaying to a
   **floor** — never below, never a guilt bar. This is **mood-as-weather** applied to the `fit`
   track. The payoff is *expression + pacing* (the next unlock comes sooner when consistent), not a %.
2. **Daily-first bonus + soft diminishing returns.** The *first* effort each day pays the juiciest
   reward; extra reps that day taper. This is the legitimate, **visible** form of "daily counts for
   more" — the bonus is on **cadence**, shown to the user, so daily beats binge *without* a streak
   cliff. (Goal-gradient effect, gain-framed.)
3. **Streak-shields = forgiveness built in.** One miss never shatters momentum; the pet coasts or
   spends an earned shield (already a planned *functional power*, §"What 'power' means"). Removes the
   anxiety cliff structurally.
4. **Comeback warmth.** Returning after a gap = warm reunion + a small catch-up payoff (the
   **idle-return story**, `01`), not "0/3" shaming. The Drill persona may *roast* the gap — that's
   **character/flavor** (`07` `STREAK_BROKEN`), never a mechanic that costs you anything.

**The deepest driver — cozier *and* stickier than any of the above — is identity/competence**
(SDT/PENS, §Sources). Momentum framed as the pet **embodying your consistency** — who it *is*, not a
number it *holds* — is identity reinforcement: "I'm becoming someone who trains, and my buddy is the
proof." It can't be lost punitively, which is exactly why it fits.

> ⏳ **Numbers are a kicked can** (like the evolution bands): decay rate / floor, the daily-first
> curve, the shield economy — all TBD on hardware. Capture the *principle* (gain-framed, visible,
> forgiven); tune the *curve* in the `pet-sandbox` scrubber later. → `open-questions.md §C`.

---

## How it plugs into the foundation

This layers cleanly onto the track/tier/currency model from README + `01-solo-game.md`:

```
// SAVE-STATE additions (tiny; Application.Storage)
state = {
  // ... existing bal{effort,bonds}, tier{...}, worn[], show[], ts{} ...
  id: {                       // Layer A — PERMANENT, set-once, never re-written freely
    name:    "Spud",          // one-time at creation
    species: 2,               // one-time at creation
    persona: 0,               // 0=drill-sgt 1=cheerleader 2=deadpan 3=zen (07-personality.md)
    evo:     [1, 0]           // chosen branch per evolution; append-only history
  }                           // persona re-pickable only at evolution (like a branch)
}

// CATALOG (static, in resources)
EVOLUTIONS = [
  { band: 0, branches: [ {id:0, look:"sleek"}, {id:1, look:"chonk"}, {id:2, look:"wild"} ] },
  { band: 1, requires:{any_track_tier: 10}, branches: [ ... ] },
  // each evolution = the one "real fig"; branches are sampled across lives
]
```

- **Layer A** = `state.id` (append-only; the UI must *gate* these behind a deliberate confirm —
  they're the permanent ones).
- **Layer B** = the existing `tier{}` indices climbing through `TRACKS` (all eventually maxable).
- **Layer C** = a per-day surfaced subset of affordable next-tiers + telegraphed unlock previews.
  Editable *arrangement* also includes the **visitor-greeting routine** (`02`): the earned
  emotes are Layer-B acquisition (permanent), the routine composed from them is Layer-C
  arrangement (freely re-editable) — no new rules needed.

---

## Decisions locked by this doc

- [x] **Not open-vs-single-track** — both, by layer (permanence where it creates ownership;
      abundance where it kills FOMO; guidance where it prevents paralysis).
- [x] **~4 permanent identity choices** (name, species, **persona** [`07`], evolution branches)
      = the ownership engine. Gated behind explicit confirm; re-pick only at evolution.
- [x] **Progression tracks are additive** (everything eventually; order = expression).
- [x] **Daily choices are small, telegraphed, reversible**; acquisition persists, arrangement is fluid.
- [x] **Evolution = the one real fork + the meta-track** (infinite height, no dead end), sampled
      across lives so it never "rots."
- [x] **Cozy guardrails are hard rules** — no death/neglect spiral, no FOMO, gentle decay.
- [x] **Momentum is gain-framed, visible, and forgiven** — never a hidden effort multiplier
      (already vetoed) and never a loss-framed streak (FOMO). It's a warmed-up *state* + a
      daily-first bonus + shield forgiveness + comeback warmth, with identity/competence as the
      deepest driver. Curve numbers TBD (kicked can). See §"Momentum & consistency".

### Still open (product calls, see also `open-questions.md §C`)
- [ ] How many evolution **bands** total, and what gates each (track-tier? age? a quest?).
- [ ] Do evolution branches differ in **powers/verbs**, **cosmetics only**, or both? (Lean, now
      that "power" = a capability-verb: a branch grants **one signature *functional* power + a
      look** — horizontal, not power-superior. The Layer-B power track is the broad menu everyone
      eventually unlocks; the evolution branch is the one *permanent signature* capability. —
      firming up next.)
- [ ] Exact **decay forgiveness** curve (how gentle; does it pause when away?).

---

## Sources (confidence-tagged)

**Game design**
- Cozy framework — Project Horseshoe 2017: https://projecthorseshoe.com/reports/featured/ph17r3.htm [solid]
- Horizontal vs vertical progression: https://www.gamedeveloper.com/design/the-fundamentals-of-game-progression
- Bounded choice / meta-progression — *Hades* Mirror of Night: https://www.thegamer.com/hades-mirror-of-night-roguelite-progression/ ; *Slay the Spire* card rewards / "FOMO drafting": https://www.spirebuilds.com/guides/understanding-card-rewards
- "Interesting decisions" (predictability, no dominant option) — Sid Meier, via:
  https://www.gamedeveloper.com/design/designing-interesting-decisions-in-games-and-when-not-to-
- Cautionary: PoE tree paralysis: https://www.wayline.io/blog/paradox-of-customization-player-engagement ;
  D2 permanence/respec history: https://www.pcgamesn.com/diablo-2-resurrected/respec

**Choice psychology**
- Self-Determination Theory — Ryan & Deci 2000: https://selfdeterminationtheory.org/SDT/documents/2000_RyanDeci_SDT.pdf [solid]
- PENS / "Motivational Pull of Video Games" — Ryan, Rigby & Przybylski 2006: https://link.springer.com/article/10.1007/s11031-006-9051-8 [solid]
- **Reversibility breeds *less* satisfaction** — Gilbert & Ebert 2002: https://dtg.sites.fas.harvard.edu/Gilber%20t&%20Ebert%20(DECISIONS%20&%20REVISIONS).pdf [direction solid; exact numbers unverified]
- Paradox of choice / jam study — Iyengar & Lepper 2000: https://pubmed.ncbi.nlm.nih.gov/11138768/ ;
  **but barely replicates** — meta-analysis Scheibehenne et al. 2010: https://doi.org/10.1086/651235 [⚠️ use as "curate & differentiate," not "fewer is better"]
- Maximizers vs satisficers — Schwartz et al. 2002 (Maximization Scale) [correlational]
- Loss aversion / Prospect Theory — Kahneman & Tversky 1979 [solid]; counterfactual regret — Medvec, Madey & Gilovich 1995 (Olympic medalists) [solid]
- FOMO scale (built on SDT) — Przybylski et al. 2013 [solid]
- Zeigarnik *memory* effect ≈ chance — Ghibellini & Meier 2025: https://www.nature.com/articles/s41599-025-05000-w ; use **Ovsiankina** (resumption) instead

**Poetry**
- Fig-tree image — Sylvia Plath, *The Bell Jar* (1963), ch. 7. Reading: paralysis from treating
  choices as simultaneous + exclusive + permanent; she starves from *not* choosing.
  (In-copyright — paraphrased here, not quoted. Ref: https://www.sparknotes.com/lit/belljar/quotes/)

## Cross-refs
- `README.md` — track/tier/currency foundation + tier-index wire format
- `01-solo-game.md` — the daily loop these layers sit on; decay model
- `02-async-social.md` — why identity+arrangement is the shareable snapshot
- `09-appearance-and-transfer.md` — how Layers A/B/C map onto the composable-sprite render stack + the save blob that transfers
- `10-power-roster.md` — the concrete catalog of real CIQ capabilities behind this doc's functional/expressive power philosophy
- `open-questions.md §C` — the product decisions this doc resolves / leaves open
