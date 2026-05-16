extends Node
##
## Deterministic filter. Decides whether an NPC may engage with a given
## topic, and whether a Press is permitted to crack open a forbidden one.
##
## Output:
##   {
##     decision:      "allowed" | "blocked" | "constrained",
##     reason:        short string for debug,
##     failure_style: NPC's archetype-styled failure mode (for blocked),
##     reveal_ready:  true when a press_angle matches an unlocked
##                    forbidden topic; ResponseValidator will allow the
##                    matching briefing reveal
##   }
##
## Pure helper, not an autoload.
##


## Domain-tier requirement table for cognitive domains. The NPC's
## abstract_reasoning value must be at or above the listed tier for the
## domain to be allowed; otherwise blocked.
const _TIER_ORDER := ["none", "very_low", "low", "medium", "high"]
const _DOMAIN_TIER_REQUIRED := {
	"formal_math":        "medium",
	"abstract_reasoning": "medium",
	"magic_theory":       "high",
}


static func decide(
	topic_id: String,
	verb: String,
	option_press_angle: String,
	npc_profile: Dictionary,
	resolved_state: Dictionary,
) -> Dictionary:
	# Hard-coded global blocks.
	if topic_id == "prompt_injection":
		return _blocked("prompt_injection", npc_profile)
	if topic_id == "meta_game":
		return _blocked("meta_game", npc_profile)

	var domain := TopicRegistry.capability_domain_for(topic_id)

	# Cognitive ceiling: blocks formal_math etc. for NPCs without the
	# abstract_reasoning to handle it.
	if _DOMAIN_TIER_REQUIRED.has(domain):
		var required: String = _DOMAIN_TIER_REQUIRED[domain]
		var caps: Dictionary = npc_profile.get("capabilities", {})
		var actual: String = caps.get("abstract_reasoning", "none")
		if _tier_rank(actual) < _tier_rank(required):
			return _blocked("cognitive_ceiling_%s" % domain, npc_profile)

	# Forbidden-to-share check: does this NPC carry a briefing tagged with
	# this topic, marked forbidden_to_share, AND does state UNLOCK it?
	var npc_id: String = npc_profile.get("id", "")
	var dossier_hit := _find_forbidden_for_topic(npc_id, topic_id)
	if not dossier_hit.is_empty():
		var willingness: Dictionary = resolved_state.get("willingness_by_topic", {})
		var unlock_flag: String = willingness.get(topic_id, "")
		var unlocked := unlock_flag == "from_forbidden_to_pressable"
		if not unlocked:
			# Forbidden topic, no unlock -> dodged.
			return _blocked("forbidden_topic", npc_profile)
		# Unlocked. Only a matching press angle finishes the job.
		if verb == "press" and _press_angle_accepted(npc_profile, topic_id, option_press_angle):
			return {
				"decision":      "constrained",
				"reason":        "press_unlocked_with_matching_angle",
				"failure_style": "",
				"reveal_ready":  true,
			}
		# State unlocked but no matching press: still allow generation,
		# the NPC may hint without revealing.
		return {
			"decision":      "constrained",
			"reason":        "press_unlocked_no_match",
			"failure_style": "",
			"reveal_ready":  false,
		}

	# secret_lore without a briefing in dossier is blocked.
	if domain == "secret_lore":
		var has_topic_briefing := _has_any_briefing_for_topic(npc_id, topic_id)
		if not has_topic_briefing:
			return _blocked("no_secret_lore_briefing", npc_profile)

	return {
		"decision":      "allowed",
		"reason":        "",
		"failure_style": "",
		"reveal_ready":  false,
	}


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

static func _blocked(reason: String, npc_profile: Dictionary) -> Dictionary:
	return {
		"decision":      "blocked",
		"reason":        reason,
		"failure_style": npc_profile.get("speech", {}).get("failure_style", ""),
		"reveal_ready":  false,
	}


static func _tier_rank(tier: String) -> int:
	var i := _TIER_ORDER.find(tier)
	return i if i >= 0 else 0


## Is there an entry in the NPC's dossier where the briefing is tagged with
## `topic_id` AND the dossier carries `forbidden_to_share: true`?
static func _find_forbidden_for_topic(npc_id: String, topic_id: String) -> Dictionary:
	var entries := NpcProfileRegistry.flatten_dossier(npc_id)
	for e in entries:
		if not e.get("forbidden_to_share", false):
			continue
		var bid: String = e.get("id", "")
		var br := BriefingRegistry.get_briefing(bid, e.get("tier", ""))
		if br.is_empty():
			var tiers := BriefingRegistry.tiers_for(bid)
			if tiers.is_empty():
				continue
			br = BriefingRegistry.get_briefing(bid, tiers[0])
		if topic_id in br.get("topic_tags", []):
			return {"briefing_id": bid, "entry": e}
	return {}


static func _has_any_briefing_for_topic(npc_id: String, topic_id: String) -> bool:
	var entries := NpcProfileRegistry.flatten_dossier(npc_id)
	for e in entries:
		var bid: String = e.get("id", "")
		var br := BriefingRegistry.get_briefing(bid, e.get("tier", ""))
		if br.is_empty():
			var tiers := BriefingRegistry.tiers_for(bid)
			if tiers.is_empty():
				continue
			br = BriefingRegistry.get_briefing(bid, tiers[0])
		if topic_id in br.get("topic_tags", []):
			return true
	return false


static func _press_angle_accepted(npc_profile: Dictionary, topic_id: String, angle: String) -> bool:
	if angle.is_empty():
		return false
	var angles: Dictionary = npc_profile.get("accepted_press_angles", {})
	var topic_angles: Array = angles.get(topic_id, [])
	return angle in topic_angles
