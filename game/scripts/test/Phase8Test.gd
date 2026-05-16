extends Node
##
## Phase 8: Kael's journal.
##
## Verifies:
##   - Journal seeds with 3 starting entries (kael_self, kingdom_overview, marlow_hollow)
##   - Granting facts adds the right briefings to Kael's dossier
##   - Opening the journal panel + picking an authored option generates an
##     AI answer through the Kael-self pipeline
##   - Free-text query routes to topic detection + answer
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"

var _failures: Array[String] = []
var _added: Array[String] = []


func _ready() -> void:
	Journal.reset()
	FactLedger.reset()
	EventBus.journal_briefing_added.connect(func(id, _t): _added.append(id))

	# Need a real scene loaded so InputMap + autoloads have a host.
	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	await _settle(3)

	# Re-seed since reset was called after _ready.
	Journal._seed_starting_entries()
	await _settle(2)

	# --- Starting entries ---
	for id in ["kael_self", "kingdom_overview", "marlow_hollow"]:
		_assert(Journal.has_id(id),
			"expected starting entry '%s' in Journal" % id)

	# --- Fact -> briefing mapping ---
	FactLedger.grant_fact("bandit_note_recovered", {"kind": "test"})
	await _settle(2)
	_assert(Journal.has_id("bandit_note"),
		"bandit_note should land in Journal after bandit_note_recovered")
	_assert(Journal.has_id("gold_eyed_one"),
		"gold_eyed_one should land in Journal after bandit_note_recovered")

	FactLedger.grant_fact("drust_dead", {"kind": "test"})
	await _settle(2)
	_assert(Journal.has_id("bandits_defeated"),
		"bandits_defeated should land after drust_dead")

	FactLedger.grant_fact("iskar_bonded", {"kind": "test"})
	await _settle(2)
	_assert(Journal.has_id("iskar_drake"),
		"iskar_drake should land after iskar_bonded")
	_assert(Journal.has_id("iskar_rescued"),
		"iskar_rescued should land after iskar_bonded")

	# --- Open journal, pick a topic option, get an answer ---
	JournalController.open()
	await _settle(4)
	_assert(JournalController.is_open(), "journal should be open after open()")

	var panel: Node = JournalController._panel
	# Pick the "Who is 'the gold-eyed one'?" option (index 1 of default).
	panel.option_chosen.emit({"label": "Who is 'the gold-eyed one'?", "topic_id": "gold_eyed_one"})
	await _settle(8)
	var answer: String = panel.get("_answer").text
	_assert(answer.length() > 0 and answer != "...",
		"expected non-empty Kael answer; got '%s'" % answer)
	print("  Journal answer: %s" % answer)

	# --- Free text query ---
	panel.text_submitted.emit("What about Iskar?")
	await _settle(8)
	var answer2: String = panel.get("_answer").text
	_assert(answer2.length() > 0 and answer2 != "...",
		"expected non-empty Kael free-text answer; got '%s'" % answer2)
	print("  Journal free-text answer: %s" % answer2)

	JournalController.close()
	await _settle(2)
	_assert(not JournalController.is_open(), "journal should close")

	_finish()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Phase8Test] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase8Test] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
