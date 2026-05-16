"""
Provider protocol. Concrete providers implement these two methods.
"""

from __future__ import annotations

from typing import Protocol

from ..schema import (
    AiRequest, AiResponse,
    ClassifyTopicRequest, ClassifyTopicResponse,
)


class AiProvider(Protocol):
    def generate(self, req: AiRequest) -> AiResponse: ...
    def classify_topic(self, req: ClassifyTopicRequest) -> ClassifyTopicResponse: ...
