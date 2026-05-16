# ARCHITECTURE

## Purpose

This document describes a starting technical architecture for a small, non-commercial 2D RPG for macOS with AI-powered NPC interaction.

The target is a classic 2D RPG: a small world, authored quests, tile-based maps, simple inventory, and text-driven NPC conversations. The AI layer should make selected NPCs feel more alive without allowing the language model to become the game engine, quest designer, or source of truth.

## Goals

- Run well on macOS.
- Be approachable for solo indie development and vibe coding.
- Keep the core game deterministic and debuggable.
- Allow AI-powered NPC dialogue through interchangeable providers.
- Avoid hard dependency on any single LLM provider.
- Support offline or mock-mode development.
- Keep quest and world state under game-engine control.

## Non-goals

- Massively multiplayer support.
- Fully dynamic quest generation.
- AI-controlled game rules.
- Shipping a large local model inside the game.
- Commercial-scale backend infrastructure.
- Perfect protection against all prompt injection or model failures.

## Recommended Stack

### Game Engine

**Godot 4**

Godot is the recommended engine for this project because it is strong for 2D games, lightweight enough for a small indie project, runs well on macOS, and supports fast iteration.

Recommended language:

```text
GDScript
```

GDScript is suitable for vibe coding because it is compact, readable, and close enough to Python-like pseudocode that AI coding tools tend to produce understandable output.

### Runtime Platform

Primary target:

```text
macOS desktop
```

Possible future targets:

```text
Windows
Linux
Web export, if AI provider constraints allow it
```

### AI Integration Strategy

The game should not call every AI provider directly from every NPC script. Instead, use a small internal AI abstraction layer.

Recommended structure:

```text
Godot Game
  ↓
AiService singleton
  ↓
CapabilityGate
  ↓
PromptBuilder
  ↓
ProviderAdapter
  ↓
ResponseValidator
  ↓
Dialogue UI / Game Logic
```

The language model may generate dialogue, but the game engine decides what is true and what changes in the world.

## High-level Module Layout

Suggested repository structure:

```text
/game
  /scenes
    /world
      Village.tscn
      Forest.tscn
    /actors
      Player.tscn
      Npc.tscn
    /ui
      DialogueBox.tscn
      InventoryPanel.tscn
      QuestLog.tscn

  /scripts
    /core
      GameState.gd
      SaveManager.gd
      EventBus.gd
      Config.gd

    /player
      PlayerController.gd
      Inventory.gd

    /npc
      NpcController.gd
      NpcRegistry.gd
      NpcDialogueBrain.gd
      NpcMemory.gd
      NpcProfile.gd

    /ai
      AiService.gd
      AiRequest.gd
      AiResponse.gd
      PromptBuilder.gd
      CapabilityGate.gd
      ResponseValidator.gd
      ConversationSummarizer.gd

    /ai/providers
      AiProvider.gd
      MockProvider.gd
      LocalProxyProvider.gd
      OpenAIProvider.gd
      AnthropicProvider.gd

    /quests
      QuestState.gd
      QuestRegistry.gd
      QuestRuleEngine.gd

    /dialogue
      DialogueSession.gd
      DialogueRenderer.gd
      DialogueAction.gd

  /data
    /npc
      child_toma.json
      drunk_orren.json
      blacksmith_mara.json
    /quests
      dragon_sighting.json
    /lore
      world_facts.json
```

## Core Design Rule

The LLM can speak, but it cannot directly mutate game state.

All model output should be treated as a proposal. The game must validate any proposed action before applying it.

Examples of model output that must be validated:

```text
Give item
Start quest
Complete quest
Reveal fact
Change relationship
Move NPC
Change price
Open door
Trigger cutscene
```

The model should never be able to invent an item, grant experience, mark a quest complete, or reveal secret lore unless the deterministic game layer approves it.

## Game State

The game state is the authoritative source of truth.

It should include:

```text
Player location
Inventory
Quest states
Known facts
NPC relationship values
NPC memory summaries
World flags
Time of day, if used
Visited locations
Completed events
```

Example:

```json
{
  "player": {
    "location": "village_square",
    "inventory": ["rusty_sword", "apple"],
    "known_fact_ids": ["dragon_seen_near_old_tower"]
  },
  "quests": {
    "dragon_sighting": {
      "state": "active",
      "steps_completed": ["ask_villagers"]
    }
  },
  "npcs": {
    "orren_drunk": {
      "relationship": -1,
      "memory_summary": "Player asked about the dragon. Orren was evasive and drunk."
    }
  }
}
```

