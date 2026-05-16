# AI Workflow Rules

## Approach

Build this project incrementally against the phased plan
in `BUILD-PLAN.md` (Phases 1–10). The six context files
in this folder define what to build, how to build it,
and the current state of progress. Long-form rationale
lives in `CONCEPT.md`, `ARCHITECTURE.md`, and
`NPC-INTELLIGENCE.md` at the repo root — read those when
a context file is ambiguous, not when context is
sufficient.

Implement against specs. When the spec is missing,
write one (or add an open question to
`progress-tracker.md`) before coding. Do not infer
product behavior from a vague prompt.

## Scoping Rules

- Work on one feature unit at a time.
- A unit is one verifiable outcome: a single NPC's
  Press flow, one combat encounter type, one
  dossier mutation event. Not "polish the dialogue
  system" or "improve combat."
- Prefer small, verifiable increments over large
  speculative changes. The codebase is small
  enough that drift compounds quickly.
- Do not combine unrelated system boundaries in a
  single implementation step.

## When to Split Work

Split an implementation step if it combines:

- A new autoload singleton AND the gameplay that
  uses it. Land the autoload first with a smoke
  test; wire callers in a second step.
- Engine state changes (registry shape, save
  schema) AND new dialogue or combat behavior.
  Engine first, then behavior.
- Proxy schema changes AND Godot consumer
  changes. Land the proxy with a passing curl
  test; then update GDScript.
- UI rework AND the underlying state machine.
  Build the state machine headless; then attach
  the UI.
- Authored data changes (briefings, dossiers,
  facts) AND code that reads them. Authored data
  is the source of truth — land it first, run
  `BootValidator`, then write the code.

If a change cannot be verified end to end quickly,
the scope is too broad — split it.

## Handling Missing Requirements

- Do not invent NPC behavior, faction reactions,
  combat numbers, or fact-unlock flows that are
  not present in `data/`, `CONCEPT.md`, or
  `BUILD-PLAN.md`. `BUILD-PLAN.md`'s "Authored
  content the plan will need supplemented" section
  is the canonical list of known gaps.
- If a requirement is ambiguous, resolve it in the
  relevant context file (or `CONCEPT.md` for design
  intent) before implementing.
- If a requirement is missing, add it to
  `progress-tracker.md` under Open Questions and
  pause until it is resolved.
- For LLM behavior gaps: the deterministic path
  always wins. When in doubt, gate harder
  (`CapabilityGate`), validate stricter
  (`ResponseValidator`), and fall back to authored
  lines (`FallbackProvider`).

## Protected Files

Do not modify the following unless explicitly
instructed:

- `game/data/` (runtime JSON) — regenerated from
  `data/` via `tools/yaml_to_json.py`.
- `game/scripts/test/` — test harnesses and preview
  generators. Touch only when changing the test
  scenario itself.
- `proxy/__pycache__/`, `tools/__pycache__/`,
  `game/.import/` — generated.
- `game/*.png.import` — Godot import metadata; let
  the editor manage these.
- Long-form design docs at the repo root
  (`CONCEPT.md`, `ARCHITECTURE.md`,
  `NPC-INTELLIGENCE.md`, `BUILD-PLAN.md`,
  `REVIEW_GUIDE.md`) — these are reference. Update
  them only when a real design decision has shifted.
- Anthropic API keys and any `.env` files — never
  commit, never log.

## Keeping Docs in Sync

Update the relevant context file whenever
implementation changes:

- A new autoload or a change to autoload order →
  `architecture.md` (System Boundaries).
- A new save field, version bump, or migration →
  `architecture.md` (Storage Model) and
  `code-standards.md` (Save and State Rules).
- A new UI overlay or layout change → `ui-context.md`.
- A new GDScript pattern adopted across files
  (e.g. a different way to await provider responses)
  → `code-standards.md`.
- Any scope change (in/out) → `project-overview.md`.
- Any new feature, completed phase, resolved open
  question → `progress-tracker.md` (every session).

## Before Moving to the Next Unit

1. The current unit works end to end within its
   defined scope. For dialogue: run with `use_mock_ai
   = true` AND with the proxy live; both paths
   produce a valid dialogue line. For combat: a full
   encounter completes without softlock.
2. No invariant defined in `architecture.md` was
   violated. In particular: model output never
   directly mutated canon; `LocalProxyProvider` did
   not share an `HTTPRequest`; no Anthropic key
   leaked into Godot.
3. `BootValidator` runs clean in headless mode.
4. The relevant test harness under
   `game/scripts/test/` (Phase 3..10 tests +
   `PlaythroughTour`) still passes.
5. With the proxy stopped, the game still runs
   on Mock + Fallback. Try this at least once per
   unit.
6. `progress-tracker.md` reflects the completed
   work, any new open questions, and the next
   unit to start.
