# Aurelix — Review Guide for AI Agents

You are reviewing a Godot 4.6 demo. You don't have a display and can't press
keys interactively, but the project has a scripted playthrough that drives
every gameplay beat and dumps screenshots. Use it.

## What this game is

Top-down 2D RPG (32×32 tiles, 480×270 viewport). Hero "Kael" is hired by
Reeve Halden to find a dragon near an old tower. Five villager NPCs run on
a real AI dialogue pipeline (MockProvider by default, Anthropic-via-proxy
optional). A drake-hatchling companion "Iskar" bonds mid-game and joins
combat. Demo arc is documented in `BUILD-PLAN.md`.

The README-style overview lives in `BUILD-PLAN.md` (10 phases, all green).
`game/project.godot` lists every autoload — it's the cleanest map of the
engine's nervous system.

## Run anything

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd /Users/smic/PhpstormProjects/aurelix/game
```

Run a scene headless and capture the log:

```bash
"$GODOT" --headless --path . res://scenes/test/<Name>.tscn 2>&1 | tail -80
```

`--headless` skips the window. Stdout is your only window into the game.

## Rebuild data first

The engine reads JSON; sources live in YAML/Markdown. If you change
anything under `/data/`, rebuild before launching:

```bash
python3 tools/yaml_to_json.py
```

It's idempotent and fast (<1s). Skip if you only changed `/game/` scripts.

## The full playthrough (your "playing the game")

`scenes/test/PlaythroughTour.tscn` walks 12 demo beats end-to-end:
village boot, journal open, notice board, Halden quest accept, Mara/Orren
first talks, Orren ale + press → fact reveal, coin → Mara, note → Edda,
Drust dies, Iskar bonds, Iskar enters village, journal Q&A. Each beat:

- emits assertions to stdout (`[Playthrough] ok: ...` / `FAIL: ...`)
- writes a PNG to `/tmp/aurelix_playthrough/NN_<label>.png`

Run it:

```bash
"$GODOT" --path . res://scenes/test/PlaythroughTour.tscn 2>&1 | tail -100
```

(Drop `--headless` if you want screenshots; `--headless` produces only
black PNGs because there's no GPU output.)

Then look at every shot with the `Read` tool:

```text
Read /tmp/aurelix_playthrough/00_01_village_boot.png
Read /tmp/aurelix_playthrough/05_05_mara_first_talk.png
...
```

Screenshot review is the closest thing to "seeing" the game.

## Per-phase tests

`scenes/test/Phase{3..10}Test.tscn` plus `Phase7BondTest`, `Phase7CombatTest`,
`AiServiceTest`. They run headless in seconds and print `[PhaseNTest] PASS`
or a list of failures. Use them to verify a subsystem before touching
broader code:

| Test | What it covers |
|---|---|
| Phase3Test | tile movement, interaction prompts |
| Phase4Test | dialogue UI + Halden templated path |
| Phase5Test | press lever, capability gate, fact reveal |
| Phase6Test | inventory + offer-item |
| Phase7Test / 7Bond / 7Combat | combat engine, Iskar bonding, affinity, stance AI |
| Phase8Test | Kael's journal as a dialogue target |
| Phase9Test | dossier mutations (item shown, drake entry, fact ripple) |
| Phase10Test | save/load round-trip, fallback bank, anger cooldown, quest_paid |
| AiServiceTest | mock provider keywords, prompt injection, classifier |

Run all of them in parallel with a shell loop if you want a regression
sweep. Each scene quits with exit code 0 (pass) or 1 (fail).

## Reading the log

The engine prints structured tags. Most useful to grep:

| Tag | Meaning |
|---|---|
| `[DataLoader]` | bootstrap counts (topics/facts/npcs/briefings) |
| `[BootValidator]` | static-data referential integrity |
| `[WorldState] loaded scene` | scene change |
| `[Player] dialogue_requested(<id>)` | NPC conversation opens |
| `[DialogueController] gate(<npc>, <topic>) -> <decision>` | capability gate decision |
| `[DialogueController] facts granted via reveal: ...` | LLM reveal accepted |
| `[DialogueController] validation: [...]` | response validator issues |
| `[FactLedger] +<fact_id>` | fact unlocked |
| `[QuestState] <quest>: <from> -> <to>` | quest state transition |
| `[Journal] +<briefing> (<tier>)` | Kael learned something |
| `[NpcDossierStore] <npc> += <briefing>` | dossier mutation |
| `[CombatController] combat_started / combat ended` | combat lifecycle |
| `[Iskar] bonded / affinity +<n>` | companion progression |
| `[SaveManager] wrote/loaded` | persistence |
| `[FallbackProvider]` | authored fallback bank loaded |

## Debug overlay

In normal play, backtick (`` ` ``) toggles `scenes/ui/DebugOverlay.tscn`.
It shows last-turn info (gate decision, prompt size, granted facts,
validation issues), provider toggle (Mock ↔ Proxy/Haiku), force-fallback
toggle, save/load buttons, quest state, NPC inspector (memory + dossier
of any NPC). When inspecting bugs, the NPC inspector is usually the
fastest path.

