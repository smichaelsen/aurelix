extends Node
##
## Minimal quest state machine. Phase 4 stub: tracks each quest's current
## state string. Phase 5 will plug in QuestRuleEngine to advance states
## based on facts. For now `set_state` is called directly by scripted beats
## (e.g. HaldenScript on quest acceptance).
##
## Autoload as `QuestState`.
##

const DRAGON_SIGHTING := "dragon_sighting"

const STATE_NOT_STARTED := "not_started"
const STATE_ACTIVE      := "active"
const STATE_COMPLETE    := "complete"


var _states: Dictionary = {}     # quest_id -> state


func get_state(quest_id: String) -> String:
	return _states.get(quest_id, STATE_NOT_STARTED)


func set_state(quest_id: String, new_state: String) -> void:
	var prev := get_state(quest_id)
	if prev == new_state:
		return
	_states[quest_id] = new_state
	print("[QuestState] %s: %s -> %s" % [quest_id, prev, new_state])
	EventBus.quest_state_changed.emit(quest_id, new_state)


func is_active(quest_id: String) -> bool:
	return get_state(quest_id) == STATE_ACTIVE


func is_complete(quest_id: String) -> bool:
	return get_state(quest_id) == STATE_COMPLETE
