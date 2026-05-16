extends CanvasLayer
##
## EarthBound-style combat overlay. The world is dimmed and the panel docks
## at the bottom with HP bars + action menu + narration line.
##
## Signals into CombatController:
##   - action_chosen(kind, payload)   from the action menu
##
## The overlay is purely presentational; CombatEngine owns state.
##

signal action_chosen(kind: String, payload: Dictionary)
signal item_picker_requested
signal stance_chosen(stance: String)

@onready var _dim:           ColorRect      = $Dim
@onready var _enemy_name:    Label          = $EnemyHud/Name
@onready var _enemy_hp_lbl:  Label          = $EnemyHud/HpLabel
@onready var _enemy_hp_bar:  ProgressBar    = $EnemyHud/HpBar
@onready var _panel:         Panel          = $Panel
@onready var _narration:     Label          = $Panel/Narration
@onready var _kael_hp_lbl:   Label          = $Panel/KaelLine/Hp
@onready var _kael_hp_bar:   ProgressBar    = $Panel/KaelLine/Bar
@onready var _iskar_line:    Control        = $Panel/IskarLine
@onready var _iskar_hp_lbl:  Label          = $Panel/IskarLine/Hp
@onready var _iskar_hp_bar:  ProgressBar    = $Panel/IskarLine/Bar
@onready var _actions:       VBoxContainer  = $Panel/Actions
@onready var _stance_block:  Control        = $Panel/StanceBlock
@onready var _stances:       VBoxContainer  = $Panel/StanceBlock/Stances
@onready var _item_picker:   PanelContainer = $ItemPicker


func _ready() -> void:
	visible = false
	_item_picker.visible = false
	_item_picker.picked.connect(_on_item_picked)
	_item_picker.cancelled.connect(_close_item_picker)


# ---------------------------------------------------------------------------
# Public API used by CombatController
# ---------------------------------------------------------------------------

func show_combat(enemy_battler: Dictionary, kael_battler: Dictionary, iskar_battler: Dictionary = {}) -> void:
	visible = true
	_enemy_name.text   = enemy_battler.get("name", "Enemy").to_upper()
	_set_enemy_hp(enemy_battler["hp"], enemy_battler["max_hp"])
	_set_kael_hp(kael_battler["hp"], kael_battler["max_hp"])
	_narration.text = ""
	if iskar_battler.is_empty():
		_iskar_line.visible = false
		_stance_block.visible = false
	else:
		_iskar_line.visible = true
		_stance_block.visible = true
		_set_iskar_hp(int(iskar_battler["hp"]), int(iskar_battler["max_hp"]))
		_build_stances()
	_build_actions()


func hide_combat() -> void:
	visible = false


func set_narration(text: String) -> void:
	_narration.text = text


func set_enemy_hp(hp: int, max_hp: int) -> void:
	_set_enemy_hp(hp, max_hp)


func set_kael_hp(hp: int, max_hp: int) -> void:
	_set_kael_hp(hp, max_hp)


func set_iskar_hp(hp: int, max_hp: int) -> void:
	_set_iskar_hp(hp, max_hp)


func enable_actions(enable: bool) -> void:
	for child in _actions.get_children():
		if child is Button:
			(child as Button).disabled = not enable
	if enable and _actions.get_child_count() > 0:
		var first := _actions.get_child(0) as Button
		first.grab_focus.call_deferred()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _set_enemy_hp(hp: int, max_hp: int) -> void:
	_enemy_hp_bar.max_value = max(1, max_hp)
	_enemy_hp_bar.value = max(0, hp)
	_enemy_hp_lbl.text = "%d/%d" % [max(0, hp), max(1, max_hp)]


func _set_kael_hp(hp: int, max_hp: int) -> void:
	_kael_hp_bar.max_value = max(1, max_hp)
	_kael_hp_bar.value = max(0, hp)
	_kael_hp_lbl.text = "%d/%d" % [max(0, hp), max(1, max_hp)]


func _set_iskar_hp(hp: int, max_hp: int) -> void:
	_iskar_hp_bar.max_value = max(1, max_hp)
	_iskar_hp_bar.value = max(0, hp)
	_iskar_hp_lbl.text = "%d/%d" % [max(0, hp), max(1, max_hp)]


