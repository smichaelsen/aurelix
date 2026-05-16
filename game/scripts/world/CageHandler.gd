extends CanvasLayer
##
## Handles the cage interaction in the bandit camp.
##
##   - Requires `drust_dead` fact before the bond can happen
##     (you don't open the cage with Drust still circling).
##   - On bond: plays a short caption, sets IskarCompanion.bonded = true,
##     emits cage_opened so the world can swap the cage sprite.
##

const CAPTION_DURATION := 2.5

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label


func _ready() -> void:
	_panel.visible = false
	EventBus.cage_interacted.connect(_on_cage_interacted)
	if IskarCompanion.bonded:
		_swap_cage_sprite.call_deferred()


func _on_cage_interacted(_object_id: String) -> void:
	if IskarCompanion.bonded:
		_show("The cage stands open. Iskar is at your heel.")
		return
	if not FactLedger.has_fact("drust_dead"):
		_show("Drust is still here. Better not.")
		return

	# Bond.
	IskarCompanion.bond()
	FactLedger.grant_fact("iskar_bonded", {"kind": "world_event", "object_id": "iskar_cage"})
	FactLedger.grant_fact("iskar_named",  {"kind": "world_event", "object_id": "iskar_cage"})
	EventBus.cage_opened.emit()
	_swap_cage_sprite()
	_show("The drake follows you.")


## Swap the visual cage_iskar sprite for cage_empty so the world reflects
## that he's out.
func _swap_cage_sprite() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var props := scene.get_node_or_null("Props")
	if props == null:
		return
	for child in props.get_children():
		var name := String(child.name)
		if "cage_iskar" in name and child is Sprite2D:
			(child as Sprite2D).texture = load("res://assets/tiles/cage_empty.png")
			return


func _show(text: String) -> void:
	_label.text = text
	_panel.visible = true
	await get_tree().create_timer(CAPTION_DURATION).timeout
	_panel.visible = false