You can't toggle it programmatically from a test, but every value it
surfaces is reachable in code:

- `QuestState._states` — dict of quest → state
- `NpcMemoryStore._by_id[<npc_id>]` — memory dict (stress, patience,
  flags, recent_summary, anger_cooldown_turns)
- `NpcDossierStore.dossier_for(<npc_id>)` — live mutated dossier
- `FactLedger.known_facts()` — array of granted fact ids
- `Inventory.bag` / `Inventory.coins`
- `IskarCompanion.bonded / affinity_points / unlocked_tier / stance`
- `Journal.entries()` — Kael's accrued briefings

## The canonical demo arc (what counts as "finished")

If you're judging completeness, the title-card path is:

1. Talk to Halden, accept "I'll find your dragon."
2. Talk to Orren, ask about the tower → blocked.
3. Offer **Ale** (starting inventory has one) → his `drunk` flag flips.
4. Ask about the tower again → he dodges with the smoke/wings line. The
   options now switch to the `the_tower` bank with three press options.
5. Pick one of the press options ("You saw something, didn't you?",
   "You're afraid of the wings.", "I won't tell the reeve.") → fact
   `dragon_seen_near_old_tower` granted → quest `complete`.
6. Talk to Halden → `EventBus.quest_paid("dragon_sighting")` → title card.

The bandit camp + Iskar bond + village mutations are bonus showcase
content, not required for the title card.

`PlaythroughTour.tscn` walks all of this and the bonus showcase too.

## Limitations to acknowledge

- You cannot test interactive feel (input lag, animation polish) headless.
  Screenshot review catches layout/visual bugs; it misses timing.
- The proxy/Anthropic path is off by default (`Config.use_mock_ai = true`).
  Set it to `false` only when reviewing real-AI behaviour, and start the
  FastAPI proxy in `proxy/` first.
- Tests print `WARNING: ObjectDB instances leaked at exit` — that's
  expected (Godot's strict shutdown order vs. our autoload children).
  It is not a failure.

## What good review feedback looks like

Findings should reference exact paths and line numbers:
`game/scripts/dialogue/DialogueController.gd:88` not "the dialog controller".
The previous Claude session's own self-review notes are visible in
`/tmp/aurelix_playthrough/` if recent, and earlier rounds discovered:

- Patience leaked across conversations (fixed)
- Stress never reset after cooldown (fixed)
- Fact granted before quest accepted → quest stuck active (fixed)
- Quest toast overlapped next dialog (fixed: dismissed on `dialogue_opened`)
- Grab-focus errors when option buttons were queue-freed mid-deferral (fixed)
- Offering an item routed to a bland fallback line instead of pivoting
  topic to the briefing the dossier just absorbed (fixed)

If you find anything in those categories that's still broken, it's
likely a new regression and worth flagging clearly.
