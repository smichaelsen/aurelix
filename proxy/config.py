"""
Provider selection by env. Default is mock so the proxy boots without any
external service.

  AURELIX_PROVIDER=mock        deterministic in-proxy mock (default)
  AURELIX_PROVIDER=anthropic   Claude Haiku 4.5 (needs ANTHROPIC_API_KEY)
  AURELIX_PROVIDER=ollama      local Ollama daemon (see providers/ollama.py)
"""

from __future__ import annotations

import os
from typing import Literal

ProviderName = Literal["mock", "anthropic", "ollama"]
_VALID: tuple[ProviderName, ...] = ("mock", "anthropic", "ollama")


def selected_provider() -> ProviderName:
    name = os.environ.get("AURELIX_PROVIDER", "mock").lower()
    if name in _VALID:
        return name  # type: ignore[return-value]
    return "mock"


def get_provider():
    name = selected_provider()
    if name == "anthropic":
        from .providers.anthropic_haiku import AnthropicHaikuProvider
        return AnthropicHaikuProvider()
    if name == "ollama":
        from .providers.ollama import OllamaProvider
        return OllamaProvider()
    from .providers.mock import MockProvider
    return MockProvider()
