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


## "authored" | "ai_suggested" — does this topic want scripted player options
## or AI-generated ones? Authors set this in the per-NPC YAML via a top-level
## `options_source` map; the bank's entry wins either way:
##
##   options_source:
##     greeting:   authored          # keep scripted even mid-conversation
##     the_tower:  ai_suggested      # force AI (redundant — already default)
##
## Defaults when no entry is present:
##   - "default" topic (the opening greeting after `_open`) → authored, so
##     every NPC keeps its scripted intro.
##   - Every other topic → ai_suggested, so AI suggestions show up everywhere
##     after the first turn unless an author explicitly says otherwise.
func options_source(npc_id: String, topic: String) -> String:
	var bank: Dictionary = _banks.get(npc_id, {})
	var sources: Dictionary = bank.get("options_source", {})
	if sources.has(topic):
		return String(sources[topic])
	return "authored" if topic == "default" else "ai_suggested"


func templated_line(npc_id: String, line_id: String) -> String:
	var bank: Dictionary = _banks.get(npc_id, {})
	var lines: Dictionary = bank.get("templated_lines", {})
	return lines.get(line_id, "")


func has_bank(npc_id: String) -> bool:
	return _banks.has(npc_id)


func count() -> int:
	return _banks.size()
