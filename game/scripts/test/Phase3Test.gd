extends Node
##
## Headless smoke test for Phase 3: tile-grid movement, collision, NPC
## adjacency detection, interaction prompt, dialogue trigger, notice board.
##
## Loads VillageSquare, programmatically jumps the player around the grid,
## and asserts the expected EventBus signals fire.
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"

var _failures: Array[String] = []

var _dialogue_requested_npc: String = ""
var _interaction_label: String = ""
var _last_fact_granted: String = ""
var _exit_event: Dictionary = {}


func _ready() -> void:
	# Wire EventBus listeners before loading the scene.
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.interaction_available.connect(_on_interaction_available)
	EventBus.interaction_unavailable.connect(_on_interaction_unavailable)
	EventBus.fact_granted.connect(_on_fact_granted)
	EventBus.exit_attempted.connect(_on_exit_attempted)

	# Load the village.
	var ps := load(VILLAGE_PATH) as PackedScene
	if ps == null:
		_fatal("failed to load village_square.tscn")
		return
	var village := ps.instantiate()
	add_child(village)

	# Wait for WorldState + Player to finish their async _ready.
	await get_tree().process_frame
	await get_tree().process_frame

	var player: Node2D = village.get_node("Player")
	_assert(player != null, "no Player node in village")
	if player == null:
		_finish()
		return

	# ----- collision -----------------------------------------------------------
	_assert(WorldState.is_solid(Vector2i(7, 5)),
		"well_water should be solid (7,5)")
	_assert(WorldState.is_solid(Vector2i(7, 4)),
		"well_stone should be solid (7,4)")
	_assert(not WorldState.is_solid(Vector2i(7, 6)),
		"player start (7,6) should be passable")
	_assert(WorldState.is_solid(Vector2i(1, 0)),
		"tavern roof (1,0) should be solid")
	_assert(WorldState.is_solid(Vector2i(0, 1)),
		"prop tree at (0,1) should be solid")

	# ----- NPC positions -------------------------------------------------------
	_assert(WorldState.npc_at(Vector2i(9, 3)) == "mara_blacksmith",
		"Mara should be at (9,3)")
	_assert(WorldState.npc_at(Vector2i(6, 4)) == "toma_child",
		"Toma should be at (6,4)")

	# ----- jump near Mara, expect interaction_available -----------------------
	_interaction_label = ""
	_jump(player, Vector2i(9, 4))            # one tile south of Mara
	await get_tree().process_frame
	# adjacency check happens on jump via player._emit_interaction_state().
	# Because _jump uses internal API, call the public emit path:
	player.call("_emit_interaction_state")
	await get_tree().process_frame
	_assert(_interaction_label.find("Mara") != -1,
		"expected interaction label to mention Mara, got '%s'" % _interaction_label)

	# Trigger interaction -> dialogue_requested(mara_blacksmith)
	_dialogue_requested_npc = ""
	player.call("_try_interact")
	await get_tree().process_frame
	_assert(_dialogue_requested_npc == "mara_blacksmith",
		"expected dialogue_requested(mara_blacksmith), got '%s'" % _dialogue_requested_npc)

	# ----- jump near notice board, expect notice_board_read fact --------------
	_last_fact_granted = ""
	_jump(player, Vector2i(4, 7))            # one tile south of notice board (4,6)
	player.call("_emit_interaction_state")
	await get_tree().process_frame
	player.call("_try_interact")
	await get_tree().process_frame
	_assert(_last_fact_granted == "notice_board_read",
		"expected fact_granted(notice_board_read), got '%s'" % _last_fact_granted)

	# ----- south exit data is in place ----------------------------------------
	# (Phase 7 wires the actual transition; here we just verify the village's
	# south exit tile knows where it leads. Triggering _try_move would call
	# SceneRouter and tear down this test scene.)
	var exit_data := WorldState.exit_at(Vector2i(7, 8))
	_assert(exit_data.get("direction") == "south" and exit_data.get("target") == "forest_edge",
		"expected south exit -> forest_edge, got %s" % exit_data)

	_finish()


# ---------------------------------------------------------------------------
# Listeners
# ---------------------------------------------------------------------------

func _on_dialogue_requested(npc_id: String) -> void:
	_dialogue_requested_npc = npc_id

func _on_interaction_available(_target_id: String, _target_type: String, label: String) -> void:
	_interaction_label = label

func _on_interaction_unavailable() -> void:
	_interaction_label = ""

func _on_fact_granted(fact_id: String, _source: Dictionary) -> void:
	_last_fact_granted = fact_id

func _on_exit_attempted(direction: String, target: String) -> void:
	_exit_event = {"direction": direction, "target": target}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _jump(player: Node2D, to: Vector2i) -> void:
	# Skip the tween: place the player directly on the target tile.
	player.set("grid_pos", to)
	player.position = Vector2(to.x * 32 + 4, to.y * 32)


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _fatal(msg: String) -> void:
	_failures.append("FATAL: " + msg)
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Phase3Test] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase3Test] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
