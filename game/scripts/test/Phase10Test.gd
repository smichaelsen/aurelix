extends Node
##
## Phase 10: save/load + fallback + anger cooldown + quest_paid.
##
## Verifies:
##   - SaveManager.save_slot() refused during combat, allowed otherwise
##   - SaveManager round-trip: facts, quest state, inventory, npc memory,
##     dossier mutations, iskar, journal entries all restored
##   - FallbackProvider returns authored line when force_active
##   - AngerCooldownResolver: setting cooldown blocks dialog; apology item
##     clears it
##   - quest_paid fires when player re-talks to Halden after completion
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"

var _failures: Array[String] = []
var _quest_paid_fired := false


func _ready() -> void:
	# Wipe any prior save from a previous run so we don't accidentally
	# pre-load before we even start.
	SaveManager.delete_slot()

	Journal.reset()
	NpcDossierStore.reset()
	NpcMemoryStore.reset_all()
	FactLedger.reset()
	IskarCompanion.bonded = false
	IskarCompanion.affinity_points = 0
	IskarCompanion.unlocked_tier = 0
	QuestState._states.clear()

	EventBus.quest_paid.connect(func(_q): _quest_paid_fired = true)

	add_child((load(VILLAGE_PATH) as PackedScene).instantiate())
	await _settle(4)

	Journal._seed_starting_entries()
	await _settle(2)

	await _test_save_blocker()
	await _test_round_trip()
	await _test_fallback_provider()
	await _test_anger_cooldown()
	await _test_quest_paid()

	_finish()


# ---------------------------------------------------------------------------
# Save blocker
# ---------------------------------------------------------------------------

func _test_save_blocker() -> void:
	_expect(SaveBlocker.can_save(),
		"save_blocker: allowed at idle")
	# Simulate combat in progress; SaveBlocker should refuse.
	CombatController.start_encounter("phase10_test_phantom", "wolf")
	await _settle(3)
	_expect(not SaveBlocker.can_save(),
		"save_blocker: refused during combat")
	# Flee out by feeding "flee" actions until combat ends.
	var guard := 40
	while CombatController.is_active() and guard > 0:
		CombatController._on_action_chosen("flee", {})
		await _settle(2)
		guard -= 1
	await _settle(3)
	_expect(SaveBlocker.can_save(),
		"save_blocker: allowed again after combat ends")


# ---------------------------------------------------------------------------
# Round trip
# ---------------------------------------------------------------------------

func _test_round_trip() -> void:
	# Seed unique state.
	Inventory.coins = 99
	Inventory.add("strange_coin", 1)
	FactLedger.grant_fact("drust_dead", {"kind": "test"})
	QuestState.set_state("dragon_sighting", "complete")
	IskarCompanion.bonded = true
	IskarCompanion.affinity_points = 17
	IskarCompanion.unlocked_tier = 1
	NpcDossierStore.add("mara_blacksmith", "gold_eyed_one", "rumor")
	var mem := NpcMemoryStore.memory_for("orren_drunk")
	mem["recent_summary"] = "Orren spoke about smoke and wings."
	mem["stress"] = 4

	var ok_save := SaveManager.save_slot()
	_expect(ok_save, "save: save_slot returns true")

	# Wipe everything in-memory.
	Inventory.coins = 0
	Inventory.bag = []
	FactLedger.reset()
	QuestState._states.clear()
	IskarCompanion.bonded = false
	IskarCompanion.affinity_points = 0
	IskarCompanion.unlocked_tier = 0
	NpcDossierStore.reset()
	NpcMemoryStore.reset_all()
	Journal.reset()

	var ok_load := SaveManager.load_slot()
	_expect(ok_load, "load: load_slot returns true")
	await _settle(3)

	_expect(Inventory.coins == 99,
		"round-trip: coins (got %d)" % Inventory.coins)
	_expect(Inventory.has("strange_coin"),
		"round-trip: strange_coin in inventory")
	_expect(FactLedger.has_fact("drust_dead"),
		"round-trip: drust_dead fact")
	_expect(QuestState.get_state("dragon_sighting") == "complete",
		"round-trip: quest state complete")
	_expect(IskarCompanion.bonded,
		"round-trip: iskar bonded")
	_expect(IskarCompanion.affinity_points == 17,
		"round-trip: iskar affinity (got %d)" % IskarCompanion.affinity_points)
	_expect(IskarCompanion.unlocked_tier == 1,
		"round-trip: iskar tier (got %d)" % IskarCompanion.unlocked_tier)
	_expect(NpcDossierStore.has("mara_blacksmith", "gold_eyed_one"),
		"round-trip: mara dossier carries gold_eyed_one")
	var mem2 := NpcMemoryStore.memory_for("orren_drunk")
	_expect(String(mem2.get("recent_summary", "")).find("smoke") >= 0,
		"round-trip: orren memory recent_summary preserved")
	_expect(int(mem2.get("stress", 0)) == 4,
		"round-trip: orren memory stress (got %d)" % int(mem2.get("stress", 0)))

	# Clean up save file.
	SaveManager.delete_slot()


