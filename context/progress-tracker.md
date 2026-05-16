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

1. Verify all 14 success criteria via
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
- Mock/Haiku byte-for-byte parity: currently the in-Godot
  Mock and proxy Mock diverge in canned content. Decide
  whether to fix or accept (the demo path uses Mock
  only as a fallback).

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
