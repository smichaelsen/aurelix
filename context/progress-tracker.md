# Progress Tracker

Update this file after every meaningful implementation
change.

## Current Phase

- Phase 10 (Save/load, fallbacks, debug, hardening) —
  in progress. All scaffolding from Phases 1–9 is on
  disk: 75 GDScript files spanning core, ai, dialogue,
  npc, quests, combat, companion, player, world,
  journal, ui, test. The FastAPI proxy is wired with
  Mock + Anthropic Haiku 4.5 providers. The 480×270
  village square and forest edge scenes render and the
  full critical path is playable end to end.

## Current Goal

- Finish hardening: save round-trip safety, schema
  migration, and the last round of defensive fixes
  in the AI proxy pipeline so the 14 demo success
  criteria all hold under network failure + prompt
  injection.

## Completed

- Phase 1 — Data loader, registries, BootValidator,
  YAML→JSON pipeline (`tools/yaml_to_json.py`).
- Phase 2 — FastAPI proxy on `127.0.0.1:8421`,
  Mock + Haiku providers, AiService with provider
  fallback chain.
- Phase 3 — Tile-grid player movement, interaction
  prompts, village square + forest edge scenes,
  notice board.
- Phase 4 — Dialogue pipeline: TopicDetector,
  PromptBuilder, ResponseValidator, DialogueBox UI
  with authored options + free text.
- Phase 5 — CapabilityGate, Press loop, NPC memory
  (structured + recent_summary), state modifiers,
  AngerCooldownResolver.
- Phase 6 — Inventory, ItemPicker, OfferItemAction;
  ale → Orren and the other three social levers wired.
- Phase 7 — Combat engine + overlay, Iskar bond,
  stance-based companion AI, affinity tier 1
  Ember-Spark.
- Phase 8 — Journal with categorized briefings and
  free-text query through the same AI pipeline.
- Phase 9 — DossierMutator dispatches all dossier
  mutation events through one channel.
- Phase 10 (partial) — SaveManager + SaveBlocker;
  FallbackProvider with authored line banks;
  DebugOverlay surfaces topic / gate / briefings /
  raw JSON / validation.
- Scene presence in state paragraph (2026-05-16):
  new `game/scripts/dialogue/ScenePresence.gd` adds
  up to two lines to the state paragraph the speaking
  NPC sees: "Within 3 tiles: Mara (E), Iskar (S)" and
  "Elsewhere in scene: Orren (W), Halden (N), …".
  Distance is Chebyshev; direction folds to N/S/E/W
  with horizontal preferred on ties (same rule as
  `IskarFollower._cardinal_of`). Companion tile is
  published by IskarFollower via two new fields on
  `IskarCompanion`: `present_in_scene` and
  `current_tile`. DialogueController appends the
  lines after `StateModifierResolver.build_state_paragraph`.
  Player is intentionally excluded — face-to-face with
  the speaker is implied by the dialogue itself.
- Ollama provider (2026-05-16): new `proxy/providers/
  ollama.py` speaks Ollama's `/api/chat` with
  `format: "json"`. Selected via `AURELIX_PROVIDER=
  ollama`; configurable via `OLLAMA_HOST`,
  `OLLAMA_MODEL`, `OLLAMA_CLASSIFY_MODEL`,
  `OLLAMA_TIMEOUT_S`. Shared JSON extraction moved to
  `proxy/providers/_json_utils.py` and reused by the
  Anthropic provider. `httpx` added to
  `proxy/requirements.txt`. Godot side untouched —
  `LocalProxyProvider` does not know which backend
  serves a turn.
- Bandit-camp cage persistence fix (2026-05-16):
  `CageHandler._ready()` now swaps the cage sprite
  to `cage_empty.png` (deferred) when
  `IskarCompanion.bonded` is true, so re-entering
  forest_edge no longer reverts the cage to the
  drake-inside texture.
