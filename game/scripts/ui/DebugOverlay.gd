extends CanvasLayer
##
## Toggleable debug overlay (backtick).
##
## Surfaces:
##   - last dialogue turn (npc, topic, gate, prompt size, raw + validated)
##   - provider toggle (Mock / Proxy)
##   - force fallback toggle
##   - quest state list
##   - save / load buttons
##   - NPC inspector (memory + dossier snapshot for picked NPC)
##

@onready var _panel:        Panel         = $Panel
@onready var _turn_label:   Label         = $Panel/Turn
@onready var _quest_label:  Label         = $Panel/Quests
@onready var _provider_btn: Button        = $Panel/Buttons/ProviderToggle
@onready var _fallback_btn: Button        = $Panel/Buttons/FallbackToggle
@onready var _save_btn:     Button        = $Panel/Buttons/Save
@onready var _load_btn:     Button        = $Panel/Buttons/Load
@onready var _npc_picker:   OptionButton  = $Panel/NPC/Picker
@onready var _npc_view:     Label         = $Panel/NPC/View

var _visible: bool = false
var _last_turn: Dictionary = {}


func _ready() -> void:
	_panel.visible = false
	EventBus.debug_turn_recorded.connect(_on_turn_recorded)
	EventBus.quest_state_changed.connect(func(_q, _s): _refresh_quests())
	EventBus.npc_dossier_mutated.connect(func(_n, _b, _t): _refresh_npc())

	_provider_btn.pressed.connect(_on_provider_toggle)
	_fallback_btn.pressed.connect(_on_fallback_toggle)
	_save_btn.pressed.connect(_on_save)
	_load_btn.pressed.connect(_on_load)
	_npc_picker.item_selected.connect(func(_i): _refresh_npc())
	_populate_npc_picker()
	_refresh_quests()
	_refresh_buttons()
	_refresh_npc()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_toggle()


func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_render_turn()
		_refresh_quests()
		_refresh_buttons()
		_refresh_npc()


# ---------------------------------------------------------------------------
# Turn panel
# ---------------------------------------------------------------------------

func _on_turn_recorded(info: Dictionary) -> void:
	_last_turn = info
	if _visible:
		_render_turn()


func _render_turn() -> void:
	if _last_turn.is_empty():
		_turn_label.text = "(no dialogue turn yet)"
		return
	var gate: Dictionary = _last_turn.get("gate", {})
	var validated: Dictionary = _last_turn.get("validated", {})
	var issues: Array = _last_turn.get("issues", [])
	var lines := [
		"npc        %s" % _last_turn.get("npc_id", ""),
		"topic      %s" % _last_turn.get("topic", ""),
		"verb       %s (%s)" % [_last_turn.get("verb", ""), _last_turn.get("press_angle", "")],
		"gate       %s (%s)" % [gate.get("decision", ""), gate.get("reason", "")],
		"reveal     %s" % gate.get("reveal_ready", false),
		"prompt     %d bytes" % int(_last_turn.get("prompt_size", 0)),
		"tone       %s" % validated.get("tone", ""),
		"granted    %s" % str(_last_turn.get("granted_facts", [])),
		"issues     %s" % str(issues),
	]
	_turn_label.text = "\n".join(lines)


# ---------------------------------------------------------------------------
# Quest list
# ---------------------------------------------------------------------------

func _refresh_quests() -> void:
	if QuestState._states.is_empty():
		_quest_label.text = "Quests: (none)"
		return
	var rows := ["Quests:"]
	for q in QuestState._states.keys():
		rows.append("  %s -> %s" % [q, QuestState._states[q]])
	_quest_label.text = "\n".join(rows)


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

func _refresh_buttons() -> void:
	_provider_btn.text = "Provider: %s" % ("Mock" if Config.use_mock_ai else "Proxy/Haiku")
	_fallback_btn.text = "Force Fallback: %s" % ("ON" if FallbackProvider.force_active else "off")


func _on_provider_toggle() -> void:
	Config.use_mock_ai = not Config.use_mock_ai
	_refresh_buttons()


func _on_fallback_toggle() -> void:
	FallbackProvider.force_active = not FallbackProvider.force_active
	_refresh_buttons()


func _on_save() -> void:
	if SaveManager.save_slot():
		print("[DebugOverlay] saved.")
	else:
		print("[DebugOverlay] save refused: %s" % SaveBlocker.reason())


func _on_load() -> void:
	if SaveManager.load_slot():
		print("[DebugOverlay] loaded.")
	else:
		print("[DebugOverlay] no save file.")


# ---------------------------------------------------------------------------
# NPC inspector
# ---------------------------------------------------------------------------

func _populate_npc_picker() -> void:
	_npc_picker.clear()
	for npc_id in NpcProfileRegistry.all_ids():
		_npc_picker.add_item(npc_id)


func _refresh_npc() -> void:
	if _npc_picker.item_count == 0:
		_npc_view.text = "(no NPCs)"
		return
	var npc_id: String = _npc_picker.get_item_text(_npc_picker.selected if _npc_picker.selected >= 0 else 0)
	var mem: Dictionary = NpcMemoryStore._by_id.get(npc_id, {})
	var dossier: Array = NpcDossierStore.dossier_for(npc_id)
	var lines: Array = ["[%s]" % npc_id]
	lines.append("memory:")
	for k in mem.keys():
		var s: String = str(mem[k])
		if s.length() > 60:
			s = s.substr(0, 60) + "..."
		lines.append("  %s = %s" % [k, s])
	lines.append("dossier (%d):" % dossier.size())
	for e in dossier:
		var forb: String = "*" if e.get("forbidden_to_share", false) else " "
		lines.append("  %s%s (%s)" % [forb, e.get("id", ""), e.get("tier", "")])
	_npc_view.text = "\n".join(lines)
