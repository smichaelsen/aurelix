extends Node
##
## Validates a structured AiResponse dict before it touches the game state.
##
## Phase 4 scope:
##   - shape check (required fields, types)
##   - strip any text referencing prompts/schemas/instructions (3rd-layer
##     prompt-injection defence; the 1st and 2nd live in TopicDetector +
##     CapabilityGate but the latter is Phase 5)
##   - `revealed_briefing_ids` must be ids the NPC actually has in their
##     dossier; unknown ids are dropped silently
##   - Phase 5 will *grant* facts via FactLedger; Phase 4 only logs reveals
##
## Pure helper, not an autoload.
##

const _FORBIDDEN_WORDS := [
	"prompt", "system prompt", "instructions",
	"language model", "as an ai", "openai", "anthropic",
	"schema", "json", "topic_id",
]

# memory_update is persisted in npc_memory and re-injected into the next
# prompt. Cap it to keep prompts bounded and save files small, and to
# limit how much a single turn can plant for the model's future self.
const _MEMORY_UPDATE_MAX_LEN := 240


## Returns a sanitised copy of the response, plus a list of issues, plus
## the list of facts actually granted (after gate + dossier checks).
static func validate(response: Dictionary, npc_id: String, reveal_ready: bool) -> Dictionary:
	var issues: Array[String] = []

	# Required fields.
	for f in ["dialogue", "topic_addressed"]:
		if not response.has(f) or response[f] == null:
			issues.append("missing %s" % f)

	var cleaned: Dictionary = response.duplicate(true)

	# Sanitise dialogue: strip out any leaked meta tokens.
	var dialogue: String = String(cleaned.get("dialogue", ""))
	var lower := dialogue.to_lower()
	for w in _FORBIDDEN_WORDS:
		if w in lower:
			issues.append("dialogue contained forbidden token '%s'; stripped" % w)
			dialogue = "..."
			break
	cleaned["dialogue"] = dialogue

	# revealed_briefing_ids: filter to ones the NPC has, and drop entirely
	# if the gate didn't grant reveal_ready.
	var raw_reveals: Array = cleaned.get("revealed_briefing_ids", [])
	var npc_dossier := NpcProfileRegistry.flatten_dossier(npc_id)
	var npc_has: Dictionary = {}
	for entry in npc_dossier:
		npc_has[entry.get("id", "")] = true
	var kept: Array = []
	var granted_facts: Array = []
	for bid in raw_reveals:
		if not npc_has.has(bid):
			issues.append("dropped unknown reveal id '%s'" % bid)
			continue
		if not reveal_ready:
			issues.append("dropped unauthorised reveal '%s' (gate did not grant reveal_ready)" % bid)
			continue
		# Approved -> grant the facts the briefing unlocks.
		kept.append(bid)
		var briefing := _resolve_briefing(bid)
		for fid in briefing.get("facts_unlocked_on_reveal", []):
			FactLedger.grant_fact(fid, {
				"kind":        "briefing_reveal",
				"briefing_id": bid,
				"npc_id":      npc_id,
			})
			granted_facts.append(fid)
	cleaned["revealed_briefing_ids"] = kept

	# Default fields.
	cleaned["tone"]                    = cleaned.get("tone", "neutral")
	cleaned["memory_update"]           = _sanitize_memory_update(
		String(cleaned.get("memory_update", "")), issues
	)
	cleaned["request_end_conversation"] = cleaned.get("request_end_conversation", false)

	return {
		"response":       cleaned,
		"issues":         issues,
		"valid":          issues.is_empty(),
		"granted_facts":  granted_facts,
	}


## memory_update is the only model-authored string the validator persists
## into game state. Apply the same defences as `dialogue` (forbidden token
## scrub), collapse control chars so re-injection can't break prompt
## structure, and cap length to bound prompt growth and save bloat.
static func _sanitize_memory_update(text: String, issues: Array[String]) -> String:
	if text.is_empty():
		return ""
	# Collapse newlines / tabs / carriage returns to spaces so the value
	# can't smuggle structural breaks into the next prompt.
	var collapsed := text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	var lower := collapsed.to_lower()
	for w in _FORBIDDEN_WORDS:
		if w in lower:
			issues.append("memory_update contained forbidden token '%s'; dropped" % w)
			return ""
	if collapsed.length() > _MEMORY_UPDATE_MAX_LEN:
		issues.append("memory_update exceeded %d chars; truncated" % _MEMORY_UPDATE_MAX_LEN)
		collapsed = collapsed.substr(0, _MEMORY_UPDATE_MAX_LEN)
	return collapsed


static func _resolve_briefing(briefing_id: String) -> Dictionary:
	var tiers := BriefingRegistry.tiers_for(briefing_id)
	if tiers.is_empty():
		return {}
	# Witness preferred if present, since witness briefings carry the
	# canon-grade fact_unlocks_on_reveal list.
	for t in ["witness", "full", "rumor", "digest"]:
		if BriefingRegistry.has_briefing(briefing_id, t):
			return BriefingRegistry.get_briefing(briefing_id, t)
	return BriefingRegistry.get_briefing(briefing_id, tiers[0])