- Code review (2026-05-16): fixed
  `LocalProxyProvider` HTTPRequest concurrency bug
  (shared node scrambled overlapping `request_completed`
  signals) and proxy `_extract_json` brittleness
  (replaced greedy `\{.*\}` regex with fenced-block +
  string-aware balanced-brace scan; iterate
  `msg.content` for first text block).
- 4-direction facing system (2026-05-16): plumbing
  only. `PlayerController.facing`, last-cardinal
  tracking, diagonals collapse to last pressed,
  rotation only on successful move (no rotate on
  wall-bump). `WorldState.npc_facings` authored
  per-scene with default `"south"`. Entry points
  carry a facing. `DialogueController` rotates both
  speakers face-to-face on open and restores on
  close. `IskarFollower` derives facing from its
  movement delta. `SaveManager` round-trips player
  facing (no schema bump — missing field defaults
  to `"south"`). `FacingSprite` helper is in place
  but is a graceful no-op until directional
  artwork lands. Phase3Test + Phase10Test extended
  with facing assertions; all phase tests still
  pass.
- Kael directional sprites (2026-05-16): placeholder
  art for kael_north / kael_east / kael_west emitted
  by `tools/generate_placeholders.py` via a new
  `sprite_kael_directional()` (north = back/hooded
  silhouette, west = profile with one eye + dropped
  arm, east = west mirrored). `PlayerCharacter.tscn`
  now hosts a FacingSprite child with the four
  textures wired in. Phase3Test verifies the sprite
  swaps to `kael_east.png` after an east move.
- Iskar directional sprites (2026-05-16): the
  existing west-profile drake gets rotated into all
  four facings (east = west mirrored; south = 90°
  CCW so snout points down; north = 90° CW so snout
  points up). All four padded to a uniform 32×32
  with the drake centered, so swapping textures
  doesn't produce a visual jump from the original
  32×24 sprite. `IskarFollower.tscn` defaults to
  `iskar_south.png` and hosts a FacingSprite with
  the four textures wired. Phase7BondTest still
  green.
- Village NPC directional sprites (2026-05-16):
  `sprite_<name>_directional()` added for Toma,
  Mara, Orren, Halden, Edda — humanoids reuse
  `base_human_north`/`base_human_west` and overlay
  per-NPC details (Mara's apron, Halden's rank
  chain, Edda's robe + collar, Orren's slumped
  shoulders); Toma gets bespoke north/west at the
  child silhouette dimensions. Each existing
  south-only function now also saves
  `<name>_south.png` so the FacingSprite dict has
  a stable alias. `village_square.tscn` rewired:
  each NPC is now a Node2D wrapper containing a
  Sprite child + FacingSprite child with subject
  `"npc:<id>"`. Halden's `Sprite.texture` defaults
  to `halden_west.png` and Edda's to `edda_east.png`
  to match their authored grid facings on load
  (no facing event fires at scene load).
  Phase3Test / Phase4Test / Phase10Test all still
  pass.
- Mock classify rules consolidated (2026-05-16):
  Extracted the keyword-rule table that drives
  `MockProvider.classify_topic` into a shared
  `proxy/data/mock_classify_rules.json`, mirrored to
  `game/data/` by `tools/yaml_to_json.py` (added to
  the shared-asset copy pairs and `OWNED_TOPLEVEL`).
  Both `proxy/providers/mock.py` and
  `game/scripts/ai/MockProvider.gd` now load rules
  from JSON at startup; the previously-hardcoded
  rule tables (which had drifted in order and
  keywords) are gone. Canonical rule order puts
  `prompt_injection` first, then `meta_game`, then
  the rest — fixes a real bug where Python's
  ordering (with bare `'system'` as a `meta_game`
  keyword listed after the topic-specific rules)
  let inputs like "ignore your system prompt"
  classify as `meta_game` instead of
  `prompt_injection`, sneaking past the
  capability-gate's prompt-injection branch. Also
  dropped a dead `capability_gate.decision ==
  'blocked'` branch in proxy mock's `generate()`
  that returned the same archetype-fallback as
  the fall-through. Verified with 8 test inputs
  through the proxy venv.
