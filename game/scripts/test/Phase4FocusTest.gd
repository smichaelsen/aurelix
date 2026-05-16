extends Node
##
## Verifies focus chain in the dialogue box:
##   - First option gets focus on open
##   - Up from first option wraps to LineEdit
##   - Down from LineEdit goes to first option
##   - Up from LineEdit goes to last option
##   - Down from last option wraps to LineEdit
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"

var _failures: Array[String] = []


func _ready() -> void:
	add_child((load(VILLAGE_PATH) as PackedScene).instantiate())
	await _settle(3)

	EventBus.dialogue_requested.emit("toma_child")
	await _settle(5)

	var box = DialogueController._box
	var free_text = box.get("_free_text")
	var options_box = box.get("_options")
	var n = options_box.get_child_count()
	_assert(n >= 2, "expected at least 2 options for Toma, got %d" % n)

	var first = options_box.get_child(0)
	var last  = options_box.get_child(n - 1)

	# First option should be the current focus owner on open.
	await _settle(2)
	var owner = box.get_viewport().gui_get_focus_owner()
	_assert(owner == first,
		"expected first option to be focused on open, got %s" % owner)

	# first.focus_neighbor_top -> LineEdit
	_assert(first.focus_neighbor_top == free_text.get_path(),
		"first option's focus_neighbor_top should be LineEdit, got %s" % first.focus_neighbor_top)
	# last.focus_neighbor_bottom -> LineEdit
	_assert(last.focus_neighbor_bottom == free_text.get_path(),
		"last option's focus_neighbor_bottom should be LineEdit, got %s" % last.focus_neighbor_bottom)
	# LineEdit.focus_neighbor_top -> last
	_assert(free_text.focus_neighbor_top == last.get_path(),
		"LineEdit's focus_neighbor_top should be last option, got %s" % free_text.focus_neighbor_top)
	# LineEdit.focus_neighbor_bottom -> first
	_assert(free_text.focus_neighbor_bottom == first.get_path(),
		"LineEdit's focus_neighbor_bottom should be first option, got %s" % free_text.focus_neighbor_bottom)

	_finish()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Phase4FocusTest] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase4FocusTest] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
