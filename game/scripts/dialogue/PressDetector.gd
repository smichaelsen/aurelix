extends Node
##
## Detects whether a free-text (or AI-suggested) player line is a Press
## attempt against the speaking NPC, based on authored per-NPC keyword maps.
##
## This is intentionally brittle: short substring matches against the
## NPC profile's `press_keywords[topic][angle]: [...]`. The model is not
## consulted; press intent is recognised the moment the text contains an
## authored cue. Authors extend coverage by adding more keywords — no code
## change required.
##
## Returns {is_press: bool, angle: String, topic: String}.
## - is_press = false means callers should keep verb="ask".
## - When true, the matched angle is one of `accepted_press_angles[topic]`
##   for the NPC. The caller (DialogueController) sets verb="press" and
##   passes angle to CapabilityGate, which already handles the reveal path.
##
## Pure helper, not an autoload.
##


## Match the text against `npc_id`'s press_keywords for `topic`. Returns the
## first angle whose keyword list contains a substring of the text.
##
## Topic selection lives in the caller — typically the most recently dodged
## topic from DialogueSession (so "I won't tell anyone" pressures on the
## last secret, not whatever the topic classifier thinks of that phrase).
static func detect(npc_id: String, topic: String, text: String) -> Dictionary:
	if topic.is_empty() or text.is_empty():
		return _no_press(topic)
	var profile := NpcProfileRegistry.get_profile(npc_id)
	var per_topic: Dictionary = profile.get("press_keywords", {}).get(topic, {})
	if per_topic.is_empty():
		return _no_press(topic)
	# Only consider angles that the NPC actually accepts — guards against
	# stale keyword maps lingering after an angle is removed.
	var accepted: Array = profile.get("accepted_press_angles", {}).get(topic, [])
	var lower := text.to_lower()
	for angle in accepted:
		var keywords: Array = per_topic.get(angle, [])
		for k in keywords:
			if String(k).to_lower() in lower:
				return {"is_press": true, "angle": String(angle), "topic": topic}
	return _no_press(topic)


static func _no_press(topic: String) -> Dictionary:
	return {"is_press": false, "angle": "", "topic": topic}
