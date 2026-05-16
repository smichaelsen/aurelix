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
## Access rules:
##   - `DialogueSession` holds a live reference into `_by_id` and is the
##     conversation-side mutator (patience, stress, recent_summary,
##     last_topic). This is intentional intimate coupling.
##   - `SaveManager` owns serialization and rebuild and reaches `_by_id`
##     directly.
##   - Every other caller goes through the public accessors below.
##     Do not reach into `_by_id` or mutate nested dicts from outside.
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


# ---------------------------------------------------------------------------
# Public accessors (use these from outside the autoload)
# ---------------------------------------------------------------------------

## NPC ids with an existing memory entry. Does not create entries.
func known_npc_ids() -> Array:
	return _by_id.keys()


## Read-only snapshot. Returns an empty dict if the NPC has no entry; does
## not create one. The caller gets a deep copy so they cannot accidentally
## mutate the live store.
func peek_memory(npc_id: String) -> Dictionary:
	if not _by_id.has(npc_id):
		return {}
	return (_by_id[npc_id] as Dictionary).duplicate(true)


func set_flag(npc_id: String, key: String, value: Variant) -> void:
	var mem := memory_for(npc_id)
	var flags: Dictionary = mem.get("flags", {})
	flags[key] = value
	mem["flags"] = flags


func get_flag(npc_id: String, key: String, default: Variant = null) -> Variant:
	var mem := memory_for(npc_id)
	var flags: Dictionary = mem.get("flags", {})
	return flags.get(key, default)


func set_anger_cooldown(npc_id: String, turns: int) -> void:
	var mem := memory_for(npc_id)
	mem["anger_cooldown_turns"] = max(0, turns)


func get_anger_cooldown(npc_id: String) -> int:
	var mem := memory_for(npc_id)
	return int(mem.get("anger_cooldown_turns", 0))


## Decrement by one, floored at zero. Returns the new value.
func decrement_anger_cooldown(npc_id: String) -> int:
	var mem := memory_for(npc_id)
	var t: int = max(0, int(mem.get("anger_cooldown_turns", 0)) - 1)
	mem["anger_cooldown_turns"] = t
	return t


func clear_stress(npc_id: String) -> void:
	var mem := memory_for(npc_id)
	mem["stress"] = 0


func set_recent_summary(npc_id: String, text: String) -> void:
	var mem := memory_for(npc_id)
	mem["recent_summary"] = text


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
