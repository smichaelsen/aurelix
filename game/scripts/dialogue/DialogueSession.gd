extends RefCounted
##
## Per-conversation mutable state. Sits on top of NpcMemoryStore: durable
## state (relationship, stress, flags, anger cooldown) lives in the store;
## conversation-only state (last_turns, dodged topics, patience-this-session)
## lives on the session.
##

const ANGER_THRESHOLD := 5
const PRESS_PATIENCE_COST := 2
const ASK_PATIENCE_COST := 1


var npc_id: String
var last_topic: String = "default"
var last_turns: Array = []                      # [{role, text}]
var dodged_topics: Dictionary = {}              # topic_id -> true
var npc_memory: Dictionary                      # ref to NpcMemoryStore entry


func _init(npc_id_in: String) -> void:
	npc_id = npc_id_in
	npc_memory = NpcMemoryStore.memory_for(npc_id_in)


# ---------------------------------------------------------------------------
# Conversation log
# ---------------------------------------------------------------------------

func record_player(text: String) -> void:
	last_turns.append({"role": "player", "text": text})
	_trim()


func record_npc(text: String) -> void:
	last_turns.append({"role": "npc", "text": text})
	_trim()


func _trim() -> void:
	while last_turns.size() > 6:
		last_turns.pop_front()


# ---------------------------------------------------------------------------
# Press / patience
# ---------------------------------------------------------------------------

func mark_dodged(topic_id: String) -> void:
	if topic_id == "" or topic_id == "greeting" or topic_id == "small_talk":
		return
	dodged_topics[topic_id] = true


func is_pressable(topic_id: String) -> bool:
	return dodged_topics.has(topic_id)


func decrement_patience(verb: String) -> void:
	var cost: int = PRESS_PATIENCE_COST if verb == "press" else ASK_PATIENCE_COST
	npc_memory["patience"] = int(npc_memory.get("patience", 0)) - cost


func patience_empty() -> bool:
	return int(npc_memory.get("patience", 0)) <= 0


func increment_stress() -> void:
	npc_memory["stress"] = int(npc_memory.get("stress", 0)) + 1


func stress_at_limit() -> bool:
	return int(npc_memory.get("stress", 0)) >= ANGER_THRESHOLD
