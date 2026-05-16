extends CanvasLayer
##
## Full-screen parchment panel for Kael's inventory.
##
##   Left:  equipment slots + coins
##   Right: bag rows; consumables with an overworld heal stat get a [Use]
##          button that calls HealService.use_item.
##
## Hotkey is owned by `InventoryController` (I to toggle, Esc/I to close).
##

signal closed

@onready var _panel:     Panel         = $Panel
@onready var _equipment: VBoxContainer = $Panel/Left/Margin/Equipment
@onready var _bag:       VBoxContainer = $Panel/Right/Margin/Bag


func _ready() -> void:
	_panel.visible = false
	EventBus.item_added.connect(_on_inventory_changed)
	EventBus.item_removed.connect(_on_inventory_changed)
	EventBus.party_heal_applied.connect(_on_party_heal_applied)
	EventBus.party_hp_changed.connect(_on_party_hp_changed)


func show_panel() -> void:
	_panel.visible = true
	_rebuild()
	_focus_first_use_button()


func hide_panel() -> void:
	_panel.visible = false


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

func _rebuild() -> void:
	_render_equipment()
	_render_bag()


func _render_equipment() -> void:
	for child in _equipment.get_children():
		_equipment.remove_child(child)
		child.queue_free()

	const SLOTS := [
		["weapon",  "Weapon"],
		["armor",   "Armor"],
		["trinket", "Trinket"],
	]
	for pair in SLOTS:
		var slot_id: String = pair[0]
		var slot_label: String = pair[1]
		var item_id: String = String(Inventory.equipment.get(slot_id, ""))
		var name_text: String = ItemRegistry.name_of(item_id) if item_id != "" else "—"
		var row := _dark_label("%s: %s" % [slot_label, name_text], 16)
		_equipment.add_child(row)

	_equipment.add_child(_spacer(8))
	_equipment.add_child(_dark_label("Coins: %d" % Inventory.coins, 16))
	_equipment.add_child(_spacer(8))
	_equipment.add_child(_dark_label(
		"HP: %d / %d" % [PartyHealth.get_kael_hp(), PartyHealth.kael_max()],
		16,
	))


func _render_bag() -> void:
	for child in _bag.get_children():
		_bag.remove_child(child)
		child.queue_free()

	if Inventory.bag.is_empty():
		_bag.add_child(_dark_label("Bag is empty.", 16))
		return

	for entry in Inventory.bag:
		var item_id: String = entry["id"]
		var count: int = int(entry["count"])
		var item: Dictionary = ItemRegistry.get_item(item_id)
		_bag.add_child(_build_row(item_id, item, count))


func _build_row(item_id: String, item: Dictionary, count: int) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 28)

	var name_text: String = item.get("name", item_id)
	if count > 1:
		name_text += "  x%d" % count
	var name_lbl := _dark_label(name_text, 18)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var stats: Dictionary = item.get("stats", {})
	var stats_text: String = _format_stats(stats)
	if stats_text != "":
		var stats_lbl := _dark_label(stats_text, 14)
		stats_lbl.add_theme_color_override("font_color", Color(0.33, 0.30, 0.32))
		stats_lbl.custom_minimum_size = Vector2(140, 0)
		stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(stats_lbl)

	if _can_use(item):
		row.add_child(_build_use_button(item_id))

	return row


func _can_use(item: Dictionary) -> bool:
	# Today the only overworld "Use" effect is healing Kael. Adding more
	# kinds (cures, throwables) routes through HealService or its siblings;
	# the row builder stays the same.
	return int(item.get("stats", {}).get("heal", 0)) > 0


func _build_use_button(item_id: String) -> Button:
	var btn := Button.new()
	btn.text = "Use"
	btn.focus_mode = Control.FOCUS_ALL
	btn.disabled = PartyHealth.kael_is_full()
	btn.custom_minimum_size = Vector2(56, 22)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color",          Color(0.94, 0.94, 0.88))
	btn.add_theme_color_override("font_hover_color",    Color(0.94, 0.94, 0.88))
	btn.add_theme_color_override("font_focus_color",    Color(0.94, 0.66, 0.28))
	btn.add_theme_color_override("font_pressed_color",  Color(0.94, 0.66, 0.28))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.52, 0.46))
	var sb_flat := StyleBoxFlat.new()
	sb_flat.bg_color = Color(0.16, 0.13, 0.13, 1)
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
	btn.add_theme_stylebox_override("normal",  sb_flat)
	btn.add_theme_stylebox_override("hover",   sb_flat)
	btn.add_theme_stylebox_override("focus",   sb_focus)
	btn.add_theme_stylebox_override("pressed", sb_focus)
	btn.pressed.connect(func(): HealService.use_item(item_id))
	return btn


func _focus_first_use_button() -> void:
	for row in _bag.get_children():
		for child in row.get_children():
			if child is Button and not (child as Button).disabled:
				(child as Button).grab_focus.call_deferred()
				return


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

func _format_stats(stats: Dictionary) -> String:
	if stats.is_empty():
		return ""
	var parts: Array[String] = []
	for key in stats.keys():
		var raw = stats[key]
		if raw is Array:
			parts.append("%s %s" % [key, str(raw)])
		else:
			parts.append("%s +%s" % [key, str(raw)])
	return ", ".join(parts)


func _dark_label(text: String, size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", Color(0.11, 0.10, 0.12))
	return lbl


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_inventory_changed(_item_id: String) -> void:
	if _panel.visible:
		_rebuild()


func _on_party_heal_applied(_who: String, _item_id: String, _amount: int, _hp: int, _max_hp: int) -> void:
	if _panel.visible:
		_rebuild()


func _on_party_hp_changed(_who: String, _hp: int, _max_hp: int) -> void:
	if _panel.visible:
		_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
	elif event.is_action_pressed("inventory_toggle"):
		closed.emit()
