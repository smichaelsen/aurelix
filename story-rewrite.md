# Story Rewrite — Demo Coherence Pass

Source of truth for the new demo storyline and its three-screen
implementation plan. Supersedes the playthrough beats in
`CONCEPT.md §Demo playthrough` and `context/project-overview.md
§Core User Flow` where they disagree. `CONCEPT.md` remains canonical
for theme, full-game arc, and architecture rationale.

## Why this exists

The previous demo arc read as four disconnected beats: a notice
board claiming a confirmed dragon, a bribed witness with vague
hints, a robbery backstory with no payoff, and a bandit hideout
holding a hatchling. The quest could turn in after the camp alone,
making the Press mechanic — the demo's marquee feature — feel
optional and the "small dragon" reveal land as anticlimax instead
of revelation.

This rewrite stitches the threads together: the notice board, the
sheep, and the robbery are **one suspicion**. The bandit camp is
the click. The Press reveal earns the demo's biggest information.
The demo ends with the player wondering about bigger beasts.

## Through-line

> The reeve fears a dragon. The player finds something smaller —
> and something larger behind it. The "dragon" people panic about
> is a caged hatchling; the real threat is the man who wanted it
> caged. The demo ends with the player holding the leash of a
> creature whose owner is still out there.

## Story arc (~30 minutes)

### 1. Hook — Notice Board

Soften the board. Don't overclaim what we can't confirm.

> **By order of Reeve Halden**
> Strange sightings near the old tower. Smoke. Wings. Livestock
> missing. Whoever brings a credible witness account is owed coin
> and bread.

### 2. The Brief — Halden

Halden lays out **three threads as one suspicion**:

1. Three weeks ago — smoke from the old tower.
2. Two weeks ago — sheep going missing along the north road.
3. Five nights ago — Pell's barn robbed. Not bread, not coin.
   **Chains. A cage. A heavy tarp.**

> "The council won't act on rumor. Bring me a man who *saw* it,
> and I'll pay. Anything less and we keep losing sheep."

The robbery is no longer orphaned backstory. It's the third leg
of the same stool. Someone prepared to catch something.

### 3. Village — Triangulation

Each NPC carries one thread of the same mystery. Player learns
NPCs disagree.

- **Toma (well)** — confident lie. Saw a dragon eat a whole
  sheep. Detail-rich, wrong. *Apple* makes him drop the act
  partway: he didn't see anything, but adults listen when he
  says "dragon." Teaches *Offer item*; teaches that NPCs lie.
- **Mara (smithy)** — sells gear. Mentions a stranger paid in a
  **strange coin** she didn't recognize. And: *"A man named
  Drust bought heavy chains off me three weeks back. Said it
  was for a bear pit. There aren't any bears."* Quietly
  connects Pell's robbery to the bandit camp.
- **Edda (chapel)** — moral weight. Won't bless the errand.
  *"The tower is older than the kingdom. My brother went there
  a year ago. He hasn't come back."* Seeds Act II.
- **Orren (tavern, sober)** — flat refusal on the tower. Talks
  about anything else. Teaches: some doors stay shut until you
  bring leverage. Press does **not** appear yet.

### 4. Decision — Tower Door Is Locked

Player can't get into Orren without leverage. Path north is the
way forward. The game teaches by closing off the wrong order.

### 5. Forest — Solo Combat

Two wolf encounters. Teaches HP, ATK, Item, Flee.

### 6. Bandit Camp — The Click

Drust pre-fight:

> "Drop the sword and walk away, marsh-rat. The cargo isn't yours."

Fight. Loot the camp:

- **The cage** — Pell's chains, Pell's tarp. The robbery was prep.
- **Bandit note**: *"Three days more. Cargo stays in the cage.
  The gold-eyed one pays on delivery, not before."*
- **Strange coin** — same as Mara mentioned.
- **Iskar** — drake hatchling. Bone tag with his name, carved by
  someone who knew him.

The click: **the dragon everyone fears is a child, and someone
was trying to keep him.** The player's question shifts from *is
there a dragon* to *who wants this dragon, and where did he come
from*.

Iskar bonds. Caption: *"The drake follows you."*

### 7. Return Path — Companion Tutorial

One straggler fight. Iskar earns first affinity. Tier 1:
Ember-Spark.

### 8. Back to Village — Visible Consequence

Walk in with Iskar at your heel. NPCs react (dossier mutation,
observable):

