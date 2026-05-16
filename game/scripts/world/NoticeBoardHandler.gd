extends CanvasLayer
##
## Listens for the notice_board_read fact_granted event and shows the three
## notice lines for ~4 seconds. Phase 3 stub: the fact is granted by the
## player controller; this handler is purely presentational. The FactLedger
## (Phase 5) will consume the fact for real.
##

const NOTICE_TEXT := """[ NOTICE ]
Dragon sighted near the old tower. Whoever brings proof of its
whereabouts to Reeve Halden is owed coin and bread.

Lost goat. Brown nose. Reward an ale. - Pell.

Sister Edda's evening service cancelled until further notice."""

const DURATION := 4.0

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label


func _ready() -> void:
	_panel.visible = false
	_label.text = NOTICE_TEXT
	EventBus.fact_granted.connect(_on_fact_granted)
	# Dismiss the overlay if the player opens a dialog while it's still up.
	EventBus.dialogue_opened.connect(_on_dialogue_opened)


func _on_fact_granted(fact_id: String, _source: Dictionary) -> void:
	if fact_id != "notice_board_read":
		return
	_panel.visible = true
	await get_tree().create_timer(DURATION).timeout
	_panel.visible = false


func _on_dialogue_opened(_npc_id: String) -> void:
	_panel.visible = false
