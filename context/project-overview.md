# Aurelix — Chapter One Demo: The Reeve's Errand

## Overview

Aurelix is a small 2D RPG for macOS built around AI-voiced NPCs
whose dialogue feels alive without ever letting the language
model become the game engine. The hero, Kael, is hired by a
frontier reeve to investigate dragon sightings near an old
tower. The demo is the first quarter of Act I — the dragon
never appears on screen. Its job is to prove the
"deterministic engine, generative voice" architecture: every
NPC speaks via Claude Haiku, but quests, facts, and rewards
only advance through engine-validated reveals. The full game's
central twist (the dragon Aurelix is the unreliable narrator
the player must learn to distrust) is foreshadowed but not
played in the demo.

## Goals

1. Make five archetype NPCs feel like people who live in a
   world, not assistants — each with a distinct voice,
   capability ceiling, and willingness profile.
2. Make the central reveal (Orren's drunk witness account)
   earnable through the Press mechanic, and provable through
   triangulation against authored rumor and false claims.
3. Keep canon deterministic — the LLM proposes; the engine
   approves. No fact, quest state, item, or relationship
   change is ever taken from model output without validation.
4. Ship a ~30-minute polished playthrough on macOS (Apple
   Silicon primary) at vibe-coding pace, solo dev.
5. Survive offline play, prompt injection, and malformed
   model output without breaking the critical path.

## Core User Flow

1. Player opens on Marlow's Hollow village square. Notice
   board explains the dragon bounty.
2. Reeve Halden briefs Kael. Quest `dragon_sighting` begins
   in state `active`.
3. Player explores the village: Toma at the well repeats a
   confident false rumor; Mara mentions a smoke rumor and
   sells gear; Edda warns against the errand; sober Orren
   is evasive.
4. Player spends starting coin (ale is the lever for Orren,
   iron sword/jerkin for combat survivability).
5. Path north into Forest Edge. Two wolf encounters teach
   solo combat.
6. Bandit camp: three bandits plus named mini-boss Drust.
   Drust drops the bandit note. Strange coin and throwing
   knives loot in camp.
7. Cage in the camp holds Iskar (drake hatchling). Player
   frees him; the bone tag carries his name. Iskar bonds
   and follows Kael on the overworld from this point.
8. Return path: companion-pair fight. Iskar earns affinity
   points; tier 1 unlocks Ember-Spark.
9. Back in village: offer ale to Orren → drunk state.
10. Ask Orren about the tower → he dodges. Press → authored
    sharper options appear. Right idea cracks him → engine
    grants canon fact `dragon_seen_near_old_tower`.
11. Optional: show strange coin to Mara, bandit note to
    Edda, feed Toma. Each mutates that NPC's dossier and
    seeds full-game faction reactions.
12. Return to Halden with the fact. Bounty paid. Quest
    `dragon_sighting` advances to `complete`.
13. Title card: "Chapter One ends. The full game is in
    development."

## Features

### Dialogue

- Universal pattern: every text moment offers authored
  options *and* a free-text field. Both go through the
  same pipeline.
- Four player verbs: Ask, Press, Change subject, Offer item.
- Press is context-sensitive — only appears on topics the
  NPC has dodged. Raises hidden NPC stress; combines with
  willingness to crack, dodge again, or anger.
- Anger enters a recoverable cooldown (in-game beats or
  apology gift), never a permanent lock.
- Capability gate runs deterministically before generation
  and returns `allowed | blocked | constrained`. Blocked
  domains fail in-character via the NPC's `failure_style`.

### NPC Intelligence

- Five demo NPCs: Halden (templated), Mara (hybrid), Orren
  (full AI, holds canon), Toma (full AI, false-rumor
  showcase), Edda (hybrid).
- Each has a dossier of authored briefings (witness +
  rumor tiers) and a `forbidden_to_share` flag per entry.
- Memory is hybrid: structured fields (patience, stress,
  flags) plus a model-produced one-paragraph summary
  refreshed every turn.
- Dossiers mutate at runtime — showing items, walking in
  with Iskar, witnessing events — and persist across saves.

### Combat

- EarthBound-style top-down menu battles, overlay on the
  current map. No scene transition.
- Stats: HP, ATK, DEF, SPD. Turn order by SPD.
- Kael actions: Attack, Item, Defend, Flee. No magic.
- Iskar companion uses stance-based AI (Aggressive,
  Defensive, Support). Player picks the stance, not the
  action.
- Affinity points earned per fight; tier 1 (10 pts) =
  Ember-Spark (Burn-causing breath).

### Quests, Facts, Journal

- Quests are state machines gated by required facts.
- Facts are atomic, registered in `data/facts.yaml`, only
  written by validated briefing reveals or world
  interactions.
- Journal is Kael's own dossier — same schema, same
  retrieval, same AI pipeline as NPC dialogue. The player
  asks questions in Kael's voice.

### World

- Two scenes for the demo: Marlow's Hollow village square
  and Forest Edge.
- Tile-grid 8-direction movement, discrete steps.
- Visible encounter sprites (avoidable on the map).
- Single-slot JSON save, anywhere outside combat.

## Scope

### In Scope

- The 13-step playthrough above, end to end.
- Five fully voiced NPCs with authored fallback line banks.
- Orren's Press + crack flow as the demo's marquee mechanic.
- Iskar bond, follower behavior, and stance-driven combat.
- Local FastAPI proxy hiding the Anthropic key; Haiku 4.5
  for villager dialogue.
- Mock provider parity so the game runs fully offline.
- Debug overlay surfacing topic detection, capability gate,
  retrieved briefings, raw model JSON, validation outcome.

### Out of Scope

- The dragon Aurelix himself — he does not appear in the demo.
- Open world, procedural quests, branching endings.
- Full faction standing UI (seeded internally, not surfaced).
- Magic system for Kael (Iskar carries the only magic).
- Multiple save slots.
- Windows/Linux builds (macOS only for the demo).
- Detecting every possible prompt injection — diegetic
  refusal is sufficient.
- A multi-NPC concurrent dialogue or party chatter system.

## Success Criteria

1. Player completes `dragon_sighting` using Orren's drunk
   reveal of `dragon_seen_near_old_tower`.
2. Asking Toma, Mara, and Edda about the tower yields
   distinct, in-character responses (not boilerplate).
3. Sober Orren refuses; drunk Orren cracks under Press.
   The capability and willingness gates are visible in
   the debug panel.
4. Wolves and bandits resolve in combat without softlock.
5. After bonding, Iskar appears in combat with stance-based
   behavior.
6. Affinity tier 1 (Ember-Spark) is reachable in one
   playthrough.
7. All four social levers fire: ale → Orren, apple/ration →
   Toma, strange coin → Mara, bandit note → Edda.
8. Journal queries return in-character answers grounded in
   the player's accumulated briefings.
9. Save and reload between dialogue turns preserves NPC
   memory, dossier mutations, and journal entries.
10. With the network disconnected, the game falls back to
    canned responses and the quest is still completable.
11. Prompt injection attempts fail diegetically, in
    character.
12. Angering an NPC enters a recoverable cooldown, not a
    permanent lock.
13. Dossier mutations are observable: showing strange coin
    to Mara changes her next dialogue; walking Iskar into
    the village changes village NPC reactions.
14. Witness-tier reveals unlock canon facts; rumor-tier
    reveals do not. Toma's confident false story never
    advances the quest no matter how often it is asked.
