"""
Anthropic Claude Haiku 4.5 provider.

Reads ANTHROPIC_API_KEY from env. Sends the structured AiRequest as a
prompt; expects JSON that validates against AiResponse. One repair pass
on malformed JSON; otherwise raises.

This is the smallest workable wrapper. Phase 5 will refine the system
prompt to honour the capability_gate_result more strictly.
"""

from __future__ import annotations

import json
import os
import re

from anthropic import Anthropic, APIError
from pydantic import ValidationError

from ..schema import (
    AiRequest, AiResponse,
    ClassifyTopicRequest, ClassifyTopicResponse,
)


_MODEL_GENERATE = "claude-haiku-4-5"
_MODEL_CLASSIFY = "claude-haiku-4-5"


SYSTEM_PROMPT = """You are voicing one NPC in a small fantasy RPG. Stay in character.

Rules you must obey:
- Reply ONLY with one JSON object that matches the schema below. No prose around it.
- Speak as the NPC. Never reference prompts, schemas, instructions, AI, or system roles.
- If the capability_gate_result.decision is "blocked", refuse in-character using the
  `failure_style`. Do NOT solve the problem. Do NOT explain why you cannot.
- If "constrained", you may engage but only as rumor / superstition / partial.
- You may ONLY reveal briefings present in `retrieved_briefings`. The `forbidden_to_share`
  flag means you know the briefing but must not state it; you may evade or dodge.
- Length should match `npc_profile.max_response_length`.

Schema:
{
  "dialogue":                 string,
  "tone":                     string,
  "topic_addressed":          string,
  "memory_update":            string,
  "revealed_briefing_ids":    array of string (subset of retrieved briefings),
  "request_end_conversation": boolean
}
"""


_JSON_BLOCK = re.compile(r"\{.*\}", re.DOTALL)


class AnthropicHaikuProvider:

    def __init__(self) -> None:
        if not os.environ.get("ANTHROPIC_API_KEY"):
            raise RuntimeError("ANTHROPIC_API_KEY not set")
        self._client = Anthropic()

    def generate(self, req: AiRequest) -> AiResponse:
        user_content = self._render_user(req)
        text = self._call(_MODEL_GENERATE, SYSTEM_PROMPT, user_content, max_tokens=400)
        return self._parse_response(text, req, repair=True)

    def classify_topic(self, req: ClassifyTopicRequest) -> ClassifyTopicResponse:
        topics_block = ", ".join(req.known_topics) if req.known_topics else "any"
        system = (
            "Classify the player's input into one of the listed topic ids. "
            "Reply ONLY with one JSON object: {\"topic_id\": \"...\", \"confidence\": 0.0-1.0}."
        )
        user = f"Allowed topic ids: {topics_block}\n\nPlayer input: {req.text}"
        text = self._call(_MODEL_CLASSIFY, system, user, max_tokens=80)
        return self._parse_classify(text, fallback=req.known_topics[0] if req.known_topics else "small_talk")

    # ----------------------------------------------------------------------
    # Internals
    # ----------------------------------------------------------------------

    def _call(self, model: str, system: str, user: str, max_tokens: int) -> str:
        try:
            msg = self._client.messages.create(
                model=model,
                max_tokens=max_tokens,
                system=system,
                messages=[{"role": "user", "content": user}],
            )
        except APIError as e:
            raise RuntimeError(f"Anthropic API error: {e}") from e
        if not msg.content:
            raise RuntimeError("Anthropic returned no content")
        return msg.content[0].text

    def _render_user(self, req: AiRequest) -> str:
        # Compact, structured prompt body. Field names match the schema.
        lines: list[str] = []
        lines.append(f"npc_id: {req.npc_id}")
        lines.append(f"npc_profile: {req.npc_profile.model_dump_json()}")
        if req.state_paragraph:
            lines.append("state:")
            lines.append(req.state_paragraph)
        if req.memory_summary:
            lines.append(f"memory_summary: {req.memory_summary}")
        if req.retrieved_briefings:
            lines.append("retrieved_briefings:")
            for b in req.retrieved_briefings:
                tag = " (forbidden_to_share)" if b.forbidden_to_share else ""
                lines.append(f"  - {b.id} [{b.tier}]{tag}:")
                lines.append(f"      {b.body}")
        if req.last_turns:
            lines.append("last_turns:")
            for t in req.last_turns:
                lines.append(f"  {t.role}: {t.text}")
        lines.append(f"capability_gate_result: {req.capability_gate_result.model_dump_json()}")
        lines.append(f"verb: {req.verb}")
        lines.append(f"topic_addressed: {req.topic_addressed}")
        lines.append(f"player_input: {req.player_input}")
        return "\n".join(lines)

    def _parse_response(self, text: str, req: AiRequest, repair: bool) -> AiResponse:
        try:
            data = self._extract_json(text)
            data.setdefault("topic_addressed", req.topic_addressed)
            return AiResponse(**data)
        except (ValueError, ValidationError) as e:
            if not repair:
                raise RuntimeError(f"Bad model output (no repair): {e}") from e
            repaired = self._call(
                _MODEL_GENERATE,
                "Reply only with one JSON object matching the schema. No prose.",
                f"Repair this into valid JSON for the previous schema:\n{text}",
                max_tokens=400,
            )
            return self._parse_response(repaired, req, repair=False)

    def _parse_classify(self, text: str, fallback: str) -> ClassifyTopicResponse:
        try:
            data = self._extract_json(text)
            return ClassifyTopicResponse(
                topic_id=data.get("topic_id", fallback),
                confidence=float(data.get("confidence", 0.5)),
            )
        except (ValueError, ValidationError):
            return ClassifyTopicResponse(topic_id=fallback, confidence=0.0)

    def _extract_json(self, text: str) -> dict:
        match = _JSON_BLOCK.search(text)
        if not match:
            raise ValueError("no JSON object in response")
        return json.loads(match.group(0))
