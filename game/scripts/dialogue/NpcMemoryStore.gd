extends Node
##
## Per-NPC mutable memory that persists across conversations within a play
## session. Phase 5 keeps it in-memory; Phase 10 will plug it into
## SaveManager so it survives reload.
##
## Each NPC's memory blob:
##   relationship_to_player: int   running score, +/- ints
##   stress:                 int   how pressed/agitated the NPC is right now
##   patience:               int   resets at the start of each conversation;
##                                 see PatienceCounter for in-session decay
##   player_tags:            Array short strings the model can use
##                                 ("dragon_curious", "armed", ...)
##   last_topic:             String topic_id of the previous turn
##   flags:                  Dict   {drunk: false, angry: false, saw_drake: ...}
##   recent_summary:         String last response's memory_update line
##   long_term_notes:        Array  significant moments, capped (Phase 10)
##   anger_cooldown_turns:   int    decremented per village interaction;
##                                  while >0 the NPC refuses to talk
##
## Autoload as `NpcMemoryStore`.
##

var _by_id: Dictionary = {}   # npc_id -> memory dict


func memory_for(npc_id: String) -> Dictionary:
	if not _by_id.has(npc_id):
		_by_id[npc_id] = _new_memory(npc_id)
	return _by_id[npc_id]


func reset_for(npc_id: String) -> void:
	_by_id.erase(npc_id)


func reset_all() -> void:
	_by_id.clear()


func tick_cooldowns() -> void:
	for mem in _by_id.values():
		if mem["anger_cooldown_turns"] > 0:
			mem["anger_cooldown_turns"] -= 1


func _new_memory(npc_id: String) -> Dictionary:
	var profile := NpcProfileRegistry.get_profile(npc_id)
	var defaults: Dictionary = profile.get("memory_defaults", {})
	return {
		"relationship_to_player": int(defaults.get("relationship_to_player", 0)),
		"stress":                 int(defaults.get("stress", 0)),
		"patience":               int(defaults.get("patience", 10)),
		"player_tags":            Array(defaults.get("player_tags", [])).duplicate(),
		"last_topic":             "",
		"flags":                  (defaults.get("flags", {}) as Dictionary).duplicate(true),
		"recent_summary":         "",
		"long_term_notes":        [],
		"anger_cooldown_turns":   0,
	}
