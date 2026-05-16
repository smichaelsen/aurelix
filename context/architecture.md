# Architecture Context

## Stack

| Layer         | Technology                          | Role                                                                    |
| ------------- | ----------------------------------- | ----------------------------------------------------------------------- |
| Engine        | Godot 4.6 (Forward+, 960×540 viewport, 1920×1080 window) | Game runtime; renders, runs scripts, owns the scene tree.            |
| Game scripts  | GDScript                            | All gameplay, dialogue orchestration, combat, save/load.               |
| AI proxy      | Python 3 + FastAPI + Uvicorn (localhost:8421) | Single backend hiding the Anthropic SDK from Godot.          |
| AI provider   | Anthropic Claude Haiku 4.5 (default cloud) or local Ollama daemon | Villager dialogue + free-text topic classification. Selected via `AURELIX_PROVIDER` (`anthropic` / `ollama` / `mock`). |
| Mock provider | In-process GDScript + in-proxy Python | Deterministic offline fallback. Identical inputs → identical outputs in both. |
| Authored data | YAML + Markdown-frontmatter under `data/` | Briefings, NPC profiles, topics, facts, items, options, fallback lines, briefing pairs. Plus `proxy/data/mock_responses.json` and `proxy/data/mock_classify_rules.json`, both mirrored into `game/data/` by `yaml_to_json.py` so the in-Godot and in-proxy mocks share one rule table. |
| Runtime data  | JSON, single slot at `user://save_slot_1.json` | Player state, world state, quest state, NPC memory, dossier mutations, journal. |
| Build tooling | Python scripts under `tools/`       | `yaml_to_json.py` converts authored YAML to JSON Godot reads natively. Preview generators. |

## System Boundaries

- `game/scenes/` — `.tscn` scene files. Two world scenes
  (`village_square.tscn`, `forest_edge.tscn`), UI scenes
  (`scenes/ui/`), and test/preview harness scenes
  (`scenes/test/`). Scenes own layout; they do not own
  state.
- `game/scripts/core/` — Engine plumbing autoloads:
  `Config`, `EventBus`, `DataLoader`, `BootValidator`,
  registries (`Topic`, `Fact`, `Briefing`,
  `NpcProfile`, `Item`), `SaveManager`, `SaveBlocker`.
  Every cross-cutting service lives here.
- `game/scripts/ai/` — The AI pipeline. `AiService`
  (autoload entry point), `AiProvider` (interface),
  `MockProvider`, `LocalProxyProvider`, `FallbackProvider`
  (canned line bank), `PromptBuilder`, `CapabilityGate`,
  `Retriever`.
- `game/scripts/dialogue/` — `DialogueController`
  (autoload), `DialogueSession`, `TopicDetector`,
  `PressDetector` (keyword-based free-text → press
  promotion), `ResponseValidator`, `NpcMemoryStore`,
  `AngerCooldownResolver`, `OfferItemAction`,
  `StateModifierResolver`, `AuthoredOptionLibrary`,
  `PlayerSuggestionGenerator` (autoload — Kael-side
  reply suggestions, strict context isolation from the
  NPC pipeline).
- `game/scripts/npc/` — `NpcDossierStore`,
  `DossierMutator`, plus authored scripted NPC behavior
  (e.g. `HaldenScript.gd`).
- `game/scripts/quests/` — `QuestState`, `FactLedger`,
  `QuestRuleEngine`. Deterministic only.
- `game/scripts/combat/` — `CombatController`
  (autoload), `CombatEngine` (turn machine),
  `CombatantStats`.
- `game/scripts/companion/` — `IskarCompanion` (state,
  affinity, stance), `IskarFollower` (overworld sprite).
- `game/scripts/player/` — `PlayerController`,
  `Inventory`.
- `game/scripts/world/` — `WorldState` (current scene
  id, player_start), `SceneRouter`, environment
  handlers (`CageHandler`, `NoticeBoardHandler`).
- `game/scripts/journal/` — `Journal` (entries store),
  `JournalController`.
- `game/scripts/ui/` — Dialogue box, journal panel,
  combat overlay, item picker, debug overlay, toasts,
  title card.
- `game/scripts/test/` — Headless test harnesses and
  preview-image generators. Not shipped, not loaded
  by the village_square scene.
- `proxy/` — FastAPI app. `main.py` exposes
  `/v1/generate`, `/v1/classify_topic`,
  `/v1/suggest_player_options`, `/health`.
  `providers/` holds `base.py` (protocol), `mock.py`,
  `anthropic_haiku.py`, `ollama.py`, and the shared
  `_json_utils.py` (fenced-block + balanced-brace JSON
  extraction). `schema.py` defines the pydantic
  request/response shapes that GDScript dataclasses
  mirror.
