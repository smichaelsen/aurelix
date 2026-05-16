extends Node
##
## Loads combatant stat blocks from /game/data/combatants.json and computes
## Kael's effective stats by adding Inventory equipment bonuses on top of
## his base.
##
## Autoload as `CombatantStats`.
##

const COMBATANTS_PATH := "res://data/combatants.json"

var _by_id: Dictionary = {}


func _ready() -> void:
	if not FileAccess.file_exists(COMBATANTS_PATH):
		push_warning("[CombatantStats] no combatants.json")
		return
	var f := FileAccess.open(COMBATANTS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		push_error("[CombatantStats] bad combatants.json")
		return
	_by_id = parsed.get("combatants", {})
	print("[CombatantStats] %d combatants" % _by_id.size())


func base_stats(id: String) -> Dictionary:
	var stats: Dictionary = _by_id.get(id, {}).duplicate(true)
	return stats


## Kael's stats with weapon/armor/trinket bonuses applied. Returns a fresh
## dict each call.
func kael_stats() -> Dictionary:
	var s := base_stats("kael")
	for slot in ["weapon", "armor", "trinket"]:
		var item_id: String = Inventory.equipment.get(slot, "")
		if item_id.is_empty():
			continue
		var item: Dictionary = ItemRegistry.get_item(item_id)
		var bonus: Dictionary = item.get("stats", {})
		for stat in ["atk", "def", "spd", "hp"]:
			if bonus.has(stat):
				s[stat] = int(s.get(stat, 0)) + int(bonus[stat])
	return s


func has(id: String) -> bool:
	return _by_id.has(id)
