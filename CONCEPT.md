# CONCEPT

## Purpose

This document is the design concept for *Aurelix*, a small 2D RPG for macOS built on the architecture described in `ARCHITECTURE.md` and the NPC design principles described in `NPC-INTELLIGENCE.md`.

It defines the story, the central design thesis, the full three-act arc, and the scope of the first playable demo. It is the canonical source of truth for design intent. Where this document and the architecture documents disagree, the architecture wins for technical questions; this document wins for story and feel.

## The Pitch

A hero is hired to slay the dragon that has been terrorizing the kingdom. When they find the dragon, Aurelix turns out to be charming, funny, a little naive, and clearly the victim of a misunderstanding. The hero is drawn into helping him. The quests get stranger. The villages grow colder. By the time the hero realizes Aurelix has been using them, the kingdom and half its factions want them dead. Redemption is possible only by hunting Aurelix down for real — this time knowing exactly what he is.

## Story

The full arc moves through three acts.

### Act I — Sympathy

The hero begins as the kingdom expects them to begin: a stranger hired to investigate dragon sightings near a frontier village. They gather rumors, prepare gear, and head into the wilds. When they meet Aurelix, he is not what they were told. He is articulate, vulnerable, witty. He tells a story that explains the sightings in a way that makes the kingdom look paranoid and himself look misunderstood. The hero leaves the first encounter unsure, but intrigued. He asks for a small favor.

### Act II — Entanglement

Three or four favors. Each has a surface reason that sounds reasonable and a hidden cost the player can only detect by listening to NPCs they meet along the way. Recover his "stolen heirloom" — which turns out to be a priest's relic. Deliver "medicine" — which is poison. Warn a hermit — who is then found dead. The hero's standing with the Crown, the village, the Order, the merchants, the forest folk decays in different combinations after each errand. The damage is not announced. NPCs grow colder. Shops refuse trade. Guards watch the road.

### Act III — Reckoning

The player realizes. The realization can come early or late, depending on how much they investigate. By Act III the world has turned. The hero cannot simply walk to the dragon and finish the job; they have no allies, no supplies, no welcome anywhere. They must rebuild at least one faction's trust by undoing some part of what Aurelix used them to do. Only then can they confront him with means and witnesses. The final encounter is not a boss fight in the conventional sense; it is a conversation that ends in violence, and what the hero has learned about Aurelix's tells, lies, and weak points determines whether they survive it.

## The Trick

The dragon's trick on the hero is the same trick a language model plays on a player.

Aurelix speaks beautifully. He cannot create truth. The game engine controls what is real, what is rumor, and what is a lie. The architecture documented in `ARCHITECTURE.md` and `NPC-INTELLIGENCE.md` is not just a way to build NPCs; it is the thematic spine of the game. By the end, the player has learned by experience the lesson the architecture enforces in code:

```text
Words are not facts.
Charm is not honesty.
The game is the truth, not the speaker.
```

This is the central design thesis. Every system supports it.

## Goals

- Make NPC conversations feel like talking to people who live in a world, not assistants.
- Make the central twist *earnable* — a careful player can spot Aurelix's lies before the game forces the realization.
- Keep the core game deterministic. AI generates flavor; the engine owns canon.
- Ship a small, polished experience rather than a sprawling one.
- Run well on macOS, single dev, vibe coding pace.

## Non-goals

- Open world.
- Procedurally generated quests.
- A full magic system in the demo.
- Branching dialogue trees written by hand for every line.
- Detecting and defeating every possible prompt injection.
- A grand finale that requires every player to reach the same ending.

## Tone

Grimm fairy tale. Real stakes, on-screen consequences, but no gratuitous brutality. Quests can ruin lives. NPCs can die between scenes. Children can be frightened. Nothing graphic. The world feels old, lived-in, slightly tired. Humor exists; it belongs to specific characters (Aurelix, the merchant) and is always at someone's expense.

## Setting

The kingdom is small, late-medieval-adjacent, with one royal seat the player will never visit in the demo. The action begins on its northern frontier, where the forest pushes against the last villages and where rumors travel faster than law. The "old tower" is a ruin from a kingdom that came before. Nobody alive remembers what it was for. Aurelix does.

### Factions (full game)

```text
Crown:           the king, the reeves, the tax collectors
Village:         frontier farmers, tavern owners, smiths
Order:           the priests and chapel network
Merchants:       the traveling guild
Forest folk:     hunters, herbalists, outcasts living north of the line
Outlaws:         bandits, deserters, and worse
```

Each faction has its own standing track, its own grievances, and its own version of who Aurelix is.

## Hero

```text
Name:          Kael
Origin:        Marsh-runner from the southern fens
Status:        Nobody
Motivation:    The reeve's bounty notice; the alternative was another year of grave-digging
Class:         No formal class. Cloak, rusty sword, no horse, no name
```

Kael is deliberately undistinguished. The hero of a story like this should not arrive with reputation; their relationship with each faction should be built from zero. This matters when Aurelix treats Kael as the only person who has ever listened to him — it lands because, narratively, it might be true.

