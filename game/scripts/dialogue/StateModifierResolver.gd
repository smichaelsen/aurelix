extends Node
##
## Maps NPC profile + active flags to effective values that the rest of the
## pipeline reads:
##   - `patience` base + per-flag bonuses
##   - `willingness_by_topic` -- the merged map of state_modifiers
##   - `tone_default` -- which tone the model should default to
##
## Pure helper, not an autoload.
##


## Resolve all state-driven effects. Returns:
##   {
##     patience_bonus: int,          summed across active flags
##     willingness_by_topic: Dict,   topic_id -> "from_forbidden_to_pressable" | ...
##     tone_default: String,         tone hint for the model
##     active_flag_names: Array,     for the state paragraph
##   }
static func resolve(npc_profile: Dictionary, flags: Dictionary) -> Dictionary:
	var modifiers: Dictionary = npc_profile.get("state_modifiers", {})
	var patience_bonus := 0
	var willingness: Dictionary = {}
	var tone_default := ""
	var active: Array = []
	for flag_name in flags.keys():
		if not flags[flag_name]:
			continue
		active.append(flag_name)
		if not modifiers.has(flag_name):
			continue
		var rule: Dictionary = modifiers[flag_name]
		patience_bonus += int(rule.get("patience_bonus", 0))
		var wm: Dictionary = rule.get("willingness_modifier", {})
		for topic in wm.keys():
			willingness[topic] = wm[topic]
		var td: String = rule.get("tone_default", "")
		if not td.is_empty():
			tone_default = td
	return {
		"patience_bonus":       patience_bonus,
		"willingness_by_topic": willingness,
		"tone_default":         tone_default,
		"active_flag_names":    active,
	}


## Build the human-readable state paragraph injected into the prompt.
## Format is deliberately simple and matches what MockProvider parses.
static func build_state_paragraph(memory: Dictionary, resolved: Dictionary) -> String:
	var lines := []
	var mood: String = resolved.get("tone_default", "")
	if not mood.is_empty():
		lines.append("Mood: %s" % mood)
	var stress: int = memory.get("stress", 0)
	var stress_label := "low"
	if stress >= 5:    stress_label = "high"
	elif stress >= 2:  stress_label = "medium"
	lines.append("Stress: %s" % stress_label)
	lines.append("Patience: %d turns remaining" % int(memory.get("patience", 0)))
	var last_topic: String = memory.get("last_topic", "")
	if not last_topic.is_empty():
		lines.append("Last topic: %s" % last_topic)
	var active: Array = resolved.get("active_flag_names", [])
	if not active.is_empty():
		lines.append("Active flags: %s" % ", ".join(active))
	var rel: int = memory.get("relationship_to_player", 0)
	lines.append("Relationship to player: %d" % rel)
	if lines.is_empty():
		return ""
	return "Current state:\n  " + "\n  ".join(lines)
