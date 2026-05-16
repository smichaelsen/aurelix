extends Node
##
## Reads /data/_index.json and populates the four registries. Files on disk
## are JSON, converted from YAML by tools/yaml_to_json.py at build time so
## Godot does not need a YAML parser.
## Autoload as `DataLoader`. Order: after registries, before BootValidator.
##


func _ready() -> void:
	var index = _load_json(Config.INDEX_FILE)
	if not (index is Dictionary):
		push_error("[DataLoader] could not load %s" % Config.INDEX_FILE)
		return

	# Topics + facts are single files.
	var topics_file: String = Config.DATA_DIR + index.get("topics_file", "topics.json")
	var facts_file:  String = Config.DATA_DIR + index.get("facts_file",  "facts.json")
	var topics_data = _load_json(topics_file)
	var facts_data  = _load_json(facts_file)
	if topics_data is Dictionary: TopicRegistry.load_from(topics_data)
	if facts_data  is Dictionary: FactRegistry.load_from(facts_data)

	# NPCs are one file each, listed in the manifest.
	for entry in index.get("npcs", []):
		var p: String = Config.DATA_DIR + entry.get("file", "")
		var d = _load_json(p)
		if d is Dictionary:
			NpcProfileRegistry.add(d)

	# Briefings: one file per (id, tier), listed in the manifest.
	for entry in index.get("briefings", []):
		var p: String = Config.DATA_DIR + entry.get("file", "")
		var d = _load_json(p)
		if d is Dictionary:
			BriefingRegistry.add(d)

	# Authored option banks per NPC (phase 4+).
	for entry in index.get("options", []):
		var npc_id: String = entry.get("npc_id", "")
		var p: String = Config.DATA_DIR + entry.get("file", "")
		var d = _load_json(p)
		if d is Dictionary and not npc_id.is_empty():
			AuthoredOptionLibrary.add_bank(npc_id, d)

	var counts: Dictionary = index.get("counts", {})
	print("[DataLoader] loaded ", counts)
	EventBus.data_loaded.emit()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[DataLoader] not found: %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[DataLoader] could not open: %s" % path)
		return null
	var text := f.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_error("[DataLoader] bad JSON in %s" % path)
		return null
	return parsed