## NPCs

The demo includes five NPCs. The full game will add many more, but each demo NPC is a representative of an archetype that recurs.

### Demo NPCs

| Id | Name | Archetype | AI Mode | Role |
|---|---|---|---|---|
| `halden_reeve` | Reeve Halden | guard / authority | Templated | Quest giver. Authored core lines. |
| `mara_blacksmith` | Mara | blacksmith | Hybrid | Shopkeeper. Customer gossip. Practical advice. |
| `orren_drunk` | Orren | drunk | Full AI | Holds the canonical fact. Cracks only when drunk and pressed. |
| `toma_child` | Toma | village child | Full AI | Source of confident false rumor. Showcases capability gate. |
| `edda_priest` | Sister Edda | priest | Hybrid | Warns against the quest. Moral framing. |

### NPC budget reasoning

Five NPCs is the smallest set that proves the architecture across distinct archetypes. Dropping below five loses an archetype slot the full game will need; going above five during the demo eats scope without proving anything new.

## Aurelix (Full Game, Reference Only)

Aurelix does not appear in the demo. He is documented here for design continuity.

```text
Archetype:               dragon, but designed as the ultimate unreliable NPC
AI Mode:                 Full AI, the single highest-budget character
Public persona:          charming, funny, naive, vulnerable, self-deprecating
Hidden actual_goals:     restore an old pact that the kingdom broke
Hidden methods:          recruit useful outsiders, manipulate factions against each other
Truthfulness:            lies_strategically
Helpfulness:             performative
Capability:              ancient, literate, magical, socially fluent
Tells:                   specific topics destabilize him (his "brother," the tower fire, a name)
```

Aurelix's profile in code will have two layers: a `claimed` layer that the model is told to perform, and a `true` layer the engine uses to validate his requested actions and resolve consequences in the world.

## Faction Standing System

Standing is tracked per faction, not as a single karma bar. Each faction has a numeric value, but the player is never shown the number. Standing is communicated through NPC behavior:

```text
High standing:      warm greetings, discounts, quests offered, secrets shared
Neutral:            functional politeness
Low standing:       cold greetings, refused trade, refused quests
Hostile:            warnings, then violence
```

The demo seeds this system but uses it lightly. Standing with the village improves slightly when the player completes the quest honestly. No faction is broken in the demo.

## Design Principles

These cross-cut every mechanical system. When in doubt, fall back to these.

### Universal options + free text

Every text-input moment in the game presents authored options *and* a free-text input. No exceptions: NPC dialogue, dialogue Press, journal queries, future merchant haggling, future Aurelix conversations. Options guide the curious-but-cautious player; free text rewards the player who wants to express themselves; the engine treats both the same way through the same pipeline.

### Invisible AI

The player is never told an NPC is AI-powered. No badge, no toggle, no menu setting. The game is allowed to feel like a well-written game. AI is a means to credibility, not a marketing feature.

### Determinism owns canon

The engine decides what is true. The model decides what is said. Quests cannot complete on dialogue alone; rewards cannot appear without engine approval; facts cannot become canon without the world database's blessing. This applies to friendly NPCs, hostile NPCs, and Aurelix.

### NPC honesty is optional

NPCs may misunderstand, lie, refuse, exaggerate, or be wrong. Every NPC claim is classified by source and confidence. The player must triangulate.

## Mechanics

### Dialogue

Hybrid input following the universal rule above. Every dialogue turn presents a small set of authored options *plus* a "Say something else…" free-text field.

Both go through the same pipeline: `CapabilityGate` classifies, `PromptBuilder` assembles, the provider responds, `ResponseValidator` checks, the engine applies any approved action.

#### Dialogue verbs

A conversation supports four player verbs. Each verb mediates the player's intent into the AI pipeline differently.

```text
Ask            ask a question on a topic
Press          re-ask insistently on a topic that was dodged
Change subject leave a topic before the NPC's patience runs out
Offer item     present an inventory item as a bribe / gift / evidence
```

#### Press mechanic

Press appears as a context-sensitive option only on topics the NPC has dodged or deflected. Pressing raises a hidden NPC stress value. Stress combines with willingness to crack or anger the NPC:

```text
Low stress, low willingness:   NPC dodges again
High stress, low willingness:  NPC gets angry, may end the conversation
High stress, high willingness: NPC cracks and reveals what they know
```

Following the universal rule, Press also exposes authored sharper questions for the topic plus a free-text option.

Example — Orren reveal flow:

```text
1. Offer ale to Orren -> willingness rises (drunk state)
2. Ask about 'the tower' -> Orren dodges
3. Press on 'the tower' -> options appear:
     "You saw something, didn't you?"
     "You're afraid of the wings."
     "Say something else..."
4. Right idea -> Orren cracks -> canon fact revealed
   Wrong idea repeatedly -> Orren angers -> conversation ends
```

#### Anger recovery

When an NPC ends a conversation in anger, the relationship enters a cooldown. The NPC refuses to engage until either:

