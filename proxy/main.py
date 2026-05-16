"""
Aurelix AI proxy. FastAPI on localhost. One endpoint per concern.

Run:
    cd proxy
    .venv/bin/uvicorn main:app --port 8421 --reload     # mock by default
    AURELIX_PROVIDER=anthropic .venv/bin/uvicorn main:app --port 8421   # real Haiku
"""

from __future__ import annotations

from fastapi import FastAPI, HTTPException

from .config import get_provider, selected_provider
from .observability import record, summary
from .schema import (
    AiRequest, AiResponse,
    ClassifyTopicRequest, ClassifyTopicResponse,
    PlayerSuggestionsRequest, PlayerSuggestionsResponse,
)


app = FastAPI(title="Aurelix Proxy", version="0.1.0")
_provider = get_provider()


@app.get("/health")
def health() -> dict:
    return {"ok": True, "provider": selected_provider()}


@app.get("/v1/stats")
def stats() -> dict:
    return summary()


@app.post("/v1/generate")
def generate(req: AiRequest) -> AiResponse:
    try:
        resp = _provider.generate(req)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    record("generate", req.player_input, resp.dialogue, conversation_id=req.npc_id)
    return resp


@app.post("/v1/classify_topic")
def classify_topic(req: ClassifyTopicRequest) -> ClassifyTopicResponse:
    try:
        resp = _provider.classify_topic(req)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    record("classify", req.text, resp.topic_id)
    return resp


@app.post("/v1/suggest_player_options")
def suggest_player_options(req: PlayerSuggestionsRequest) -> PlayerSuggestionsResponse:
    try:
        resp = _provider.suggest_player_options(req)
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))
    joined = " | ".join(s.text for s in resp.suggestions)
    record("suggest", req.last_npc_line, joined, conversation_id=req.npc_display_name)
    return resp
