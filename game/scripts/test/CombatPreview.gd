extends Node
##
## Open forest, kick off a wolf combat, take one attack, snapshot.
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"
const OUT_PRE     := "/tmp/aurelix_combat_open.png"
const OUT_MID     := "/tmp/aurelix_combat_mid.png"


func _ready() -> void:
	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	await _settle(3)

	CombatController.start_encounter("wolf_path_a", "wolf")
	await _settle(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_PRE)
	print("[CombatPreview] saved ", OUT_PRE)

	# Take an attack so the narration line + bars update.
	CombatController._on_action_chosen("attack", {})
	await _settle(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT_MID)
	print("[CombatPreview] saved ", OUT_MID)

	get_tree().quit(0)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame
