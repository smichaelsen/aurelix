extends Node
##
## Loaded atomic fact registry. Facts are boolean truths the engine tracks;
## quests gate on them. The model never creates facts directly; only
## validated briefing reveals or engine world-events do.
## Autoload as `FactRegistry`. Populated by DataLoader.
##

var _facts: Dictionary = {}    # id -> {type, canon, description}


func load_from(data: Dictionary) -> void:
	_facts = data.get("facts", {})


func get_fact(id: String) -> Dictionary:
	return _facts.get(id, {})


func has_fact(id: String) -> bool:
	return _facts.has(id)


func is_canon(id: String) -> bool:
	return get_fact(id).get("canon", false)


func fact_type(id: String) -> String:
	return get_fact(id).get("type", "")


func all_ids() -> Array:
	return _facts.keys()


func count() -> int:
	return _facts.size()
