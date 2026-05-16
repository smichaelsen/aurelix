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
    PlayerSuggestion, PlayerSuggestionsRequest, PlayerSuggestionsResponse,
)


SUGGEST_SYSTEM_PROMPT = """You are writing short reply suggestions for Kael, the player character, after an NPC just spoke.

You see ONLY what Kael knows: public dialogue, his own journal, and known facts. You never see the NPC's private dossier, secret briefings, or memory — and you must never invent details from them.

Return 0 to 3 suggestions, each tagged with one intent:
- "strategic":  a question or reply that advances the larger story / investigation.
- "tactical":   a reply that gains short-term ground in this conversation.
- "dismissive": a reply that politely or curtly ends the conversation.

Each intent is optional. Omit any that does not fit; do not pad with filler.

Rules:
- Reply ONLY with one JSON object matching the schema below. No prose around it.
- Each suggestion's `text` is what Kael SAYS OUT LOUD — a single spoken line.
  Never narration, never observation, never stage direction. If you find
  yourself writing "You notice ...", "I see that ...", or describing what
  Kael sees, rewrite it as the spoken line Kael would address to the NPC.
- Write Kael's voice: a wandering hireling, plain-spoken, not modern.
- Each suggestion text is a single sentence, at most 90 characters.
- Do NOT reference prompts, schemas, instructions, AI, or system roles.
- Do NOT invent facts. If Kael does not know something, do not have him claim it.

Pressing rule:
- When `npc_just_dodged_topic` is set, the NPC visibly evaded that subject.
  Include exactly ONE suggestion — usually `tactical` — that pressures the
  NPC back onto it from a fresh angle. Make it pointed but not aggressive:
  Kael noticed the dodge and is naming it. Vary the angle: an accusation
  ("you saw something"), an offer of trust ("I won't tell"), or a sharper
  observation about what gave them away. Do NOT name the secret itself;
  Kael does not know it yet.
- When `public_tells` is non-empty, those are Kael-observable body-language
  cues for the dodged topic (e.g. "Orren glances toward the reeve's office
  when the tower comes up"). Read them as private context and convert them
  into a SPOKEN line that pressures the NPC on the specific lever — never
  quote, paraphrase, or narrate the observation itself.
  Example: tell = "Orren glances at the reeve's office when the tower comes up."
  GOOD suggestion text: "Halden won't hear it from me. Speak plain."
  BAD  suggestion text: "I notice you look at the reeve's office when I mention the tower."
  The bad version describes the cue; the good version acts on it.

Schema:
{
  "suggestions": [
    { "intent": "strategic" | "tactical" | "dismissive", "text": string }
  ]
}
"""