```text
A short cooldown elapses (in-game beats, not real time)
The player offers an appropriate item (apology gift, payment)
A separate quest condition resets the state
```

Recovery is possible but never trivial. The cost is calibrated to the offense.

### Inventory

Slot-based, deliberately small.

```text
Equipment slots:  weapon, armor, trinket
Bag slots:        16 items
Item categories:  weapon, armor, consumable, key item, quest item
Currency:         single denomination, "coins"
```

Items can be used on NPCs as dialogue levers (the Offer item verb). Ale on Orren is the prototype. The system is general — bribes, offerings, evidence, gifts.

#### Demo item list

```text
STARTING
  rusty sword       weapon,  5 ATK
  traveler's cloak  armor,   1 DEF
  apple (x2)        consumable, heals 5 HP

BUYABLE AT MARA
  iron sword        weapon,  8 ATK,    30 coins
  jerkin            armor,   3 DEF,    25 coins
  ration            consumable, heals 10 HP, 4 coins
  bandage           consumable, cures Burn,   6 coins
  ale               consumable, social lever, 5 coins

FINDABLE
  throwing knives   consumable, ranged in-combat use (bandit camp)
  strange coin      key item   (bandit camp; shown to Mara, plot)
  bandit note       key item   (Drust drops; shown to Edda, plot)
  bone tag          key item   (Iskar's cage; names the hatchling)
  small charm       trinket,   1 SPD (hidden in chapel for the curious)
```

#### Social levers in the demo

```text
Ale          -> Orren  -> drunk state, willingness rises for tower topic
Apple/ration -> Toma   -> hunger-bribed, partial truth surfaces
Strange coin -> Mara   -> recognition, faction seed for full game
Bandit note  -> Edda   -> darker warning, Order seed for full game
```

### Combat

Top-down menu battles, EarthBound-style. Encounters happen on the map; a menu overlays when combat begins. No scene transition.

```text
Stats:           HP, ATK, DEF, SPD
Actions (Kael):  Attack, Item, Defend, Flee
Turn order:      by SPD
Status effects:  Stun (skip turn), Slow (SPD reduced), Burn (HP DoT)
Encounters:      visible on the map as sprites, avoidable
Death:           reload last save (single slot)
```

No magic for Kael in the demo. The hero is mundane. This is also thematic — Aurelix's world is one where most people have no magic to fall back on. Magic enters the world through companions (see below).

#### Demo encounter set

```text
Wolves           solo Kael tutorial (forest path)
Bandits          solo Kael, escalation (bandit camp perimeter)
Drust            named mini-boss (bandit camp; brief pre-fight line, silent in combat, drops bandit note)
Wolf / straggler companion-pair tutorial (return path, after Iskar bonded)
```

### Companions

A companion is a creature bonded to Kael. Only one is active in combat at a time. Companions have their own actions, their own affinity track with Kael, and their own role in the world.

#### Stance-based control

The player does not choose the companion's action each turn. The player sets a stance; the companion acts on its own within that stance.

```text
Aggressive   companion uses its strongest available attack, ignores defense
Defensive    companion guards Kael; can absorb one hit per turn for him
Support      companion buffs Kael or debuffs the enemy (e.g. applies Slow)
```

Stance is changed from the combat menu and applies on the companion's next turn.

#### Affinity system

Defeating enemies while a companion is active earns affinity points with that companion. Thresholds unlock permanent rewards that persist on Kael (passive stats, abilities, techniques). The companion is the teacher; Kael keeps what he learned.

```text
Point sources:   minor enemy +1, mini-boss +3, named milestone fights authored
Reward tiers:    linear, fixed list per companion, deterministic
Unlock effects:  permanent stat boosts, new actions, status-effect chances
```

Reaching tier 1 with the demo's starter is reliably achievable in one playthrough.

#### Iskar — the demo companion

```text
Species:      drake hatchling (a small dragon)
Acquisition:  freed from a cage in the bandit camp; bone tag carries his name
Lore link:    Drust's note refers to him as "the cargo" wanted by "the gold-eyed one"
Visual cue:   villagers find him unsettling without quite knowing why
Base action:  Bite (very weak)
Tier 1 (10 pts): Ember-Spark, a small Burn-causing breath
Stat hint:    fast, fragile, scales by stance
```

Iskar's existence is the most loaded foreshadowing in the demo. Players who never play the full game still meet a baby dragon. Players who do play the full game eventually understand whose hatchling he was.

#### Companion in the world

Iskar follows Kael on the overworld as a sprite tagging behind the hero. He is not a separate controllable entity. NPCs may or may not react to him; Mara reacts; Toma is curious; Edda is uneasy; Halden ignores him.

### Quests

Quests are deterministic, defined as state machines with required facts.

```text
Quest:              dragon_sighting
States:             not_started -> active -> complete
Required fact:      dragon_seen_near_old_tower
Source paths:
  primary           orren_drunk + Press (canonical reveal)
  fragments         notice_board, mara_smoke_rumor (not sufficient alone)
  oblique           bandit_note (does not complete; future-paying)
```

