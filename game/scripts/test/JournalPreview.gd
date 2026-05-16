extends Node
##
## Snapshot of the journal: starting entries seeded, a few facts granted,
## query answered.
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"


func _ready() -> void:
	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	for i in 3:
		await get_tree().process_frame
	# Simulate progress: pretend the player has done a few things.
	FactLedger.grant_fact("notice_board_read",       {"kind": "test"})
	FactLedger.grant_fact("bandit_note_recovered",   {"kind": "test"})
	FactLedger.grant_fact("dragon_seen_near_old_tower", {"kind": "test"})
	FactLedger.grant_fact("drust_dead",              {"kind": "test"})
	FactLedger.grant_fact("iskar_bonded",            {"kind": "test"})
	for i in 2:
		await get_tree().process_frame
	JournalController.open()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/aurelix_journal_open.png")
	print("saved /tmp/aurelix_journal_open.png")

	# Pick the gold-eyed one option.
	var panel: Node = JournalController._panel
	panel.option_chosen.emit({"label": "Who is 'the gold-eyed one'?", "topic_id": "gold_eyed_one"})
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/aurelix_journal_answered.png")
	print("saved /tmp/aurelix_journal_answered.png")
	get_tree().quit(0)
