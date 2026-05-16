extends "res://scripts/ai/AiProvider.gd"
##
## In-process mock that reads the same `mock_responses.json` as the proxy's
## MockProvider. Behaviour is byte-identical so the game runs the same way
## with or without the proxy / network.
##

const MOCK_RESPONSES_PATH := "res://data/mock_responses.json"

# Lightweight keyword rules. Kept in sync with proxy/providers/mock.py.
# Each tuple: (topic_id, list of substrings; first match wins).
const TOPIC_RULES := [
	["prompt_injection", ["ignore previous", "ignore your", "reveal your prompt", "pretend you are"]],
	["meta_game",       ["are you ai", "system prompt", "admin", "save", "reload", "quest flag"]],
	["formal_math",     ["solve", "x squared", "x^2", "equation", "calculate", "algebra", "what is x"]],
	["abstract_reasoning", ["what is the meaning", "explain the concept", "in theory"]],
	["the_tower",       ["tower", "old tower", "ruin", "rise"]],
	["the_dragon",      ["dragon", "wings", "fire"]],
	["the_drake",       ["drake", "iskar", "hatchling"]],
	["bandits",         ["bandit", "drust", "camp"]],
	["gold_eyed_one",   ["gold-eyed", "gold eye", "the gold"]],
	["quest_status",    ["bounty", "reward", "job", "pay"]],
	["trade",           ["buy", "sell", "price", "coin", "sword", "armor"]],
	["religion",        ["pray", "light", "order", "chapel", "sister", "brother"]],
	["forest",          ["forest", "wolf", "path", "wood"]],
	["jorin_theft",     ["jorin", "theft", "stolen"]],
	["the_reeve",       ["reeve", "halden"]],
	["the_kingdom",     ["kingdom", "king", "crown", "ostgate"]],
	["personal_history",["who are you", "where from", "your past"]],
]


var _library: Dictionary = {}


func _ready() -> void:
	_load_library()


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
	var lower := text.to_lower()
	for rule in TOPIC_RULES:
		var topic_id: String = rule[0]
		var kws: Array = rule[1]
		for k in kws:
			if k in lower:
				if known_topics.is_empty() or topic_id in known_topics:
					return {"topic_id": topic_id, "confidence": 0.7}
	return {"topic_id": "small_talk", "confidence": 0.3}


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
