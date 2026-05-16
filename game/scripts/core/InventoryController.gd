extends Node
##
## Opens / closes the inventory panel on `inventory_toggle` ([I]).
##
## Gated while dialogue or combat is active. Mirrors JournalController's
## lifecycle: panel scene instantiated lazily and reused.
##
## Autoload as `InventoryController`.
##

const PANEL_SCENE := preload("res://scenes/ui/InventoryPanel.tscn")

var _panel: Node = null
var _open: bool = false


func _ready() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if DialogueController.is_open():
		return
	if CombatController.is_active():
		return
	if JournalController.is_open():
		return
	if event.is_action_pressed("inventory_toggle"):
		toggle()


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_ensure_panel()
	_open = true
	_panel.show_panel()


func close() -> void:
	_open = false
	if _panel != null:
		_panel.hide_panel()


func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	_panel = PANEL_SCENE.instantiate()
	add_child(_panel)
	_panel.closed.connect(close)