- **Toma**: dropped jaw. *"A real one."*
- **Mara**: *"Put it on a leash before someone with a crossbow
  sees it."*
- **Edda**: quiet horror. *"You brought it down from the tower.
  You should not have."*
- **Halden**: ignores the drake. Cares only about the fact.

Now Orren matters. Ale → drunk. Ask about the tower → still
dodges (drunk alone doesn't crack him; the press has to land).
Press appears. Authored angles:

> "You saw smoke and wings."
> "There was someone *with* it, wasn't there?"
> "Say something else…"

Right angle cracks him:

> "Smoke. Wings, yes. And a man. Stood under it like a man stands
> under a tree. Spoke to it soft. His eyes caught the fire wrong."

Grants `dragon_seen_near_old_tower` and seeds the gold-eyed one
as a person, not a bandit boss. The marquee mechanic earns the
demo's biggest piece of information.

### 9. Turn-In — Halden

Kael delivers the witness account. Halden reads the bandit note
in silence. Pays the bounty.

> "A man with the wrong eyes. I'll write it down. The council
> will still call it rumor."

Quest complete. **Resolution that doesn't resolve.** The player
got paid; the world didn't change.

### 10. The Hook — Edda's Closing

Edda intercepts Kael at the village edge before he can leave.
Looks at Iskar.

> "Whoever wanted him kept will come for him. And he will not be
> alone. My brother went up that tower for the same reason you
> came down it. Be quicker than my brother."

Title card: *Chapter One ends. The full game is in development.*

## What the player leaves wondering

- Who is the gold-eyed one? *(Aurelix's first fingerprint.)*
- Why was a baby dragon being trafficked? *(Implies older,
  bigger ones — and someone is collecting.)*
- What did Edda's brother find in the tower?
- Iskar's bone tag was carved by someone who knew his name.

---

# Implementation Plan — Three Screens

Each screen carries one teaching job + one story job. The current
codebase has `village_square.tscn` + `forest_edge.tscn`; split
forest into `forest_path` + `bandit_hideout` for clean save and
transition boundaries.

## Screen 1 — Marlow's Hollow (Village)

**Story job:** Set the world. Establish three threads as one
mystery. Lock the Orren door.
**Teaching job:** Movement, dialogue verbs, inventory, save,
journal.

### Layout

```
                    [Path north → Forest Path]
                            │
        ┌───────────────────┼───────────────────┐
        │   Chapel (Edda)              Tavern (Orren)
        │                                       │
        │           ░ Notice Board ░            │
        │              ░ Well ░                 │
        │             (Toma here)               │
        │                                       │
        │  Smithy (Mara)         Reeve House (Halden)
        └───────────────────────────────────────┘
```

Single open square. All five NPCs visible at once. Buildings are
facades; NPCs stand outside or in doorways.

### NPC placement

| Pos | NPC | First-visit role | Return-visit role |
|---|---|---|---|
| NW | Edda | Warns. Mentions missing brother. | Uneasy at Iskar. Delivers closing coda. |
| N | Notice board | Hook (hedged text). | — |
| Center | Toma (well) | Confident lie. Apple softens. | Awe at Iskar. |
| SW | Mara | Sells gear. Chains-to-Drust gossip. | Recognizes strange coin. |
| SE | Halden | Three-thread brief. Quest accept. | Accepts fact + bandit note. Pays. |
| E | Orren (tavern doorway) | Sober refusal on tower. | Ale → drunk → Press → cracks. |

### Mechanics introduced

1. Movement — tile-grid 8-dir, 4-cardinal facing. *Already done.*
2. Interaction prompt — [E] near NPC/object. *Already done.*
3. Dialogue box — authored options + free text. *Already done.*
4. Verbs taught organically:
   - **Ask** — every NPC.
   - **Change subject** — Toma's lie pushes you to leave the
     topic.
   - **Offer item** — apple to Toma is the cheapest, lowest-stakes
     teach. (Orren's ale waits until return.)
   - **Press** — does *not* appear yet. Orren refuses too cleanly
     to give the player a dodge to press on. Press is taught on
     return, when it matters.
5. Inventory + economy — Mara's shop. Buy from limited starting
   coin. Forces a choice.
6. Journal — [J] opens. Notice board auto-logs as first entry.
7. Save — [S] anywhere outside dialogue/combat. *Already done.*
8. Quest accept — Halden's brief writes `dragon_sighting:active`.

### Authored content to add/change

- Notice board: rewrite per story arc (smoke + wings + livestock,
  witness wanted).
- Halden first-brief: three-thread version (currently a single
  dragon line — needs full ~3-paragraph brief).
- Mara: new briefing `chains_for_drust` (rumor) — "sold heavy
  chains to a man named Drust three weeks back." Surfaces on
  `the_tower`, `bandits`, `strangers` topic.
- Toma: apple-softened authored line — partial truth, drops
  dragon claim.
- Edda: keep missing-brother seed on first visit. Add
  closing-coda beat (see below).
- Orren sober: ensure refusal is hard and clean. No Press option
  offered (no dodged topic → no Press, per existing rule).

### Engine changes

- `dragon_sighting` quest's `required_facts` stays
  `[dragon_seen_near_old_tower]`. *Do not* also gate on Iskar
  rescue — Halden takes Orren's witness as the qualifying proof.
- Add an authored item interaction on Halden after return: if
  `bandit_note` in inventory → he reads it → triggers his final
  "council will still call it rumor" line. Optional, non-blocking.

## Screen 2 — Forest Path

**Story job:** Transit + isolation. The world gets quieter. Sets
up the hideout without showing it.
**Teaching job:** Solo combat, encounter avoidance, item use.

### Layout

```
[Bandit Hideout ↑ (north exit)]
        │
        ░ tree    ░ tree
   ░ wolf-sprite
        │
        ░ tree     ░ tree
   ░ wolf-sprite   ░ rock
        │
        ░ tree
[Village ↓ (south exit)]
```

Single vertical corridor with trees as soft walls. Two visible
wolf sprites on the way up. On the way down (after Iskar
bonded), one straggler sprite (wolf or stray bandit) spawns in
the middle.

### Mechanics introduced

1. Visible encounter sprites — touchable, avoidable.
2. Combat overlay — menu battles, no scene transition. *Done.*
3. Solo combat verbs — Attack, Item, Defend, Flee. *Done.*
4. HP carry-over — PartyHealth persists. *Done.*
5. [H] quick-heal + heal toast — *Done.*
6. Bandage cures Burn — saved for the return trip after
   Ember-Spark exists.

### Return-trip mechanics

7. Companion in combat (stance) — Aggressive / Defensive /
   Support. Iskar acts on its own.
8. Affinity tier 1 — Ember-Spark — earned on this fight or
   shortly after.

### Authored content

- Wolf combatant sheet (HP/ATK/DEF/SPD) — balance pass.
- Forest path tile art (mostly placeholder PNGs already).
- One environmental detail: roadside cairn or torn cloak as a
  journal-loggable curiosity (`forest_path_unease` briefing —
  flavor, no fact). Adds atmosphere without adding mechanics.

### Engine changes

- New scene id `forest_path` replacing current `forest_edge`
  (rename file + grid + scene-router entries).
- `SceneRouter`: village ↔ forest_path ↔ bandit_hideout.
- Return-trip straggler spawn gated on `iskar_bonded` flag.

## Screen 3 — Bandit Hideout

**Story job:** The click. Caged drake, bandit note, strange coin,
chains-from-Pell. Iskar bonds.
**Teaching job:** Mini-boss, world-loot interactions, companion
bonding.

### Layout

```
              ░ cliff wall ░
   ░ tent     ░ campfire    ░ tent
              [Drust]
   ░ chest                  ░ crate
              [CAGE w/ Iskar]
   ░ bandit                 ░ bandit
              ░ bandit
[Forest Path ↓ south exit]
```

Compact arena. Three bandits + Drust patrol; cage is centerpiece.
Loot containers around the perimeter.

### Mechanics introduced

1. Mini-boss with pre-fight dialogue — Drust's one warning line,
   then combat. *Done.*
2. World object interactions — cage (releases Iskar), chest
   (throwing knives), crate (strange coin), Drust's corpse
   (bandit note auto-loots). Each is an [E] prompt.
3. Iskar bonding scripted beat — `CageHandler` already exists.
   After cage open: short caption, Iskar spawns as follower,
   `iskar_bonded` flag set.
4. Dossier mutation cascade — items entering inventory triggers:
   - `bandit_note` → adds `gold_eyed_one` to Kael's journal
     (rumor).
   - `strange_coin` → adds `gold_eyed_one` to Kael's journal
     (rumor, distinct briefing).
   - `iskar_bonded` flag → opens the Orren Press path
     semantically (no engine gate; the player now has a reason
     to press).

### Authored content

- Drust pre-fight line — already canon: *"Drop the sword and
  walk away, marsh-rat. The cargo isn't yours."*
- Drust combatant sheet — balance pass.
- 3 generic bandit sheets.
- Cage scripted beat — already implemented, verify caption:
  *"The drake follows you."*
- New briefing `pells_chains` (rumor) — what the chains in the
  camp once held. Earned by inspecting the cage. Connects to
  Mara's chains-for-Drust gossip.
- Bone tag item text — already canon: *"Iskar." Old hand. The
  name is carved with care.*

### Engine changes

- New scene file `bandit_hideout.tscn` + grid + scene-router.
- Verify order of operations: defeat-all-bandits → cage
  interactable → Iskar follows.
- Save block during the scripted bonding beat (existing
  SaveBlocker).
- Once Iskar is following, exiting south transitions to
  `forest_path` with `return_trip=true` so the companion-pair
  encounter spawns.

## Cross-cutting NPC implementation

### Already works (per progress tracker)

- All 5 NPC profiles + dossiers loaded.
- State modifiers (drunk, cracked, fed, cooldown_recovery).
- Press detection + crack flow.
- AI player-reply suggestions on Orren's tower/personal_history
  topics.
- Item acknowledgement short-circuit (ale, apple).
- Dossier mutation pipeline (`kael_has_drake` propagation).
- Fallback line banks for greeting/dragon/tower/item-offered/
  press-too-far/generic-confusion.

### Story-specific content to author or revise

| NPC | Change | Why |
|---|---|---|
| Halden | Three-thread brief. Turn-in coda. Optional bandit-note read. | Connects orphaned robbery thread. |
| Mara | `chains_for_drust` briefing. Verify `strange_coin` reaction mentions the previous customer. | Bandit prep traces back through her. |
| Orren | Update `tower_smoke` witness body to include the gold-eyed man. (`on_reveal_flags: tower_smoke → cracked: true` already exists.) | Crack reveal seeds Aurelix. |
| Toma | Apple-softened "I made it up" line. | Teaches Offer item + NPCs lie. |
| Edda | Closing-coda beat after quest turn-in. Missing-brother seed stays. | Demo's parting hook. |

### New briefings to author

```text
events/pells_robbery.md          (rumor) — chains, tarp, no coin taken
events/chains_for_drust.md       (rumor) — Mara's customer log
people/gold_eyed_one.md          (rumor) — already canon, expand body
events/tower_smoke.md            (witness) — REVISE body to include the man
events/forest_path_unease.md     (flavor, no fact)
```

### Facts

- `dragon_seen_near_old_tower` — exists. No change.
- **Decision:** do *not* add a second canon fact for the
  gold-eyed man in the demo. Keep him as rumor in the journal so
  the full game can promote him later. Avoids quest-state
  branching for the demo.

### Closing coda trigger

After `dragon_sighting:complete`, when player approaches the
village edge with Iskar following:

- Fire scripted scene: Edda intercepts.
- Plays her authored coda line.
- Title card scene loads on confirm.

The only fully scripted (non-AI) NPC beat in the demo besides
Drust's pre-fight. Author the line directly in `EddaScript.gd` or
a `closing_coda.tscn` overlay — *do not* route through the AI
pipeline. The demo's last line should be deterministic.

## Sequencing

1. **Split `forest_edge` → `forest_path` + `bandit_hideout`**
   (scene files, SceneRouter, save schema bump).
2. **Notice board + Halden brief** rewrite (three threads).
3. **Mara `chains_for_drust`** + **Toma apple-softened line** +
   **Orren `tower_smoke` body revision**.
4. **Pell's robbery briefing** + journal auto-log on inspecting
   the cage.
5. **Edda closing coda** scripted scene.
6. **Combat-numbers balance pass** (separate track, already on
   Next Up).
7. **Offline acceptance run** with the new arc end-to-end on
   Mock + Fallback.

Steps 1–5 are story-side and can land in any order after step 1.
Step 6 was already on the Next Up list and slots in parallel.

## What this plan does NOT change

- The five-NPC budget. No new NPCs.
- The AI pipeline. Same dialogue → topic → gate → retrieve →
  generate → validate flow.
- The Press mechanic implementation. Same crack logic.
- The save format (one slot, JSON). Schema migration covers the
  scene-id split.
- The 30-minute target playthrough.
