extends RefCounted
##
## Turn-based combat engine.
##
## Supports any number of battlers split into two sides (player, enemy).
## Initiative order is built once at start by descending SPD; turns
## cycle through the order, skipping defeated combatants.
##
## Battler dict shape:
##   id, side ("player"|"enemy"), name, hp, max_hp, atk, def, spd,
##   attack_name, defending: bool, burn_turns: int, burn_per_turn: int,
##   guard_target: String  (for Iskar's Defensive stance)
##

signal narration(text: String)
signal hp_changed(battler_id: String, hp: int, max_hp: int)
signal combat_ended(outcome: String)   # "won" | "lost" | "fled"
signal awaiting_player_input


const RNG_DELTA := 1


var battlers: Array = []
var _order: Array = []          # indices into `battlers` in turn order
var _ptr: int = 0               # current index into `_order`
var _rng := RandomNumberGenerator.new()
var _ended := false


func _init() -> void:
	_rng.randomize()


## Solo legacy start: Kael vs one enemy. If Iskar is bonded, he joins.
##
## Kael's stats from the caller already carry current `hp` from PartyHealth.
## Iskar's current HP is pulled from PartyHealth here so the engine remains
## the only consumer of the party-state autoload.
func start(kael_stats: Dictionary, enemy_stats: Dictionary, enemy_id: String) -> void:
	var player_party := [_battler_from(kael_stats, "kael", "player")]
	if IskarCompanion.bonded:
		var iskar_stats := CombatantStats.base_stats("iskar")
		if not iskar_stats.is_empty():
			var iskar_with_hp := iskar_stats.duplicate(true)
			iskar_with_hp["max_hp"] = int(iskar_stats["hp"])
			iskar_with_hp["hp"]     = PartyHealth.get_iskar_hp()
			player_party.append(_battler_from(iskar_with_hp, "iskar", "player"))
	var enemies := [_battler_from(enemy_stats, enemy_id, "enemy")]
	start_party(player_party, enemies)


func start_party(player_party: Array, enemies: Array) -> void:
	battlers = []
	battlers.append_array(player_party)
	battlers.append_array(enemies)
	_build_initiative()
	_ended = false
	_ptr = -1
	_advance()


## Player picks an action for Kael's turn.
func player_action(kind: String, payload: Dictionary = {}) -> void:
	if _ended:
		return
	var idx := _ptr
	var actor: Dictionary = battlers[_order[idx]]
	var actor_idx: int = _order[idx]
	match kind:
		"attack":
			_do_attack(actor_idx, _first_living_enemy_idx())
		"defend":
			actor["defending"] = true
			narration.emit("%s braces." % actor["name"])
		"flee":
			if _rng.randf() < 0.6:
				narration.emit("%s slips away." % actor["name"])
				_end("fled")
				return
			else:
				narration.emit("%s tries to flee but can't break free." % actor["name"])
		"item":
			var item_id: String = payload.get("item_id", "")
			if not _use_heal_item(actor_idx, item_id):
				narration.emit("Can't use that here.")
				return
	_after_turn()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _battler_from(stats: Dictionary, id: String, side: String) -> Dictionary:
	# Carry-over: if stats carries an explicit max_hp, hp may be lower than max
	# (Kael walked into the fight wounded). Default max_hp to hp for blocks
	# that don't track current HP (enemies, freshly-bonded Iskar).
	var hp_now: int = int(stats.get("hp", 10))
	var hp_max: int = int(stats.get("max_hp", hp_now))
	return {
		"id":          id,
		"side":        side,
		"name":        stats.get("name", id.capitalize()),
		"hp":          hp_now,
		"max_hp":      hp_max,
		"atk":         int(stats.get("atk", 1)),
		"def":         int(stats.get("def", 0)),
		"spd":         int(stats.get("spd", 5)),
		"attack_name": stats.get("attack_name", "swings"),
		"defending":   false,
		"burn_turns":  0,
		"burn_per_turn": 0,
		"guard_target": "",
	}


func _build_initiative() -> void:
	var indices: Array = []
	for i in battlers.size():
		indices.append(i)
	indices.sort_custom(func(a, b): return int(battlers[a]["spd"]) > int(battlers[b]["spd"]))
	_order = indices


func _advance() -> void:
	if _ended:
		return
	var n: int = _order.size()
	for _i in n:
		_ptr = (_ptr + 1) % n
		var idx: int = _order[_ptr]
		if int(battlers[idx]["hp"]) > 0:
			_take_turn(idx)
			return
	_end("won" if not _any_living("enemy") else "lost")


func _take_turn(idx: int) -> void:
	var b: Dictionary = battlers[idx]
	_apply_burn(idx)
	if int(b["hp"]) <= 0:
		_after_turn()
		return
	b["defending"] = false
	hp_changed.emit(b["id"], b["hp"], b["max_hp"])
	if b["side"] == "player" and b["id"] == "kael":
		awaiting_player_input.emit()
		return
	if b["side"] == "player" and b["id"] == "iskar":
		_iskar_act(idx)
	else:
		_enemy_act(idx)
	_after_turn()


func _iskar_act(idx: int) -> void:
	var action: Dictionary = IskarCompanion.pick_action(_rng)
	var actor: Dictionary = battlers[idx]
	match action["kind"]:
		"bite":
			_do_attack(idx, _first_living_enemy_idx())
		"ember_spark":
			_do_ember_spark(idx, _first_living_enemy_idx())
		"guard":
			var kael_idx := _find_battler_idx("kael")
			if kael_idx >= 0:
				actor["guard_target"] = "kael"
				narration.emit("%s steps between %s and danger." % [actor["name"], battlers[kael_idx]["name"]])
		"support_buff":
			var kael_idx2 := _find_battler_idx("kael")
			if kael_idx2 >= 0:
				battlers[kael_idx2]["defending"] = true
				narration.emit("%s chirps; %s feels steadier." % [actor["name"], battlers[kael_idx2]["name"]])