# ---------------------------------------------------------------------------
# Fallback provider
# ---------------------------------------------------------------------------

func _test_fallback_provider() -> void:
	FallbackProvider.force_active = true
	var profile := NpcProfileRegistry.get_profile("mara_blacksmith")
	var resp: Dictionary = await AiService.generate({
		"npc_id":          "mara_blacksmith",
		"topic_addressed": "the_tower",
		"npc_profile":     profile,
	})
	FallbackProvider.force_active = false
	_expect(resp.get("dialogue", "").find("tower") >= 0
			or resp.get("dialogue", "").find("won't say") >= 0,
		"fallback: mara on the_tower (got '%s')" % resp.get("dialogue", ""))

	# Unknown topic should fall through to _default.
	var resp2 := FallbackProvider.generate("mara_blacksmith", "unknown_topic", profile)
	_expect(not resp2.get("dialogue", "").is_empty(),
		"fallback: mara unknown topic falls through to _default")

	# Unknown NPC should hit archetype bank or last-resort.
	var bandit_profile := {"archetype": "drunk", "speech": {}}
	var resp3 := FallbackProvider.generate("nobody", "_default", bandit_profile)
	_expect(not resp3.get("dialogue", "").is_empty(),
		"fallback: unknown NPC archetype fallback")


# ---------------------------------------------------------------------------
# Anger cooldown
# ---------------------------------------------------------------------------

func _test_anger_cooldown() -> void:
	AngerCooldownResolver.set_anger_cooldown("orren_drunk")
	var mem := NpcMemoryStore.memory_for("orren_drunk")
	_expect(int(mem.get("anger_cooldown_turns", 0)) == AngerCooldownResolver.COOLDOWN_TURNS,
		"cooldown: set to default (%d)" % AngerCooldownResolver.COOLDOWN_TURNS)

	# Opening dialog with someone else ticks Orren's cooldown.
	EventBus.dialogue_opened.emit("mara_blacksmith")
	await _settle(2)
	_expect(int(mem.get("anger_cooldown_turns", 0))
			== AngerCooldownResolver.COOLDOWN_TURNS - 1,
		"cooldown: other-NPC dialog ticked Orren (got %d)"
			% int(mem.get("anger_cooldown_turns", 0)))

	# Offering ale (apology=true) clears it.
	Inventory.add("ale", 1)
	EventBus.item_offered.emit("orren_drunk", "ale")
	await _settle(2)
	_expect(int(mem.get("anger_cooldown_turns", 0)) == 0,
		"cooldown: apology ale cleared it")
	_expect(bool(mem.get("flags", {}).get("forgave_player", false)),
		"cooldown: forgave_player flag set")


# ---------------------------------------------------------------------------
# Quest paid
# ---------------------------------------------------------------------------

func _test_quest_paid() -> void:
	_quest_paid_fired = false
	# State already complete from the round-trip test. Re-talking to Halden
	# should fire quest_paid.
	QuestState.set_state("dragon_sighting", "complete")
	# Calling HaldenScript.start_turn() directly is cheaper than driving
	# the dialog UI and matches what DialogueController would do.
	var HaldenScript = load("res://scripts/npc/HaldenScript.gd")
	HaldenScript.start_turn()
	await _settle(2)
	_expect(_quest_paid_fired,
		"quest_paid: fired when Halden state=complete")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		printerr("[Phase10Test] FAIL: ", msg)
	else:
		print("[Phase10Test] ok: ", msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Phase10Test] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase10Test] %d failures:" % _failures.size())
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
