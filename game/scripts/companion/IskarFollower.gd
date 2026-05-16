extends Node2D
##
## Overworld follower sprite. Visible whenever Iskar is bonded; trails Kael
## by one tile.
##
## Placement: as a sibling of the Player node in each scene that supports
## the companion (currently forest_edge; villager scene to follow once
## bonded). The follower sets its initial position to Kael's spawn tile so
## visually he and Iskar share the cage spawn moment.
##

const TILE := 32
const MOVE_DURATION := 0.12

@onready var _sprite: Sprite2D = $Sprite

var _kael_pos: Vector2i = Vector2i.ZERO


func _ready() -> void:
	visible = IskarCompanion.bonded
	EventBus.iskar_bonded.connect(_on_iskar_bonded)
	EventBus.player_moved.connect(_on_player_moved)
	# Wait one frame so WorldState is populated by Player._ready.
	await get_tree().process_frame
	_kael_pos = WorldState.player_start
	position = _pixel_for(_kael_pos)
	# Announce Iskar's presence on scene-load so DossierMutator can update
	# any village NPCs who can see him.
	if IskarCompanion.bonded and not WorldState.current_scene_id.is_empty():
		EventBus.iskar_entered_location.emit(WorldState.current_scene_id)


func _on_iskar_bonded() -> void:
	visible = true
	# When bonded inside the bandit camp, the follower is already next to
	# Kael; place him at Kael's current tile so the visual reads "the drake
	# steps out of the cage and to your heel."
	var player := get_tree().current_scene.get_node_or_null("Player")
	if player != null:
		_kael_pos = player.grid_pos
	position = _pixel_for(_kael_pos)
	# Bonding-on-the-spot also fires the "drake entered this scene" event.
	if not WorldState.current_scene_id.is_empty():
		EventBus.iskar_entered_location.emit(WorldState.current_scene_id)


func _on_player_moved(col: int, row: int) -> void:
	if not visible:
		return
	var new_kael := Vector2i(col, row)
	var prev_kael := _kael_pos
	_kael_pos = new_kael
	# Iskar moves to where Kael just was -- one-tile lag.
	var tween := create_tween()
	tween.tween_property(self, "position", _pixel_for(prev_kael), MOVE_DURATION)


func _pixel_for(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE + 4, p.y * TILE)
