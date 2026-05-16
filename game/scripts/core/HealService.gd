extends Node
##
## Single overworld heal path. Both the [H] quick-heal and the inventory
## panel's "Use" button call in here so the consume + clamp + signal flow
## is identical.
##
## Autoload as `HealService`. Depends on Inventory, ItemRegistry, PartyHealth,
## EventBus.
##


## Quick-heal: pick the smallest item that closes Kael's HP gap, or the
## largest available if none fully fits. Returns true if a heal was applied.
func heal_kael_with_best_fit() -> bool:
	if PartyHealth.kael_is_full():
		print("[Heal] HP already full (%d/%d)." % [
			PartyHealth.get_kael_hp(), PartyHealth.kael_max(),
		])
		return false
	var deficit: int = PartyHealth.kael_max() - PartyHealth.get_kael_hp()
	var pick: Dictionary = _best_heal_item_for(deficit)
	if pick.is_empty():
		print("[Heal] no heal items in bag.")
		return false
	return _apply(pick["id"])


## Use a specific item id. Inventory panel calls this from a row button.
## Returns true if a heal was applied (item present + had a heal stat +
## Kael not already full).
func use_item(item_id: String) -> bool:
	if PartyHealth.kael_is_full():
		print("[Heal] HP already full (%d/%d)." % [
			PartyHealth.get_kael_hp(), PartyHealth.kael_max(),
		])
		return false
	if not Inventory.has(item_id, 1):
		return false
	var item: Dictionary = ItemRegistry.get_item(item_id)
	if int(item.get("stats", {}).get("heal", 0)) <= 0:
		return false
	return _apply(item_id)


func _apply(item_id: String) -> bool:
	var item: Dictionary = ItemRegistry.get_item(item_id)
	var heal: int = int(item.get("stats", {}).get("heal", 0))
	Inventory.remove(item_id, 1)
	var applied: int = PartyHealth.heal_kael(heal)
	print("[Heal] used %s, +%d HP -> %d/%d" % [
		item.get("name", item_id), applied,
		PartyHealth.get_kael_hp(), PartyHealth.kael_max(),
	])
	EventBus.party_heal_applied.emit(
		"kael", item_id, applied,
		PartyHealth.get_kael_hp(), PartyHealth.kael_max(),
	)
	return true


func _best_heal_item_for(deficit: int) -> Dictionary:
	var best_fit: Dictionary = {}
	var best_fit_diff: int = 1 << 30
	var largest: Dictionary = {}
	var largest_amount: int = 0
	for entry in Inventory.bag:
		var item: Dictionary = ItemRegistry.get_item(entry["id"])
		var heal: int = int(item.get("stats", {}).get("heal", 0))
		if heal <= 0:
			continue
		var candidate := {
			"id": entry["id"],
			"name": item.get("name", entry["id"]),
			"heal": heal,
		}
		if heal >= deficit:
			var diff: int = heal - deficit
			if diff < best_fit_diff:
				best_fit_diff = diff
				best_fit = candidate
		if heal > largest_amount:
			largest_amount = heal
			largest = candidate
	if not best_fit.is_empty():
		return best_fit
	return largest