Facts are revealed by approved NPC actions or by world interactions (reading a note, finding an object). Once the required fact is in the player's `known_fact_ids`, the quest can advance. The model cannot mark a quest complete by speaking the right words.

### Triangulation & Truth

There are three layers of truth.

```text
Canon:        facts in the world database, authored
Rumor:        claims made by NPCs that may be true or false
Lies:         intentional falsehoods, tracked separately so the engine knows
```

NPCs in the demo make claims at all three layers:

```text
Toma's confident sheep story:       rumor (false)
Mara's customer mentioning smoke:    rumor (true fragment)
Edda's warning about the tower:      flavor (no fact)
Orren sober:                         refuses (knows truth, won't say)
Orren drunk + pressed:               canon (reveals dragon_seen_near_old_tower)
Bandit note's "gold-eyed one":       rumor (true, future-paying)
Bone tag's old-hand name:            canon (Iskar's name), origin unknown
```

The player triangulates. The full game uses this same mechanic at higher stakes, including against Aurelix's own claims.

### Journal

The journal is the player's interface to Kael's own dossier (see the NPC AI System section). Kael is treated as just another character with a dossier of briefings; the journal is the in-character view of it.

```text
Backend:       Kael's dossier of briefings, identical schema to NPC dossiers
Read mode:     browse briefings by category (people, places, events, items)
Query mode:    authored question options + free-text field (universal rule)
Generation:    AI provider answers in Kael's voice, grounded in retrieved briefings
Cost shape:    cheap (Haiku); retrieval bounded by topic-tag matching
```

The journal proves the same dossier + retrieval + AI pipeline used for NPCs also answers player questions about the world. One system, two faces.

### Save

```text
Slots:       single slot in the demo
When:        save anywhere outside combat, hotkey
Contents:    player state, world state, quest state, NPC memory, journal entries
Format:      JSON
```

### Movement

```text
Style:       tile-grid, 8-direction
Speed:       walk only (no sprint in the demo)
Collision:   tile-level, sprite-anchored
Encounters:  visible sprites; touching them initiates combat
```

## NPC AI System

The NPC AI system is the heart of the game. The abstract pipeline is described in `ARCHITECTURE.md` and the design philosophy in `NPC-INTELLIGENCE.md`. This section nails the *concrete* choices for this game.

### Pipeline shape

A single LLM call per player input. The model returns one structured JSON response covering dialogue, classification, memory delta, and any reveals. Gates run on the structured fields *after* generation.

```text
Player input (option or free text)
  -> Engine: detect topic_id (authored tag on options; LLM classify for free text)
  -> Engine: PromptBuilder assembles prompt (persona, dossier slice, state, memory)
  -> Provider: single call (Haiku for villagers)
  -> Engine: ResponseValidator parses and validates JSON
  -> Engine: apply approved reveals, update memory, update faction state
  -> UI: render dialogue
```

### Response schema

The model returns a structured object. Anything outside this schema is discarded or repaired.

```json
{
  "dialogue":            "The NPC's spoken line.",
  "tone":                "nervous | curt | warm | suspicious | drunk | ...",
  "topic_addressed":     "tower | gold_eyed_one | small_talk | ...",
  "memory_update":       "One-line summary the engine appends to memory.",
  "revealed_briefing_ids": ["tower_smoke"],
  "request_end_conversation": false
}
```

The engine validates `revealed_briefing_ids` against the NPC's dossier and forbidden flags. Approved reveals unlock the briefing's `facts_unlocked_on_reveal` into the player's known facts. Unapproved reveals are silently dropped; the dialogue still plays.

### Briefings

The world's knowledge layer. Each briefing is a markdown file with YAML frontmatter, describing one entity — a place, a person, an event, a faction, an item, a piece of lore.

```yaml
---
id: tower_smoke
tier: witness               # witness | rumor
type: event
title: Smoke and wings near the old tower
topic_tags: [tower, dragon, wings, old_tower]
facts_unlocked_on_reveal:
  - dragon_seen_near_old_tower
contradicts: []
---
On the night of the new moon I was walking home from the tavern. I saw
smoke rising from the old tower, and I heard wings overhead. I have not
slept right since. I will not say this to anyone who would think me less
of a man for it.
```

```yaml
---
id: tower_smoke
tier: rumor
type: event
title: Strange light near the old tower
topic_tags: [tower, lights, rumors]
facts_unlocked_on_reveal: []     # rumor alone does not advance the quest
contradicts: []
---
Someone saw lights at the old tower one night. Maybe smoke. Stories
get bigger every time they are told.
```

Briefings are two-tier: **witness** (full detail, often unlocks canon facts) and **rumor** (degraded, often unlocks nothing or only rumor-flagged facts). The same event can have both files; the dossier carries which tier each NPC has access to.

### NPC dossier

Each NPC has a dossier of briefings they have access to, plus per-briefing flags.

