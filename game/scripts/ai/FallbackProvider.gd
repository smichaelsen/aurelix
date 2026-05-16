extends Node
##
## Authored last-resort provider. Returns canned dialogue lines from
## `data/fallback_lines/<npc_id>.json` when the live AI pipeline (proxy or
## mock) has failed `MAX_FAILURES` consecutive turns for that NPC, or when
## the DebugOverlay's force-fallback toggle is on.
##
## Lookup precedence:
##   1. per-NPC bank, topic key (e.g. mara_blacksmith -> the_tower)
##   2. per-NPC bank, _default
##   3. _archetype bank, archetype key
##   4. _archetype bank, _default
##   5. terminal "..."
##
## Autoload as `FallbackProvider`.
##

const FALLBACK_DIR := "res://data/fallback_lines/"
const ARCHETYPE_FILE := "res://data/fallback_lines/_archetype.json"

var force_active: bool = false      # toggled by DebugOverlay

var _by_npc: Dictionary = {}        # npc_id -> {topic: line, _default: ...}
var _by_archetype: Dictionary = {}  # archetype -> line


func _ready() -> void:
	_load_banks()


func _load_banks() -> void:
	var dir := DirAccess.open(FALLBACK_DIR)
	if dir == null:
		push_warning("[FallbackProvider] no fallback_lines dir")
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json") and not name.begins_with("_"):
			var npc_id := name.replace(".json", "")
			_by_npc[npc_id] = _read_lines(FALLBACK_DIR + name)
		name = dir.get_next()
	dir.list_dir_end()
	if FileAccess.file_exists(ARCHETYPE_FILE):
		_by_archetype = _read_lines(ARCHETYPE_FILE)
	print("[FallbackProvider] %d NPC banks, %d archetype lines" % [
		_by_npc.size(), _by_archetype.size(),
	])


func _read_lines(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return {}
	return parsed.get("lines", {})


# ---------------------------------------------------------------------------
# Lookup
# ---------------------------------------------------------------------------

## Returns a complete response dict shaped exactly like a normal AI
## response so the rest of the pipeline doesn't need to special-case.
func generate(npc_id: String, topic: String, npc_profile: Dictionary) -> Dictionary:
	var line := _line_for(npc_id, topic, npc_profile)
	return {
		"dialogue":               line,
		"tone":                   npc_profile.get("speech", {}).get("default_tone", "neutral"),
		"topic_addressed":        topic,
		"memory_update":          "",
		"revealed_briefing_ids":  [],
		"request_end_conversation": false,
	}


## Scripted response when the classifier flagged the player input as
## out_of_context (modern tech, real-world places, etc.). NPC is mildly
## confused; no state mutation — DialogueController treats this as a turn
## that "did not happen" so the model's last_turns view never carries the
## setting-break.
func out_of_context_response(npc_id: String, npc_profile: Dictionary) -> Dictionary:
	var line := _category_line(npc_id, "out_of_context", "I didn't catch that. What do you mean?")
	return {
		"dialogue":               line,
		"tone":                   "neutral",
		"topic_addressed":        "out_of_context",
		"memory_update":          "",
		"revealed_briefing_ids":  [],
		"claims":                 [],
		"request_end_conversation": false,
	}


## Scripted response when the classifier flagged the player input as
## offensive (grave slurs / explicit content). Triggers the same anger-out
## flow used by stress_at_limit; conversation ends, AngerCooldownResolver
## keeps the NPC closed off for a window.
func offensive_response(npc_id: String, npc_profile: Dictionary) -> Dictionary:
	var line := _category_line(npc_id, "offensive", "That was unnecessary. Leave me alone.")
	return {
		"dialogue":               line,
		"tone":                   "hostile",
		"topic_addressed":        "offensive",
		"memory_update":          "",
		"revealed_briefing_ids":  [],
		"claims":                 [],
		"request_end_conversation": true,
	}


## Look up a top-level category key (e.g. "out_of_context") on the
## per-NPC bank first, then on the archetype bank, then fall back to the
## hardcoded default. Distinct from `_line_for` because category keys are
## not topic-shaped — they sit alongside topics in the per-NPC bank but
## archetype keys in `_by_archetype` are still flat (an `out_of_context`
## entry there is a generic default, not an archetype name).
func _category_line(npc_id: String, category: String, default_line: String) -> String:
	var npc_bank: Dictionary = _by_npc.get(npc_id, {})
	if npc_bank.has(category):
		return String(npc_bank[category])
	if _by_archetype.has(category):
		return String(_by_archetype[category])
	return default_line


func _line_for(npc_id: String, topic: String, npc_profile: Dictionary) -> String:
	var npc_bank: Dictionary = _by_npc.get(npc_id, {})
	if not npc_bank.is_empty():
		if npc_bank.has(topic):
			return String(npc_bank[topic])
		if npc_bank.has("_default"):
			return String(npc_bank["_default"])
	var arch: String = npc_profile.get("archetype", "")
	if _by_archetype.has(arch):
		return String(_by_archetype[arch])
	if _by_archetype.has("_default"):
		return String(_by_archetype["_default"])
	return "..."
