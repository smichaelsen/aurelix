# Code Standards

## General

- Keep modules small and single-purpose. The autoload
  list in `project.godot` is long on purpose — each
  service owns one responsibility.
- Fix root causes. Do not pile workarounds on top of
  unclear behavior. Trace through the autoload
  pipeline first.
- Do not mix unrelated concerns in one script. UI
  rendering, dialogue orchestration, persistence, and
  AI plumbing each live in their own folder.
- Never invent canon. If a behavior change implies a
  new fact, briefing, NPC capability, or quest state,
  it belongs in `data/`, not in code.
- Comments are rare. A comment explains *why* a line
  is non-obvious (a hidden invariant, an LLM quirk,
  a Godot footgun). Identifiers carry the *what*.

## GDScript

- Static types on every parameter and return value.
  `func foo(x: int) -> Dictionary`. Untyped GDScript
  is acceptable only when interfacing with Godot
  APIs that return `Variant`.
- Use `const` for autoload-relative resource paths
  and tuning constants at the top of the file.
- Prefer `await` over polling. Dialogue and HTTP
  pipelines are signal-driven; do not busy-wait.
- Guard signals with `is_connected()` before
  connecting if the connection could already exist.
  Disconnect on teardown for any object you do not
  control the lifetime of.
- Use `is_instance_valid()` when keeping a
  reference across frames — Godot can free a node
  out from under you.
- Cast to the expected type at the boundary
  (`int(blob.get("hp", 0))`) — JSON parses everything
  to `Variant`.

## Godot Project Structure

- New autoloads register in `project.godot`. Pick the
  load position carefully — registries before stores,
  stores before controllers, UI overlays last.
- Scenes under `game/scenes/` describe layout only.
  Scripts under `game/scripts/` own behavior. A scene
  may attach a script; a script must not embed
  layout literals beyond what the scene needs.
- World scenes (`village_square.tscn`,
  `forest_edge.tscn`) live in `scenes/`. UI scenes
  go in `scenes/ui/`. Test/preview harnesses go in
  `scenes/test/`. Do not load test scenes from
  shipping code paths.
- `EventBus` is the cross-cutting signal hub. Any
  cross-module communication goes through it; do
  not reach across folders by direct script reference
  when a signal will do.

## AI Pipeline Rules

- Only `ResponseValidator` writes facts, dossier
  mutations, and quest progression that originated
  from model output. Other modules call its public
  entry points; they do not unpack model JSON
  themselves.
- `CapabilityGate` decides allowed / blocked /
  constrained per turn. The gate's output is an
  input to `PromptBuilder`, never bypassed.
- `PromptBuilder` is the only place that constructs
  prompts. If a prompt change is needed, change it
  there — do not inline prompt fragments at the call
  site.
- `LocalProxyProvider` instantiates a fresh
  `HTTPRequest` per call and frees it on completion.
  Never share one node across `await`s.
- Topic ids, fact ids, briefing ids, and item ids
  are `snake_case`. They are referenced everywhere
  by string id — never hardcode display strings.
- The proxy's `_extract_json` is the one place that
  parses model output. Fenced blocks first, then a
  string-aware balanced-brace scan. Do not relax to
  a greedy regex.
- The Kael-side suggestion pipeline
  (`PlayerPromptBuilder`, `PlayerSuggestionGenerator`,
  `/v1/suggest_player_options`) must remain strictly
  context-isolated from the NPC pipeline. Do not pass
  the speaking NPC's profile, dossier entries, memory
  fields, or any briefing carrying `forbidden_to_share`
  into a suggestion request. The only NPC info this
  side may read is the public display name and
  archetype. Suggestions never write canon — no fact
  grants, memory updates, or dossier mutations.

## Save and State Rules

- Engine state lives in autoload singletons. The
  shape of `SaveManager._serialize()` is the
  contract — adding a new persistent field means
  adding a `_apply_*` restorer.
- Save writes must go through `SaveBlocker` first.
  Combat and in-flight AI requests block saves.
- Save file version is `SAVE_PATH` + `VERSION` in
  `SaveManager.gd`. Bumping `VERSION` requires an
  explicit migration path; the current loader only
  warns on mismatch and proceeds, which is a known
  gap (see progress-tracker).
- Never reach directly into `Inventory.bag`,
  `FactLedger._known`, etc. from outside the
  owning autoload. Route through the public API
  (`Inventory.add_item`, `FactLedger.grant_fact`,
  ...).

## Data and Storage

- Authored content lives in `data/`. The runtime
  reads from `game/data/` (JSON, produced by
  `tools/yaml_to_json.py`). Do not hand-author
  `game/data/` — regenerate.
- Briefings are markdown with YAML frontmatter.
  Pairs (witness + rumor) share an id, differ by
  tier, live in the same folder.
- NPC dossiers reference briefings by id. Every
  reference must resolve — `BootValidator` will
  reject unknown ids at boot.
- Save files are JSON at `user://save_slot_1.json`.
  Never write outside `user://`.
- Secrets live in the proxy's environment, never in
  the repo or in Godot project files.

## Proxy (Python) Conventions

- Pydantic models in `proxy/schema.py` are the
  canonical request/response shape. GDScript
  dataclasses mirror them.
- `from __future__ import annotations` at the top
  of every file.
- The Anthropic API key is read once in the
  provider constructor. Never re-read it elsewhere.
  Never log it; `observability.py` is explicit
  about what is loggable.
- One repair pass on malformed JSON, then raise.
  Recursion is bounded; AiService handles the
  fall-through to Mock.
- Iterate `msg.content` for a text block — do not
  index `[0]` blindly. Future SDK versions may
  return non-text leading blocks.

## File Organization

- `game/scenes/` — Godot `.tscn` files (layout).
- `game/scripts/<area>/` — GDScript by area: `core`,
  `ai`, `dialogue`, `npc`, `quests`, `combat`,
  `companion`, `player`, `world`, `journal`, `ui`,
  `test`.
- `game/assets/` — sprites, tilesets, fonts.
- `game/data/` — runtime JSON (generated; do not
  hand-edit).
- `data/` — authored YAML/Markdown (source of truth).
- `proxy/` — FastAPI app; `providers/` for provider
  implementations; `data/` for any proxy-side
  authored data.
- `tools/` — Python build-time scripts.
- Root: long-form design docs (`CONCEPT.md`,
  `ARCHITECTURE.md`, `NPC-INTELLIGENCE.md`,
  `BUILD-PLAN.md`, `REVIEW_GUIDE.md`), `CLAUDE.md`
  entry point, `context/` working summaries.
