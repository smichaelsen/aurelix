extends Node
##
## Headless coverage for the post-Phase-10 health pass:
##   - PartyHealth basics (damage / heal / clamp)
##   - HP carry-over across fights (the bug we just fixed)
##   - Overworld heal-item via PlayerController._try_heal_self
##   - Edda's pray_heal dialogue action restores party to full
##   - drust_camp encounter resolves to the Drust combatant block (hp=18),
##     not the Bandit copy-paste (hp=14)
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"
const FOREST_GRID_PATH := "res://data/scenes/forest_edge_grid.json"

var _failures: Array[String] = []


func _ready() -> void:
	add_child((load(VILLAGE_PATH) as PackedScene).instantiate())
	await _settle(3)

	_case_party_health_basics()
	await _case_overworld_heal_item()
	await _case_hp_carries_over()
	await _case_edda_pray_heal()
	_case_drust_stats_resolve()

	_finish()


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _case_party_health_basics() -> void:
	PartyHealth.reset_to_full()
	var k_max: int = PartyHealth.kael_max()
	_assert(PartyHealth.get_kael_hp() == k_max,
		"reset_to_full: expected kael hp=%d, got %d" % [k_max, PartyHealth.get_kael_hp()])
	_assert(PartyHealth.kael_is_full(), "kael_is_full true after reset")

	PartyHealth.set_kael_hp(5)
	_assert(PartyHealth.get_kael_hp() == 5,
		"set_kael_hp(5) failed: got %d" % PartyHealth.get_kael_hp())
	_assert(not PartyHealth.kael_is_full(), "kael_is_full false after damage")

	var healed: int = PartyHealth.heal_kael(3)
	_assert(healed == 3, "heal_kael(3) returned %d" % healed)
	_assert(PartyHealth.get_kael_hp() == 8, "hp after +3 heal expected 8, got %d" % PartyHealth.get_kael_hp())

	var overshoot: int = PartyHealth.heal_kael(999)
	_assert(PartyHealth.get_kael_hp() == k_max,
		"heal overshoot clamps at max=%d, got %d" % [k_max, PartyHealth.get_kael_hp()])
	_assert(overshoot == k_max - 8,
		"heal_kael(999) should report actual amount %d, got %d" % [k_max - 8, overshoot])

	PartyHealth.set_kael_hp(-50)
	_assert(PartyHealth.get_kael_hp() == 0, "negative hp clamps to 0")
	PartyHealth.reset_to_full()


func _case_overworld_heal_item() -> void:
	PartyHealth.reset_to_full()
	# Make sure Kael has at least one apple in his bag (starting kit gives 2).
	if not Inventory.has("apple"):
		Inventory.add("apple", 1)
	var apples_before: int = Inventory.count_of("apple")
	PartyHealth.set_kael_hp(max(1, PartyHealth.kael_max() - 5))
	var before_hp: int = PartyHealth.get_kael_hp()

	var player := get_tree().get_first_node_in_group("player_grid")
	_assert(player != null, "player_grid node should be in tree")
	if player == null:
		return
	player._try_heal_self()
	await _settle(1)

	_assert(PartyHealth.get_kael_hp() > before_hp,
		"overworld heal should raise hp; was %d now %d" % [before_hp, PartyHealth.get_kael_hp()])
	_assert(Inventory.count_of("apple") == apples_before - 1,
		"overworld heal should consume one apple (was %d, now %d)" % [
			apples_before, Inventory.count_of("apple"),
		])


