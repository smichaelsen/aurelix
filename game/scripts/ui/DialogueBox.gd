extends CanvasLayer
##
## Bottom-of-screen dialogue panel. Renders the current NPC line plus up to
## four authored option buttons and a free-text LineEdit. Pure presentation:
## DialogueController owns the conversation state.
##

signal option_chosen(option: Dictionary)
signal text_submitted(text: String)
signal item_offered(item_id: String)
signal closed

const MAX_OPTIONS := 4

@onready var _panel:        Panel         = $Panel
@onready var _name_lbl:     Label         = $Panel/Name
@onready var _tone_lbl:     Label         = $Panel/Tone
@onready var _dialogue:     Label         = $Panel/Dialogue
@onready var _options:      VBoxContainer = $Panel/Options
@onready var _free_text:    LineEdit      = $Panel/FreeText
@onready var _offer_btn:    Button        = $Panel/OfferButton
@onready var _item_picker:  PanelContainer = $ItemPicker


func _ready() -> void:
	_panel.visible = false
	_free_text.text_submitted.connect(_on_free_text_submitted)
	# When focus reaches the LineEdit (mouse OR keyboard navigation),
	# put it in edit mode immediately and show a blinking caret so the
	# player can start typing without pressing Enter first.
	_free_text.caret_blink = true
	_free_text.caret_blink_interval = 0.5
	_free_text.focus_entered.connect(_on_free_text_focus_entered)

	_offer_btn.add_theme_font_size_override("font_size", 9)
	_offer_btn.pressed.connect(_on_offer_pressed)
	_item_picker.picked.connect(_on_item_picked)
	_item_picker.cancelled.connect(_close_picker)
	_item_picker.visible = false

	# Mock AI can't meaningfully interpret free text; hide the LineEdit
	# when running mock-only so the player isn't promised something the
	# game can't actually deliver. Real Haiku mode keeps it.
	if Config.use_mock_ai:
		_free_text.visible = false


func _on_free_text_focus_entered() -> void:
	# Defer one frame so Godot has finished the focus traversal before we
	# poke the LineEdit's internal edit state.
	_free_text.edit.call_deferred()


func show_for(display_name: String, archetype: String) -> void:
	_panel.visible = true
	_name_lbl.text = display_name.to_upper()
	_tone_lbl.text = "-- " + archetype.replace("_", " ")
	_dialogue.text = ""
	_clear_options()
	_free_text.text = ""
	# Focus is established by set_options once the option buttons exist
	# (LineEdit takes focus by default; arrow keys navigate to options).


func hide_box() -> void:
	_panel.visible = false
	_clear_options()


func set_dialogue(text: String, tone: String) -> void:
	_dialogue.text = text
	_tone_lbl.text = "-- " + tone


func set_pending() -> void:
	_dialogue.text = "..."


func set_options(options: Array) -> void:
	_clear_options()
	var buttons: Array[Button] = []
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
		# Flat, compact styleboxes so 4 buttons fit. The focus stylebox is
		# subtly tinted so the selected option is visible without a border.
		var sb_flat := StyleBoxFlat.new()
		sb_flat.bg_color = Color(0.878, 0.839, 0.737, 0)  # transparent
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
		btn.add_theme_stylebox_override("normal",  sb_flat)
		btn.add_theme_stylebox_override("hover",   sb_flat)
		btn.add_theme_stylebox_override("focus",   sb_focus)
		btn.add_theme_stylebox_override("pressed", sb_focus)
		btn.custom_minimum_size = Vector2(0, 14)
		btn.size_flags_vertical = Control.SIZE_FILL
		btn.pressed.connect(func(): option_chosen.emit(opt))
		_options.add_child(btn)
		buttons.append(btn)

	_wire_focus_chain(buttons)
	# First option takes initial focus. Arrow keys navigate between options
	# and wrap to / from the LineEdit. Once the player navigates to (or
	# clicks) the LineEdit, typing works immediately -- no Enter needed.
	if not buttons.is_empty():
		# Guard against the previous set_options' deferred grab firing on a
		# detached button.
		var b := buttons[0]
		(func():
			if is_instance_valid(b) and b.is_inside_tree():
				b.grab_focus()
		).call_deferred()


## Wire focus neighbors so arrow keys cycle: LineEdit <-> first option <->
## ... <-> last option <-> back to LineEdit.
func _wire_focus_chain(buttons: Array[Button]) -> void:
	if buttons.is_empty():
		_free_text.focus_neighbor_top    = NodePath()
		_free_text.focus_neighbor_bottom = NodePath()
		return
	var lp := _free_text.get_path()
	var first := buttons[0]
	var last  := buttons[buttons.size() - 1]
	first.focus_neighbor_top    = lp
	last.focus_neighbor_bottom  = lp
	_free_text.focus_neighbor_top    = last.get_path()
	_free_text.focus_neighbor_bottom = first.get_path()
	# Between adjacent buttons (Godot auto-detects most of the time, but be
	# explicit so it survives layout quirks).
	for i in buttons.size():
		var b := buttons[i]
		if i > 0:
			b.focus_neighbor_top = buttons[i - 1].get_path()
		if i < buttons.size() - 1:
			b.focus_neighbor_bottom = buttons[i + 1].get_path()


func _clear_options() -> void:
	# Detach immediately so the upcoming first.grab_focus targets a fresh
	# child, not a queued-for-free stale one.
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()


func _on_free_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	text_submitted.emit(text)
	_free_text.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if _item_picker.visible:
			_close_picker()
		else:
			closed.emit()


func _on_offer_pressed() -> void:
	_item_picker.open()


func _on_item_picked(item_id: String) -> void:
	_close_picker()
	item_offered.emit(item_id)


func _close_picker() -> void:
	_item_picker.close()
	_offer_btn.grab_focus.call_deferred()
