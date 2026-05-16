extends Node
##
## End-to-end playthrough tour. Walks every major demo beat with
## journal-state checks and a screenshot at each beat, so we can review
## the experience visually + spot rough edges.
##
## Output: /tmp/aurelix_playthrough/
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"
const OUT_DIR      := "/tmp/aurelix_playthrough/"

var _shot_idx := 0
var _findings: Array[String] = []
var _village_root: Node = null


func _ready() -> void:
	DirAccess.make_dir_absolute(OUT_DIR)

	# Fresh state.
	Journal.reset()
	NpcDossierStore.reset()
	FactLedger.reset()
	IskarCompanion.bonded = false
	IskarCompanion.affinity_points = 0
	IskarCompanion.unlocked_tier = 0

	_village_root = (load(VILLAGE_PATH) as PackedScene).instantiate()
	add_child(_village_root)
	await _settle(4)

	# Re-seed since Journal.reset() wiped the startup briefings.
	Journal._seed_starting_entries()
	await _settle(2)

	await _beat_01_starting_state()
	await _beat_02_open_journal()
	await _beat_03_notice_board()
	await _beat_04_talk_to_halden()
	await _beat_05_talk_to_mara_first_pass()
	await _beat_06_press_orren_for_tower_with_ale()
	await _beat_07_show_coin_to_mara()
	await _beat_08_show_note_to_edda()
	await _beat_09_drust_dies_journal_grows()
	await _beat_10_iskar_bonds_journal_grows()
	await _beat_11_iskar_walks_into_village()
	await _beat_12_journal_final_view()

	_finish()


# ---------------------------------------------------------------------------
# Beats
# ---------------------------------------------------------------------------

func _beat_01_starting_state() -> void:
	_expect(Journal.has_id("kael_self"),       "starting: kael_self present")
	_expect(Journal.has_id("kingdom_overview"),"starting: kingdom_overview present")
	_expect(Journal.has_id("marlow_hollow"),   "starting: marlow_hollow present")
	_expect(Journal.count() == 3,
		"starting: journal has exactly 3 entries (got %d)" % Journal.count())
	await _shot("01_village_boot")


func _beat_02_open_journal() -> void:
	JournalController.open()
	await _settle(4)
	_expect(JournalController.is_open(), "journal opens")
	await _shot("02_journal_initial")
	JournalController.close()
	await _settle(2)


func _beat_03_notice_board() -> void:
	# Notice board fact is fired by PlayerController.interact -> we just emit
	# directly here. NoticeBoardHandler should show the placard.
	EventBus.fact_granted.emit("notice_board_read", {
		"source": "world_event", "object_id": "notice_board",
	})
	await _settle(3)
	await _shot("03_notice_board_overlay")
	# Notice fact doesn't add journal entry on its own (marlow_hollow is
	# already in the starting kit). Verify count is still 3.
	_expect(Journal.count() == 3,
		"notice_board: still 3 journal entries after reading (got %d)"
			% Journal.count())
	# Wait the overlay out.
	await get_tree().create_timer(4.2).timeout


func _beat_04_talk_to_halden() -> void:
	# Halden is templated. Pick "I'll find your dragon." to accept the quest.
	EventBus.dialogue_requested.emit("halden_reeve")
	await _settle(6)
	await _shot("04_halden_first")
	_expect(DialogueController.is_open(), "halden dialogue opened")
	_pick_label_containing("find your dragon")
	await _settle(4)
	await _shot("04b_halden_quest_accepted")
	_close_dialogue()
	await _settle(2)
	_expect(QuestState.get_state("dragon_sighting") == "active",
		"halden talk: dragon_sighting active (got %s)"
			% QuestState.get_state("dragon_sighting"))


func _beat_05_talk_to_mara_first_pass() -> void:
	EventBus.dialogue_requested.emit("mara_blacksmith")
	await _settle(8)
	await _shot("05_mara_first_talk")
	_expect(DialogueController.is_open(), "mara dialogue opened")
	# Mara should NOT yet know gold_eyed_one rumor; static dossier doesn't
	# carry it.
	_expect(not NpcDossierStore.has("mara_blacksmith", "gold_eyed_one"),
		"mara: gold_eyed_one NOT in dossier yet")
	_close_dialogue()
	await _settle(2)


func _beat_06_press_orren_for_tower_with_ale() -> void:
	EventBus.dialogue_requested.emit("orren_drunk")
	await _settle(6)
	await _shot("06a_orren_open")

	# Press tower first (should be blocked, surfacing Press lever).
	_pick_label_containing("tower")
	await _settle_until_idle(40)
	await _shot("06b_orren_blocked_tower")

	# Offer ale - this satisfies the patience modifier.
	Inventory.add("ale", 1)
	_box_offer_item("ale")
	await _settle_until_idle(40)
	await _shot("06c_orren_after_ale")

	# Press tower from a specific angle now (reveal_ready).
	# Orren's accepted angles: angle_saw_something / angle_wings /
	# angle_safe_to_share. Pick the "saw something" press option.
	_pick_label_containing("saw something")
	if not _last_pick_succeeded:
		_pick_label_containing("wings")
	await _settle_until_idle(40)
	await _shot("06d_orren_reveal")

	_expect(Journal.has_id("tower_smoke"),
		"orren reveal: tower_smoke landed in journal")
	_close_dialogue()
	await _settle(2)


func _beat_07_show_coin_to_mara() -> void:
	Inventory.add("strange_coin", 1)
	EventBus.dialogue_requested.emit("mara_blacksmith")
	await _settle(6)
	_box_offer_item("strange_coin")
	await _settle_until_idle(50)
	await _shot("07_mara_after_coin")
	_expect(NpcDossierStore.has("mara_blacksmith", "gold_eyed_one"),
		"mara: gold_eyed_one in dossier after coin shown")
	_close_dialogue()
	await _settle(2)


