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
    forbidden_to_share flag scoped to this NPC."""
    id: str
    tier: str
    body: str
    forbidden_to_share: bool = False


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
    request_end_conversation: bool = False


# ---------------------------------------------------------------------------
# Classify-topic endpoint
# ---------------------------------------------------------------------------

class ClassifyTopicRequest(BaseModel):
    text: str
    known_topics: list[str] = Field(default_factory=list)


class ClassifyTopicResponse(BaseModel):
    topic_id: str
    confidence: float = 0.5
