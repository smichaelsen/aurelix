extends Node
##
## Loaded briefings. Lookup is by (id, tier) because the same id can have
## multiple tiers (e.g. tower_smoke at witness AND rumor).
## Autoload as `BriefingRegistry`. Populated by DataLoader.
##

var _by_key:   Dictionary = {}   # "id|tier" -> briefing dict
var _by_id:    Dictionary = {}   # id -> Array of {tier, ref}
var _by_topic: Dictionary = {}   # topic_tag -> Array of {id, tier}


func add(briefing: Dictionary) -> void:
	var id: String = briefing.get("id", "")
	var tier: String = briefing.get("tier", "")
	if id.is_empty() or tier.is_empty():
		push_error("BriefingRegistry: missing id or tier")
		return
	_by_key[_key(id, tier)] = briefing
	if not _by_id.has(id):
		_by_id[id] = []
	_by_id[id].append({"tier": tier, "ref": briefing})
	for tag in briefing.get("topic_tags", []):
		if not _by_topic.has(tag):
			_by_topic[tag] = []
		_by_topic[tag].append({"id": id, "tier": tier})


func get_briefing(id: String, tier: String) -> Dictionary:
	return _by_key.get(_key(id, tier), {})


func has_briefing(id: String, tier: String) -> bool:
	return _by_key.has(_key(id, tier))


func has_id(id: String) -> bool:
	return _by_id.has(id)


func tiers_for(id: String) -> Array:
	var out: Array = []
	for entry in _by_id.get(id, []):
		out.append(entry["tier"])
	return out


func by_topic(topic_tag: String) -> Array:
	return _by_topic.get(topic_tag, [])


func all_briefings() -> Array:
	return _by_key.values()


func all_ids() -> Array:
	return _by_id.keys()


func count() -> int:
	return _by_key.size()


func _key(id: String, tier: String) -> String:
	return id + "|" + tier
