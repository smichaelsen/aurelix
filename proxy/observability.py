"""
Lightweight observability. Counts requests + rough token estimates.
Never logs API keys. Per-conversation totals if a conversation_id is passed.
"""

from __future__ import annotations

import sys
import time
from collections import defaultdict


_total_requests = 0
_total_input_chars = 0
_total_output_chars = 0
_per_conversation: dict[str, dict[str, int]] = defaultdict(lambda: {
    "requests": 0, "input_chars": 0, "output_chars": 0,
})


def record(endpoint: str, input_text: str, output_text: str, conversation_id: str | None = None) -> None:
    global _total_requests, _total_input_chars, _total_output_chars
    _total_requests += 1
    _total_input_chars += len(input_text)
    _total_output_chars += len(output_text)

    if conversation_id:
        rec = _per_conversation[conversation_id]
        rec["requests"] += 1
        rec["input_chars"] += len(input_text)
        rec["output_chars"] += len(output_text)

    print(
        f"[proxy] {time.strftime('%H:%M:%S')} {endpoint}  "
        f"in={len(input_text)} out={len(output_text)} "
        f"total_req={_total_requests} "
        f"total_in_chars={_total_input_chars} "
        f"total_out_chars={_total_output_chars}",
        file=sys.stderr,
    )


def summary() -> dict:
    return {
        "total_requests":     _total_requests,
        "total_input_chars":  _total_input_chars,
        "total_output_chars": _total_output_chars,
        "per_conversation":   dict(_per_conversation),
    }
