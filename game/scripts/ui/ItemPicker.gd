extends PanelContainer
##
## A small overlay that lists offerable inventory items (consumables and
## key items). Pick one -> emits picked(item_id). Esc closes without picking.
##

signal picked(item_id: String)
signal cancelled

@onready var _list: VBoxContainer = $Margin/List


func open() -> void:
	_build()
	visible = true
	if _list.get_child_count() > 0:
		var first := _list.get_child(0) as Button
		first.grab_focus.call_deferred()


func close() -> void:
	visible = false
	for child in _list.get_children():
		child.queue_free()


func _build() -> void:
	for child in _list.get_children():
		child.queue_free()
	var items := Inventory.offerable_items()
	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "Nothing to offer."
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.94, 0.94, 0.88))
		_list.add_child(lbl)
		return
	for i in items.size():
		var item: Dictionary = items[i]
		var btn := Button.new()
		var label := "%d. %s" % [i + 1, item["name"]]
		if int(item["count"]) > 1:
			label += "  x%d" % item["count"]
		btn.text = label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color",         Color(0.94, 0.94, 0.88))
		btn.add_theme_color_override("font_hover_color",   Color(0.94, 0.94, 0.88))
		btn.add_theme_color_override("font_focus_color",   Color(0.94, 0.66, 0.28))
		btn.add_theme_color_override("font_pressed_color", Color(0.94, 0.66, 0.28))
		var sb_flat := StyleBoxFlat.new()
		sb_flat.bg_color = Color(0.16, 0.13, 0.13, 0)
		sb_flat.content_margin_left = 4
		sb_flat.content_margin_right = 4
		sb_flat.content_margin_top = 1
		sb_flat.content_margin_bottom = 1
		var sb_focus := StyleBoxFlat.new()
		sb_focus.bg_color = Color(0.36, 0.27, 0.13, 1)
		sb_focus.content_margin_left = 4
		sb_focus.content_margin_right = 4
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
		btn.custom_minimum_size = Vector2(0, 22)
		btn.pressed.connect(func(): picked.emit(item["id"]))
		_list.add_child(btn)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
