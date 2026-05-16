extends Node
##
## Phase 7 playthrough tour: clear the camp, bond Iskar, fight with him.
## Screenshots dumped to /tmp/aurelix_phase7/.
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"
const OUT_DIR     := "/tmp/aurelix_phase7/"

var _shot_idx := 0


func _ready() -> void:
	DirAccess.make_dir_absolute(OUT_DIR)
	# Fresh state
	IskarCompanion.bonded = false
	IskarCompanion.affinity_points = 0
	IskarCompanion.unlocked_tier = 0
	FactLedger.reset()

	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	await _settle(3)
	await _shot("forest_entry")

	# 1. Walk into bandit -> fight -> win
	await _walk_into_encounter("bandit_path_b", "bandit", "bandit_combat_mid")
	await _shot("bandit_won")

	# 2. Walk into wolf -> fight -> win
	await _walk_into_encounter("wolf_path_a", "wolf", "wolf_combat_mid")
	await _shot("wolf_won")

	# 3. Drust (boss)
	await _walk_into_encounter("drust_camp", "drust", "drust_combat_mid")
	await _shot("drust_won")

	# 4. Walk Kael adjacent to cage and interact.
	var player := get_child(0).get_node("Player")
	_jump_player(player, Vector2i(8, 3))   # one tile south of cage at (8,2)
	await _settle(3)
	await _shot("cage_adjacent_prompt")

	# Simulate pressing E on cage.
	EventBus.cage_interacted.emit("iskar_cage")
	await _settle(5)
	await _shot("bonding_caption")
	await get_tree().create_timer(2.6).timeout    # let the caption auto-clear

	# 5. Iskar should now be visible following Kael.
	_jump_player(player, Vector2i(6, 5))
	# Manually fire player_moved so the follower lags.
	EventBus.player_moved.emit(6, 5)
	await _settle(8)
	await _shot("iskar_following")

	# 6. Bonded combat showcase. Start a phantom combat to re-use the
	# defeated encounter as the visual.
	CombatController.start_encounter("phase7_tour_phantom_wolf", "wolf")
	await _settle(4)
	await _shot("bonded_combat_open")
	# Tap one Attack so narration + Iskar acting populates.
	CombatController._on_action_chosen("attack", {})
	await _settle(6)
	await _shot("bonded_combat_mid")
	# Finish the fight.
	var guard := 40
	while CombatController.is_active() and guard > 0:
		CombatController._on_action_chosen("attack", {})
		await _settle(2)
		guard -= 1
	await _shot("bonded_combat_done")

	# 7. Push affinity over tier 1 to demonstrate ember unlock.
	IskarCompanion.add_affinity(8)
	await _settle(3)
	CombatController.start_encounter("phase7_tour_phantom_bandit", "bandit")
	await _settle(4)
	await _shot("post_tier1_combat_open")
	# Try several Iskar turns to see Ember-Spark + Burn ticks.
	for i in 8:
		CombatController._on_action_chosen("attack", {})
		await _settle(3)
	await _shot("post_tier1_combat_burn")

	print("[Phase7Tour] done -> ", OUT_DIR)
	get_tree().quit(0)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _walk_into_encounter(encounter_id: String, combatant: String, mid_label: String) -> void:
	CombatController.start_encounter(encounter_id, combatant)
	await _settle(4)
	await _shot(mid_label)
	var guard := 60
	while CombatController.is_active() and guard > 0:
		CombatController._on_action_chosen("attack", {})
		await _settle(2)
		guard -= 1
	await _settle(2)


func _jump_player(player: Node, to: Vector2i) -> void:
	player.set("grid_pos", to)
	player.position = Vector2(to.x * 32 + 4, to.y * 32)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var name := "%02d_%s.png" % [_shot_idx, label]
	get_viewport().get_texture().get_image().save_png(OUT_DIR + name)
	print("[Phase7Tour] saved ", name)
	_shot_idx += 1


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