- NpcMemoryStore public accessors (2026-05-16):
  Added `set_flag`, `get_flag`, `set_anger_cooldown`,
  `get_anger_cooldown`, `decrement_anger_cooldown`,
  `clear_stress`, `set_recent_summary`,
  `known_npc_ids`, `peek_memory` (deep-copy snapshot,
  no entry creation) to `NpcMemoryStore`. Migrated
  `AngerCooldownResolver` and `OfferItemAction` off
  direct nested-dict mutation; `DebugOverlay` now
  uses `peek_memory`; `Phase10Test` ghost-npc
  assertion uses `known_npc_ids()`. `DialogueSession`
  and `DialogueController._session.npc_memory` keep
  their live-reference pattern (documented in the
  store header as intentional intimate coupling).
  `SaveManager` keeps owner-level `_by_id` access
  (also documented). Brings mutation surface in line
  with the code-standards rule "never reach directly
  into ... from outside the owning autoload."
- DialogueController _busy watchdog (2026-05-16):
  `_run_ai_turn` split into a thin wrapper and
  `_run_ai_turn_body`. The wrapper owns the `_busy`
  lifecycle via `_begin_busy_turn` / `_end_busy_turn`,
  so every exit path — normal completion, stress/patience
  early returns, and a runtime error or hung provider
  await inside the body — releases the flag. A 30s
  generation-counter watchdog (`_arm_busy_watchdog`)
  force-resets `_busy` and logs `push_error` if the
  turn never completes, preventing a permanent
  SaveBlocker softlock when an `await` in the body
  fails to resolve. The stress/patience branches still
  release `_busy` before the 2s parting-line timer so
  saves aren't blocked during the read window;
  `_end_busy_turn` is idempotent (bumps generation).
  External readers (`SaveBlocker`, `PlaythroughTour`)
  see no API change.
- SaveManager hardening (2026-05-16): atomic write
  via temp file + `DirAccess.rename` in `user://`;
  `load_slot` refuses newer-than-build saves outright;
  `_apply_npc_memory` rebuilds each entry from current
  defaults and overlays saved fields, so new fields
  added since the save get sensible defaults; unknown
  NPC ids are dropped, not slammed into the store;
  `_apply_npc_dossiers` filters broken entries
  (missing id or tier); `_migrate(blob, from_version)`
  scaffolding lands with a clear error path for
  unregistered transitions. Phase10Test now covers
  these four hardening cases.

## In Progress

- Nothing actively in progress; Phase 10 hardening
  pass landed.

## Next Up

1. **Directional sprites for the remaining
   characters.** Kael, Iskar, and the five village
   NPCs (Toma, Mara, Orren, Halden, Edda) are
   done. Forest encounters (wolf, bandits) still
   render as side-profile only; if they should
   turn during combat or while patrolling, give
   them the same treatment — the rotate-and-pad
   trick used for Iskar is the faster path for
   non-humanoid silhouettes already drawn in
   profile. Combat overlay owns its own pose so
   overworld facing on enemies is only relevant
   when they appear in the overworld (currently
   they don't — they're encounter sprites that
   trigger combat on touch).
2. Verify all 14 success criteria via
   `PlaythroughTour.gd` headless run.
3. Final pass on authored content gaps listed in
   `BUILD-PLAN.md` — Halden quest lines, per-NPC
   fallback banks, Iskar combat numbers, Kael combat
   numbers, enemy stat sheets.
4. Prompt-injection regression set: at least three
   canonical attempts ("ignore previous instructions",
   role-claim, schema-leak) should fail diegetically
   on every NPC.
5. Offline acceptance run with the proxy stopped —
   confirm quest completable on Mock + Fallback only.

## Open Questions

- Free-text classification cost: concept says "no
  hard caps in the demo," but a curious player can
  burn budget on Toma. Decide whether to add a soft
  per-conversation cap before public demo.
- Iskar HP and affinity between fights: heal to full,
  decay, or persist? Currently unspecified — pick a
  default in code and lock it down in CONCEPT.md.
