extends "res://scripts/ai/AiProvider.gd"
##
## In-process mock that reads the same `mock_responses.json` AND
## `mock_classify_rules.json` as the proxy's MockProvider. Behaviour is
## byte-identical so the game runs the same way with or without the proxy /
## network. The classify rules used to be hardcoded in two places (here and
## proxy/providers/mock.py) and drifted; both sides now load the shared JSON.
##

const MOCK_RESPONSES_PATH := "res://data/mock_responses.json"
const MOCK_CLASSIFY_PATH  := "res://data/mock_classify_rules.json"


var _library: Dictionary = {}
var _classify_rules: Array = []
var _classify_match_confidence: float = 0.7
var _classify_default_topic: String = "small_talk"
var _classify_default_confidence: float = 0.3


func _ready() -> void:
	_load_library()
	_load_classify_rules()


func _load_library() -> void:
	if not FileAccess.file_exists(MOCK_RESPONSES_PATH):
		push_error("[MockProvider] mock_responses.json not found")
		return
	var f := FileAccess.open(MOCK_RESPONSES_PATH, FileAccess.READ)
	if f == null:
		push_error("[MockProvider] cannot open mock_responses.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("[MockProvider] bad JSON")
		return
	_library = parsed


func _load_classify_rules() -> void:
	if not FileAccess.file_exists(MOCK_CLASSIFY_PATH):
		push_error("[MockProvider] mock_classify_rules.json not found")
		return
	var f := FileAccess.open(MOCK_CLASSIFY_PATH, FileAccess.READ)
	if f == null:
		push_error("[MockProvider] cannot open mock_classify_rules.json")
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("[MockProvider] bad classify JSON")
		return
	_classify_rules            = parsed.get("rules", [])
	_classify_match_confidence = float(parsed.get("match_confidence", 0.7))
	_classify_default_topic    = String(parsed.get("default_topic_id", "small_talk"))
	_classify_default_confidence = float(parsed.get("default_confidence", 0.3))


func generate(request: Dictionary) -> Dictionary:
	if _library.is_empty():
		_load_library()
	var npc_id: String = request.get("npc_id", "")
	var topic: String  = request.get("topic_addressed", "")
	var profile: Dictionary = request.get("npc_profile", {})
	var archetype: String = profile.get("archetype", "")
	var state_paragraph: String = request.get("state_paragraph", "")
	var state := _derive_state_key(state_paragraph, archetype)

	var lib_state: Dictionary = _library.get("by_npc_topic_state", {})
	var fallbacks: Dictionary = _library.get("fallback_by_archetype", {})

	# Prompt injection / meta_game wildcards regardless of NPC.
	if topic == "prompt_injection" or topic == "meta_game":
		var wild := "*|%s|none" % topic
		if lib_state.has(wild):
			return _build(request, lib_state[wild])

	# Specific (npc, topic, state)
	var key := "%s|%s|%s" % [npc_id, topic, state]
	if lib_state.has(key):
		return _build(request, lib_state[key])

	# (npc, topic, "none")
	key = "%s|%s|none" % [npc_id, topic]
	if lib_state.has(key):
		return _build(request, lib_state[key])

	# Capability-blocked or generic fallback by archetype
	var canned: Dictionary = fallbacks.get(archetype, fallbacks.get("_default", {}))
	return _build(request, canned)


func classify_topic(text: String, known_topics: Array) -> Dictionary:
	if _classify_rules.is_empty():
		_load_classify_rules()
	var lower := text.to_lower()
	for rule in _classify_rules:
		var topic_id: String = String(rule.get("topic_id", ""))
		var kws: Array = rule.get("keywords", [])
		for k in kws:
			if String(k) in lower:
				if known_topics.is_empty() or topic_id in known_topics:
					return {"topic_id": topic_id, "confidence": _classify_match_confidence}
	return {"topic_id": _classify_default_topic, "confidence": _classify_default_confidence}


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _derive_state_key(state_paragraph: String, archetype: String) -> String:
	var p := state_paragraph.to_lower()
	if "drunk" in p:
		return "drunk"
	if "angry" in p:
		return "angry"
	if "fed" in p:
		return "fed"
	if archetype == "drunk":
		return "sober"
	return "none"


func _build(request: Dictionary, canned: Dictionary) -> Dictionary:
	return {
		"dialogue":               canned.get("dialogue", "..."),
		"tone":                   canned.get("tone", "neutral"),
		"topic_addressed":        request.get("topic_addressed", ""),
		"memory_update":          canned.get("memory_update", ""),
		"revealed_briefing_ids":  canned.get("revealed_briefing_ids", []),
		"request_end_conversation": canned.get("request_end_conversation", false),
	}