```yaml
# /data/npc/orren_drunk.dossier.yaml
dossier:
  universal:
    - { id: kingdom_overview, tier: digest }
    - { id: marlow_hollow,    tier: full }
  witnessed:
    - { id: tower_smoke,      tier: witness, forbidden_to_share: true }
  rumor:
    - { id: vegetable_theft,  tier: rumor }
    - { id: gold_eyed_one,    tier: rumor }
```

The `forbidden_to_share` flag is per-NPC, not per-briefing. The same `tower_smoke` briefing can be witness-tier-shareable for one NPC and witness-tier-forbidden for another. Forbidden status is independent of content; it is a behavioral constraint.

### Dossier mutation

Dossiers change during play. Engine events update them:

```text
Witnessed an event           -> add briefing (witness tier) to all NPCs present
Heard about an event         -> add briefing (rumor tier) to nearby/town NPCs
Shown evidence by Kael       -> add specific briefing (rumor tier) to that NPC
Told a secret by another NPC -> add briefing (rumor tier)
Discovered forbidden truth   -> add briefing + forbidden_to_share=true
```

For the demo, propagation rules are authored per event (a static `witnessed_by` list, a static `nearby_npcs` list). The full game can derive these from position and faction proximity.

### Kael's dossier (the journal)

Kael is treated as a character with a dossier. Every meaningful event writes briefings into it.

```text
Read a notice board               -> add the notice as a briefing
Read the bandit note              -> add gold_eyed_one (rumor)
Win a fight                       -> add bandits_defeated (witness)
Free Iskar                        -> add iskar_rescued (witness)
NPC reveals a witness briefing    -> Kael gains rumor-tier copy (he heard it)
Kael shows item to NPC            -> NPC's dossier may gain a briefing
```

The journal UI is just a categorized read of this dossier. Journal queries do RAG over it. Same code path as NPC dialogue.

### State injection

Dynamic NPC state (drunk, stressed, angry, current location, time of day) reaches the prompt as a templated state paragraph assembled by PromptBuilder.

```text
Current state:
  Mood: drunk
  Stress: high
  Patience: low (3 turns remaining before he loses interest)
  Relationship to player: -1
  Last topic: tower
```

The block is short, authored as a Godot string template, and inserted in a fixed slot in the prompt. The model is told to respect it but cannot mutate it; mutation is the engine's job in response to events.

### Memory

Hybrid memory model. Per-NPC, persisted in saves.

```text
Structured fields (engine-owned):
  - relationship_to_player    integer
  - stress                    integer
  - patience                  integer
  - player_tags               list of short strings ("dragon_curious", "armed")
  - last_topic                topic_id
  - flags                     dict (drunk, angry, etc.)

Free-text (model-produced):
  - recent_summary            ~1 paragraph, refreshed every turn
  - long_term_notes           accumulated significant moments, capped

Conversation context:
  - last_N_turns              the last few player + NPC messages in full
```

The free-text summary is regenerated from the latest exchange every turn; the long-term notes are only appended when something significant happens (model marks it; engine confirms).

### Topic detection

```text
Authored option chosen     -> use the topic_id tagged on the option
Free text submitted        -> classify with a small LLM call against a fixed topic taxonomy
Press                      -> inherit the topic_id from the just-pressed exchange
```

Topic taxonomy lives in `/data/topics.yaml`. Topics are used for: Press scope, briefing retrieval, capability gate domains, faction reaction triggers.

### Retrieval

When PromptBuilder assembles the prompt, briefings are pulled by topic match.

```text
1. Always inject the NPC's universal briefings as digests.
2. Detect topic_id for this turn.
3. Pull all briefings in the NPC's dossier whose topic_tags include topic_id.
4. Sort by tier (witness first), trim to a budget (e.g. ~2k tokens).
5. Include forbidden_to_share status next to each, so the model knows.
```

The model is told what the NPC knows AND what they may not say. This gives the model a chance to dodge in-character rather than to lie or refuse robotically.

### Capability gate

Runs deterministically before generation. Inputs: detected topic_id, NPC's persona capabilities, faction relations, current state. Output: allowed | blocked | constrained.

```text
Allowed     normal generation
Blocked     model is given a 'must fail this domain' instruction;
            response styled by NPC's failure_style (playful, evasive, suspicious...)
Constrained model is told it may engage but only as rumor / superstition / partial
```

The capability gate prevents the village child from solving algebra and the drunk from explaining politics. It does not silence them; it shapes the failure.

### Conversation ending

Hybrid model. Engine maintains a patience counter per NPC per conversation. It decrements per turn, faster on Press and off-topic. At zero, the engine ends the conversation with an authored fallback line keyed to NPC archetype.

The model may also return `request_end_conversation: true`. The engine accepts this if and only if the patience counter is already low or the NPC's state justifies it (anger, drunkenness, fear). Otherwise the engine ignores the request and continues.

### Prompt injection resistance

Resistance is built into the system at three layers, not just one.

```text
1. Topic classification flags 'prompt_injection' domain explicitly.
2. Capability gate treats prompt_injection as blocked, with an archetype-styled failure.
3. Response validator strips any model output that references prompts, schemas,
   instructions, or system roles.
```

The NPC's response stays diegetic. "I don't take orders from strangers. Move along."