- `data/` — Authored content tree (YAML +
  Markdown). Mirrored into `game/data/` at build
  via `tools/yaml_to_json.py`.
- `tools/` — Build-time scripts (YAML→JSON, scene
  preview generators). Not part of the runtime.

## Storage Model

- **Authored content (`data/` source-of-truth → `game/data/` runtime):**
  briefings (markdown + frontmatter), NPC profiles
  (YAML), topics, facts, items, authored option
  banks, fallback line banks, tile collision map.
  Loaded once at boot; never written to at runtime.
- **In-memory runtime state (autoload singletons):**
  `WorldState`, `Inventory`, `Journal._entries`,
  `FactLedger._known`, `QuestState._states`,
  `NpcMemoryStore._by_id`, `NpcDossierStore._by_id`,
  `IskarCompanion.*`. These are the things SaveManager
  serializes.
- **Persistent save (`user://save_slot_1.json`):**
  one JSON blob with a `version` field. Contains
  inventory, facts, quest state, NPC memory, NPC
  dossier mutations, Iskar state, journal entries,
  current scene id + player tile.
- **Proxy state (process-local, ephemeral):** token
  counters and per-conversation totals in
  `observability.py`. Not persisted; the proxy can
  be restarted between sessions without consequence.
- **Secrets:** `ANTHROPIC_API_KEY` lives only in the
  proxy's environment. Godot never reads it.

## Auth and Access Model

This is a single-player offline-capable RPG. There
is no user auth, no accounts, no network identity.
The only privileged boundary is the API key, which:

- Lives only in the proxy process environment.
- Is never logged (proxy `observability.py` is
  explicit about this).
- Is never sent to Godot. Godot speaks only to
  `http://127.0.0.1:8421`.
- The game must remain fully playable if the proxy
  is down (Mock + Fallback path).

## AI / Background Task Model

Two separate, context-isolated AI calls per turn. The NPC call sees only
the NPC's private dossier and memory; the Kael-side suggestion call sees
only public knowledge Kael holds. Mixing them in one call would let a
forbidden briefing leak into Kael's mouth.

```
Player input (option, AI suggestion click, or free text)
  → TopicDetector (authored tag if option; LLM classify if free text)
       Free-text classify also tags `category`:
         in_game        → normal flow (below)
         out_of_context → real-world / modern-tech / current-events refs
                          the world can't answer. Engine substitutes the
                          NPC's authored "I didn't catch that" fallback,
                          does NOT touch patience / stress / last_turns.
         offensive      → grave slurs / explicit content. Engine substitutes
                          the NPC's authored offended line and triggers
                          AngerCooldownResolver. One-shot, conversation ends.
       Layer-2 backup: the NPC's `generate` response can also raise
       `safety_flag = out_of_context | offensive` for inputs that slipped
       past the cheap pre-classify (e.g. roleplay-framed jailbreaks). Same
       short-circuit fires; the offending player line is popped from
       last_turns so it cannot resurface in a later prompt.
  → PressDetector (free-text + suggestion clicks only; if the text matches
                   an authored press keyword for the most-recently-dodged
                   topic, promote verb → "press" and attach the matching
                   `press_angle` so CapabilityGate can fire the reveal)
  → CapabilityGate (allowed | blocked | constrained, by domain × NPC)
  → Retriever (dossier briefings matching the topic, bounded by token budget)
  → PromptBuilder (persona + state paragraph + memory summary + briefings)
  → AiProvider.generate (LocalProxy → FastAPI → Anthropic, OR Mock)
  → ResponseValidator (schema + safety + scope checks)
  → engine applies approved reveals, memory delta, faction state
  → DialogueBox renders the dialogue line

Then, in parallel with the player reading the line:
  → DialogueBox shows 3 disabled "..." placeholder rows
  → PlayerPromptBuilder (Kael's known_facts + journal excerpts + public
                         conversation history; NO NPC dossier or memory.
                         When the NPC just dodged a topic, that topic id
                         is passed as `npc_just_dodged_topic` — a publicly
                         observable cue — so the model can include one
                         pressing suggestion among the three)
  → AiProvider.suggest_player_options (same provider chain)
  → PlayerSuggestionGenerator validates (intent enum, length cap, injection
                                          filter, dedupe by intent, cap 3)
  → DialogueBox.apply_suggestions replaces placeholders

When the player picks an AI suggestion, the box emits text_submitted, the
same path as the free-text LineEdit. That path runs TopicDetector and then
PressDetector, so a "you saw something" suggestion turns into a real Press
turn (with stress + reveal semantics) the moment its text lands on an
authored angle keyword. The detector is deliberately keyword-based and
brittle; authors extend coverage by adding keywords to
`press_keywords[topic][angle]: [...]` in the NPC profile.
```

