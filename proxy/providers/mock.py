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
    PlayerSuggestion, PlayerSuggestionsRequest, PlayerSuggestionsResponse,
)


_DATA_PATH = Path(__file__).resolve().parents[1] / 'data' / 'mock_responses.json'
_CLASSIFY_RULES_PATH = (
    Path(__file__).resolve().parents[1] / 'data' / 'mock_classify_rules.json'
)
_SUGGEST_PATH = (
    Path(__file__).resolve().parents[1] / 'data' / 'mock_player_suggestions.json'
)


def _load_library() -> dict:
    return json.loads(_DATA_PATH.read_text())


def _load_classify_rules() -> dict:
    return json.loads(_CLASSIFY_RULES_PATH.read_text())


def _load_suggestions() -> dict:
    return json.loads(_SUGGEST_PATH.read_text())


def _derive_state_key(state_paragraph: str, archetype: str) -> str:
    p = state_paragraph.lower()
    # cracked wins over drunk on purpose. Post-reveal Orren is still drunk
    # numerically (patience bonus carries) but the *response* lookup should
    # pick up his haunted post-reveal lines, not the dodge bank.
    if 'cracked' in p:
        return 'cracked'
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
        self._classify = _load_classify_rules()
        self._suggest = _load_suggestions()

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

        # Archetype fallback (also covers capability_gate.decision == 'blocked';
        # both end up at the same archetype-keyed canned line).
        canned = self._lib['fallback_by_archetype'].get(
            archetype, self._lib['fallback_by_archetype']['_default']
        )
        return self._build(req, canned)

    def classify_topic(self, req: ClassifyTopicRequest) -> ClassifyTopicResponse:
        """Cheap keyword-based topic classifier for the mock. Real Haiku
        provider does it semantically. Rules are loaded from
        proxy/data/mock_classify_rules.json so the Godot-side MockProvider
        stays bit-identical without duplicating the table."""
        text = req.text.lower()
        match_conf = float(self._classify.get('match_confidence', 0.7))
        default_topic = str(self._classify.get('default_topic_id', 'small_talk'))
        default_conf = float(self._classify.get('default_confidence', 0.3))
        # Category rules first: offensive / out_of_context short-circuit
        # before topic classification.
        for rule in self._classify.get('category_rules', []):
            category = rule['category']
            for k in rule['keywords']:
                if k in text:
                    return ClassifyTopicResponse(
                        topic_id='', confidence=match_conf, category=category,
                    )
        for rule in self._classify['rules']:
            topic_id = rule['topic_id']
            for k in rule['keywords']:
                if k in text:
                    if topic_id in req.known_topics or not req.known_topics:
                        return ClassifyTopicResponse(topic_id=topic_id, confidence=match_conf)
        return ClassifyTopicResponse(topic_id=default_topic, confidence=default_conf)

    def suggest_player_options(
        self, req: PlayerSuggestionsRequest
    ) -> PlayerSuggestionsResponse:
        archetype = req.npc_archetype or "_default"
        topic = req.topic_addressed or ""
        key = f"{archetype}|{topic}"
        items = self._suggest.get("by_archetype_topic", {}).get(key)
        if items is None:
            items = self._suggest["fallback_by_archetype"].get(
                archetype, self._suggest["fallback_by_archetype"]["_default"]
            )
        return PlayerSuggestionsResponse(
            suggestions=[PlayerSuggestion(**item) for item in items]
        )

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
            claims=list(canned.get('claims', [])),
            request_end_conversation=bool(canned.get('request_end_conversation', False)),
            safety_flag=canned.get('safety_flag', ''),
            reveal_intent=bool(canned.get('reveal_intent', False)),
        )
