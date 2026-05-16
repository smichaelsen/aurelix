extends Node
##
## Authored dialogue option banks, loaded from /data/options/*.json.
##
## Each NPC has a dict keyed by topic_id. The first lookup uses topic "default"
## (start of a fresh conversation). Subsequent turns may pass the last topic
## to surface follow-up options. Returns an empty array when no bank exists.
##
## Autoload as `AuthoredOptionLibrary`. Populated by DataLoader.
##

var _banks: Dictionary = {}      # npc_id -> bank dict {options:{topic:[...]}, templated_lines:{...}}


func add_bank(npc_id: String, data: Dictionary) -> void:
	_banks[npc_id] = data


func options_for(npc_id: String, topic: String) -> Array:
	var bank: Dictionary = _banks.get(npc_id, {})
	var by_topic: Dictionary = bank.get("options", {})
	var key := topic if by_topic.has(topic) else "default"
	return by_topic.get(key, [])


func templated_line(npc_id: String, line_id: String) -> String:
	var bank: Dictionary = _banks.get(npc_id, {})
	var lines: Dictionary = bank.get("templated_lines", {})
	return lines.get(line_id, "")


func has_bank(npc_id: String) -> bool:
	return _banks.has(npc_id)


func count() -> int:
	return _banks.size()