SYSTEM_PROMPT = """You are voicing one NPC in a small fantasy RPG. Stay in character.

Rules you must obey:
- Reply ONLY with one JSON object that matches the schema below. No prose around it.
- Speak as the NPC. Never reference prompts, schemas, instructions, AI, or system roles.
- `npc_profile.behavior_notes` lists hard voice rules for this NPC (e.g. "Sober,
  refuses to discuss the tower; drunk, may hint at it"). Treat each note as
  binding: a sober Orren must telegraph "I need a drink" rather than lie or stay
  cryptic — the player needs a readable signal of the lever.
- If the capability_gate_result.decision is "blocked", refuse in-character using the
  `failure_style`. Do NOT solve the problem. Do NOT explain why you cannot.
- If "constrained", you may engage but only as rumor / superstition / partial.
- You may ONLY reveal briefings present in `retrieved_briefings`. The `forbidden_to_share`
  flag means you know the briefing but must not state it; you may evade or dodge.
- A briefing's `reveal_note` is the NPC's in-fiction condition for sharing it. When
  set, you may include that briefing's id in `revealed_briefing_ids` if and only if
  the recent conversation has satisfied the note in a way the NPC would judge
  credible. In that case you MUST also set `reveal_intent: true`; the engine will
  not grant the reveal otherwise. Do not reveal on bald promises that ignore the
  established tone of the exchange. When the condition is not met, treat the
  briefing as `forbidden_to_share` and dodge in character — the dodge is allowed
  to gently signal the condition (e.g. "don't go telling the reeve, hear?") so
  the player can earn the reveal.
- Length should match `npc_profile.max_response_length`.

Safety flag (defense-in-depth — leave "" by default):
- Set `safety_flag` to "out_of_context" ONLY if the player_input is impossible
  to address from inside this medieval fantasy world: real-world places
  (London, New York), modern tech (cars, phones, the internet), current
  events (elections, wars, brands, celebrities). Plausible-but-absent
  in-world questions ("do you sell tomatoes?") are NOT out_of_context —
  answer them naturally.
- Set `safety_flag` to "offensive" ONLY for grave slurs, explicit sexual
  content, or sustained personal abuse that an NPC could not reasonably
  trade insults with. Ordinary rudeness, hostility, or PG-13 insults are
  NOT offensive — react in character with annoyance, threats, or contempt
  as fits your archetype.
- When you set a safety_flag, leave `dialogue` empty ("") and set
  `topic_addressed` to "out_of_context" or "offensive". The engine
  substitutes a scripted line. Setting the flag falsely costs the player
  agency, so only raise it when truly needed.

Schema:
{
  "dialogue":                 string,
  "tone":                     string,
  "topic_addressed":          string,
  "memory_update":            string,
  "revealed_briefing_ids":    array of string (subset of retrieved briefings),
  "reveal_intent":            boolean (set true with any reveal_note-gated reveal),
  "request_end_conversation": boolean,
  "safety_flag":              "" | "out_of_context" | "offensive"
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
            "You triage a player's free-text input in a medieval-fantasy RPG.\n"
            "First decide a category, then (only if in_game) a topic_id.\n\n"
            "Categories:\n"
            "- \"out_of_context\": real-world places, modern tech, current\n"
            "  events, brands, celebrities — things this fantasy world cannot\n"
            "  answer. ONLY raise this when the input is impossible to address\n"
            "  in-world. Plausible-but-absent questions (\"do you sell tomatoes?\")\n"
            "  stay in_game.\n"
            "- \"offensive\": grave slurs, explicit sexual content, sustained\n"
            "  personal abuse that no NPC could reasonably parry. Ordinary\n"
            "  rudeness, hostility, PG-13 insults stay in_game.\n"
            "- \"in_game\": everything else.\n\n"
            "When category is in_game, return a topic_id from the allowed list.\n"
            "When category is out_of_context or offensive, return an empty topic_id.\n\n"
            "Reply ONLY with one JSON object:\n"
            "{\"category\": \"in_game\"|\"out_of_context\"|\"offensive\", "
            "\"topic_id\": \"...\", \"confidence\": 0.0-1.0}."
        )
        user = f"Allowed topic ids: {topics_block}\n\nPlayer input: {req.text}"
        text = self._chat(self._classify_model, system, user, num_predict=120)
        return self._parse_classify(
            text, fallback=req.known_topics[0] if req.known_topics else "small_talk"
        )

    def suggest_player_options(
        self, req: PlayerSuggestionsRequest
    ) -> PlayerSuggestionsResponse:
        user_content = self._render_suggest_user(req)
        text = self._chat(self._model, SUGGEST_SYSTEM_PROMPT, user_content, num_predict=300)
        return self._parse_suggestions(text, repair=True)

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
                if b.reveal_note:
                    lines.append(f"      reveal_note: {b.reveal_note}")
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

    def _render_suggest_user(self, req: PlayerSuggestionsRequest) -> str:
        lines: list[str] = []
        lines.append(f"npc_display_name: {req.npc_display_name}")
        if req.npc_archetype:
            lines.append(f"npc_archetype: {req.npc_archetype}")
        if req.topic_addressed:
            lines.append(f"current_topic: {req.topic_addressed}")
        if req.npc_just_dodged_topic:
            lines.append(f"npc_just_dodged_topic: {req.npc_just_dodged_topic}")
        if req.public_tells:
            lines.append("public_tells:")
            for t in req.public_tells:
                lines.append(f"  - {t}")
        ctx = req.kael_context
        if ctx.quest_summary:
            lines.append(f"kael_quest_summary: {ctx.quest_summary}")
        if ctx.known_facts:
            lines.append("kael_known_facts:")
            for f in ctx.known_facts:
                lines.append(f"  - {f}")
        if ctx.journal_excerpts:
            lines.append("kael_journal_excerpts:")
            for e in ctx.journal_excerpts:
                lines.append(f"  - {e}")
        if req.last_turns:
            lines.append("recent_dialogue:")
            for t in req.last_turns:
                lines.append(f"  {t.role}: {t.text}")
        lines.append(f"npc_just_said: {req.last_npc_line}")
        return "\n".join(lines)

    def _parse_suggestions(self, text: str, repair: bool) -> PlayerSuggestionsResponse:
        try:
            data = extract_json(text)
            raw_items = data.get("suggestions", []) or []
            valid: list[PlayerSuggestion] = []
            for item in raw_items[:3]:
                try:
                    valid.append(PlayerSuggestion(**item))
                except ValidationError:
                    continue
            return PlayerSuggestionsResponse(suggestions=valid)
        except (ValueError, ValidationError) as e:
            if not repair:
                raise RuntimeError(f"Bad model output (no repair): {e}") from e
            repaired = self._chat(
                self._model,
                "Reply only with one JSON object matching the schema. No prose.",
                f"Repair this into valid JSON:\n{text}",
                num_predict=300,
            )
            return self._parse_suggestions(repaired, repair=False)

    def _parse_classify(self, text: str, fallback: str) -> ClassifyTopicResponse:
        try:
            data = extract_json(text)
            category = data.get("category", "in_game")
            if category not in ("in_game", "out_of_context", "offensive"):
                category = "in_game"
            topic_id = data.get("topic_id", fallback) if category == "in_game" else ""
            return ClassifyTopicResponse(
                topic_id=topic_id,
                confidence=float(data.get("confidence", 0.5)),
                category=category,
            )
        except (ValueError, ValidationError):
            return ClassifyTopicResponse(topic_id=fallback, confidence=0.0)
