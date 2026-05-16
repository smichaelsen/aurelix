extends Node
##
## Static item catalog loaded from /game/data/items.json.
## Autoload as `ItemRegistry`. Loads itself in _ready.
##

const ITEMS_PATH := "res://data/items.json"

var _items: Dictionary = {}    # item_id -> item dict


func _ready() -> void:
	if not FileAccess.file_exists(ITEMS_PATH):
		push_warning("[ItemRegistry] no items.json")
		return
	var f := FileAccess.open(ITEMS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("[ItemRegistry] bad items.json")
		return
	_items = parsed.get("items", {})
	print("[ItemRegistry] %d items" % _items.size())


func get_item(id: String) -> Dictionary:
	return _items.get(id, {})


func has_item(id: String) -> bool:
	return _items.has(id)


func name_of(id: String) -> String:
	return _items.get(id, {}).get("name", id)


## Returns the on_offer descriptor for `npc_id`, or {} if the item has
## no lever effect on that NPC.
func offer_descriptor(item_id: String, npc_id: String) -> Dictionary:
	var item := get_item(item_id)
	var on_offer: Dictionary = item.get("on_offer", {})
	return on_offer.get(npc_id, {})


func all_ids() -> Array:
	return _items.keys()
