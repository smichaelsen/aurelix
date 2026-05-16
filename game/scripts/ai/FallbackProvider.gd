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