Authored options vs AI suggestions are decided per topic via
`options_source: <topic>: authored | ai_suggested` in each NPC's option
bank. Defaults when the bank has no entry: the `default` topic (the scripted
opening line after `_open`) is `authored`; every other topic is
`ai_suggested`. Banks override either direction. When a topic is
`ai_suggested`, AI suggestions own the player's reply surface for that topic
— authored Press options for the same topic do NOT also appear (an earlier
"pressable Press wins" guard was removed; it silently suppressed AI
suggestions on Orren the moment he first dodged). If the Press shortcut is
needed on an AI-suggested topic, the fix belongs in the suggestion prompt,
not the UI rule. Mock mode falls through to authored across the board.

Failure handling:

- AiService retries via Mock on any proxy error.
- After `MAX_CONSECUTIVE_FAILURES` (currently 2) per
  NPC, AiService switches that NPC to the
  FallbackProvider (authored canned bank).
- `DebugOverlay.force_active` lets QA pin all NPCs
  to FallbackProvider regardless of mode.
- The proxy's Haiku wrapper has one repair pass for
  malformed JSON; on second failure it raises so
  AiService falls back.

There is no background-task or job queue. All work
runs synchronously on the player's turn behind a
Godot `await`. The save system refuses to write
while a dialogue/journal turn is in flight (via
`SaveBlocker`).

## Invariants

1. **The engine owns canon.** The LLM proposes; the
   engine validates. No fact, quest state, inventory
   change, faction value, or relationship delta is
   ever written from model output without
   `ResponseValidator` approval.
2. **Briefing reveals are gated by the NPC's
   dossier.** A `revealed_briefing_ids` entry is
   accepted only if that briefing is in the NPC's
   dossier AND not flagged `forbidden_to_share` for
   them. Rejected reveals are silently dropped; the
   dialogue line still plays.
3. **The API key never leaves the proxy process.**
   No GDScript file may read, log, or transmit it.
   The proxy never includes it in responses or logs.
4. **The game must be completable offline.** With
   the network disconnected and `use_mock_ai = false`,
   AiService falls through to Mock and then to
   FallbackProvider. Every NPC ships authored
   fallback lines for greeting, dragon, tower,
   item-offered, press-too-far, generic-confusion.
5. **Save writes never happen mid-turn.** `SaveBlocker`
   refuses while combat or a dialogue/journal request
   is in flight. Save points are between turns only.
6. **Boot fails loudly on broken authored data.**
   `BootValidator` rejects unknown briefing ids in
   dossiers, unknown fact ids in `facts_unlocked_on_reveal`,
   and unknown topic ids in `topic_tags`. Soft warnings
   are not acceptable for these.
7. **Prompt injection fails diegetically.** Topic
   classification flags an `prompt_injection` domain;
   capability gate treats it as blocked with the NPC's
   `failure_style`; `ResponseValidator` strips any
   leaked references to prompts, schemas, instructions,
   or system roles. The NPC stays in character.
8. **One HTTPRequest per call.** `LocalProxyProvider`
   instantiates a fresh `HTTPRequest` per request and
   frees it on completion. Sharing a single node
   collides on `request_completed` when calls overlap.
9. **Autoload order matters and is fixed in
   `project.godot`.** Registries load before stores;
   stores load before controllers; UI overlays
   (DebugOverlay, TitleCard) load last. Do not
   reorder without re-running `BootValidator`.
10. **Kael's reply suggestions never see NPC private state.**
    `PlayerPromptBuilder` reads only `FactLedger`, `QuestState`,
    `Journal._entries`, and `DialogueSession.last_turns` (the public
    log). The NPC's profile, dossier, memory, and any briefing flagged
    `forbidden_to_share` MUST NOT enter this call. Suggestions are
    player utterances and never write canon: no fact grants, no
    memory updates, no dossier mutations come out of this path.
11. **Facing is 4-cardinal; movement is 8-direction.**
    Player facing rotates on any directional input —
    blocked moves, wall bumps, edge pushes, and
    exit/encounter triggers all update facing even
    when Kael does not move. Movement may or may not
    follow; facing always does. Diagonals collapse to
    the last cardinal pressed. NPCs have a per-scene
    authored facing in `WorldState.npc_facings`;
    `DialogueController` rotates speakers face-to-face
    on open and restores on close. Combat overlay is
    exempt — it owns its own pose layout.
