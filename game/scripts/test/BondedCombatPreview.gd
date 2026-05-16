extends Node
##
## Snapshot of combat with Iskar bonded: Iskar HP bar + stance picker visible.
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"


func _ready() -> void:
	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	for i in 3:
		await get_tree().process_frame
	# Force bond.
	IskarCompanion.bonded = true
	IskarCompanion.affinity_points = 12
	IskarCompanion.unlocked_tier = 1
	FactLedger.grant_fact("drust_dead", {"kind": "test"})
	# Start a bandit fight to showcase the 3-battler layout.
	CombatController.start_encounter("bandit_path_b", "bandit")
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/aurelix_bonded_combat.png")
	print("saved /tmp/aurelix_bonded_combat.png")

	# Iskar takes his turn next (he has SPD 9 > Kael 8).
	# Mash player Attack so Iskar acts in between.
	CombatController._on_action_chosen("attack", {})
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/aurelix_bonded_mid.png")
	print("saved /tmp/aurelix_bonded_mid.png")
	get_tree().quit(0)
