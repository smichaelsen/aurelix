extends Node
##
## Orchestrates a single combat:
##   - lazily creates the CombatOverlay on first use
##   - listens for encounter trigger from PlayerController
##   - instantiates a CombatEngine, hooks its signals to the overlay
##   - on win: removes the encounter from the map (defeated)
##   - on loss: restores Kael to full HP and ends combat (a tasteful
##     stand-in for save reload until Phase 10 wires real save/load)
##
## Autoload as `CombatController`.
##

const OVERLAY_SCENE := preload("res://scenes/ui/CombatOverlay.tscn")
const CombatEngineScript = preload("res://scripts/combat/CombatEngine.gd")

var _overlay: Node = null
var _engine: RefCounted = null
var _current_encounter_id: String = ""
var _current_combatant_id: String = ""
var _busy: bool = false

# Encounter -> fact granted on victory. Drives quest beats + dossier
# mutations downstream.
const ENCOUNTER_TO_FACT := {
	"drust_camp":     "drust_dead",
	"wolf_path_a":    "",
	"bandit_path_b":  "bandits_present_in_marlow_region",
}


func _ready() -> void:
	EventBus.combat_started.connect(_log_combat_started)


func is_active() -> bool:
	return _engine != null


func start_encounter(encounter_id: String, combatant_id: String) -> void:
	if _busy or _engine != null:
		return
	_busy = true
	_current_encounter_id = encounter_id
	_current_combatant_id = combatant_id

	_ensure_overlay()
	var kael := CombatantStats.kael_stats()
	var enemy := CombatantStats.base_stats(combatant_id)
	if enemy.is_empty():
		push_error("[CombatController] unknown combatant '%s'" % combatant_id)
		_busy = false
		return

	# Boss pre-fight line.
	if bool(enemy.get("is_boss", false)):
		var pre := String(enemy.get("pre_fight_line", "")).strip_edges()
		if not pre.is_empty():
			print("[CombatController] %s: %s" % [enemy.get("name", combatant_id), pre])

	# Engine setup.
	_engine = CombatEngineScript.new()
	_engine.narration.connect(func(t): _overlay.set_narration(t))
	_engine.hp_changed.connect(_on_hp_changed)
	_engine.combat_ended.connect(_on_combat_ended)
	_engine.awaiting_player_input.connect(_on_awaiting_input)

	# Overlay setup. Iskar HUD only when he's bonded; otherwise the row
	# stays hidden so solo combat looks the same as before.
	var iskar_hud: Dictionary = {}
	if IskarCompanion.bonded:
		var iskar_stats := CombatantStats.base_stats("iskar")
		if not iskar_stats.is_empty():
			iskar_hud = {
				"name":   iskar_stats.get("name", "Iskar"),
				"hp":     iskar_stats["hp"],
				"max_hp": iskar_stats["hp"],
			}
	_overlay.show_combat(
		{"name": enemy.get("name", combatant_id), "hp": enemy["hp"], "max_hp": enemy["hp"]},
		{"name": kael.get("name", "Kael"),         "hp": kael["hp"],  "max_hp": kael["hp"]},
		iskar_hud,
	)
	if not _overlay.action_chosen.is_connected(_on_action_chosen):
		_overlay.action_chosen.connect(_on_action_chosen)

	EventBus.combat_started.emit(encounter_id)
	_engine.start(kael, enemy, combatant_id)
	_busy = false


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_awaiting_input() -> void:
	_overlay.enable_actions(true)


func _on_action_chosen(kind: String, payload: Dictionary) -> void:
	if _engine == null:
		return
	_overlay.enable_actions(false)
	_engine.player_action(kind, payload)


func _on_hp_changed(_battler_id: String, _hp: int, _max_hp: int) -> void:
	if _engine == null:
		return
	var p: Dictionary = _engine.player()
	var e: Dictionary = _engine.enemy()
	if not p.is_empty():
		_overlay.set_kael_hp(int(p["hp"]), int(p["max_hp"]))
	if not e.is_empty():
		_overlay.set_enemy_hp(int(e["hp"]), int(e["max_hp"]))
	var iskar: Dictionary = _engine.iskar()
	if not iskar.is_empty():
		_overlay.set_iskar_hp(int(iskar["hp"]), int(iskar["max_hp"]))


func _on_combat_ended(outcome: String) -> void:
	print("[CombatController] combat ended: %s" % outcome)
	EventBus.combat_ended.emit(outcome)
	match outcome:
		"won":
			WorldState.remove_encounter(_current_encounter_id)
			_despawn_encounter_sprite(_current_encounter_id)
			EventBus.enemy_defeated.emit(_current_encounter_id)
			_grant_fact_for(_current_encounter_id)
			_award_affinity()
		"lost":
			# Phase 10 will reload from save. Until then, "faint" the
			# party (don't actually die) so the player isn't trapped in
			# a death loop at 0 HP. The encounter remains on the map.
			print("[CombatController] Kael fell -- faint and recover. (Save/reload Phase 10.)")
		"fled":
			pass
	if _overlay != null:
		_overlay.hide_combat()
	_engine = null
	_current_encounter_id = ""
	_current_combatant_id = ""


func _grant_fact_for(encounter_id: String) -> void:
	var fact_id: String = ENCOUNTER_TO_FACT.get(encounter_id, "")
	if fact_id.is_empty():
		return
	FactLedger.grant_fact(fact_id, {
		"kind":         "combat_victory",
		"encounter_id": encounter_id,
	})


func _award_affinity() -> void:
	if not IskarCompanion.bonded:
		return
	var enemy_block: Dictionary = CombatantStats.base_stats(_current_combatant_id)
	var pts: int = 3 if bool(enemy_block.get("is_boss", false)) else 1
	IskarCompanion.add_affinity(pts)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _ensure_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	_overlay = OVERLAY_SCENE.instantiate()
	add_child(_overlay)


func _despawn_encounter_sprite(encounter_id: String) -> void:
	# Find an "Encounters" node anywhere under the active tree. In normal
	# play it's a direct child of the scene root; in headless tests the
	# scene may be wrapped under a test container, so search recursively.
	var encounters := _find_descendant(get_tree().root, "Encounters")
	if encounters == null:
		return
	for child in encounters.get_children():
		if child.has_meta("encounter_id") and child.get_meta("encounter_id") == encounter_id:
			child.queue_free()
			return


func _find_descendant(node: Node, target_name: String) -> Node:
	if node == null:
		return null
	for c in node.get_children():
		if c.name == target_name:
			return c
		var sub := _find_descendant(c, target_name)
		if sub != null:
			return sub
	return null


func _log_combat_started(eid: String) -> void:
	print("[CombatController] combat_started encounter=%s" % eid)
