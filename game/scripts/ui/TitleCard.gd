extends CanvasLayer
##
## Closing card for the demo build. Triggered by Halden's `turn_in_paid`
## moment (quest_paid signal). Pauses input and fades in over the scene.
##

const LINES := [
	"AURELIX",
	"",
	"Reeve Halden's coin is in your purse",
	"and his bread is in your pack.",
	"",
	"The gold-eyed one is still out there.",
	"The drake at your heel knows more than he says.",
	"",
	"Demo build — 2026",
	"",
	"Press Esc to close.",
]

@onready var _panel: ColorRect = $Panel
@onready var _label: Label = $Panel/Label

var _shown: bool = false


func _ready() -> void:
	_panel.visible = false
	_label.text = "\n".join(LINES)
	EventBus.quest_paid.connect(_on_quest_paid)


func _on_quest_paid(quest_id: String) -> void:
	if quest_id != "dragon_sighting":
		return
	if _shown:
		return
	_shown = true
	# Defer one frame so the dialog box can finish rendering its own close.
	call_deferred("_show")


func _show() -> void:
	_panel.visible = true
	_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 1.5)


func _unhandled_input(event: InputEvent) -> void:
	if not _panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_panel.visible = false
		get_tree().quit(0)
