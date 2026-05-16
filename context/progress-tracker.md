# Progress Tracker

Update this file after every meaningful implementation
change. Keep entries focused on status quo and durable
context — not file-by-file diffs or change history.

## Current Phase

- Phase 10 hardening pass complete. All scaffolding from
  Phases 1–9 is on disk; the 960×540 village square and
  forest edge scenes render and the full critical path
  is playable end to end. FastAPI proxy supports Mock +
  Anthropic Haiku 4.5 + Ollama providers.

## Current Goal

- **Story coherence rewrite** — see `story-rewrite.md` at
  repo root. Stitches the three threads (smoke, sheep,
  Pell's robbery) into one suspicion, makes the Press
  reveal load-bearing (gold-eyed man seeded as
  Aurelix's first fingerprint), and splits the current
  `forest_edge` scene into `forest_path` +
  `bandit_hideout` so each screen carries one teaching
  job. Supersedes the playthrough beats in CONCEPT.md
  §Demo playthrough and project-overview.md §Core User
  Flow where they disagree.
- Authored-content gaps + combat-numbers balance pass
  (see Next Up) run alongside the rewrite.

## Completed

### Pipeline phases

- **Phase 1** — Data loader, registries, BootValidator,
  YAML→JSON pipeline (`tools/yaml_to_json.py`).
- **Phase 2** — FastAPI proxy on `127.0.0.1:8421`;
  Mock + Haiku + Ollama providers; AiService with
  provider fallback chain.
- **Phase 3** — Tile-grid player movement, interaction
  prompts, village square + forest edge scenes,
  notice board.
- **Phase 4** — Dialogue pipeline: TopicDetector,
  PromptBuilder, ResponseValidator, DialogueBox UI
  with authored options + free text.
- **Phase 5** — CapabilityGate, Press loop, NPC memory
  (structured + recent_summary), state modifiers,
  AngerCooldownResolver.
- **Phase 6** — Inventory, ItemPicker, OfferItemAction;
  all four social levers wired (ale → Orren etc.).
- **Phase 7** — Combat engine + overlay, Iskar bond,
  stance-based companion AI, Ember-Spark affinity tier 1.
- **Phase 8** — Journal with categorized briefings and
  free-text query through the AI pipeline.
- **Phase 9** — DossierMutator dispatches all dossier
  mutation events through one channel.
- **Phase 10** — SaveManager (atomic write, refuse
  newer-than-build, _migrate scaffolding, defensive
  rebuild of NPC memory on load), SaveBlocker,
  FallbackProvider with authored line banks,
  DebugOverlay (topic / gate / briefings / raw JSON /
  validation), `_busy` watchdog on DialogueController.

### Features layered on top of the phase scaffolding

- **4-direction facing system.** Movement stays
  8-directional; facing is 4-cardinal. Facing rotates
  on any directional input including blocked moves.
  Diagonals collapse via last-cardinal-pressed. NPCs +
  Kael face each other on `dialogue_opened` and keep
  the facing on close. FacingSprite handles texture
  swaps; step-pose textures supported via
  `EventBus.player_step_changed` (no-op until step
  PNGs land). Directional sprites authored for Kael,
  Iskar, and all five village NPCs.
- **Resolution: 960×540 internal viewport** (window
  1920×1080), 64-px tiles throughout. All sprite/tile/UI
  PNGs upscaled 2× via the `SCALE` knob in
  `tools/generate_placeholders.py`; UI scenes scaled via
  `tools/scale_ui_tscn.py`. Bundled Godot sans kept;
  Pixelify Sans trialled and reverted.
- **HP carry-over + heal channels.** `PartyHealth`
  autoload owns current HP for Kael + Iskar across
  fights; saved by SaveManager (pre-PartyHealth saves
  default to full). [H] in overworld consumes
  smallest-fit heal item; Edda's "Pray for healing."
  authored option restores party to full. Combat loss
  still resets to full (save-reload stand-in). Drust
  combatant stats now resolve correctly (separate from
  sprite id).
- **Inventory panel + heal toast.** [I] opens a
  parchment `InventoryPanel` (mirrors JournalPanel
  layout). Left column shows equipment + coins + HP;
  right column lists bag rows with stats. Consumables
  with `stats.heal > 0` carry a `Use` button that
  routes through the new `HealService` autoload —
  same path as the [H] quick-heal, so the consume +
  clamp + signal flow is shared. `HealService.use_item`
  and `heal_kael_with_best_fit` both emit a new
  `EventBus.party_heal_applied(who, item_id, amount,
  hp, max_hp)` signal. `HealToast` (sibling of
  QuestToast, sits at y=64 with a green border) renders
  "Apple +5 HP — 19/24" for 2s. `InventoryController`
  is autoloaded; gated while dialogue, combat, or the
  journal is open.
- **Scene presence in state paragraph.** Speaking NPC
  sees up to two lines: "Within 3 tiles: …" and
  "Elsewhere in scene: …". Chebyshev distance,
  N/S/E/W with horizontal preferred on ties. Player
  excluded — face-to-face with speaker is implied.
- **Ollama provider.** `proxy/providers/ollama.py`
  speaks `/api/chat` with `format: "json"`. Selected
  via `AURELIX_PROVIDER=ollama`. Shared JSON extraction
  in `proxy/providers/_json_utils.py` used by both
  Anthropic and Ollama providers.
- **Soft reveal via authored reveal_note.** Forbidden
  briefings carry per-NPC `reveal_note` (in-fiction
  condition) and `public_tell` (Kael-side body-language
  cue). `AiResponse.reveal_intent` is the model's opt-in;
  ResponseValidator accepts a reveal iff (deterministic
  reveal_ready) OR (gate ≥ constrained AND reveal_note
  present AND reveal_intent=true).
- **Out-of-context + offensive guardrails.**
  `/v1/classify_topic` returns a `category` field
  (in_game / out_of_context / offensive); triages free
  text before generate. `out_of_context` substitutes a
  scripted "I didn't catch that" line and does NOT
  mutate state. `offensive` substitutes a scripted line
  and triggers `set_anger_cooldown`. Authored options
  bypass classifier. Layer 2: `safety_flag` on
  `AiResponse` for jailbreaks the classifier missed —
  same fallback line, plus the offending input is
  popped from `last_turns` so it can't resurface.
  Fallback lines authored per-NPC + `_archetype` defaults.
- **State-aware greetings + options.** NPC profiles
  may declare `greetings: {default, drunk, cracked,
  cooldown_recovery, fed, ...}` and
  `default_options_by_state:`. Priority order:
  cooldown_recovery (one-shot) > cracked > drunk >
  fed > default. Tone comes from
  `state_modifiers[<state>].tone_default`. Falls back
  to archetype greeting if a state key is missing.
- **Item acknowledgement short-circuit.** Item
  `on_offer.<npc>` may carry
  `acknowledgement: {dialogue, tone}`. Present →
  `_on_item_offered` fires an authored beat and skips
  the AI turn. Flag flip happens regardless. Used by
  Orren's ale and Toma's apple/ration.
- **Post-reveal flag mapping.** NPC profiles may
  declare `on_reveal_flags: {<briefing_id>: {<flag>: bool}}`.
  After ResponseValidator approves a reveal,
  DialogueController applies any mapped flags. Orren's
  `tower_smoke → cracked: true` is the first user;
  cracked beats drunk in mock state-key derivation.
- **Claims channel for non-canon facts.** New
  `claims: list[str]` field on `AiResponse`.
  ResponseValidator grants each id via FactLedger iff
  `FactRegistry.has_fact` AND
  `is_canon(id) == false` — canon facts are never
  grantable through claims (preserves invariant #1).
  Granted claims append to the same `granted_facts`
  array as reveal-granted facts. Mock-only for now;
  Anthropic + Ollama default to `[]`.
- **Free-text Press detection.** `PressDetector`
  promotes a player line to `verb=press` when its text
  matches a keyword in the current NPC's
  `accepted_press_angles`. Topic selection prefers the
  most recently dodged topic over the classifier
  verdict. Wired into the same `_on_text_submitted`
  path as AI-suggestion clicks.
- **AI player-reply suggestions.** Separate
  `/v1/suggest_player_options` call carries Kael-side
  context only (strict isolation from NPC dossier).
  Up to 3 AI-generated rows + always-present free-text
  + Offer-item. 3 disabled "…" placeholders render
  immediately; replaced in place when suggestions
  arrive. Per-topic `options_source: ai_suggested`
  opt-in; banks override either direction. Default
  topic stays authored. Mock mode keeps authored options.
  Suggestion prompt is told `npc_just_dodged_topic` and
  asked to include one Press-style angle when set.
  First-button focus parity with scripted options.
  Orren's `the_tower` and `personal_history` opted in
  as smoke test.
- **Kingdom-overview digest tier.** Commoners (drust,
  mara, orren, toma) carry the `digest` tier as their
  universal kingdom briefing; wisdom-carriers (kael_self,
  halden_reeve, edda_priest) keep `full`. Matches
  Retriever's "universals = digest" design.
- **NpcMemoryStore public accessors.** `set_flag`,
  `get_flag`, `set_anger_cooldown`,
  `decrement_anger_cooldown`, `clear_stress`,
  `set_recent_summary`, `known_npc_ids`, `peek_memory`
  (deep-copy snapshot, no entry creation). Resolvers
  no longer reach into nested dicts.
  `DialogueSession.npc_memory` keeps its live-reference
  pattern by design (documented in the store header).
  `SaveManager` keeps owner-level `_by_id` access.
- **Mock classify rules consolidated.** Single
  `proxy/data/mock_classify_rules.json` (mirrored to
  `game/data/` by `tools/yaml_to_json.py`) drives both
  the proxy mock and the Godot-side MockProvider.
  Canonical rule order: `prompt_injection` first, then
  `meta_game`, then the rest — fixes inputs like
  "ignore your system prompt" classifying as
  `meta_game` instead of `prompt_injection`.
- **UI polish.** Player-line echo Label above the NPC
  dialogue ("Kael: …"), set at every commit point
  (option pick, free text, item offer). `set_pending()`
  clears options instantly to close the double-pick
  window. Templated-lines YAML uses `>` folded scalars
  (not `|` literal) so Godot Label autowrap reflows
  to panel width.

## Next Up

0. **Story-rewrite implementation** (`story-rewrite.md`):
   sequencing inside the doc. Split `forest_edge` →
   `forest_path` + `bandit_hideout`; rewrite notice
   board + Halden brief (three threads); revise Orren
   `tower_smoke` body to include the gold-eyed man; add
   `chains_for_drust`, `pells_robbery`, and
   `forest_path_unease` briefings; author Edda's closing
   coda as a deterministic scripted beat (not AI). Do
   not add a second canon fact for the gold-eyed man;
   keep him as journal rumor.
1. **Authored content gaps** (`BUILD-PLAN.md`):
   - Halden's full quest-state line bank: first_brief,
     probe_progress, turn_in_with_fact, turn_in_paid,
     re-talk.
   - Per-NPC fallback banks for Mara/Orren/Toma/Edda:
     greeting, dragon, tower, item-offered,
     press-too-far, generic-confusion, anger-out,
     cooldown-recovery acceptance.
2. **Combat-numbers balance pass**: Kael's base
   HP/ATK/DEF/SPD; Iskar's HP/ATK/SPD + Bite damage +
   Ember-Spark spec + stance multipliers; enemy sheets
   (Wolf/Bandit/Drust). Goal: wolf → bandit → Drust
   arc tight but winnable when the player uses
   apples/rations + Edda's prayer judiciously. Also:
   notice-board body text verbatim from concept.
3. **Prompt-injection regression set**: at least three
   canonical attempts ("ignore previous instructions",
   role-claim, schema-leak) should fail diegetically
   on every NPC.
4. **Offline acceptance run** with the proxy stopped —
   confirm quest completable on Mock + Fallback only.

## Open Questions

- **Free-text classification cost.** Concept says
  "no hard caps in the demo," but a curious player can
  burn budget on Toma. AI player-suggestions add a
  second generate call per turn on opted-in topics,
  roughly doubling per-turn token cost. When a throttle
  lands, it should degrade suggestions (fall back to
  authored) before degrading the NPC reply.
- **AI player-suggestion rollout.** Only Orren is opted
  in. Decide per-NPC which topics get `ai_suggested` vs
  stay authored — especially Toma (false-rumor showcase
  — suggestions must not let the LLM "see through"
  Toma's lie since Kael can't).
- **Latency UX.** With two serial calls per turn,
  options can take 4–6s on a slow network. Watch
  whether "..." placeholders feel patient or inert; if
  inert, consider a soft animation cycle.
- **Prompt-injection blocked-response style per NPC.**
  Author one per archetype, or share a generic "I don't
  take orders from strangers" across all?

## Architecture Decisions

- **One LLM call per turn for the NPC line**, plus one
  classify call when input is free text. Authored
  options skip the classify call entirely.
  (CONCEPT.md §"Pipeline shape")
- **AI player-reply suggestions are a SEPARATE call**
  with Kael-only context. Bundling NPC reply +
  suggestions in one call was rejected on isolation
  grounds: any leak between the NPC's private dossier
  and Kael's response surface would let secret
  briefings reach the player even when the NPC is
  dodging. Cost is the price of safety; throttle
  degrades suggestions first.
- **Proxy holds the Anthropic key**; Godot never sees
  it. Key lives only in the proxy process environment.
- **LocalProxyProvider creates a fresh `HTTPRequest`
  per call.** Sharing a single node scrambled
  overlapping `request_completed` signals.
- **`_extract_json`** prefers fenced blocks, then a
  balanced-brace scan that respects string literals.
  Greedy `\{.*\}` misfired on decorative trailing
  braces.
- **Save format**: single JSON file at
  `user://save_slot_1.json` with a `version` field.
  Multi-slot out of scope. Writes are atomic
  (write `.tmp`, then `DirAccess.rename` within
  `user://` — POSIX-atomic on macOS). Newer-than-build
  saves are refused; older saves go through
  `_migrate(blob, from_version)`. NPC memory is
  re-defaulted from the profile and saved fields
  overlaid, so new fields default in.
- **Facing rules.** Movement 8-directional, facing
  4-cardinal. Facing rotates on any directional input
  including blocked moves (responsive over conservative).
  Diagonals collapse via last-cardinal-pressed. NPCs +
  Kael face each other on `dialogue_opened` and keep
  the facing on close (snapping back read as the NPC
  ignoring the player). Interaction stays 8-neighbour,
  not facing-gated. Combat overlay owns its own pose
  layout — overworld facing does not leak in.
- **Briefing reveals are gated by the NPC's dossier
  AND the per-NPC `forbidden_to_share` flag.** Rejected
  reveals are silently dropped; the dialogue line still
  plays. Intentional — the model can dodge in character
  without being caught lying.
- **World-item pickups grant facts directly via the
  engine**, not through an LLM reveal. The bandit
  note's `facts_unlocked_on_reveal` only fires if an
  NPC reveals its contents to another NPC (out of
  scope for the demo).
- **Save points are between turns only.** `SaveBlocker`
  refuses while combat or a dialogue/journal turn is
  in flight. A 30s watchdog on `DialogueController._busy`
  force-resets the flag if the turn never completes,
  preventing a permanent softlock.
- **`PlayerController.MOVE_DURATION` and
  `IskarFollower.MOVE_DURATION` must move in lockstep.**
  Iskar tweens independently on `player_moved`, so a
  mismatch makes him snap fast then idle.

## Session Notes

- Phase10Test's `_test_save_hardening` block prints
  one expected `ERROR: save is newer than build` line
  when run headless — that's the refusal path firing
  on purpose. The next assertion confirms the refused
  load did not mutate in-memory state.
- The codebase has both an in-process MockProvider
  (`game/scripts/ai/MockProvider.gd`) and a proxy
  MockProvider (`proxy/providers/mock.py`). They share
  rule tables (`mock_classify_rules.json`,
  `mock_responses.json`) but byte-identical responses
  are not guaranteed.
- DebugOverlay is autoloaded but hidden by default.
  Toggle with the backtick key in-game.
- After regenerating placeholder PNGs, run
  `godot --headless --import` once or `.godot/imported/*.ctex`
  may render tiles at the old size.
