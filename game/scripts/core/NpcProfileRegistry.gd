extends Node
##
## Loaded NPC profiles + their starting dossiers. Static at boot; mutated
## at runtime by NpcDossierStore (Phase 9). For Phase 1 it is read-only.
## Autoload as `NpcProfileRegistry`. Populated by DataLoader.
##

var _by_id: Dictionary = {}    # id -> profile dict


func add(profile: Dictionary) -> void:
	var id: String = profile.get("id", "")
	if id.is_empty():
		push_error("NpcProfileRegistry: profile missing id")
		return
	_by_id[id] = profile


func get_profile(id: String) -> Dictionary:
	return _by_id.get(id, {})


func has_profile(id: String) -> bool:
	return _by_id.has(id)


func all_ids() -> Array:
	return _by_id.keys()


func count() -> int:
	return _by_id.size()


## Flatten the dossier for retrieval.
##
##   - `kael_self`:  live Journal dossier
##   - everyone else: live NpcDossierStore dossier (seeded from static profile
##     on first access, then mutated as the world changes)
func flatten_dossier(id: String) -> Array:
	if id == "kael_self":
		return Journal.flatten_dossier()
	return NpcDossierStore.dossier_for(id)


## Public-observation lookup intended for the Kael-side suggestion pipeline.
## Returns ONLY the `public_tell` strings from this NPC's dossier entries
## that match `topic_id` (via the briefing's `topic_tags`). Does NOT leak
## the briefing body, the reveal_note (NPC-side), or any other private
## dossier field — by design, so PlayerPromptBuilder can call it without
## breaking the strict context isolation between the NPC prompt path and
## the Kael-suggestion prompt path. Empty array when no tells are
## authored for this topic.
func public_tells_for(id: String, topic_id: String) -> Array:
	var out: Array = []
	if topic_id.is_empty():
		return out
	var entries := flatten_dossier(id)
	for entry in entries:
		var tell: String = String(entry.get("public_tell", ""))
		if tell.is_empty():
			continue
		var briefing_id: String = String(entry.get("id", ""))
		var tiers := BriefingRegistry.tiers_for(briefing_id)
		if tiers.is_empty():
			continue
		var briefing: Dictionary = BriefingRegistry.get_briefing(briefing_id, tiers[0])
		var tags: Array = briefing.get("topic_tags", [])
		if topic_id in tags:
			out.append(tell)
	return out
