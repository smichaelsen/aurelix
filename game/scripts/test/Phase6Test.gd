extends Node
##
## Headless Phase 6 smoke test:
##   - Inventory starts with the expected kit (incl. an ale loaner)
##   - Offering ale to Orren flips drunk flag + consumes ale
##   - Drunk state allows the_tower to be reached via Press
##   - Apple to Toma flips fed flag without consuming key items
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"

var _failures: Array[String] = []


func _ready() -> void:
	add_child((load(VILLAGE_PATH) as PackedScene).instantiate())
	await _settle(3)

	_assert(Inventory.has("ale"), "expected ale in starting kit")
	_assert(Inventory.has("apple", 1), "expected apple in starting kit")
	_assert(Inventory.coins == 30, "expected 30 starting coins, got %d" % Inventory.coins)

	await _case_offer_ale_to_orren()
	await _case_apple_to_toma()
	await _case_ale_then_press_reveals_fact()

	_finish()


# ---------------------------------------------------------------------------
# Cases
# ---------------------------------------------------------------------------

func _case_offer_ale_to_orren() -> void:
	NpcMemoryStore.reset_for("orren_drunk")
	_assert(Inventory.has("ale"), "ale missing before offer")

	EventBus.dialogue_requested.emit("orren_drunk")
	await _settle(4)
	var box = DialogueController._box
	box.item_offered.emit("ale")
	await _settle(8)

	var mem = NpcMemoryStore.memory_for("orren_drunk")
	_assert(mem["flags"].get("drunk", false) == true,
		"expected Orren.flags.drunk=true after ale; got %s" % mem["flags"])
	_assert(not Inventory.has("ale"),
		"expected ale to be consumed after offer")
	print("  Offered ale -> Orren.drunk=%s, ale_left=%d" % [mem["flags"]["drunk"], Inventory.count_of("ale")])
	box.closed.emit()
	await _settle(2)


func _case_apple_to_toma() -> void:
	NpcMemoryStore.reset_for("toma_child")
	var apples_before = Inventory.count_of("apple")
	_assert(apples_before >= 1, "need apple in kit for this test")

	EventBus.dialogue_requested.emit("toma_child")
	await _settle(4)
	var box = DialogueController._box
	box.item_offered.emit("apple")
	await _settle(8)

	var mem = NpcMemoryStore.memory_for("toma_child")
	_assert(mem["flags"].get("fed", false) == true,
		"expected Toma.flags.fed=true after apple; got %s" % mem["flags"])
	_assert(Inventory.count_of("apple") == apples_before - 1,
		"expected apple count to decrease by 1")
	print("  Offered apple to Toma -> Toma.fed=%s, apples_left=%d" % [mem["flags"]["fed"], Inventory.count_of("apple")])
	box.closed.emit()
	await _settle(2)


func _case_ale_then_press_reveals_fact() -> void:
	NpcMemoryStore.reset_for("orren_drunk")
	FactLedger.reset()
	QuestState.set_state(QuestState.DRAGON_SIGHTING, QuestState.STATE_ACTIVE)
	# Restore ale so we can offer it.
	Inventory.add("ale", 1)

	EventBus.dialogue_requested.emit("orren_drunk")
	await _settle(4)
	var box = DialogueController._box

	# 1. Ask about the tower (default option 2, sober) -> dodge.
	(box.get("_options").get_child(1) as Button).pressed.emit()
	await _settle(8)
	_assert(DialogueController._session.dodged_topics.has("the_tower"),
		"expected the_tower to be dodged after sober ask")

	# 2. Offer ale -> Orren drunk.
	box.item_offered.emit("ale")
	await _settle(8)
	var mem = NpcMemoryStore.memory_for("orren_drunk")
	_assert(mem["flags"].get("drunk", false), "Orren should be drunk after ale")

	# 3. Press option 1 ("You saw something, didn't you?") -> matching angle.
	(box.get("_options").get_child(0) as Button).pressed.emit()
	await _settle(10)

	_assert(FactLedger.has_fact("dragon_seen_near_old_tower"),
		"expected dragon_seen_near_old_tower granted via ale->press flow")
	_assert(QuestState.is_complete(QuestState.DRAGON_SIGHTING),
		"expected dragon_sighting complete; got %s" % [QuestState.get_state(QuestState.DRAGON_SIGHTING)])
	print("  Ale -> Press -> reveal -> quest complete (end-to-end demo loop)")

	box.closed.emit()
	await _settle(2)


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
		print("[Phase6Test] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase6Test] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
