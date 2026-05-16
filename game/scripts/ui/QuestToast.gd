extends CanvasLayer
##
## Small top-of-screen toast that pops when a quest changes state.
## Auto-dismisses after a few seconds.
##

const HOLD_SECONDS := 3.5

const QUEST_LABELS := {
	"dragon_sighting": "The Reeve's Errand",
}

const STATE_LABELS := {
	"active":   "begun",
	"complete": "complete",
}

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label


func _ready() -> void:
	_panel.visible = false
	EventBus.quest_state_changed.connect(_on_quest_state_changed)
	# Same pattern as the notice board: clear the toast when the player
	# opens a dialog, so it doesn't sit on top of the next conversation.
	EventBus.dialogue_opened.connect(func(_npc_id): _panel.visible = false)


func _on_quest_state_changed(quest_id: String, new_state: String) -> void:
	var quest_label: String = QUEST_LABELS.get(quest_id, quest_id)
	var state_label: String = STATE_LABELS.get(new_state, new_state)
	if new_state == "complete":
		_label.text = "Quest complete: %s" % quest_label
	elif new_state == "active":
		_label.text = "Quest %s: %s" % [state_label, quest_label]
	else:
		_label.text = "%s: %s" % [quest_label, state_label]
	_panel.visible = true
	await get_tree().create_timer(HOLD_SECONDS).timeout
	_panel.visible = false
