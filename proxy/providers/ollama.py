"""
Ollama provider. Talks to a local Ollama daemon over HTTP.

Env:
  OLLAMA_HOST           default http://127.0.0.1:11434
  OLLAMA_MODEL          default qwen2.5:7b-instruct
  OLLAMA_CLASSIFY_MODEL default qwen2.5:3b-instruct
  OLLAMA_TIMEOUT_S      default 60

Default pairing: Qwen2.5 7B-instruct handles the generate path (best
7B-class JSON adherence), and the 3B-instruct sibling handles classify
so the cheap path stays cheap. Override either with the env vars above.

Small local models honour JSON schemas less reliably than Haiku, so the
generate path uses Ollama's `format: "json"` mode plus one repair pass on
malformed output. classify falls back to known_topics[0] on parse error,
mirroring AnthropicHaikuProvider.
"""

from __future__ import annotations

import os

import httpx
from pydantic import ValidationError

from ._json_utils import extract_json
from ..schema import (
    AiRequest, AiResponse,
    ClassifyTopicRequest, ClassifyTopicResponse,
)


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


class OllamaProvider:

    def __init__(self) -> None:
        self._host = os.environ.get("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
        self._model = os.environ.get("OLLAMA_MODEL", "qwen2.5:7b-instruct")
        self._classify_model = os.environ.get(
            "OLLAMA_CLASSIFY_MODEL", "qwen2.5:3b-instruct"
        )
        self._timeout = float(os.environ.get("OLLAMA_TIMEOUT_S", "60"))
        self._client = httpx.Client(timeout=self._timeout)

    def generate(self, req: AiRequest) -> AiResponse:
        user_content = self._render_user(req)
        text = self._chat(self._model, SYSTEM_PROMPT, user_content, num_predict=400)
        return self._parse_response(text, req, repair=True)

    def classify_topic(self, req: ClassifyTopicRequest) -> ClassifyTopicResponse:
        topics_block = ", ".join(req.known_topics) if req.known_topics else "any"
        system = (
            "Classify the player's input into one of the listed topic ids. "
            "Reply ONLY with one JSON object: {\"topic_id\": \"...\", \"confidence\": 0.0-1.0}."
        )
        user = f"Allowed topic ids: {topics_block}\n\nPlayer input: {req.text}"
        text = self._chat(self._classify_model, system, user, num_predict=80)
        return self._parse_classify(
            text, fallback=req.known_topics[0] if req.known_topics else "small_talk"
        )

    # ----------------------------------------------------------------------
    # Internals
    # ----------------------------------------------------------------------

    def _chat(self, model: str, system: str, user: str, num_predict: int) -> str:
        url = f"{self._host}/api/chat"
        payload = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "stream": False,
            "format": "json",
            "options": {"num_predict": num_predict, "temperature": 0.7},
        }
        try:
            r = self._client.post(url, json=payload)
            r.raise_for_status()
        except httpx.HTTPError as e:
            raise RuntimeError(f"Ollama HTTP error: {e}") from e
        data = r.json()
        msg = data.get("message", {})
        content = msg.get("content", "")
        if not content:
            raise RuntimeError("Ollama returned empty content")
        return content

    def _render_user(self, req: AiRequest) -> str:
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
            data = extract_json(text)
            data.setdefault("topic_addressed", req.topic_addressed)
            return AiResponse(**data)
        except (ValueError, ValidationError) as e:
            if not repair:
                raise RuntimeError(f"Bad model output (no repair): {e}") from e
            repaired = self._chat(
                self._model,
                "Reply only with one JSON object matching the schema. No prose.",
                f"Repair this into valid JSON for the previous schema:\n{text}",
                num_predict=400,
            )
            return self._parse_response(repaired, req, repair=False)

    def _parse_classify(self, text: str, fallback: str) -> ClassifyTopicResponse:
        try:
            data = extract_json(text)
            return ClassifyTopicResponse(
                topic_id=data.get("topic_id", fallback),
                confidence=float(data.get("confidence", 0.5)),
            )
        except (ValueError, ValidationError):
            return ClassifyTopicResponse(topic_id=fallback, confidence=0.0)