func _build_stances() -> void:
	for child in _stances.get_children():
		_stances.remove_child(child)
		child.queue_free()
	var entries := [
		{"label": "AGGR.", "stance": IskarCompanion.STANCE_AGGRESSIVE},
		{"label": "DEF.",  "stance": IskarCompanion.STANCE_DEFENSIVE},
		{"label": "SUPP.", "stance": IskarCompanion.STANCE_SUPPORT},
	]
	for entry in entries:
		var btn := Button.new()
		var marker: String = "* " if entry["stance"] == IskarCompanion.stance else "  "
		btn.text = marker + entry["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 8)
		_apply_flat_button_style(btn)
		btn.custom_minimum_size = Vector2(0, 12)
		var stance: String = entry["stance"]
		btn.pressed.connect(func(): _on_stance_pressed(stance))
		_stances.add_child(btn)


func _on_stance_pressed(new_stance: String) -> void:
	IskarCompanion.set_stance(new_stance)
	_build_stances()    # refresh marker
	stance_chosen.emit(new_stance)


func _apply_flat_button_style(btn: Button) -> void:
	btn.add_theme_color_override("font_color",         Color(0.94, 0.94, 0.88))
	btn.add_theme_color_override("font_hover_color",   Color(0.94, 0.94, 0.88))
	btn.add_theme_color_override("font_focus_color",   Color(0.94, 0.66, 0.28))
	btn.add_theme_color_override("font_pressed_color", Color(0.94, 0.66, 0.28))
	var sb_flat := StyleBoxFlat.new()
	sb_flat.bg_color = Color(0.16, 0.13, 0.13, 0)
	sb_flat.content_margin_left = 6
	sb_flat.content_margin_right = 6
	sb_flat.content_margin_top = 1
	sb_flat.content_margin_bottom = 1
	var sb_focus := StyleBoxFlat.new()
	sb_focus.bg_color = Color(0.36, 0.27, 0.13, 1)
	sb_focus.content_margin_left = 6
	sb_focus.content_margin_right = 6
	sb_focus.content_margin_top = 1
	sb_focus.content_margin_bottom = 1
	sb_focus.border_color = Color(0.94, 0.66, 0.28, 1)
	sb_focus.border_width_left = 1
	sb_focus.border_width_top = 1
	sb_focus.border_width_right = 1
	sb_focus.border_width_bottom = 1
	btn.add_theme_stylebox_override("normal", sb_flat)
	btn.add_theme_stylebox_override("hover",  sb_flat)
	btn.add_theme_stylebox_override("focus",  sb_focus)
	btn.add_theme_stylebox_override("pressed", sb_focus)


func _build_actions() -> void:
	# Remove old buttons immediately. queue_free() alone is deferred, so
	# the old buttons would still be in the tree when enable_actions()
	# tries to grab_focus on the new first child -- it would hit the
	# stale button instead. remove_child + queue_free fixes it.
	for child in _actions.get_children():
		_actions.remove_child(child)
		child.queue_free()
	var entries := [
		{"label": "1. ATTACK", "kind": "attack"},
		{"label": "2. ITEM",   "kind": "item"},
		{"label": "3. DEFEND", "kind": "defend"},
		{"label": "4. FLEE",   "kind": "flee"},
	]
	for entry in entries:
		var btn := Button.new()
		btn.text = entry["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color",         Color(0.94, 0.94, 0.88))
		btn.add_theme_color_override("font_hover_color",   Color(0.94, 0.94, 0.88))
		btn.add_theme_color_override("font_focus_color",   Color(0.94, 0.66, 0.28))
		btn.add_theme_color_override("font_pressed_color", Color(0.94, 0.66, 0.28))
		var sb_flat := StyleBoxFlat.new()
		sb_flat.bg_color = Color(0.16, 0.13, 0.13, 0)
		sb_flat.content_margin_left = 6
		sb_flat.content_margin_right = 6
		sb_flat.content_margin_top = 1
		sb_flat.content_margin_bottom = 1
		var sb_focus := StyleBoxFlat.new()
		sb_focus.bg_color = Color(0.36, 0.27, 0.13, 1)
		sb_focus.content_margin_left = 6
		sb_focus.content_margin_right = 6
		sb_focus.content_margin_top = 1
		sb_focus.content_margin_bottom = 1
		sb_focus.border_color = Color(0.94, 0.66, 0.28, 1)
		sb_focus.border_width_left = 1
		sb_focus.border_width_top = 1
		sb_focus.border_width_right = 1
		sb_focus.border_width_bottom = 1
		btn.add_theme_stylebox_override("normal", sb_flat)
		btn.add_theme_stylebox_override("hover",  sb_flat)
		btn.add_theme_stylebox_override("focus",  sb_focus)
		btn.add_theme_stylebox_override("pressed", sb_focus)
		btn.custom_minimum_size = Vector2(0, 14)
		var kind: String = entry["kind"]
		btn.pressed.connect(func(): _on_action_pressed(kind))
		_actions.add_child(btn)


func _on_action_pressed(kind: String) -> void:
	if kind == "item":
		_open_item_picker()
		return
	action_chosen.emit(kind, {})


func _open_item_picker() -> void:
	_item_picker.open()


func _on_item_picked(item_id: String) -> void:
	_close_item_picker()
	action_chosen.emit("item", {"item_id": item_id})


func _close_item_picker() -> void:
	_item_picker.close()
	enable_actions(true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _item_picker.visible:
			_close_item_picker()
		return
	# `interact` (E + Enter): activate the focused action button. Without
	# this, pressing E -- which the player learns for NPC dialogue --
	# does nothing in combat.
	if event.is_action_pressed("interact"):
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused is Button:
			(focused as Button).pressed.emit()
		return
	# Number-key shortcuts 1..4 for the action menu, but only while the
	# ItemPicker isn't capturing input.
	if _item_picker.visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		var idx := -1
		match (event as InputEventKey).keycode:
			KEY_1: idx = 0
			KEY_2: idx = 1
			KEY_3: idx = 2
			KEY_4: idx = 3
		if idx >= 0 and idx < _actions.get_child_count():
			(_actions.get_child(idx) as Button).pressed.emit()
