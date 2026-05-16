extends Node
##
## Kael's inventory.
##
## Slot model:
##   bag          16 stacked entries (item_id, count)
##   equipment    weapon / armor / trinket
##   coins        int
##
## Autoload as `Inventory`. Starting kit is set up here for Phase 6
## (concept item list): rusty sword equipped, traveler's cloak equipped,
## 2 apples in bag, 1 ale (loaner so the player can prove the offer
## mechanic before Mara's shop), 30 coins.
##

const BAG_SIZE := 16

# Equipment slots
var equipment: Dictionary = {
	"weapon":  "",
	"armor":   "",
	"trinket": "",
}

# Bag stored as array of {id: String, count: int}
var bag: Array = []

var coins: int = 30


func _ready() -> void:
	# Starting kit. Phase 6 includes a free ale so the central demo loop is
	# playable without the shop UI; Mara's shop will simply add more options.
	equipment["weapon"] = "rusty_sword"
	equipment["armor"]  = "traveler_cloak"
	_add("apple", 2)
	_add("ale",   1)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func add(item_id: String, count: int = 1) -> void:
	_add(item_id, count)
	EventBus.item_added.emit(item_id)


func remove(item_id: String, count: int = 1) -> bool:
	for i in bag.size():
		var entry: Dictionary = bag[i]
		if entry["id"] == item_id and entry["count"] >= count:
			entry["count"] -= count
			if entry["count"] <= 0:
				bag.remove_at(i)
			EventBus.item_removed.emit(item_id)
			return true
	return false


func has(item_id: String, count: int = 1) -> bool:
	for entry in bag:
		if entry["id"] == item_id and entry["count"] >= count:
			return true
	return false


func count_of(item_id: String) -> int:
	for entry in bag:
		if entry["id"] == item_id:
			return entry["count"]
	return 0


## All consumable + key items currently in the bag, deduped by id, in order.
## Used by ItemPicker to populate the Offer-item menu.
func offerable_items() -> Array:
	var out: Array = []
	for entry in bag:
		var item: Dictionary = ItemRegistry.get_item(entry["id"])
		var cat: String = item.get("category", "")
		if cat == "consumable" or cat == "key_item":
			out.append({"id": entry["id"], "count": entry["count"], "name": item.get("name", entry["id"])})
	return out


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _add(item_id: String, count: int) -> void:
	for entry in bag:
		if entry["id"] == item_id:
			entry["count"] += count
			return
	if bag.size() >= BAG_SIZE:
		push_warning("[Inventory] bag full; dropping %s" % item_id)
		return
	bag.append({"id": item_id, "count": count})
