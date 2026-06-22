// ═══════════════════════════════════════════════════════════════════════════════
// PROGRESSION LADDER — sandbox mock of garmin-pet/05-progression.md
// ═══════════════════════════════════════════════════════════════════════════════
// One XP track that, as it rises, evolves the pet's life stage and unlocks
// capabilities. This is a DEV-FACING MOCK so "growing up" can be scrubbed in
// seconds instead of earned over real days.
//
// On the real watch, XP accrues ONLY from real effort (Buddy Mode sessions, daily
// activity). Here a slider / +- buttons fast-forward it; the minus button is a dev
// rewind, NOT a shipped feature — you would never lose progression IRL.
//
// Per 05-progression.md, unlocks are a mix (the "kind" tags map to that doc):
//   power  — a CAPABILITY (sense / say / do); has consequence
//   emote  — pure expression; zero consequence (ACNH-style)
//   phrase — a new voiced line set (07-personality.md voice-pack)
//   look   — a visual / evolution change (Layer A identity)
// and every band maps to one of the three life stages the creature art uses.
//
// The numbers below are illustrative pacing, not a balanced economy.
// ═══════════════════════════════════════════════════════════════════════════════

export const XP_MAX = 1000;

// Ordered by xp ascending. `unlock` is what *arrives* at that band (null = the
// pet simply exists at the start).
export const LADDER = [
  { xp: 0,   stage: "baby",  name: "Hatchling", unlock: null },
  { xp: 120, stage: "child", name: "Sprout",    unlock: { kind: "emote",  label: "😤 Flex" } },
  { xp: 280, stage: "child", name: "Trainee",   unlock: { kind: "power",  label: "Senses generic effort" } },
  { xp: 380, stage: "child", name: "Talker",    unlock: { kind: "phrase", label: "Trash-talk line pack" } },
  { xp: 500, stage: "adult", name: "Athlete",   unlock: { kind: "look",   label: "First evolution · counts squats" } },
  { xp: 700, stage: "adult", name: "Veteran",   unlock: { kind: "emote",  label: "🔥 Burst into flames" } },
  { xp: 900, stage: "adult", name: "Legend",    unlock: { kind: "power",  label: "Signature power · streak shield" } },
];

export function bandIndexForXp(xp) {
  let idx = 0;
  for (let i = 0; i < LADDER.length; i++) {
    if (xp >= LADDER[i].xp) idx = i;
  }
  return idx;
}

export function bandForXp(xp) { return LADDER[bandIndexForXp(xp)]; }

export function nextBand(xp) {
  const i = bandIndexForXp(xp);
  return i < LADDER.length - 1 ? LADDER[i + 1] : null;
}

// Every unlock earned up to this xp (skips the empty band-0 unlock).
export function unlocksForXp(xp) {
  const i = bandIndexForXp(xp);
  return LADDER.slice(0, i + 1).map(b => b.unlock).filter(Boolean);
}

// First xp of the band that owns a given life stage — lets the manual stage
// radios jump the XP scrubber to a matching point and stay consistent.
export function xpForStage(stage) {
  const b = LADDER.find(band => band.stage === stage);
  return b ? b.xp : 0;
}