func _beat_08_show_note_to_edda() -> void:
	Inventory.add("bandit_note", 1)
	# Also fire bandit_note_recovered so Journal has both the item briefing
	# and the gold-eyed rumor (per Phase 8 mapping).
	FactLedger.grant_fact("bandit_note_recovered", {"kind": "world_event"})
	await _settle(2)
	EventBus.dialogue_requested.emit("edda_priest")
	await _settle(6)
	_box_offer_item("bandit_note")
	await _settle_until_idle(50)
	await _shot("08_edda_after_note")
	_expect(NpcDossierStore.has("edda_priest", "gold_eyed_one"),
		"edda: gold_eyed_one in dossier after note shown")
	# Edda's kael_has_drake (added later) should be forbidden, but the coin
	# rumor itself isn't forbidden. Just check presence.
	_close_dialogue()
	await _settle(2)


func _beat_09_drust_dies_journal_grows() -> void:
	# Short-circuit combat - emit the same fact CombatController would.
	FactLedger.grant_fact("drust_dead", {"kind": "test_shortcut"})
	await _settle(3)
	_expect(Journal.has_id("bandits_defeated"),
		"drust dies: bandits_defeated in journal")
	_expect(Journal.has_id("bandit_camp"),
		"drust dies: bandit_camp in journal")
	_expect(Journal.has_id("drust_bandit"),
		"drust dies: drust_bandit in journal")
	_expect(NpcDossierStore.has("mara_blacksmith", "bandits_defeated"),
		"drust dies: mara hears bandits_defeated rumor")
	_expect(NpcDossierStore.has("halden_reeve", "bandits_defeated"),
		"drust dies: halden hears bandits_defeated rumor")


func _beat_10_iskar_bonds_journal_grows() -> void:
	IskarCompanion.bond()
	FactLedger.grant_fact("iskar_bonded", {"kind": "test_shortcut"})
	await _settle(3)
	_expect(Journal.has_id("iskar_drake"),
		"iskar bonds: iskar_drake in journal")
	_expect(Journal.has_id("iskar_rescued"),
		"iskar bonds: iskar_rescued in journal")


func _beat_11_iskar_walks_into_village() -> void:
	EventBus.iskar_entered_location.emit("village_square")
	await _settle(3)
	for npc_id in ["mara_blacksmith", "orren_drunk", "edda_priest",
				   "halden_reeve", "toma_child"]:
		_expect(NpcDossierStore.has(npc_id, "kael_has_drake"),
			"iskar in village: %s sees kael_has_drake" % npc_id)
	# Edda's flag should be forbidden_to_share.
	var edda_entry := _entry_for("edda_priest", "kael_has_drake")
	_expect(edda_entry.get("forbidden_to_share", false) == true,
		"iskar in village: Edda's kael_has_drake is forbidden_to_share")


func _beat_12_journal_final_view() -> void:
	JournalController.open()
	await _settle(4)
	await _shot("12_journal_final")
	# Render a Kael answer about Iskar to verify the journal Q+A still works
	# with the grown dossier.
	JournalController._panel.option_chosen.emit({
		"label": "What about Iskar?", "topic_id": "the_drake",
	})
	await _settle_until_idle(40)
	await _shot("12b_journal_iskar_answer")
	JournalController.close()
	await _settle(2)


# ---------------------------------------------------------------------------
# DialogueBox helpers
# ---------------------------------------------------------------------------

var _last_pick_succeeded := false


func _pick_label_containing(needle: String) -> void:
	_last_pick_succeeded = false
	var box: Node = DialogueController._box
	if box == null:
		_findings.append("pick(%s): dialog box not open" % needle)
		return
	var options := box.get_node("Panel/Options")
	for child in options.get_children():
		if not (child is Button):
			continue
		var lbl: String = child.text.to_lower()
		if needle.to_lower() in lbl:
			child.emit_signal("pressed")
			_last_pick_succeeded = true
			return
	_findings.append("pick(%s): no matching option" % needle)


func _box_offer_item(item_id: String) -> void:
	var box: Node = DialogueController._box
	if box == null:
		_findings.append("offer(%s): dialog box not open" % item_id)
		return
	box.emit_signal("item_offered", item_id)


func _close_dialogue() -> void:
	var box: Node = DialogueController._box
	if box != null:
		box.emit_signal("closed")


# ---------------------------------------------------------------------------
# Misc helpers
# ---------------------------------------------------------------------------

func _settle_until_idle(max_frames: int) -> void:
	# Settle until DialogueController is no longer busy (or timeout).
	var n := 0
	while n < max_frames:
		await get_tree().process_frame
		n += 1
		var busy = DialogueController.get("_busy")
		if busy == null:
			continue
		if not bool(busy):
			break


func _entry_for(npc_id: String, briefing_id: String) -> Dictionary:
	for e in NpcDossierStore.dossier_for(npc_id):
		if e.get("id", "") == briefing_id:
			return e
	return {}


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var fname := "%02d_%s.png" % [_shot_idx, label]
	get_viewport().get_texture().get_image().save_png(OUT_DIR + fname)
	print("[Playthrough] shot ", fname)
	_shot_idx += 1


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_findings.append(msg)
		printerr("[Playthrough] FAIL: ", msg)
	else:
		print("[Playthrough] ok: ", msg)


func _finish() -> void:
	if _findings.is_empty():
		print("[Playthrough] all beats green (%d shots)" % _shot_idx)
		get_tree().quit(0)
	else:
		printerr("[Playthrough] %d findings:" % _findings.size())
		for f in _findings:
			printerr("  - ", f)
		get_tree().quit(1)
