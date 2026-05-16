extends Node
##
## Per-scene logical map: which tile is where, which NPC stands on which
## tile, which tiles are solid, where the exits go.
##
## Visuals live in the .tscn; this autoload owns gameplay-relevant state so
## the player controller and interaction prompt can query it without
## walking the scene tree.
##
## A new scene calls `load_scene("village_square")`; the file
## /data/scenes/village_square_grid.json is read, plus the static
## /data/tile_collision.json. Phase 7 (forest) will load a different grid.
##

const COLLISION_PATH := "res://data/tile_collision.json"
const GRID_DIR       := "res://data/scenes/"

var cols: int       = 0
var rows: int       = 0
var tile_size: int  = 32

var current_scene_id: String = ""

var tile_grid:          Dictionary = {}   # Vector2i -> tile name
var prop_grid:          Dictionary = {}   # Vector2i -> prop name
var npc_positions:      Dictionary = {}   # Vector2i -> npc_id
var npc_locations:      Dictionary = {}   # npc_id   -> Vector2i
var object_positions:   Dictionary = {}   # Vector2i -> {id, type, label, ...}
var exit_positions:     Dictionary = {}   # Vector2i -> {direction, target}
var encounter_positions: Dictionary = {}  # Vector2i -> {id, sprite}
var encounters_by_id:   Dictionary = {}   # encounter_id -> Vector2i
var entry_points:       Dictionary = {}   # name -> Vector2i

var player_start: Vector2i = Vector2i(0, 0)

var _solid_tile_names: Dictionary = {}   # name -> true
var _solid_prop_names: Dictionary = {}


func _ready() -> void:
	_load_collision()


# --------------------------------------------------------------------------
# Loading
# --------------------------------------------------------------------------

func _load_collision() -> void:
	var data = _read_json(COLLISION_PATH)
	if not (data is Dictionary):
		push_error("[WorldState] could not load tile_collision.json")
		return
	for name in data.get("solid_tiles", []):
		_solid_tile_names[name] = true
	for name in data.get("solid_props", []):
		_solid_prop_names[name] = true


func load_scene(scene_id: String) -> void:
	current_scene_id = scene_id
	tile_grid.clear()
	prop_grid.clear()
	npc_positions.clear()
	npc_locations.clear()
	object_positions.clear()
	exit_positions.clear()
	encounter_positions.clear()
	encounters_by_id.clear()
	entry_points.clear()

	var path := "%s%s_grid.json" % [GRID_DIR, scene_id]
	var data = _read_json(path)
	if not (data is Dictionary):
		push_error("[WorldState] could not load %s" % path)
		return

	var size: Dictionary = data.get("size", {})
	cols      = int(size.get("cols", 0))
	rows      = int(size.get("rows", 0))
	tile_size = int(data.get("tile_size", 32))

	var start: Dictionary = data.get("player_start", {})
	player_start = Vector2i(int(start.get("col", 0)), int(start.get("row", 0)))

	for t in data.get("tiles", []):
		tile_grid[Vector2i(int(t["col"]), int(t["row"]))] = t["tile"]
	for p in data.get("props", []):
		prop_grid[Vector2i(int(p["col"]), int(p["row"]))] = p["prop"]
	for n in data.get("npcs", []):
		var pos := Vector2i(int(n["col"]), int(n["row"]))
		npc_positions[pos] = n["id"]
		npc_locations[n["id"]] = pos
	for o in data.get("objects", []):
		var pos := Vector2i(int(o["col"]), int(o["row"]))
		object_positions[pos] = {
			"id":    o["id"],
			"type":  o.get("type", ""),
			"label": o.get("label", o["id"]),
		}
	for e in data.get("exits", []):
		var pos := Vector2i(int(e["col"]), int(e["row"]))
		exit_positions[pos] = {
			"direction": e.get("direction", ""),
			"target":    e.get("target", ""),
		}
	for enc in data.get("encounters", []):
		var pos := Vector2i(int(enc["col"]), int(enc["row"]))
		encounter_positions[pos] = {
			"id":        enc.get("id", ""),
			"sprite":    enc.get("sprite", ""),
			"combatant": enc.get("combatant", enc.get("sprite", "")),
		}
		encounters_by_id[enc.get("id", "")] = pos
	for name in data.get("entry_points", {}).keys():
		var p: Dictionary = data["entry_points"][name]
		entry_points[name] = Vector2i(int(p.get("col", 0)), int(p.get("row", 0)))

	print("[WorldState] loaded scene '%s' (%dx%d, tiles=%d props=%d npcs=%d objs=%d exits=%d encounters=%d)" % [
		scene_id, cols, rows,
		tile_grid.size(), prop_grid.size(),
		npc_locations.size(), object_positions.size(),
		exit_positions.size(), encounter_positions.size(),
	])


# --------------------------------------------------------------------------
# Queries
# --------------------------------------------------------------------------

func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < cols and pos.y >= 0 and pos.y < rows


func is_solid(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return true
	var tile_name: String = tile_grid.get(pos, "")
	if _solid_tile_names.has(tile_name):
		return true
	var prop_name: String = prop_grid.get(pos, "")
	if not prop_name.is_empty() and _solid_prop_names.has(prop_name):
		return true
	# NPCs and encounters block movement (encounters become combat on touch).
	if npc_positions.has(pos):
		return true
	if encounter_positions.has(pos):
		return true
	return false


func encounter_at(pos: Vector2i) -> Dictionary:
	return encounter_positions.get(pos, {})


func remove_encounter(encounter_id: String) -> void:
	var pos: Vector2i = encounters_by_id.get(encounter_id, Vector2i(-1, -1))
	if pos.x < 0:
		return
	encounter_positions.erase(pos)
	encounters_by_id.erase(encounter_id)


func entry_point(name: String) -> Vector2i:
	if entry_points.has(name):
		return entry_points[name]
	return player_start


func npc_at(pos: Vector2i) -> String:
	return npc_positions.get(pos, "")


func object_at(pos: Vector2i) -> Dictionary:
	return object_positions.get(pos, {})


func exit_at(pos: Vector2i) -> Dictionary:
	return exit_positions.get(pos, {})


## Find a single interactable in the 8-neighbourhood of `pos` (and on `pos`).
## Returns the first hit: NPC > object > {}. Empty dict if none.
func interactable_near(pos: Vector2i) -> Dictionary:
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
	]
	for off in offsets:
		var p: Vector2i = pos + off
		if npc_positions.has(p):
			var id: String = npc_positions[p]
			var profile: Dictionary = NpcProfileRegistry.get_profile(id)
			var label: String = profile.get("display_name", id)
			return {"target_id": id, "target_type": "npc", "label": "Talk to %s" % label, "pos": p}
		if object_positions.has(p):
			var obj: Dictionary = object_positions[p]
			var verb: String = "Read"
			match obj.get("type", "object"):
				"cage":         verb = "Open"
				"notice_board": verb = "Read"
				_:              verb = "Use"
			return {
				"target_id":   obj.get("id", ""),
				"target_type": obj.get("type", "object"),
				"label":       "%s %s" % [verb, obj.get("label", obj.get("id", ""))],
				"pos":         p,
			}
	return {}


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