func _enemy_act(idx: int) -> void:
	var targets: Array = []
	for i in battlers.size():
		if battlers[i]["side"] == "player" and int(battlers[i]["hp"]) > 0:
			targets.append(i)
	if targets.is_empty():
		return
	var target_idx: int = targets[_rng.randi() % targets.size()]
	# Iskar's Defensive stance: redirect a hit on Kael to himself.
	if battlers[target_idx]["id"] == "kael":
		for i in battlers.size():
			if battlers[i]["id"] == "iskar" and int(battlers[i]["hp"]) > 0 and battlers[i].get("guard_target", "") == "kael":
				target_idx = i
				narration.emit("%s leaps in to take the hit." % battlers[i]["name"])
				battlers[i]["guard_target"] = ""
				break
	_do_attack(idx, target_idx)


func _do_attack(attacker_idx: int, defender_idx: int) -> void:
	if defender_idx < 0:
		return
	var a: Dictionary = battlers[attacker_idx]
	var d: Dictionary = battlers[defender_idx]
	var base_dmg: int = int(a["atk"]) - int(d["def"])
	var dmg: int = max(1, base_dmg + _rng.randi_range(-RNG_DELTA, RNG_DELTA))
	if d["defending"]:
		dmg = max(1, dmg / 2)
	d["hp"] = max(0, int(d["hp"]) - dmg)
	narration.emit("%s %s %s for %d damage." % [a["name"], a["attack_name"], d["name"], dmg])
	hp_changed.emit(d["id"], d["hp"], d["max_hp"])


func _do_ember_spark(attacker_idx: int, defender_idx: int) -> void:
	if defender_idx < 0:
		return
	var spec: Dictionary = CombatantStats.base_stats("iskar").get("ember_spark", {
		"atk_bonus": 2, "burn_turns": 3, "burn_per_turn": 2,
	})
	var a: Dictionary = battlers[attacker_idx]
	var d: Dictionary = battlers[defender_idx]
	var base_dmg: int = int(a["atk"]) + int(spec.get("atk_bonus", 0)) - int(d["def"])
	var dmg: int = max(2, base_dmg + _rng.randi_range(-RNG_DELTA, RNG_DELTA))
	d["hp"] = max(0, int(d["hp"]) - dmg)
	d["burn_turns"] = int(spec.get("burn_turns", 3))
	d["burn_per_turn"] = int(spec.get("burn_per_turn", 2))
	narration.emit("%s breathes embers at %s for %d. Burning." % [a["name"], d["name"], dmg])
	hp_changed.emit(d["id"], d["hp"], d["max_hp"])


func _apply_burn(idx: int) -> void:
	var b: Dictionary = battlers[idx]
	if int(b.get("burn_turns", 0)) <= 0:
		return
	var tick: int = int(b.get("burn_per_turn", 0))
	if tick <= 0:
		b["burn_turns"] = 0
		return
	b["hp"] = max(0, int(b["hp"]) - tick)
	b["burn_turns"] = int(b["burn_turns"]) - 1
	narration.emit("%s burns. -%d HP." % [b["name"], tick])
	hp_changed.emit(b["id"], b["hp"], b["max_hp"])


func _use_heal_item(actor_idx: int, item_id: String) -> bool:
	var item: Dictionary = ItemRegistry.get_item(item_id)
	if item.is_empty():
		return false
	var heal: int = int(item.get("stats", {}).get("heal", 0))
	if heal <= 0:
		return false
	if not Inventory.has(item_id):
		return false
	Inventory.remove(item_id, 1)
	var a: Dictionary = battlers[actor_idx]
	var new_hp: int = min(int(a["max_hp"]), int(a["hp"]) + heal)
	var actual_heal: int = new_hp - int(a["hp"])
	a["hp"] = new_hp
	narration.emit("%s uses %s. +%d HP." % [a["name"], item.get("name", item_id), actual_heal])
	hp_changed.emit(a["id"], a["hp"], a["max_hp"])
	return true


func _after_turn() -> void:
	if _ended:
		return
	if not _any_living("player"):
		_end("lost"); return
	if not _any_living("enemy"):
		_end("won"); return
	_advance()


func _end(outcome: String) -> void:
	if _ended:
		return
	_ended = true
	combat_ended.emit(outcome)


func _any_living(side: String) -> bool:
	for b in battlers:
		if b["side"] == side and int(b["hp"]) > 0:
			return true
	return false


func _first_living_enemy_idx() -> int:
	for i in battlers.size():
		if battlers[i]["side"] == "enemy" and int(battlers[i]["hp"]) > 0:
			return i
	return -1


func _find_battler_idx(id: String) -> int:
	for i in battlers.size():
		if battlers[i]["id"] == id:
			return i
	return -1


# Legacy accessors used by CombatController in the 1v1 case.
func player() -> Dictionary:
	for b in battlers:
		if b["side"] == "player" and b["id"] == "kael":
			return b
	return {}


func enemy() -> Dictionary:
	for b in battlers:
		if b["side"] == "enemy":
			return b
	return {}


func iskar() -> Dictionary:
	for b in battlers:
		if b["id"] == "iskar":
			return b
	return {}
