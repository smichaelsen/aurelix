extends CanvasLayer
##
## Kael's journal as a screen-filling parchment panel.
##
## Left: list of accrued briefings, grouped by category.
## Right: Kael's answer to the current query.
## Bottom: authored quick-questions + free-text input.
##

signal option_chosen(option: Dictionary)
signal text_submitted(text: String)
signal closed

const MAX_OPTIONS := 4

@onready var _panel:     Panel          = $Panel
@onready var _entries:   VBoxContainer  = $Panel/Left/Margin/Entries
@onready var _answer:    Label          = $Panel/Right/Margin/Answer
@onready var _options:   VBoxContainer  = $Panel/Bottom/Options
@onready var _free_text: LineEdit       = $Panel/Bottom/FreeText


func _ready() -> void:
	_panel.visible = false
	_free_text.text_submitted.connect(_on_text_submitted)
	_free_text.caret_blink = true
	_free_text.caret_blink_interval = 0.5
	_free_text.focus_entered.connect(func(): _free_text.edit.call_deferred())
	# Mock AI -> hide the LineEdit (it can't interpret natural questions).
	if Config.use_mock_ai:
		_free_text.visible = false


func show_for(entries_by_category: Dictionary) -> void:
	_panel.visible = true
	_render_entries(entries_by_category)
	_answer.text = "Kael waits for a question."
	_clear_options()


func hide_panel() -> void:
	_panel.visible = false


func set_pending() -> void:
	_answer.text = "..."


func set_answer(text: String) -> void:
	_answer.text = text


func set_options(options: Array) -> void:
	_clear_options()
	var first_btn: Button = null
	for i in range(min(MAX_OPTIONS, options.size())):
		var opt: Dictionary = options[i]
		var btn := Button.new()
		btn.text = "%d. %s" % [i + 1, opt.get("label", "")]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.focus_mode = Control.FOCUS_ALL
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color",         Color(0.11, 0.10, 0.12))
		btn.add_theme_color_override("font_hover_color",   Color(0.11, 0.10, 0.12))
		btn.add_theme_color_override("font_focus_color",   Color(0.94, 0.66, 0.28))
		btn.add_theme_color_override("font_pressed_color", Color(0.94, 0.66, 0.28))
		var sb_flat := StyleBoxFlat.new()
		sb_flat.bg_color = Color(0.878, 0.839, 0.737, 0)
		sb_flat.content_margin_left = 4
		sb_flat.content_margin_right = 4
		sb_flat.content_margin_top = 0
		sb_flat.content_margin_bottom = 0
		var sb_focus := StyleBoxFlat.new()
		sb_focus.bg_color = Color(0.36, 0.27, 0.13, 1)
		sb_focus.content_margin_left = 4
		sb_focus.content_margin_right = 4
		sb_focus.content_margin_top = 0
		sb_focus.content_margin_bottom = 0
		sb_focus.border_color = Color(0.94, 0.66, 0.28, 1)
		sb_focus.border_width_left = 1
		sb_focus.border_width_top = 1
		sb_focus.border_width_right = 1
		sb_focus.border_width_bottom = 1
		btn.add_theme_stylebox_override("normal",  sb_flat)
		btn.add_theme_stylebox_override("hover",   sb_flat)
		btn.add_theme_stylebox_override("focus",   sb_focus)
		btn.add_theme_stylebox_override("pressed", sb_focus)
		btn.custom_minimum_size = Vector2(0, 14)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func(): option_chosen.emit(opt))
		_options.add_child(btn)
		if first_btn == null:
			first_btn = btn
	if first_btn != null:
		# Guard: a rapid second set_options may queue-free this button
		# before the deferred call fires. Skip the grab in that case.
		var b := first_btn
		(func():
			if is_instance_valid(b) and b.is_inside_tree():
				b.grab_focus()
		).call_deferred()


func _clear_options() -> void:
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	text_submitted.emit(text)
	_free_text.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
	elif event.is_action_pressed("journal_toggle"):
		closed.emit()


# ---------------------------------------------------------------------------
# Entries list
# ---------------------------------------------------------------------------

func _render_entries(by_cat: Dictionary) -> void:
	for child in _entries.get_children():
		_entries.remove_child(child)
		child.queue_free()

	const CATEGORY_TITLES := {
		"people":    "People",
		"locations": "Places",
		"events":    "Events",
		"items":     "Items",
		"factions":  "Factions",
		"world":     "World",
	}
	const CATEGORY_ORDER := ["events", "people", "items", "locations", "factions", "world"]

	for cat in CATEGORY_ORDER:
		var entries: Array = by_cat.get(cat, [])
		if entries.is_empty():
			continue
		var header := Label.new()
		header.text = CATEGORY_TITLES.get(cat, cat)
		header.add_theme_font_size_override("font_size", 8)
		header.add_theme_color_override("font_color", Color(0.33, 0.30, 0.32))
		_entries.add_child(header)
		for entry in entries:
			var lbl := Label.new()
			var briefing := BriefingRegistry.get_briefing(entry["id"], entry["tier"])
			var title: String = briefing.get("title", entry["id"])
			var tier_marker := " (rumor)" if entry["tier"] == "rumor" else ""
			lbl.text = "  " + title + tier_marker
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.add_theme_color_override("font_color", Color(0.11, 0.10, 0.12))
			_entries.add_child(lbl)