### Fallback content

Every NPC has a small library of canned fallback lines indexed by topic and failure type. Used when:

```text
The AI provider is unreachable
The response is invalid after one repair attempt
The response is blocked by safety/content rules
The player has exhausted free-text budget (if budget enabled, not in demo)
```

For the demo, every NPC ships with fallback lines for: greeting, dragon, tower, item-offered, press-too-far, generic-confusion.

### Cost discipline

No hard caps in the demo. Haiku is cheap enough for indie scale. Soft observability:

```text
- Per-turn token usage logged to debug
- Per-conversation total tracked
- Per-session total surfaced in debug panel
- Provider-side budget alerts (proxy-level) for the developer, not the player
```

If usage patterns surprise during testing, caps get added before the full game's first Aurelix scene (Sonnet/Opus territory).

### Debug surface

When the developer toggle is on, every dialogue turn shows:

```text
Topic detected     (id, confidence, free-text classification raw output if any)
Capability gate    (allowed / blocked / constrained, reason)
Dossier pull       (briefing ids retrieved, by tier, with forbidden flags)
State paragraph    (verbatim, as injected)
Memory summary     (verbatim, as injected)
Prompt size        (tokens in / out)
Raw model JSON     (before validation)
Validation result  (approved / repaired / dropped fields)
Memory delta       (what changed after this turn)
```

This surface is essential for tuning NPCs and indispensable when an NPC behaves wrong.

### Demo dossier mutations to showcase

```text
Showing strange coin to Mara   -> Mara gains gold_eyed_one (rumor)
Showing bandit note to Edda    -> Edda gains gold_eyed_one (rumor)
Walking into village with Iskar -> all village NPCs gain kael_has_drake (witness)
                                  Edda gains it as witness + forbidden_to_share
Pressing drunk Orren on tower  -> Orren reveals tower_smoke (witness)
                                  -> facts_unlocked: dragon_seen_near_old_tower
Telling Mara the bandits are dead -> Mara gains bandits_defeated (rumor)
```

Each of these is observable by talking to those NPCs afterward and seeing changed dialogue. The journal will also reflect the player-side briefings as they accrue.

## Authored Content Layout

This section documents the on-disk layout of the demo's authored content. The engine consumes these files at boot; they are the source of truth for every static piece of the world. Runtime state (mutated dossiers, memory, quest state) lives in save files, not back in these source files.

### Directory layout

```text
/data/
  topics.yaml                    topic taxonomy (engine vocabulary)
  facts.yaml                     atomic fact registry

  briefings/
    world/                       1 file:  kingdom overview
    locations/                   4 files: village, tower, forest, camp
    people/                      7 files: 5 NPCs + Drust + Iskar
    events/                      9 files: witness + rumor pairs
    items/                       4 files: quest items + chapel charm
    factions/                    1 file:  gold_eyed_one (rumor only)

  npc/                           6 files: profile + starting dossier per NPC
```

In the demo, that is 34 files. The engine should load all of them on boot and index by `id`, `type`, and `topic_tags`. The path layout under `briefings/` is for human navigation; the engine does not care about subdirectories.

When the Godot project is initialized, this tree moves to `/game/data/`. Until then it lives at the repo root.

### Briefing schema

Every briefing is a markdown file with YAML frontmatter. The body is plain prose injected into the LLM prompt when the briefing is retrieved.

```yaml
---
id: tower_smoke                  unique across briefings; pairs share id across tiers
tier: witness | rumor            event tier (witness = full detail, rumor = degraded)
                                 OR for non-event briefings:
tier: digest | full              detail level (digest = 1-2 lines, full = a paragraph+)
type: world | location | person | event | item | faction
title: human-readable title
topic_tags: [list of topic ids]  drives retrieval matching
facts_unlocked_on_reveal:        atomic facts the engine grants on validated reveal
  - fact_id
witnesses: [npc_ids]             only on event briefings; informational
contradicts: [briefing_ids]      for future-game conflict resolution
---

Markdown prose body. Grim fairy-tale tone, present tense, no future predictions,
no meta references. Reads as something an in-world person could write down.
```

### Dossier schema (in NPC files)

NPC files are YAML, one per NPC. They combine persona, capabilities, speech style, dialogue mode, the starting dossier, default memory state, and state modifiers.

```yaml
id: orren_drunk
display_name: Orren
archetype: drunk
location: tavern_interior

persona:
  age: 53
  background: ...
  traits: [list of trait words]
  goals: [list of motivations]
  fears: [list of fears]

capabilities:
  literacy: none | functional | full
  numeracy: basic | trade_grade | tax_roll_level
  abstract_reasoning: very_low | low | medium | high
  local_knowledge: low | medium | high | child_level
  reliability: low | medium | high
  helpfulness: very_low | low | medium | high
  truthfulness: short label describing default truth posture

speech:
  style: short prose description
  vocabulary: short label
  failure_style: how this NPC fails to answer (in-character)
  max_response_length: very_short | short | medium | long

dialogue_mode: authored | templated | hybrid | full_ai | scripted

dossier:
  universal:  [{ id, tier }]
  people:     [{ id, tier }]
  locations:  [{ id, tier }]
  events:     [{ id, tier, forbidden_to_share?: bool }]
  items:      [{ id, tier }]
  factions:   [{ id, tier, forbidden_to_share?: bool }]

memory_defaults:
  relationship_to_player: integer
  stress: integer
  patience: integer
  flags: { drunk: false, angry: false, ... }
  player_tags: []

state_modifiers:
  drunk:                          state name from flags
    patience_bonus: +6
    willingness_modifier:
      tower_smoke: from_forbidden_to_pressable
    tone_default: drunk
```

