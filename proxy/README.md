# Aurelix AI Proxy

Localhost FastAPI bridge between Godot and the AI provider. Reasons for
existing:

- Keeps the Anthropic SDK out of Godot.
- API key never leaves the proxy process.
- Provider can be swapped (mock / anthropic) by env without touching Godot.
- Streaming, retries, schema repair, observability live here.

## Setup

```bash
cd proxy
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

## Run

Mock provider (default, no API key needed):

```bash
.venv/bin/uvicorn main:app --port 8421 --reload
```

Real Anthropic Haiku 4.5:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
AURELIX_PROVIDER=anthropic .venv/bin/uvicorn main:app --port 8421
```

## Endpoints

| Method | Path                | Purpose                                  |
|--------|---------------------|------------------------------------------|
| GET    | `/health`           | `{"ok": true, "provider": ...}`          |
| GET    | `/v1/stats`         | rolling token + request counts           |
| POST   | `/v1/generate`      | NPC dialogue turn → structured response  |
| POST   | `/v1/classify_topic`| free-text → topic id                     |

## Schemas

See `schema.py`. The game side must match.

## Mock library

`data/mock_responses.json` keyed by `npc_id|topic|state`, with fallbacks by
archetype. Both this proxy and the in-Godot MockProvider read the same file,
so behaviour is byte-identical with or without the proxy.

## Adding a new provider

1. Implement `AiProvider` from `providers/base.py`.
2. Register a new name in `config.py`'s `get_provider()`.
3. Set `AURELIX_PROVIDER=<name>`.
