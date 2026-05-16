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
var _own_tile: Vector2i = Vector2i.ZERO
var _facing: String = "south"


func _ready() -> void:
	visible = IskarCompanion.bonded
	EventBus.iskar_bonded.connect(_on_iskar_bonded)
	EventBus.player_moved.connect(_on_player_moved)
	# Wait one frame so WorldState is populated by Player._ready.
	await get_tree().process_frame
	_kael_pos = WorldState.player_start
	_own_tile = _kael_pos
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
	_own_tile = _kael_pos
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
	# Iskar's destination this step is Kael's previous tile (one-tile lag).
	# Facing is the cardinal of (destination - own_current_tile).
	var dest := prev_kael
	var delta := dest - _own_tile
	var dir := _cardinal_of(delta)
	if dir != "" and dir != _facing:
		_facing = dir
		EventBus.iskar_facing_changed.emit(_facing)
	_own_tile = dest
	var tween := create_tween()
	tween.tween_property(self, "position", _pixel_for(dest), MOVE_DURATION)


# Collapse a 2D delta to a single cardinal. Dominant axis wins; ties
# favour horizontal (matches the dialogue rule and feels right for follow).
func _cardinal_of(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return ""
	if abs(delta.x) >= abs(delta.y):
		return "east" if delta.x > 0 else "west"
	return "south" if delta.y > 0 else "north"


func _pixel_for(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE + 4, p.y * TILE)
