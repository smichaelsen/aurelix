"""
Provider selection by env. Default is mock so the proxy boots without
ANTHROPIC_API_KEY.

Set AURELIX_PROVIDER=anthropic to use real Haiku 4.5.
"""

from __future__ import annotations

import os
from typing import Literal

ProviderName = Literal["mock", "anthropic"]


def selected_provider() -> ProviderName:
    name = os.environ.get("AURELIX_PROVIDER", "mock").lower()
    if name in ("mock", "anthropic"):
        return name  # type: ignore[return-value]
    return "mock"


def get_provider():
    name = selected_provider()
    if name == "anthropic":
        from .providers.anthropic_haiku import AnthropicHaikuProvider
        return AnthropicHaikuProvider()
    from .providers.mock import MockProvider
    return MockProvider()
