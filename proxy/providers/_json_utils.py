"""
JSON extraction helpers shared by LLM providers.

LLMs sometimes wrap their JSON in markdown fences or trail prose around
it. `extract_json` accepts either form: a fenced ```json block first,
then the first balanced `{...}` object found in the text. The balanced
scan honours string literals so braces inside quoted dialogue do not
throw off the depth counter.
"""

from __future__ import annotations

import json
import re


_FENCED_JSON = re.compile(r"```(?:json)?\s*(\{.*?\})\s*```", re.DOTALL)


def extract_json(text: str) -> dict:
    fenced = _FENCED_JSON.search(text)
    if fenced:
        return json.loads(fenced.group(1))
    candidate = first_balanced_object(text)
    if candidate is None:
        raise ValueError("no JSON object in response")
    return json.loads(candidate)


def first_balanced_object(text: str) -> str | None:
    start = text.find("{")
    if start < 0:
        return None
    depth = 0
    in_string = False
    escape = False
    for i in range(start, len(text)):
        ch = text[i]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return None
