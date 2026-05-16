"""
Request/response schemas for the Aurelix AI proxy.

The proxy speaks one shape. Both Mock and Anthropic providers must produce
responses that validate against `AiResponse`. The game's ResponseValidator
on the Godot side enforces the same contract.
"""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Generate (NPC dialogue) endpoint
# ---------------------------------------------------------------------------

class BriefingSlice(BaseModel):
    """A briefing as it appears in a prompt: id, tier, body, and the
    forbidden_to_share flag scoped to this NPC.

    `reveal_note` is an authored in-fiction condition on a forbidden
    briefing. When non-empty, the model may include this briefing's id
    in `revealed_briefing_ids` if it judges the conversation has
    satisfied the note. ResponseValidator opens a soft acceptance path
    (independent of `reveal_ready` from the deterministic press gate)
    for briefings carrying a `reveal_note`. Empty string means the only
    way to reveal is the deterministic keyword path."""
    id: str
    tier: str
    body: str
    forbidden_to_share: bool = False
    reveal_note: str = ""


class ConversationTurn(BaseModel):
    role: Literal["player", "npc"]
    text: str


class CapabilityGateResult(BaseModel):
    decision: Literal["allowed", "blocked", "constrained"]
    reason: str = ""
    failure_style: str = ""


class NpcProfileSlice(BaseModel):
    """Compact NPC profile the model sees. Not the full YAML."""
    id: str
    display_name: str
    archetype: str
    traits: list[str] = []
    speech_style: str = ""
    failure_style: str = ""
    max_response_length: str = "short"
    # Free-form natural-language voice constraints. Each entry is a single
    # behavioral rule that should colour the NPC's lines (e.g. "Sober,
    # refuses to discuss the tower; drunk, may hint with care"). Sits
    # alongside `traits` but speaks to behavior rather than personality.
    # Authored under `behavior_notes:` on the NPC YAML.
    behavior_notes: list[str] = []


class AiRequest(BaseModel):
    """One NPC dialogue turn."""
    npc_id: str
    npc_profile: NpcProfileSlice
    state_paragraph: str = ""
    memory_summary: str = ""
    retrieved_briefings: list[BriefingSlice] = []
    last_turns: list[ConversationTurn] = []
    player_input: str
    verb: Literal["ask", "press", "change_subject", "offer_item"] = "ask"
    topic_addressed: str
    capability_gate_result: CapabilityGateResult


class AiResponse(BaseModel):
    """One NPC dialogue turn response."""
    dialogue: str
    tone: str = "neutral"
    topic_addressed: str
    memory_update: str = ""
    revealed_briefing_ids: list[str] = []
    # Non-canon rumor facts the NPC volunteers. The engine grants these via
    # FactLedger iff each id resolves to a fact with canon: false. Unlike
    # revealed_briefing_ids (canon, gated by capability + dossier), claims
    # are talk: rumors, hearsay, things the NPC believes but the world has
    # not confirmed. The validator enforces canon: false so the model can
    # never sneak a canon fact through this channel.
    claims: list[str] = []
    request_end_conversation: bool = False
    # Defense-in-depth signal the model raises when a player input slipped
    # past the cheap classify pre-check. When set, ResponseValidator drops
    # `dialogue` and DialogueController routes to FallbackProvider's
    # scripted line for the same category. "" = normal response.
    safety_flag: Literal["", "out_of_context", "offensive"] = ""
    # Soft-reveal opt-in: when true, the model is asserting that any ids
    # listed in `revealed_briefing_ids` were judged eligible against the
    # briefing's `reveal_note`. ResponseValidator's soft-reveal path
    # requires this flag to be true — without it only the deterministic
    # press-keyword path can grant a reveal. The Mock provider leaves
    # this false by default so its canned entries cannot inadvertently
    # bypass the deterministic angle gate (Phase5Test relies on that).
    reveal_intent: bool = False


# ---------------------------------------------------------------------------
# Classify-topic endpoint
# ---------------------------------------------------------------------------

class ClassifyTopicRequest(BaseModel):
    text: str
    known_topics: list[str] = Field(default_factory=list)


class ClassifyTopicResponse(BaseModel):
    topic_id: str
    confidence: float = 0.5
    # Cheap pre-LLM guardrail. "in_game" = ordinary classified topic; the
    # generate pipeline runs normally. "out_of_context" = the player said
    # something the game world cannot answer (real-world places, modern
    # tech, current events) — DialogueController short-circuits to a
    # scripted line and does NOT mutate NPC state. "offensive" = grave
    # slur / explicit content — short-circuits to a scripted line and
    # triggers AngerCooldownResolver. Medium-severity rudeness stays
    # in_game so the NPC can react organically per their personality.
    category: Literal["in_game", "out_of_context", "offensive"] = "in_game"


# ---------------------------------------------------------------------------
# Suggest-player-options endpoint
#
# Strict context isolation: this request carries only what Kael (the player)
# legitimately knows. The speaking NPC's dossier, memory, and forbidden
# briefings MUST NOT appear here. Mixing the two contexts in one model call
# would let an NPC's secret leak into Kael's mouth.
# ---------------------------------------------------------------------------

class PlayerKaelContext(BaseModel):
    """Kael's own knowledge. Public information from the player's POV."""
    known_facts: list[str] = Field(default_factory=list)
    quest_summary: str = ""
    journal_excerpts: list[str] = Field(default_factory=list)


class PlayerSuggestionsRequest(BaseModel):
    """Inputs for generating Kael's reply suggestions after an NPC speaks."""
    npc_display_name: str
    npc_archetype: str = ""
    last_npc_line: str
    last_turns: list[ConversationTurn] = Field(default_factory=list)
    kael_context: PlayerKaelContext = Field(default_factory=PlayerKaelContext)
    topic_addressed: str = ""
    # Non-empty when the NPC has visibly dodged this topic in the recent
    # turns. Public information from Kael's POV (a dodge is something Kael
    # can observe). Lets the model produce one pressing suggestion that
    # returns to the topic from a fresh angle. The engine's PressDetector
    # then turns the player's pick into verb=press if the wording lands on
    # an authored angle keyword.
    npc_just_dodged_topic: str = ""
    # Authored Kael-side observations about the NPC's body language for the
    # dodged topic — e.g. "Orren's eyes flick toward the reeve's office when
    # the tower comes up." Strict isolation: these are public observations
    # by design (NpcProfileRegistry.public_tells_for guarantees only the
    # `public_tell` field escapes). The model uses them to land one
    # suggestion on the specific lever the player can press.
    public_tells: list[str] = Field(default_factory=list)


class PlayerSuggestion(BaseModel):
    intent: Literal["strategic", "tactical", "dismissive"]
    text: str


class PlayerSuggestionsResponse(BaseModel):
    """0..3 suggestions. Each direction is optional; model may omit any."""
    suggestions: list[PlayerSuggestion] = Field(default_factory=list, max_length=3)
