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
const TMP_PATH  := "user://save_slot_1.json.tmp"
const VERSION := 1


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# Write to a temp file first, then atomic-rename onto the real path. A crash
# or power loss between open() and rename() leaves the previous save intact.
func save_slot() -> bool:
	if not SaveBlocker.can_save():
		push_warning("[SaveManager] save refused: %s" % SaveBlocker.reason())
		return false
	var blob := _serialize()
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] cannot open temp save file for write")
		return false
	f.store_string(JSON.stringify(blob, "  "))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("[SaveManager] cannot open user:// for rename")
		_remove_if_exists(TMP_PATH)
		return false
	var err := dir.rename(TMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		push_error("[SaveManager] atomic rename failed: %d" % err)
		_remove_if_exists(TMP_PATH)
		return false
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
	var save_version: int = int(parsed.get("version", 0))
	if save_version > VERSION:
		push_error("[SaveManager] save is newer than build (v%d > v%d); refusing to load" % [
			save_version, VERSION,
		])
		return false
	if save_version < VERSION:
		parsed = _migrate(parsed, save_version)
		if parsed.is_empty():
			return false
	_deserialize(parsed)
	print("[SaveManager] loaded %s" % SAVE_PATH)
	return true


func delete_slot() -> void:
	_remove_if_exists(SAVE_PATH)
	_remove_if_exists(TMP_PATH)


# Per-version migration steps land here as the schema evolves. Each bump adds
# one branch that transforms blob from `from_version` toward VERSION. Returns
# {} on failure so load_slot() can bail without applying a half-migrated blob.
func _migrate(blob: Dictionary, from_version: int) -> Dictionary:
	push_error("[SaveManager] no migration registered: v%d -> v%d" % [
		from_version, VERSION,
	])
	return {}


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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
	# Rebuild each memory entry from current defaults, then overlay saved fields.
	# This way, fields added since the save was written get sensible defaults
	# instead of leaving downstream code with null. Unknown NPC ids (removed
	# between builds) are dropped, not slammed into the store.
	var migrated: Dictionary = {}
	for npc_id in blob.keys():
		if not NpcProfileRegistry.has_profile(npc_id):
			print("[SaveManager] skipping memory for unknown NPC '%s'" % npc_id)
			continue
		var saved: Dictionary = blob[npc_id]
		var base: Dictionary = NpcMemoryStore._new_memory(npc_id)
		migrated[npc_id] = {
			"relationship_to_player": int(saved.get("relationship_to_player", base["relationship_to_player"])),
			"stress":                 int(saved.get("stress",                 base["stress"])),
			"patience":               int(saved.get("patience",               base["patience"])),
			"player_tags":            Array(saved.get("player_tags",          base["player_tags"])).duplicate(),
			"last_topic":             String(saved.get("last_topic",          base["last_topic"])),
			"flags":                  (saved.get("flags", base["flags"]) as Dictionary).duplicate(true),
			"recent_summary":         String(saved.get("recent_summary",      base["recent_summary"])),
			"long_term_notes":        Array(saved.get("long_term_notes",      base["long_term_notes"])).duplicate(true),
			"anger_cooldown_turns":   int(saved.get("anger_cooldown_turns",   base["anger_cooldown_turns"])),
		}
	NpcMemoryStore._by_id = migrated


func _apply_npc_dossiers(blob: Dictionary) -> void:
	# Skip unknown NPCs; drop entries missing an id or tier (broken records).
	var migrated: Dictionary = {}
	for npc_id in blob.keys():
		if not NpcProfileRegistry.has_profile(npc_id):
			print("[SaveManager] skipping dossier for unknown NPC '%s'" % npc_id)
			continue
		var saved_entries: Array = blob[npc_id] as Array
		var cleaned: Array = []
		for e in saved_entries:
			if not (e is Dictionary):
				continue
			var bid: String = String(e.get("id", ""))
			var tier: String = String(e.get("tier", ""))
			if bid.is_empty() or tier.is_empty():
				continue
			cleaned.append({
				"id":                 bid,
				"tier":               tier,
				"forbidden_to_share": bool(e.get("forbidden_to_share", false)),
				"category":           String(e.get("category", "events")),
			})
		migrated[npc_id] = cleaned
	NpcDossierStore._by_id = migrated


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
