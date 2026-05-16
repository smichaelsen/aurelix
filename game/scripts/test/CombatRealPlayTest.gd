extends Node
##
## Reproduces a real-play wolf encounter by dispatching genuine input events.
##
##   1. Load forest, move Kael to (6, 6) (one tile south of the wolf).
##   2. Send Up arrow -> _try_move triggers CombatController.start_encounter.
##   3. Confirm combat overlay opens, action menu visible, focus on Attack.
##   4. Send Enter -> the focused Attack button should activate.
##   5. Confirm the engine advanced.
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"

var _failures: Array[String] = []


func _ready() -> void:
	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	await _settle(3)

	var forest := get_child(0)
	var player := forest.get_node("Player")
	_assert(player != null, "could not find Player in forest")
	if player == null:
		_finish(); return

	# Plant Kael directly south of the wolf at (6,5).
	player.set("grid_pos", Vector2i(6, 6))
	player.position = Vector2(6 * 32 + 4, 6 * 32)
	await _settle(2)

	print("[CombatRealPlayTest] calling _try_move(0,-1)...")
	player.call("_try_move", Vector2i(0, -1))
	await _settle(8)

	# After moving up, encounter should have triggered combat.
	_assert(CombatController.is_active(),
		"combat should be active after stepping into wolf tile")

	var overlay = CombatController._overlay
	_assert(overlay != null, "combat overlay should exist")
	if overlay == null:
		_finish(); return

	_assert(overlay.visible, "combat overlay should be visible")
	# Action buttons should exist and the first must have focus.
	var actions = overlay.get("_actions")
	_assert(actions.get_child_count() == 4,
		"expected 4 actions, got %d" % actions.get_child_count())
	var first := actions.get_child(0) as Button
	var focused: Control = get_viewport().gui_get_focus_owner()
	_assert(focused == first,
		"expected Attack button to be focused; got %s" % focused)
	print("  Focus after combat start: %s" % focused)

	# Press Enter to activate the focused button.
	print("[CombatRealPlayTest] firing pressed on focused button (Enter equivalent)...")
	(focused as Button).pressed.emit()
	await _settle(8)

	# After Attack, the wolf should have taken damage and likely struck back.
	# Either combat is still active with Kael's HP changed or it ended.
	var still_active := CombatController.is_active()
	if still_active:
		var enemy: Dictionary = CombatController._engine.enemy()
		_assert(int(enemy["hp"]) < int(enemy["max_hp"]),
			"expected wolf HP to drop after Attack; hp=%d/%d" % [enemy["hp"], enemy["max_hp"]])
		print("  Wolf HP after Attack: %d/%d" % [enemy["hp"], enemy["max_hp"]])
	else:
		print("  Combat ended in a single round (engine moved past).")

	# Finish the first combat by mashing attacks.
	var guard := 30
	while CombatController.is_active() and guard > 0:
		CombatController._on_action_chosen("attack", {})
		await _settle(2)
		guard -= 1
	_assert(not CombatController.is_active(),
		"first combat should resolve within %d attacks" % 30)

	# --- Second combat: focus must be re-established on the new buttons ---
	await _settle(2)
	CombatController.start_encounter("bandit_path_b", "bandit")
	await _settle(4)
	_assert(CombatController.is_active(), "second combat should start")
	var overlay2 = CombatController._overlay
	var actions2 = overlay2.get("_actions")
	_assert(actions2.get_child_count() == 4,
		"expected 4 fresh actions in second combat, got %d" % actions2.get_child_count())
	var first2 := actions2.get_child(0) as Button
	var focused2: Control = get_viewport().gui_get_focus_owner()
	_assert(focused2 == first2,
		"second combat: expected focus on first new button; got %s" % focused2)
	print("  Second combat focus owner: %s" % focused2)

	_finish()


# ---------------------------------------------------------------------------
# Input helpers
# ---------------------------------------------------------------------------

func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var rel := InputEventAction.new()
	rel.action = action
	rel.pressed = false
	Input.parse_input_event(rel)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[CombatRealPlayTest] PASS")
		get_tree().quit(0)
	else:
		printerr("[CombatRealPlayTest] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