- Prompt-injection blocked-response style per NPC:
  do we author one per archetype, or share a generic
  "I don't take orders from strangers" across all?
- ~~Mock/Haiku byte-for-byte parity~~ — resolved
  2026-05-16. Classify rules now load from shared
  JSON. `mock_responses.json` was already mirrored.
  Drift surface eliminated structurally.

## Architecture Decisions

- Single LLM call per turn, plus one classify call
  when input is free text. Authored options skip the
  classify call entirely. (CONCEPT.md §"Pipeline shape")
- Proxy holds the Anthropic key; Godot never sees it.
  The key lives only in the proxy process environment.
- LocalProxyProvider creates a fresh `HTTPRequest`
  per call (decided 2026-05-16 after fixing the
  concurrency bug). Sharing a single node collided
  on `request_completed`.
- `_extract_json` in `proxy/providers/anthropic_haiku.py`
  prefers fenced blocks, then a balanced-brace scan
  that respects string literals (decided 2026-05-16).
  The previous greedy `\{.*\}` misfired on any
  decorative trailing brace.
- Save format is a single JSON file at
  `user://save_slot_1.json` with a `version` field.
  Multi-slot is out of scope for the demo.
- 4-direction facing rules (decided 2026-05-16,
  wall-bump rule revised same day): movement remains
  8-directional; facing is 4-cardinal only. Facing
  rotates on **any** directional input — including
  blocked moves, edge-pushes, and exit/encounter
  triggers. Movement may or may not follow; facing
  always does. (Earlier rule "rotate only on
  successful move" inverted after first feel-test;
  responsive rotation is the classic top-down RPG
  convention.) Diagonals collapse via "last cardinal
  pressed". NPCs and Kael face each other on
  `dialogue_opened` and **keep** that facing after
  `dialogue_closed` — a conversation just happened,
  they're not snapping back. (Earlier rule "restore
  prior facing on close" reverted 2026-05-16 once
  directional NPC sprites landed and snapping the
  NPC back to its authored default the instant
  dialogue closed read as the NPC ignoring you
  mid-goodbye.) Interaction stays 8-neighbour,
  not facing-gated.
  Combat overlay owns its own pose layout —
  overworld facing does not leak in.
- Save writes are atomic: write to
  `save_slot_1.json.tmp`, then `DirAccess.rename`
  within `user://` (POSIX-atomic on macOS). Newer-
  than-build saves are refused; older saves go
  through `_migrate(blob, from_version)`. NPC memory
  is re-defaulted from the profile and saved fields
  are overlaid, so new fields default in.
  (Decided 2026-05-16.)
- Briefing reveals are gated by the NPC's dossier
  AND the per-NPC `forbidden_to_share` flag.
  Rejected reveals are silently dropped; the
  dialogue line still plays. This is intentional —
  the model can dodge in character without being
  caught lying.
- World-item pickups grant facts directly via the
  engine, not through an LLM reveal. The bandit
  note's `facts_unlocked_on_reveal` only fires if
  an NPC reveals its contents to another NPC
  (out of scope for the demo).
- Save points are between turns only.
  `SaveBlocker` refuses while combat or a
  dialogue/journal turn is in flight.

## Session Notes

- The HTTPRequest concurrency fix in
  `game/scripts/ai/LocalProxyProvider.gd` was
  committed in `ce484d3` along with the
  `anthropic_haiku.py` JSON extractor rewrite.
  Both fixes are on `origin/main`.
- Phase10Test's `_test_save_hardening` block prints
  one expected `ERROR: save is newer than build`
  line when run headless — that's the refusal path
  firing on purpose. The next assertion confirms
  the refused load did not mutate in-memory state.
- The codebase has both an in-process MockProvider
  (`game/scripts/ai/MockProvider.gd`) and a proxy
  MockProvider (`proxy/providers/mock.py`). They
  serve the same role from different sides; their
  responses are not currently guaranteed
  byte-identical — see Open Questions.
- DebugOverlay is autoloaded but hidden by default.
  Toggle with the backtick key in-game.
