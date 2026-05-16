extends Node
##
## Headless smoke test for Phase 4: dialogue UI + pipeline.
##
## Loads VillageSquare and exercises:
##   - Toma: open dialogue, see authored options, pick one, response renders
##   - Toma: submit free text -> classifier runs -> response renders
##   - Halden: templated brief plays from authored bank, accept_quest advances
##   - Mara: open_shop action is honored as Phase 4 placeholder (closes box)
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"

var _failures: Array[String] = []

# captured by EventBus listeners
var _facts_granted: Array[String] = []
var _quest_changes: Array[Dictionary] = []


func _ready() -> void:
	EventBus.fact_granted.connect(func(id, _src): _facts_granted.append(id))
	EventBus.quest_state_changed.connect(
		func(q, s): _quest_changes.append({"quest": q, "state": s})
	)

	var ps := load(VILLAGE_PATH) as PackedScene
	add_child(ps.instantiate())

	# Let WorldState + autoloads finish.
	await get_tree().process_frame
	await get_tree().process_frame

	await _case_toma_option()
	await _case_toma_free_text()
	await _case_halden_templated()
	await _case_mara_shop_placeholder()

	_finish()


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _case_toma_option() -> void:
	EventBus.dialogue_requested.emit("toma_child")
	await _settle(3)

	var box: Node = DialogueController._box
	_assert(box != null, "no dialogue box created for Toma")
	if box == null:
		return
	_assert(box.get("_panel").visible, "Toma dialogue panel not visible")
	_assert(box.get("_name_lbl").text == "TOMA",
		"expected name TOMA, got '%s'" % box.get("_name_lbl").text)

	var options = box.get("_options")
	_assert(options.get_child_count() >= 3,
		"expected >=3 options for Toma, got %d" % options.get_child_count())

	# Pick the second option ("What do you know about the tower?"), which is
	# topic_id=the_tower.
	var second := options.get_child(1) as Button
	second.pressed.emit()
	await _settle(4)

	var rendered: String = box.get("_dialogue").text
	_assert(rendered != "..." and not rendered.is_empty(),
		"expected dialogue to render after option, got '%s'" % rendered)

	# Close.
	box.closed.emit()
	await _settle(2)


func _case_toma_free_text() -> void:
	EventBus.dialogue_requested.emit("toma_child")
	await _settle(3)
	var box: Node = DialogueController._box

	# Submit free text mentioning the dragon.
	box.text_submitted.emit("Have you seen the dragon?")
	await _settle(4)

	var rendered: String = box.get("_dialogue").text
	_assert(rendered != "..." and not rendered.is_empty(),
		"expected free-text response to render, got '%s'" % rendered)

	box.closed.emit()
	await _settle(2)


func _case_halden_templated() -> void:
	# Ensure clean state.
	QuestState.set_state("dragon_sighting", QuestState.STATE_NOT_STARTED)
	_quest_changes.clear()

	EventBus.dialogue_requested.emit("halden_reeve")
	await _settle(3)
	var box: Node = DialogueController._box

	var rendered: String = box.get("_dialogue").text
	_assert("dragon" in rendered.to_lower() or "notice" in rendered.to_lower(),
		"expected Halden's brief to mention dragon/notice, got '%s'" % rendered)

	var options = box.get("_options")
	_assert(options.get_child_count() >= 2,
		"expected Halden options to be authored, got %d" % options.get_child_count())

	# Click "I'll find your dragon." -> action: accept_quest.
	(options.get_child(0) as Button).pressed.emit()
	await _settle(3)

	var changed_to_active := false
	for ch in _quest_changes:
		if ch.get("quest") == "dragon_sighting" and ch.get("state") == "active":
			changed_to_active = true
			break
	_assert(changed_to_active,
		"expected quest_state_changed(dragon_sighting, active), got %s" % _quest_changes)

	box.closed.emit()
	await _settle(2)


func _case_mara_shop_placeholder() -> void:
	EventBus.dialogue_requested.emit("mara_blacksmith")
	await _settle(3)
	var box: Node = DialogueController._box
	_assert(box.get("_panel").visible, "Mara dialogue panel not visible")

	# First option is "Show me your wares." with action: open_shop.
	var options = box.get("_options")
	(options.get_child(0) as Button).pressed.emit()
	await _settle(3)
	_assert(not box.get("_panel").visible,
		"expected box to close on open_shop placeholder")


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
		print("[Phase4Test] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase4Test] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