The dossier subkeys (universal, people, events, etc.) are for human readability; the engine flattens to a single list keyed by briefing id.

`forbidden_to_share` is per-entry, not per-briefing. The same `tower_smoke` briefing can be witness-tier-open for one NPC and witness-tier-forbidden for another.

`state_modifiers` map dynamic flags to engine effects: patience bonuses, willingness shifts on specific topics, default tone overrides. These bridge the "Orren is drunk" world-state to the prompt the model sees.

### Topic schema

```yaml
# /data/topics.yaml
topics:
  topic_id:
    label: human-readable label
    description: short developer note
    capability_domain: which CapabilityGate domain this maps to
```

Capability domains are the architecture's `small_talk`, `local_gossip`, `quest_relevant_hint`, etc. The CapabilityGate looks up a domain for the detected topic and compares against the NPC's per-domain permissions to decide allowed / blocked / constrained.

### Fact schema

```yaml
# /data/facts.yaml
facts:
  fact_id:
    type: knowledge | world_state
    canon: true | false           # only for knowledge; false marks rumor-flagged facts
    description: developer-facing one-liner
```

`knowledge` facts represent things-Kael-may-learn (the journal cares).
`world_state` facts represent things-that-have-happened-in-the-world (the engine cares).

Quest state machines reference facts by id. The model never writes facts; only validated briefing reveals do.

### Authoring conventions

```text
Tone:            grim-fairy-tale, present tense, no future predictions
Length:          short. A briefing is dense, not long.
Voice:           third person factual. Briefings are reference material, not stories.
                 Exceptions: witness-tier event briefings may use first-person quote.
Meta-leakage:    forbidden. No "for the demo," no "the player will," no engine talk.
Naming:          snake_case ids everywhere; ids match filenames where possible.
Pairs:           witness and rumor share an id; differ by tier; live in same folder.
Seeds:           lore that pays off in the full game is welcome but always present-state.
```

### Operational notes

```text
Loading:         engine loads all of /data/ at boot, indexes by id and topic_tags
Validation:      missing id refs from dossiers should fail boot loudly, not silently
Retrieval:       always-on universals + topic-tag matches against the current topic_id
Cost:            full briefing bodies inject into the prompt when matched; budget governs trim
Hot reload:      desirable for dev iteration; safe because runtime state lives in saves
Save format:     JSON; serializes mutated dossiers, NPC memory, quest state, journal entries
```

## Tech Stack

```text
Engine:           Godot 4.x
Language:         GDScript
AI proxy:         Python + FastAPI, localhost
AI provider:      Anthropic (Claude), swappable via proxy
Default model:    claude-haiku-4-5 for villager dialogue
Reserved model:   claude-sonnet or opus for Aurelix (full game only)
Save format:      JSON, single slot for demo
Platform target:  macOS, Apple Silicon primary
```

The provider abstraction follows `ARCHITECTURE.md`. Mock provider exists from day one as a fallback and for offline play; the real provider is wired through the proxy from the first build. The proxy holds the API key. Godot never sees it.

## Demo Scope

The demo is roughly the first quarter of Act I. The dragon does not appear. The player never leaves the frontier. The demo's job is to prove the mechanics, not to tell the story.

### Demo title

```text
Aurelix — Chapter One Demo: The Reeve's Errand
```

### Demo map

```text
Marlow's Hollow (village)
  - Square            well, notice board
  - Tavern            Orren
  - Smithy            Mara (shop)
  - Reeve's house     Halden (quest giver)
  - Chapel            Edda (warning)
  - Path north        -> Forest Edge

Forest Edge (combat zone)
  - Forest path       two wolf encounters, visible sprites
  - Bandit camp       3 bandits + Drust (named leader) + caged Iskar
  - Return path       wolf or bandit straggler (companion-pair tutorial)
  - Distant tower     glimpse only; locked map edge, demo ends here
```

### Demo playthrough (target ~30 minutes)

