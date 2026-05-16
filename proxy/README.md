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

All commands run from the repo root (`main.py` uses relative imports,
so uvicorn must load it as the `proxy.main` package).

Mock provider (default, no API key needed):

```bash
proxy/.venv/bin/uvicorn proxy.main:app --port 8421 --reload
```

Real Anthropic Haiku 4.5:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
AURELIX_PROVIDER=anthropic proxy/.venv/bin/uvicorn proxy.main:app --port 8421
```

Local Ollama daemon. First pull the default model pair (generate + classify).
If you installed Ollama via Homebrew or the desktop app, the daemon is
already running on `127.0.0.1:11434` — skip `ollama serve`.

```bash
ollama pull qwen2.5:7b-instruct
ollama pull qwen2.5:3b-instruct
```

Then run the proxy:

```bash
AURELIX_PROVIDER=ollama proxy/.venv/bin/uvicorn proxy.main:app --port 8421
```

Defaults: `OLLAMA_HOST=http://127.0.0.1:11434`,
`OLLAMA_MODEL=qwen2.5:7b-instruct`,
`OLLAMA_CLASSIFY_MODEL=qwen2.5:3b-instruct`,
`OLLAMA_TIMEOUT_S=60`. The 7B/3B Qwen2.5 pair is tuned for a 32GB Apple
Silicon box: the 7B handles dialogue generation (best 7B-class JSON
adherence) and the 3B handles cheap topic classification. Override any
of the four env vars to swap in another model.

Small local models honour the JSON schema less reliably than Haiku, so
the validator will drop more reveals and more turns will degrade to
`FallbackProvider` on the Godot side. Other models worth trying:
`llama3.1:8b`, `gemma2:9b`, `mistral-nemo:12b` (slower).

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
