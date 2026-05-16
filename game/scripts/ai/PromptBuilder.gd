extends Node
##
## Assembles an AiRequest dictionary from the engine's view of the world.

const RetrieverScript = preload("res://scripts/ai/Retriever.gd")
##
## Phase 5 scope:
##   - compact NPC profile slice
##   - state paragraph from StateModifierResolver
##   - memory summary from NpcMemoryStore
##   - retrieved briefings via Retriever (topic-scoped)
##   - last_turns from DialogueSession
##   - capability_gate_result from CapabilityGate
##
## Pure helper, not an autoload.
##


static func build(
	npc_id: String,
	player_input: String,
	verb: String,
	topic_id: String,
	state_paragraph: String,
	memory_summary: String,
	last_turns: Array,
	capability_gate_result: Dictionary,
) -> Dictionary:
	var profile := NpcProfileRegistry.get_profile(npc_id)
	var compact := _compact_profile(profile)
	var briefings: Array = RetrieverScript.retrieve(npc_id, topic_id)

	return {
		"npc_id":            npc_id,
		"npc_profile":       compact,
		"state_paragraph":   state_paragraph,
		"memory_summary":    memory_summary,
		"retrieved_briefings": briefings,
		"last_turns":        last_turns,
		"player_input":      player_input,
		"verb":              verb,
		"topic_addressed":   topic_id,
		"capability_gate_result": {
			"decision":      capability_gate_result.get("decision", "allowed"),
			"reason":        capability_gate_result.get("reason", ""),
			"failure_style": capability_gate_result.get("failure_style", profile.get("speech", {}).get("failure_style", "")),
		},
	}


static func _compact_profile(profile: Dictionary) -> Dictionary:
	var persona: Dictionary = profile.get("persona", {})
	var speech: Dictionary = profile.get("speech", {})
	return {
		"id":                  profile.get("id", ""),
		"display_name":        profile.get("display_name", ""),
		"archetype":           profile.get("archetype", ""),
		"traits":              persona.get("traits", []),
		"speech_style":        speech.get("style", ""),
		"failure_style":       speech.get("failure_style", ""),
		"max_response_length": speech.get("max_response_length", "short"),
		"behavior_notes":      profile.get("behavior_notes", []),
	}