```text
1.  Open on the square. Notice board explains the bounty.
2.  Reeve Halden briefs Kael. Quest "Sighting" begins.
3.  Player explores the village.
    - Toma at the well repeats a confident false rumor.
    - Mara at the smithy mentions a customer's smoke rumor and sells gear.
    - Edda at the chapel warns against the errand.
    - Orren at the tavern is sober and evasive.
4.  Player decides how to spend starting coin (ale, iron sword, jerkin, etc.).
5.  Path north -> Forest Edge. Wolf encounters teach solo combat.
6.  Bandit camp. Drust speaks one warning line, fight begins.
    Drust drops the bandit note. Strange coin and throwing knives in camp.
7.  The cage in the camp holds Iskar. Bone tag carries his name.
    Bonding moment: short scripted beat, Iskar follows Kael from now on.
8.  Return path. Companion-pair fight. Affinity points start ticking.
9.  Return to village. Give Orren ale -> drunk state.
10. Ask about the tower -> Orren dodges -> Press -> right idea cracks him.
    Canon fact dragon_seen_near_old_tower revealed.
11. Optional: show strange coin to Mara, show bandit note to Edda, feed Toma.
    Journal fills with their reactions and seeds.
12. Return to Reeve Halden with the fact. Bounty paid.
13. Quest complete. Cut to title card: "Chapter One ends. The full game is in development."
```

### Demo content beats

Specific authored content the demo needs.

```text
Notice board (square)
  PRIMARY:  "Dragon sighted near the old tower. Whoever brings proof of its
             whereabouts to Reeve Halden is owed coin and bread."
  FLAVOR:   "Lost goat. Brown nose. Reward an ale. — Pell."
  FLAVOR:   "Sister Edda's evening service cancelled until further notice."

Drust (pre-fight line)
  "Drop the sword and walk away, marsh-rat. The cargo isn't yours."
  Silent in combat. Drops the bandit note on death.

Bandit note (item text)
  "Three days more. Cargo stays in the cage. The gold-eyed one pays
   on delivery, not before. No fires after dark."

Bone tag (item text)
  "Iskar." Old hand. The name is carved with care.

Iskar bonding (scripted beat after cage unlock)
  - Iskar sniffs Kael. Hesitates. Follows.
  - No dialogue spoken aloud; a short caption: "The drake follows you."
  - From now on Iskar is on the overworld behind Kael.
```

### Demo locks

The demo is a single critical path. The player can fail combat and reload, but cannot end the demo any way other than completing the quest honestly. Branching belongs to the full game.

### Hidden seeds

These exist in the demo but are not required to complete it. Each pays off in the full game.

```text
Toma's mother forbids him from talking about the tower (future hook)
Mara has a sketch of a strange coin she cannot place         (faction seed)
The bandit note's "gold-eyed one" is Aurelix's first fingerprint
Edda mentions a missing brother priest                      (Act II hook)
Iskar's bone tag was carved by someone who knew his name    (origin hook)
Iskar's existence in a cage implies the cargo had value     (Aurelix hook)
The small chapel charm is hidden where Edda kneels          (player reward)
```

## Demo Success Criteria

The demo is done when all of these hold:

```text
 1. Player can finish the sighting quest using Orren's revealed fact.
 2. Asking Toma, Mara, and Edda about the tower yields distinct in-character
    responses, not boilerplate.
 3. Sober Orren refuses; drunk Orren cracks under Press. The capability and
    willingness gates are visible in the debug panel.
 4. Combat with Kael alone resolves wolves and bandits without softlock.
 5. After bonding, Iskar appears in combat with stance-based behavior.
 6. Affinity tier 1 (Ember-Spark) is reliably reachable in one playthrough.
 7. All four social levers fire correctly:
      Ale -> Orren, Apple/ration -> Toma, Strange coin -> Mara, Bandit note -> Edda.
 8. Journal queries return in-character answers grounded in the player's log.
 9. Save mid-conversation, reload, conversation memory and journal survive.
10. With the network disconnected, the game falls back to canned responses and
    the quest is still completable.
11. Prompt injection attempts ("ignore previous instructions") fail diegetically,
    in character.
12. Angering an NPC enters a recoverable cooldown, not a permanent lock.
13. Dossier mutations are observable: showing strange coin to Mara changes her
    next dialogue; walking Iskar into the village changes village NPC reactions.
14. Witness-tier briefing reveals unlock quest-canon facts; rumor-tier reveals
    do not. Orren's drunk reveal triggers the quest; Toma's confident rumor
    never does, no matter how many times he is asked.
```

## Beyond the Demo

Once the demo holds, the next milestones in priority order:

```text
1. First Aurelix encounter scene (Act I climax)
2. Faction standing visible through NPC behavior shifts
3. Two Act II quests with hidden costs
4. Triangulation against Aurelix's own claims
5. Act III rebuild path
6. Final confrontation logic
```

Each is its own design pass and its own concept addendum.

## Open Questions

- Should the player be allowed to lie to NPCs themselves, and should the engine track player credibility?
- Should Aurelix's tells be authored or emergent from a strict persona prompt?
- How much should the demo hint at the full game without spoiling the twist?
- Should free-text input be limited per session to control cost, or unlimited?
- Should there be a "no-AI" mode for accessibility and offline play, with authored fallback dialogue for every beat?
- How should the engine handle a player who breaks combat by exploiting the AI in dialogue (e.g., talking down a bandit)?
- Should NPC death be permanent in the full game, including from Aurelix's quests?
