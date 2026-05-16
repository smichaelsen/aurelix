extends CanvasLayer
##
## Brief top-of-screen toast that pops on `party_heal_applied`.
## Format: "Apple +5 HP — 19/24". Auto-dismisses.
##
## Lives in each world scene as a sibling of QuestToast; sits a bit lower
## so the two stack instead of overlap.
##

const HOLD_SECONDS := 2.0

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label

var _active_token: int = 0   # cancels older timers when a new heal fires


func _ready() -> void:
	_panel.visible = false
	EventBus.party_heal_applied.connect(_on_party_heal_applied)
	# Hide on dialogue open so the toast doesn't cover the conversation.
	EventBus.dialogue_opened.connect(func(_npc_id): _panel.visible = false)


func _on_party_heal_applied(_who: String, item_id: String, amount: int, hp: int, max_hp: int) -> void:
	var item_name: String = ItemRegistry.name_of(item_id)
	_label.text = "%s +%d HP — %d/%d" % [item_name, amount, hp, max_hp]
	_panel.visible = true
	_active_token += 1
	var token := _active_token
	await get_tree().create_timer(HOLD_SECONDS).timeout
	if token == _active_token:
		_panel.visible = false