func _case_hp_carries_over() -> void:
	# Drain Kael, then fight a wolf and win. After the fight PartyHealth should
	# still reflect post-fight damage -- not snap back to max.
	PartyHealth.reset_to_full()
	var k_max: int = PartyHealth.kael_max()
	var start_hp: int = max(8, k_max - 4)   # ample to survive the wolf
	PartyHealth.set_kael_hp(start_hp)

	# Use an encounter id that isn't on the current scene (village_square has
	# no wolves). remove_encounter on a missing id is a no-op.
	CombatController.start_encounter("test_carryover_wolf", "wolf")
	await _settle(2)
	_assert(CombatController.is_active(),
		"combat should be active after start_encounter")

	# Engine should see the carried-over current HP, not the max.
	var engine_hp: int = int(CombatController._engine.player().get("hp", -1))
	_assert(engine_hp == start_hp,
		"engine should start kael at carried hp=%d, got %d" % [start_hp, engine_hp])

	# Mash Attack until the wolf falls.
	var guard := 50
	while CombatController.is_active() and guard > 0:
		CombatController._on_action_chosen("attack", {})
		await _settle(2)
		guard -= 1
	_assert(guard > 0, "wolf fight didn't resolve within 50 turns")

	_assert(PartyHealth.get_kael_hp() < k_max,
		"after a fight, PartyHealth.kael_hp should be < max (got %d/%d)" % [
			PartyHealth.get_kael_hp(), k_max,
		])
	_assert(PartyHealth.get_kael_hp() <= start_hp,
		"carry-over: hp should be <= pre-fight start (%d), got %d" % [
			start_hp, PartyHealth.get_kael_hp(),
		])


func _case_edda_pray_heal() -> void:
	PartyHealth.set_kael_hp(3)
	_assert(not PartyHealth.kael_is_full(),
		"prep: kael should not be full before pray_heal")

	EventBus.dialogue_requested.emit("edda_priest")
	await _settle(4)
	_assert(DialogueController.is_open(), "Edda dialogue should be open")

	# Find the pray_heal option in the box and pick it. Authored options live
	# in the bank under `default` / `greeting`; pray_heal carries action key.
	var box: Node = DialogueController._box
	if box == null:
		_failures.append("edda: no dialogue box")
		return
	var options := box.get_node("Panel/Options")
	var picked := false
	for child in options.get_children():
		if not (child is Button):
			continue
		if "Pray" in child.text:
			child.emit_signal("pressed")
			picked = true
			break
	_assert(picked, "edda: 'Pray for healing.' option not found in the bank")
	await _settle(3)
	_assert(PartyHealth.kael_is_full(),
		"after pray_heal, kael should be at full hp (got %d/%d)" % [
			PartyHealth.get_kael_hp(), PartyHealth.kael_max(),
		])
	# Close the dialogue so it doesn't leak into later cases.
	DialogueController._on_box_closed()
	await _settle(2)


func _case_drust_stats_resolve() -> void:
	# 1. Stat block exists and has the boss-flavoured HP (18, not 14 = bandit).
	var drust: Dictionary = CombatantStats.base_stats("drust")
	_assert(not drust.is_empty(), "combatants.json should define 'drust'")
	_assert(int(drust.get("hp", -1)) == 18,
		"drust hp expected 18, got %d" % int(drust.get("hp", -1)))
	_assert(bool(drust.get("is_boss", false)), "drust should carry is_boss=true")

	# 2. The forest_edge encounter resolves to combatant=drust, not bandit.
	var f := FileAccess.open(FOREST_GRID_PATH, FileAccess.READ)
	_assert(f != null, "forest_edge_grid.json should be readable")
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	_assert(parsed is Dictionary, "forest_edge_grid.json should parse to dict")
	var drust_combatant: String = ""
	for enc in parsed.get("encounters", []):
		if String(enc.get("id", "")) == "drust_camp":
			drust_combatant = String(enc.get("combatant", ""))
			break
	_assert(drust_combatant == "drust",
		"drust_camp encounter combatant expected 'drust', got '%s'" % drust_combatant)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("[HealthSystemTest] FAIL: ", msg)
	else:
		print("[HealthSystemTest] ok: ", msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[HealthSystemTest] PASS")
		get_tree().quit(0)
	else:
		printerr("[HealthSystemTest] %d failures" % _failures.size())
		get_tree().quit(1)
