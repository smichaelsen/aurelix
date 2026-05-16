extends Node
##
## Phase 7 Increment 1: forest scene + transitions.
##
## Tests the logic by instancing each scene as a child of the test node
## (rather than calling change_scene_to_file, which destroys the test
## itself). For end-to-end transition feel, use the screenshot tour.
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"
const FOREST_PATH  := "res://scenes/forest_edge.tscn"

var _failures: Array[String] = []


func _ready() -> void:
	var forest_packed: PackedScene = load(FOREST_PATH) as PackedScene
	_assert(forest_packed != null, "could not load forest_edge.tscn")
	var forest: Node = forest_packed.instantiate()
	add_child(forest)
	await _settle(3)

	_assert(WorldState.current_scene_id == "forest_edge",
		"expected current_scene_id=forest_edge, got %s" % WorldState.current_scene_id)
	_assert(WorldState.encounter_positions.size() >= 3,
		"forest should have 3 encounters; got %d" % WorldState.encounter_positions.size())
	for eid in ["drust_camp", "wolf_path_a", "bandit_path_b"]:
		_assert(WorldState.encounters_by_id.has(eid),
			"forest should have encounter '%s'" % eid)

	var cage_pos := Vector2i(8, 2)
	_assert(not WorldState.object_at(cage_pos).is_empty(),
		"expected cage object at (8,2)")

	var wolf_pos: Vector2i = WorldState.encounters_by_id["wolf_path_a"]
	_assert(WorldState.is_solid(wolf_pos),
		"wolf encounter tile should be solid")

	var entry := WorldState.entry_point("from_village")
	_assert(entry == Vector2i(6, 8),
		"expected from_village entry at (6,8), got %s" % entry)
	var fex := WorldState.exit_at(Vector2i(6, 8))
	_assert(fex.get("target", "") == "village_square",
		"expected forest south exit -> village_square, got %s" % fex)

	var player := forest.get_node("Player")
	_assert(player.grid_pos == entry,
		"expected player at %s, got %s" % [entry, player.grid_pos])

	forest.queue_free()
	await _settle(2)

	var village_packed: PackedScene = load(VILLAGE_PATH) as PackedScene
	var village: Node = village_packed.instantiate()
	add_child(village)
	await _settle(3)

	_assert(WorldState.current_scene_id == "village_square",
		"expected current_scene_id=village_square, got %s" % WorldState.current_scene_id)
	var vex := WorldState.exit_at(Vector2i(7, 8))
	_assert(vex.get("target", "") == "forest_edge",
		"expected village south exit -> forest_edge, got %s" % vex)

	_assert(SceneRouter.SCENES.has("village_square"),
		"SceneRouter should know village_square")
	_assert(SceneRouter.SCENES.has("forest_edge"),
		"SceneRouter should know forest_edge")

	_finish()


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Phase7Test] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase7Test] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
