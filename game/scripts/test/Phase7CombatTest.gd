extends Node
##
## Phase 7 Increment 2: drive combat through CombatController + CombatEngine
## from outside the UI. Verifies:
##   - encounter touch -> combat starts
##   - attack ticks enemy HP down
##   - winning removes the encounter from the world
##   - flee returns control to overworld without removing the encounter
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"

var _failures: Array[String] = []
var _outcomes: Array[String] = []


func _ready() -> void:
	EventBus.combat_ended.connect(func(o): _outcomes.append(o))
	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	await _settle(3)

	await _case_attack_until_win()
	await _case_flee_keeps_encounter()

	_finish()


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _case_attack_until_win() -> void:
	_outcomes.clear()
	# Make sure the wolf is still on the map.
	_assert(WorldState.encounters_by_id.has("wolf_path_a"),
		"wolf_path_a should exist at start")
	CombatController.start_encounter("wolf_path_a", "wolf")
	await _settle(2)
	_assert(CombatController.is_active(), "combat should be active after start")

	# Mash Attack until the wolf falls. Safety cap to avoid infinite loops.
	var guard := 50
	while CombatController.is_active() and guard > 0:
		CombatController._on_action_chosen("attack", {})
		await _settle(2)
		guard -= 1

	_assert("won" in _outcomes,
		"expected to win the wolf fight; outcomes=%s" % [_outcomes])
	_assert(not WorldState.encounters_by_id.has("wolf_path_a"),
		"wolf_path_a should be removed from world after win")
	print("  Wolf defeated via Attack loop (guard remaining: %d)" % guard)


func _case_flee_keeps_encounter() -> void:
	_outcomes.clear()
	_assert(WorldState.encounters_by_id.has("bandit_path_b"),
		"bandit_path_b should exist before flee test")
	CombatController.start_encounter("bandit_path_b", "bandit")
	await _settle(2)

	# Spam flee a few times; with 60% success rate, 10 attempts is essentially
	# guaranteed to eventually succeed -- and even if one fails the enemy
	# whacks us, then we try again.
	var guard := 25
	while CombatController.is_active() and guard > 0:
		CombatController._on_action_chosen("flee", {})
		await _settle(2)
		guard -= 1

	_assert("fled" in _outcomes or "lost" in _outcomes,
		"expected to flee or lose; outcomes=%s" % [_outcomes])
	# Whether we fled or were beaten, the encounter sprite stays alive.
	_assert(WorldState.encounters_by_id.has("bandit_path_b"),
		"bandit_path_b should remain after flee/lose")
	print("  Flee path resolved: outcomes=%s" % [_outcomes])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Phase7CombatTest] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase7CombatTest] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
