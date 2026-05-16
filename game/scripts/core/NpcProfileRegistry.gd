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
