extends Node
##
## Base class for AI providers. Subclasses inherit by script path
## (`extends "res://scripts/ai/AiProvider.gd"`) and override `generate` and
## `classify_topic`. Both are coroutines and may `await` other operations
## (HTTP, file I/O). Both return a Dictionary; on failure return
## an empty Dictionary so callers can chain fallbacks.
##
## NOTE: deliberately no `class_name` so autoloads can preload these scripts
## before the editor has registered global class names.
##


func generate(_request: Dictionary) -> Dictionary:
	return {}


func classify_topic(_text: String, _known_topics: Array) -> Dictionary:
	return {}


# Returns {"suggestions": [{"intent": "...", "text": "..."}, ...]}.
# Empty dict on failure so callers can fall back. 0-3 entries; each entry's
# intent is one of "strategic" | "tactical" | "dismissive".
func suggest_player_options(_request: Dictionary) -> Dictionary:
	return {}
