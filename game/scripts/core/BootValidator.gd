extends Node
##
## Validates that the loaded data is internally consistent before the game
## proceeds: every dossier briefing-id resolves, every fact referenced by a
## briefing exists, every topic_tag referenced by a briefing exists.
##
## Runs after DataLoader's _ready. Prints a one-line summary on success;
## prints a numbered list of errors on failure. If `Config.validate_only` is
## true (e.g. `godot --headless -- --validate-only`), exits the process with
## status 0 (success) or 1 (failure).
##
## Autoload as `BootValidator`. Order: last.
##


func _ready() -> void:
	# DataLoader's _ready already ran (declared before us). Yield one frame
	# so any emitted signals settle before we walk the registries.
	await get_tree().process_frame

	var errors: Array[String] = []
	_validate(errors)

	var ok := errors.is_empty()
	if ok:
		print("[BootValidator] OK  %d briefings, %d NPCs, %d topics, %d facts. All references resolve." % [
			BriefingRegistry.count(),
			NpcProfileRegistry.count(),
			TopicRegistry.count(),
			FactRegistry.count(),
		])
	else:
		printerr("[BootValidator] FAILED (%d errors)" % errors.size())
		for i in errors.size():
			printerr("  %2d. %s" % [i + 1, errors[i]])

	EventBus.boot_validated.emit(ok, errors.size())

	if Config.dump_dossiers:
		dump_dossiers()

	if Config.validate_only:
		get_tree().quit(0 if ok else 1)


func _validate(errors: Array[String]) -> void:
	# 1. Every dossier briefing-id resolves to a known briefing.
	for npc_id in NpcProfileRegistry.all_ids():
		var entries := NpcProfileRegistry.flatten_dossier(npc_id)
		for e in entries:
			var bid: String  = e.get("id", "")
			var tier: String = e.get("tier", "")
			if bid.is_empty():
				errors.append("NPC '%s': dossier entry missing id" % npc_id)
				continue
			if not BriefingRegistry.has_id(bid):
				errors.append("NPC '%s': references unknown briefing id '%s'" % [npc_id, bid])
				continue
			# Soft-warn (not error): tier mismatch is allowed by design --
			# an NPC can carry a briefing at a tier the briefing wasn't
			# authored at, in which case retrieval falls back to any
			# available tier. We surface this only when verbose.
			if not BriefingRegistry.has_briefing(bid, tier):
				print("[BootValidator] note: NPC '%s' dossier carries '%s' at tier '%s' but briefing only exists at: %s" % [
					npc_id, bid, tier, BriefingRegistry.tiers_for(bid),
				])

	# 2. Facts referenced in briefings exist.
	for briefing in BriefingRegistry.all_briefings():
		var bid: String  = briefing.get("id", "")
		var tier: String = briefing.get("tier", "")
		for fid in briefing.get("facts_unlocked_on_reveal", []):
			if not FactRegistry.has_fact(fid):
				errors.append("Briefing '%s' (%s): unknown fact id '%s'" % [bid, tier, fid])

	# 3. Topics referenced in briefings exist.
	for briefing in BriefingRegistry.all_briefings():
		var bid: String  = briefing.get("id", "")
		var tier: String = briefing.get("tier", "")
		for t in briefing.get("topic_tags", []):
			if not TopicRegistry.has_topic(t):
				errors.append("Briefing '%s' (%s): unknown topic '%s'" % [bid, tier, t])

	# 4. Briefings referenced by `contradicts` exist (when non-empty).
	for briefing in BriefingRegistry.all_briefings():
		var bid: String = briefing.get("id", "")
		for c in briefing.get("contradicts", []):
			if not BriefingRegistry.has_id(c):
				errors.append("Briefing '%s': contradicts unknown briefing id '%s'" % [bid, c])


## Print a flattened dossier per NPC. Useful as a debug command;
## Phase 10 will wire this into the debug overlay.
func dump_dossiers() -> void:
	for npc_id in NpcProfileRegistry.all_ids():
		var entries := NpcProfileRegistry.flatten_dossier(npc_id)
		print("--- %s ---" % npc_id)
		for e in entries:
			var flag := "  forbidden" if e.get("forbidden_to_share", false) else ""
			print("  [%s] %s : %s%s" % [e["category"], e["id"], e["tier"], flag])
