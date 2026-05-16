extends Node2D
##
## Tile-grid player. 8-direction movement. Holds (col,row); pixel position
## is tweened smoothly between tiles for feel. Solid checks delegate to
## WorldState. Interaction prompt fires on E when an interactable is in
## any of the 8 surrounding tiles.
##

const TILE_SIZE        := 32
const MOVE_DURATION    := 0.12   # seconds per step
const PIXEL_OFFSET_X   := 4      # match the visual offset used for static sprites

@export var sprite_offset_y: int = 0   # set by the scene if Kael needs to sit a bit lower

var grid_pos: Vector2i = Vector2i.ZERO
var _moving: bool = false
var _last_interactable_id: String = ""


const SCENE_ID_BY_ROOT_NAME := {
	"VillageSquare": "village_square",
	"ForestEdge":    "forest_edge",
}


func _ready() -> void:
	add_to_group("player_grid")
	await get_tree().process_frame
	# The Player node sits directly under the scene root (VillageSquare /
	# ForestEdge). Read its parent's name to derive the scene id; this
	# works both in normal play and when the scene is instanced as a
	# child during headless tests.
	var parent := get_parent()
	var scene_id: String = "village_square"
	if parent != null:
		scene_id = SCENE_ID_BY_ROOT_NAME.get(parent.name, "village_square")
	WorldState.load_scene(scene_id)
	grid_pos = SceneRouter.spawn_for(scene_id)
	position = _pixel_for(grid_pos)
	_emit_interaction_state()


func _unhandled_input(event: InputEvent) -> void:
	if _moving:
		return
	# Dialogue swallows player input.
	if DialogueController.is_open():
		return
	# Combat takes over fully when active.
	if CombatController.is_active():
		return
	if event.is_action_pressed("interact"):
		_try_interact()
		return
	# Movement: any combination of 4 cardinal inputs becomes 8-direction.
	if event is InputEventKey and not event.is_echo() and event.pressed:
		var dir := _intended_direction()
		if dir != Vector2i.ZERO:
			_try_move(dir)


func _intended_direction() -> Vector2i:
	var dx := 0
	var dy := 0
	if Input.is_action_pressed("ui_right"): dx += 1
	if Input.is_action_pressed("ui_left"):  dx -= 1
	if Input.is_action_pressed("ui_down"):  dy += 1
	if Input.is_action_pressed("ui_up"):    dy -= 1
	return Vector2i(dx, dy)


# --------------------------------------------------------------------------
# Movement
# --------------------------------------------------------------------------

func _try_move(dir: Vector2i) -> void:
	var target := grid_pos + dir
	# Check if the player is stepping into an exit tile (or off-edge from
	# one) -- WorldState knows the authored exit table per scene.
	var exit_here := WorldState.exit_at(grid_pos)
	var stepping_off := not WorldState.is_in_bounds(target)
	if not exit_here.is_empty() and stepping_off:
		var dirstr: String = exit_here.get("direction", "")
		var target_id: String = exit_here.get("target", "")
		# Only fire if movement direction roughly matches the exit's direction.
		var matches := (
			(dirstr == "south" and dir.y > 0) or
			(dirstr == "north" and dir.y < 0) or
			(dirstr == "east"  and dir.x > 0) or
			(dirstr == "west"  and dir.x < 0)
		)
		if matches:
			EventBus.exit_attempted.emit(dirstr, target_id)
			print("[Player] exit %s -> %s" % [dirstr, target_id])
			return
	if stepping_off:
		return
	# Stepping onto an encounter tile: start combat instead of moving.
	var enc := WorldState.encounter_at(target)
	if not enc.is_empty():
		CombatController.start_encounter(enc.get("id", ""), enc.get("combatant", ""))
		return
	if WorldState.is_solid(target):
		return
	_animate_to(target)


func _animate_to(target: Vector2i) -> void:
	_moving = true
	grid_pos = target
	var tween := create_tween()
	tween.tween_property(self, "position", _pixel_for(target), MOVE_DURATION)
	await tween.finished
	_moving = false
	EventBus.player_moved.emit(grid_pos.x, grid_pos.y)
	_emit_interaction_state()


func _pixel_for(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE_SIZE + PIXEL_OFFSET_X, p.y * TILE_SIZE + sprite_offset_y)


# --------------------------------------------------------------------------
# Interaction
# --------------------------------------------------------------------------

func _emit_interaction_state() -> void:
	var hit := WorldState.interactable_near(grid_pos)
	var new_id: String = hit.get("target_id", "")
	if new_id == _last_interactable_id:
		return
	_last_interactable_id = new_id
	if hit.is_empty():
		EventBus.interaction_unavailable.emit()
	else:
		EventBus.interaction_available.emit(
			hit["target_id"], hit["target_type"], hit["label"]
		)


func _try_interact() -> void:
	var hit := WorldState.interactable_near(grid_pos)
	if hit.is_empty():
		return
	match hit["target_type"]:
		"npc":
			EventBus.dialogue_requested.emit(hit["target_id"])
			print("[Player] dialogue_requested(%s)" % hit["target_id"])
		"notice_board":
			# Notice board has its own handler that listens for this id.
			EventBus.fact_granted.emit("notice_board_read", {
				"source": "world_event",
				"object_id": hit["target_id"],
			})
			print("[Player] notice_board read at tile %s" % hit["pos"])
		"cage":
			# Cage interaction lives on its own controller; emit a signal
			# and let CageHandler decide whether bonding is allowed.
			print("[Player] cage interaction at %s" % hit["pos"])
			EventBus.cage_interacted.emit(hit["target_id"])
		_:
			print("[Player] interacted with %s (%s)" % [hit["target_id"], hit["target_type"]])