## NPC Data Model

NPCs should be defined mostly as data, not hardcoded behavior.

Example:

```json
{
  "id": "orren_drunk",
  "display_name": "Orren",
  "archetype": "village_drunk",
  "location": "village_square",
  "persona": {
    "age": 53,
    "occupation": "former stablehand",
    "temperament": ["bitter", "tired", "superstitious"],
    "goals": ["avoid work", "get more ale", "hide what he saw near the old tower"],
    "fears": ["the dragon", "being mocked", "the reeve"]
  },
  "capabilities": {
    "literacy": "none",
    "numeracy": "basic",
    "academic_reasoning": "none",
    "local_knowledge": "medium",
    "dragon_knowledge": "rumor_only",
    "reliability": "low"
  },
  "known_fact_ids": [
    "orren_saw_smoke_near_old_tower",
    "orren_heard_wings_at_night"
  ],
  "forbidden_fact_ids": [
    "dragon_true_weakness",
    "cult_leader_identity"
  ]
}
```

## AI Request Flow

A typical NPC interaction should follow this flow:

```text
1. Player starts conversation.
2. Game creates DialogueSession.
3. Player enters text or selects a prompt.
4. CapabilityGate classifies the player's request.
5. Game checks whether this NPC can plausibly answer.
6. PromptBuilder assembles the model context.
7. AiService sends request to configured provider.
8. ResponseValidator checks structure, safety, and game constraints.
9. Dialogue UI displays approved dialogue.
10. Game applies only approved, deterministic actions.
```

## Capability Gate

The CapabilityGate prevents every NPC from behaving like a genius assistant.

It should classify the player's input into domains such as:

```text
Small talk
Local gossip
Quest hint
Trade
Personal history
Abstract reasoning
Formal math
Magic theory
Combat strategy
Forbidden lore
Meta-game question
Attempted prompt injection
```

Then it compares the requested domain against the NPC's profile.

Example:

```text
Player: "What are the roots of x² + 5x + 6?"
NPC: village child
CapabilityGate result: blocked_academic_reasoning
Response mode: in-character confusion
```

The model may still be used to produce the in-character failure response, but it should not be asked to solve the math problem.

## Prompt Builder

The PromptBuilder should assemble compact prompts from structured state.

A prompt should include:

```text
NPC identity
NPC archetype
Current scene
Conversation summary
Relevant world facts
Allowed knowledge
Forbidden knowledge
Player's latest message
Required output schema
```

Avoid sending the entire world bible every time. Use retrieved facts only.

## Response Format

Prefer structured responses from the AI provider.

Example:

```json
{
  "dialogue": "Old tower? No. Don't know anything about that. Ask the crows, maybe they saw more than me.",
  "emotional_state": "nervous",
  "confidence": "low",
  "claimed_fact_ids": ["old_tower_is_dangerous"],
  "requested_actions": [],
  "memory_update": "Orren became nervous when the player mentioned the old tower."
}
```

The game should validate:

```text
Is the JSON valid?
Is the dialogue acceptable for the game's content mode?
Are claimed facts allowed?
Are requested actions valid?
Does the NPC have permission to know or reveal this?
```

## Provider Abstraction

Use a provider interface so the rest of the game does not care whether the AI is powered by OpenAI, Anthropic, a local service, or a mock provider.

Example interface:

```text
AiProvider.generate(request: AiRequest) -> AiResponse
```

Provider implementations:

```text
MockProvider
LocalProxyProvider
OpenAIProvider
AnthropicProvider
```

### MockProvider

The MockProvider should be the first implementation.

Benefits:

```text
No API key required
No network dependency
Easy testing
Predictable responses
Cheap development
```

### LocalProxyProvider

A local proxy is recommended for serious AI integration.

```text
Godot game → localhost AI proxy → external model provider
```

The proxy can handle:

```text
API keys
Provider-specific SDKs
Retries
Streaming
Logging controls
Rate limits
Model selection
Token budgeting
Schema repair
```

This keeps Godot code simpler and reduces provider-specific coupling.

Possible proxy stack:

```text
Python + FastAPI
or
Node.js + TypeScript
```

For a solo project, Python is likely the easiest choice because it is simple and has strong AI SDK support.

## API Key Handling

For a non-commercial indie game, the simplest model is user-provided API credentials.

Rules:

```text
Do not hardcode developer API keys.
Do not log user API keys.
Do not send user API keys to your own server unless absolutely necessary.
Do not include keys in crash reports.
Store keys only in local user configuration or OS keychain if practical.
Provide a clear "AI calls may cost money" warning.
Support disabling AI completely.
```

If using a local proxy, the key can be stored in the proxy's local environment or config file rather than inside Godot project files.

## Memory Strategy

Do not keep unlimited raw conversation history.

Use a layered memory model:

```text
Recent messages: last few turns in full
Session summary: compact summary of current conversation
Long-term memory: selected facts about player/NPC relationship
Game facts: deterministic state stored separately
```

Memory should be saved per save file.

Example:

```json
{
  "npc_id": "orren_drunk",
  "recent_summary": "The player pressed Orren about the old tower. Orren denied knowledge but became nervous.",
  "relationship_delta": -1,
  "known_player_traits": ["persistent", "asked_about_dragon"]
}
```

## Quest Integration

Quest progression should be deterministic.

Bad:

```text
LLM decides whether the player has completed the quest.
```

Good:

```text
LLM produces dialogue.
Game checks whether required facts were revealed.
QuestRuleEngine updates quest state.
```

Example:

```text
If player learns fact_id = dragon_seen_near_old_tower
Then mark quest step "find_dragon_location" as complete
```

## Content and Safety

Even in a small fantasy RPG, model output needs boundaries.

Controls:

```text
Content mode: normal / stricter / debug
Profanity setting
Violence intensity setting
No sexual content with minors
No real-world extremist persuasion
No self-harm coaching
No personal data requests from NPCs
```

The model should stay inside the fictional world and should not become a real-world assistant unless explicitly placed in a debug mode.

## Debugging Tools

AI systems are hard to debug. Add tools early.

Useful debug UI:

```text
Show NPC profile
Show capability classification
Show facts injected into prompt
Show blocked facts
Show raw model response
Show validation errors
Replay last request
Switch provider at runtime
Force mock response
```

For normal players, hide this behind a developer setting.

## Failure Handling

The game must remain playable when AI fails.

Failure cases:

```text
No internet
Invalid API key
Provider rate limit
Provider refuses response
Malformed JSON
Timeout
Unexpected content
Model gives forbidden info
```

Fallback behavior:

```text
Use canned in-character fallback
Retry once if appropriate
Summarize failure in debug logs
Never block quest-critical progress behind unavailable AI
```

Example fallback:

```text
Orren squints at you, mutters something useless, and looks away.
```

## Development Milestones

### Milestone 1: Non-AI RPG Skeleton

```text
Player movement
One map
Three NPCs
Dialogue UI
Basic quest state
Save/load
```

### Milestone 2: Mock AI Layer

```text
AiService singleton
MockProvider
NPC profiles
CapabilityGate
Structured response format
```

### Milestone 3: Real Provider Prototype

```text
Local proxy
One external provider
API key config
Timeout/retry handling
Debug panel
```

### Milestone 4: Credible NPC Behavior

```text
NPC archetypes
Capability limits
In-character ignorance
Memory summaries
Quest fact validation
```

### Milestone 5: Playable Vertical Slice

```text
One village
One dragon-related quest
Three to five credible NPCs
Fallback mode
Save/load with NPC memory
```

## Recommended Initial Vertical Slice

Build one small village with three NPCs:

```text
Toma: village child
Orren: drunk former stablehand
Mara: blacksmith
```

One quest:

```text
Find out where the dragon was last seen.
```

The player can gather partial, unreliable, and domain-limited information from NPCs. The game engine determines which facts are real and when the quest advances.

## Open Questions

- Should the player type freely, select dialogue options, or both?
- Should AI dialogue be available for every NPC or only important NPCs?
- Should the game support offline play with authored fallbacks?
- Should the local proxy be bundled or optional?
- Should generated dialogue be stored permanently in save files?
- How strict should the content filter be?
- How much should NPCs remember across sessions?
- Should NPCs be allowed to lie, and how should the game distinguish lies from canon?

