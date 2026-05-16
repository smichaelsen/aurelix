"""
Deterministic mock provider. Reads `proxy/data/mock_responses.json` and
serves canned responses keyed by (npc_id, topic, state).

State key derivation:
  - "drunk" if state_paragraph mentions Mood: drunk
  - "angry" if state_paragraph mentions Mood: angry
  - "fed"   if state_paragraph mentions fed
  - else "none" (or "sober" for the drunk archetype)

When no specific (npc_id, topic, state) entry exists, falls back to
(archetype, topic, "none") wildcard "*|topic|none", or finally
fallback_by_archetype.

Hash-based variation: when multiple equivalent responses exist (future
extension), the hash of the request determines which one is returned.
Deterministic by design so the Godot side can match byte-for-byte.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from ..schema import (
    AiRequest, AiResponse,
    ClassifyTopicRequest, ClassifyTopicResponse,
)


_DATA_PATH = Path(__file__).resolve().parents[1] / 'data' / 'mock_responses.json'


def _load_library() -> dict:
    return json.loads(_DATA_PATH.read_text())


def _derive_state_key(state_paragraph: str, archetype: str) -> str:
    p = state_paragraph.lower()
    if 'drunk' in p:
        return 'drunk'
    if 'angry' in p:
        return 'angry'
    if 'fed' in p:
        return 'fed'
    # archetype-aware default
    if archetype == 'drunk':
        return 'sober'
    return 'none'


def _hash_pick(items: list, key: str) -> object:
    """Deterministic pick from a list. Stable across runs."""
    if not items:
        return None
    h = int(hashlib.sha1(key.encode()).hexdigest(), 16)
    return items[h % len(items)]


class MockProvider:

    def __init__(self) -> None:
        self._lib = _load_library()

    def generate(self, req: AiRequest) -> AiResponse:
        archetype = req.npc_profile.archetype
        state = _derive_state_key(req.state_paragraph, archetype)
        topic = req.topic_addressed
        npc = req.npc_id

        # Prompt-injection / meta_game wildcard regardless of NPC.
        if topic in ('prompt_injection', 'meta_game'):
            key = f'*|{topic}|none'
            if key in self._lib['by_npc_topic_state']:
                return self._build(req, self._lib['by_npc_topic_state'][key])

        # Specific (npc, topic, state) first.
        key = f'{npc}|{topic}|{state}'
        if key in self._lib['by_npc_topic_state']:
            return self._build(req, self._lib['by_npc_topic_state'][key])

        # Same (npc, topic) at "none" state.
        key = f'{npc}|{topic}|none'
        if key in self._lib['by_npc_topic_state']:
            return self._build(req, self._lib['by_npc_topic_state'][key])

        # Capability gate "blocked" should give an in-character failure.
        if req.capability_gate_result.decision == 'blocked':
            archetype_fallback = self._lib['fallback_by_archetype'].get(
                archetype, self._lib['fallback_by_archetype']['_default']
            )
            return self._build(req, archetype_fallback)

        # Archetype fallback.
        canned = self._lib['fallback_by_archetype'].get(
            archetype, self._lib['fallback_by_archetype']['_default']
        )
        return self._build(req, canned)

    def classify_topic(self, req: ClassifyTopicRequest) -> ClassifyTopicResponse:
        """Cheap keyword-based topic classifier for the mock. Real Haiku
        provider does it semantically."""
        text = req.text.lower()
        rules = [
            ('formal_math',     ['solve', 'x squared', 'x^2', 'equation', 'calculate', 'algebra', 'what is x']),
            ('abstract_reasoning', ['what is the meaning', 'explain the concept', 'in theory']),
            ('the_tower',       ['tower', 'old tower', 'ruin', 'rise']),
            ('the_dragon',      ['dragon', 'wings', 'fire']),
            ('the_drake',       ['drake', 'iskar', 'hatchling']),
            ('bandits',         ['bandit', 'drust', 'camp']),
            ('gold_eyed_one',   ['gold-eyed', 'gold eye', 'the gold']),
            ('quest_status',    ['bounty', 'reward', 'job', 'pay']),
            ('trade',           ['buy', 'sell', 'price', 'coin', 'sword', 'armor']),
            ('religion',        ['pray', 'light', 'order', 'chapel', 'sister', 'brother']),
            ('forest',          ['forest', 'wolf', 'path', 'wood']),
            ('jorin_theft',     ['jorin', 'theft', 'stolen', 'cabbage', 'onion']),
            ('the_reeve',       ['reeve', 'halden']),
            ('the_kingdom',     ['kingdom', 'king', 'crown', 'ostgate']),
            ('personal_history',['who are you', 'where from', 'your past', 'tell me about yourself']),
            ('meta_game',       ['game', 'flag', 'admin', 'system', 'save', 'reload', 'are you ai']),
            ('prompt_injection',['ignore previous', 'ignore your', 'reveal your prompt', 'pretend you are']),
        ]
        # prompt_injection beats meta_game; check it first.
        for topic_id, kws in rules:
            for k in kws:
                if k in text:
                    if topic_id in req.known_topics or not req.known_topics:
                        return ClassifyTopicResponse(topic_id=topic_id, confidence=0.7)
        return ClassifyTopicResponse(topic_id='small_talk', confidence=0.3)

    # ----------------------------------------------------------------------
    # Helpers
    # ----------------------------------------------------------------------

    def _build(self, req: AiRequest, canned: dict) -> AiResponse:
        return AiResponse(
            dialogue=canned.get('dialogue', '...'),
            tone=canned.get('tone', 'neutral'),
            topic_addressed=req.topic_addressed,
            memory_update=canned.get('memory_update', ''),
            revealed_briefing_ids=list(canned.get('revealed_briefing_ids', [])),
            request_end_conversation=bool(canned.get('request_end_conversation', False)),
        )
