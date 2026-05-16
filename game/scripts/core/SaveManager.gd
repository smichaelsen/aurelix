extends Node
##
## Single-slot JSON save. Captures everything the player has affected:
##
##   - inventory + equipment + coins
##   - known facts + their sources
##   - quest state
##   - per-NPC memory + dossier mutations + anger cooldowns
##   - Iskar (bonded, affinity, tier, stance)
##   - journal entries
##   - current scene + player tile
##
## Save lives at `user://save_slot_1.json`. Use `save_slot()` /
## `load_slot()`; both consult SaveBlocker first to refuse during combat
## or while a dialog/journal turn is in flight.
##
## Autoload as `SaveManager`. Depends on every store it touches.
##

const SAVE_PATH := "user://save_slot_1.json"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_slot() -> bool:
	if not SaveBlocker.can_save():
		push_warning("[SaveManager] save refused: %s" % SaveBlocker.reason())
		return false
	var blob := _serialize()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] cannot open save file for write")
		return false
	f.store_string(JSON.stringify(blob, "  "))
	f.close()
	print("[SaveManager] wrote %s" % SAVE_PATH)
	return true


func load_slot() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		push_error("[SaveManager] bad save file")
		return false
	if int(parsed.get("version", 0)) != VERSION:
		push_warning("[SaveManager] save version mismatch (got %s, expect %d)" % [
			parsed.get("version"), VERSION,
		])
	_deserialize(parsed)
	print("[SaveManager] loaded %s" % SAVE_PATH)
	return true


func delete_slot() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------------------
# Serialization
# ---------------------------------------------------------------------------

func _serialize() -> Dictionary:
	return {
		"version":       VERSION,
		"scene":         _scene_blob(),
		"inventory":     _inventory_blob(),
		"facts":         FactLedger._known.duplicate(true),
		"quest_state":   QuestState._states.duplicate(true),
		"npc_memory":    NpcMemoryStore._by_id.duplicate(true),
		"npc_dossiers":  NpcDossierStore._by_id.duplicate(true),
		"iskar":         _iskar_blob(),
		"journal":       _journal_blob(),
	}


func _deserialize(blob: Dictionary) -> void:
	# Restore everything that doesn't need scene swapping first.
	_apply_inventory(blob.get("inventory", {}))
	_apply_facts(blob.get("facts", {}))
	_apply_quest_state(blob.get("quest_state", {}))
	_apply_npc_memory(blob.get("npc_memory", {}))
	_apply_npc_dossiers(blob.get("npc_dossiers", {}))
	_apply_iskar(blob.get("iskar", {}))
	_apply_journal(blob.get("journal", {}))
	# Scene swap last; SceneRouter is responsible for putting the player
	# back at the saved tile.
	_apply_scene(blob.get("scene", {}))


# ---------------------------------------------------------------------------
# Scene
# ---------------------------------------------------------------------------

func _scene_blob() -> Dictionary:
	var pos: Vector2i = WorldState.player_start
	var player := get_tree().get_first_node_in_group("player_grid")
	if player != null and "grid_pos" in player:
		pos = player.grid_pos
	return {
		"id":  WorldState.current_scene_id,
		"col": pos.x,
		"row": pos.y,
	}


func _apply_scene(s: Dictionary) -> void:
	var scene_id: String = s.get("id", "")
	if scene_id.is_empty():
		return
	var pos := Vector2i(int(s.get("col", 0)), int(s.get("row", 0)))
	# If we're already in the right scene, just teleport the player; avoid
	# the full change_scene_to_file (which tears down the scene tree and
	# kills any test driver instantiating this scene as a child).
	if scene_id == WorldState.current_scene_id:
		var player := get_tree().get_first_node_in_group("player_grid")
		if player != null and "grid_pos" in player:
			player.grid_pos = pos
			if "position" in player:
				player.position = Vector2(pos.x * 32 + 4, pos.y * 32)
		return
	SceneRouter.go(scene_id, pos)


# ---------------------------------------------------------------------------
# Inventory
# ---------------------------------------------------------------------------

func _inventory_blob() -> Dictionary:
	return {
		"bag":       Inventory.bag.duplicate(true),
		"equipment": Inventory.equipment.duplicate(true),
		"coins":     Inventory.coins,
	}


func _apply_inventory(blob: Dictionary) -> void:
	if blob.is_empty():
		return
	Inventory.bag       = (blob.get("bag", []) as Array).duplicate(true)
	Inventory.equipment = (blob.get("equipment", {}) as Dictionary).duplicate(true)
	Inventory.coins     = int(blob.get("coins", 0))


# ---------------------------------------------------------------------------
# Facts
# ---------------------------------------------------------------------------

func _apply_facts(blob: Dictionary) -> void:
	FactLedger._known = blob.duplicate(true)


func _apply_quest_state(blob: Dictionary) -> void:
	# Route through set_state so QuestRuleEngine can re-evaluate (the
	# "fact granted before accept" path lands here on reload).
	for quest_id in blob.keys():
		QuestState.set_state(quest_id, String(blob[quest_id]))


# ---------------------------------------------------------------------------
# NPC memory + dossier
# ---------------------------------------------------------------------------

func _apply_npc_memory(blob: Dictionary) -> void:
	NpcMemoryStore._by_id = blob.duplicate(true)


func _apply_npc_dossiers(blob: Dictionary) -> void:
	NpcDossierStore._by_id = blob.duplicate(true)


# ---------------------------------------------------------------------------
# Iskar
# ---------------------------------------------------------------------------

func _iskar_blob() -> Dictionary:
	return {
		"bonded":   IskarCompanion.bonded,
		"affinity": IskarCompanion.affinity_points,
		"tier":     IskarCompanion.unlocked_tier,
		"stance":   IskarCompanion.stance,
	}


func _apply_iskar(blob: Dictionary) -> void:
	IskarCompanion.bonded          = bool(blob.get("bonded", false))
	IskarCompanion.affinity_points = int(blob.get("affinity", 0))
	IskarCompanion.unlocked_tier   = int(blob.get("tier", 0))
	IskarCompanion.stance          = String(blob.get("stance", IskarCompanion.STANCE_AGGRESSIVE))


# ---------------------------------------------------------------------------
# Journal
# ---------------------------------------------------------------------------

func _journal_blob() -> Dictionary:
	return {"entries": Journal._entries.duplicate(true)}


func _apply_journal(blob: Dictionary) -> void:
	Journal._entries = (blob.get("entries", []) as Array).duplicate(true)
	Journal._seen.clear()
	for e in Journal._entries:
		Journal._seen["%s|%s" % [e.get("id", ""), e.get("tier", "")]] = true
