extends Node
##
## Manages map-to-map transitions. PlayerController emits
## EventBus.exit_attempted(direction, target) when the player walks off a
## scene edge that has an `exits` entry; SceneRouter loads the target scene
## and tells the player where to spawn.
##
## Autoload as `SceneRouter`.
##

const SCENES := {
	"village_square": "res://scenes/village_square.tscn",
	"forest_edge":    "res://scenes/forest_edge.tscn",
}

# Reverse map: when arriving at a scene, which entry point to use based on
# the previous scene id. Falls back to "default" if unset.
const ENTRY_FROM := {
	"forest_edge":    {"village_square": "from_village"},
	"village_square": {"forest_edge":    "from_forest"},
}

var previous_scene_id: String = ""
# Set by SaveManager to force a specific spawn tile in the next scene load.
# Cleared by spawn_for() once consumed.
var pending_spawn_override: Vector2i = Vector2i(-999, -999)
var pending_spawn_facing: String = "south"


func _ready() -> void:
	EventBus.exit_attempted.connect(_on_exit_attempted)


func _on_exit_attempted(direction: String, target: String) -> void:
	if not SCENES.has(target):
		print("[SceneRouter] no scene for target '%s' (direction=%s)" % [target, direction])
		return
	change_scene_to(target)


## Change scenes. Honours the previous_scene_id to pick the right entry point.
func change_scene_to(target: String) -> void:
	var path: String = SCENES.get(target, "")
	if path.is_empty():
		push_error("[SceneRouter] unknown scene '%s'" % target)
		return
	previous_scene_id = WorldState.current_scene_id
	print("[SceneRouter] %s -> %s" % [previous_scene_id, target])
	# Defer the actual change so we don't tear the scene tree mid-input.
	_change_deferred.call_deferred(path)


func _change_deferred(path: String) -> void:
	get_tree().change_scene_to_file(path)


## Called by PlayerController on its _ready to ask "where should I spawn?"
## Returns {pos: Vector2i, facing: String}. SaveManager overrides win;
## otherwise the entry-point's authored facing applies, defaulting to "south".
func spawn_for(current_scene_id: String) -> Dictionary:
	if pending_spawn_override != Vector2i(-999, -999):
		var p := pending_spawn_override
		pending_spawn_override = Vector2i(-999, -999)
		var facing: String = pending_spawn_facing
		pending_spawn_facing = "south"
		return {"pos": p, "facing": facing}
	var entry_table: Dictionary = ENTRY_FROM.get(current_scene_id, {})
	var entry_name: String = entry_table.get(previous_scene_id, "default")
	if WorldState.entry_points.has(entry_name):
		return {
			"pos":    WorldState.entry_point(entry_name),
			"facing": WorldState.entry_point_facing(entry_name),
		}
	return {"pos": WorldState.player_start, "facing": "south"}


## Used by SaveManager to load a saved scene + place the player at a saved
## tile + facing. The new scene's PlayerController will call spawn_for(),
## which returns the override.
func go(target: String, pos: Vector2i, facing: String = "south") -> void:
	pending_spawn_override = pos
	pending_spawn_facing = facing
	change_scene_to(target)
