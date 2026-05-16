extends Node
##
## Phase 9: NPC dossier mutations.
##
## Verifies:
##   - Showing the strange coin to Mara seeds gold_eyed_one in her dossier
##   - Showing the bandit note to Edda seeds gold_eyed_one in her dossier
##   - Iskar entering village_square adds kael_has_drake (witness) to all
##     five village NPCs, with Edda specifically flagged forbidden_to_share
##   - drust_dead fact ripples bandits_defeated (rumor) to Mara + Halden
##

const VILLAGE_PATH := "res://scenes/village_square.tscn"

var _failures: Array[String] = []
var _mutations: Array = []


func _ready() -> void:
	NpcDossierStore.reset()
	FactLedger.reset()
	EventBus.npc_dossier_mutated.connect(
		func(npc, briefing, tier): _mutations.append([npc, briefing, tier])
	)

	add_child((load(VILLAGE_PATH) as PackedScene).instantiate())
	await _settle(3)

	# --- Item offer: coin -> Mara ---
	EventBus.item_offered.emit("mara_blacksmith", "strange_coin")
	await _settle(2)
	_assert(NpcDossierStore.has("mara_blacksmith", "gold_eyed_one"),
		"Mara should have gold_eyed_one after seeing strange_coin")
	_assert(_tier_of("mara_blacksmith", "gold_eyed_one") == "rumor",
		"Mara's gold_eyed_one should be tier rumor")

	# --- Item offer: bandit_note -> Edda ---
	EventBus.item_offered.emit("edda_priest", "bandit_note")
	await _settle(2)
	_assert(NpcDossierStore.has("edda_priest", "gold_eyed_one"),
		"Edda should have gold_eyed_one after seeing bandit_note")

	# --- Iskar enters the village ---
	EventBus.iskar_entered_location.emit("village_square")
	await _settle(2)
	for npc_id in ["mara_blacksmith", "orren_drunk", "edda_priest",
				   "halden_reeve", "toma_child"]:
		_assert(NpcDossierStore.has(npc_id, "kael_has_drake"),
			"%s should witness kael_has_drake when Iskar enters village" % npc_id)
		_assert(_tier_of(npc_id, "kael_has_drake") == "witness",
			"%s's kael_has_drake should be witness tier" % npc_id)

	# Edda specifically has forbidden_to_share=true.
	var edda_entry := _entry_for("edda_priest", "kael_has_drake")
	_assert(edda_entry.get("forbidden_to_share", false) == true,
		"Edda's kael_has_drake should be forbidden_to_share")
	var mara_entry := _entry_for("mara_blacksmith", "kael_has_drake")
	_assert(mara_entry.get("forbidden_to_share", true) == false,
		"Mara's kael_has_drake should NOT be forbidden_to_share")

	# --- fact_granted("drust_dead") ripples to Mara + Halden ---
	FactLedger.grant_fact("drust_dead", {"kind": "test"})
	await _settle(2)
	_assert(NpcDossierStore.has("mara_blacksmith", "bandits_defeated"),
		"Mara should hear bandits_defeated rumor after drust_dead")
	_assert(_tier_of("mara_blacksmith", "bandits_defeated") == "rumor",
		"Mara's bandits_defeated should be rumor tier")
	_assert(NpcDossierStore.has("halden_reeve", "bandits_defeated"),
		"Halden should hear bandits_defeated rumor after drust_dead")

	# --- Mutation signal fired at least once ---
	_assert(_mutations.size() > 0,
		"npc_dossier_mutated should have fired during the run")

	_finish()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _entry_for(npc_id: String, briefing_id: String) -> Dictionary:
	for e in NpcDossierStore.dossier_for(npc_id):
		if e.get("id", "") == briefing_id:
			return e
	return {}


func _tier_of(npc_id: String, briefing_id: String) -> String:
	return _entry_for(npc_id, briefing_id).get("tier", "")


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func _finish() -> void:
	if _failures.is_empty():
		print("[Phase9Test] PASS")
		get_tree().quit(0)
	else:
		printerr("[Phase9Test] FAIL")
		for f in _failures:
			printerr("  - ", f)
		get_tree().quit(1)
