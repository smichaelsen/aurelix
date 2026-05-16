extends Node
##
## Loaded topic taxonomy. Topics are the engine vocabulary for what a player
## input is "about." Maps each topic to its `capability_domain`, which the
## CapabilityGate later consults.
## Autoload as `TopicRegistry`. Populated by DataLoader.
##

var _topics: Dictionary = {}    # id -> {label, description, capability_domain}


func load_from(data: Dictionary) -> void:
	_topics = data.get("topics", {})


func get_topic(id: String) -> Dictionary:
	return _topics.get(id, {})


func has_topic(id: String) -> bool:
	return _topics.has(id)


func capability_domain_for(id: String) -> String:
	return get_topic(id).get("capability_domain", "")


func all_ids() -> Array:
	return _topics.keys()


func count() -> int:
	return _topics.size()
