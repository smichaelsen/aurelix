extends Node
##
## Per-NPC mutable dossier. Seeded from `data/npc/<id>.yaml`'s static
## dossier on first access; thereafter mutations (item shows, witnessed
## events, faction propagation) are applied through this store.
##
## Retrieval reads from here, NOT directly from NpcProfileRegistry, so
## dossier_for(npc_id) always reflects the live world.
##
## Autoload as `NpcDossierStore`.
##

var _by_id: Dictionary = {}    # npc_id -> Array of {id, tier, forbidden_to_share, category, reveal_note, public_tell}


func dossier_for(npc_id: String) -> Array:
	if not _by_id.has(npc_id):
		_seed(npc_id)
	return _by_id[npc_id]


func add(npc_id: String, briefing_id: String, tier: String, opts: Dictionary = {}) -> void:
	var entries: Array = dossier_for(npc_id)
	# De-dupe by briefing_id. If the briefing already exists, raise its
	# tier if the new tier is "stronger" (witness > rumor > digest).
	for e in entries:
		if e.get("id", "") == briefing_id:
			if _tier_rank(tier) > _tier_rank(e.get("tier", "")):
				e["tier"] = tier
			if opts.has("forbidden_to_share"):
				e["forbidden_to_share"] = bool(opts["forbidden_to_share"])
			return
	var entry := {
		"id":                 briefing_id,
		"tier":               tier,
		"forbidden_to_share": bool(opts.get("forbidden_to_share", false)),
		"category":           opts.get("category", "events"),
	}
	entries.append(entry)
	print("[NpcDossierStore] %s += %s (%s)%s" % [
		npc_id, briefing_id, tier,
		" forbidden" if entry["forbidden_to_share"] else "",
	])
	EventBus.npc_dossier_mutated.emit(npc_id, briefing_id, tier)


func has(npc_id: String, briefing_id: String) -> bool:
	for e in dossier_for(npc_id):
		if e.get("id", "") == briefing_id:
			return true
	return false


func reset() -> void:
	_by_id.clear()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _seed(npc_id: String) -> void:
	var profile := NpcProfileRegistry.get_profile(npc_id)
	var out: Array = []
	var dossier: Dictionary = profile.get("dossier", {})
	for category in dossier.keys():
		var entries = dossier[category]
		if not (entries is Array):
			continue
		for e in entries:
			if not (e is Dictionary):
				continue
			out.append({
				"id":                 e.get("id", ""),
				"tier":               e.get("tier", ""),
				"forbidden_to_share": e.get("forbidden_to_share", false),
				"category":           category,
				# reveal_note: in-fiction condition the NPC uses to gate
				# sharing. Empty when unauthored. Read by Retriever (NPC
				# prompt) and by ResponseValidator (soft-reveal path).
				"reveal_note":        String(e.get("reveal_note", "")),
				# public_tell: Kael-visible body-language cue. Only the
				# narrow public_tells_for() accessor on NpcProfileRegistry
				# exposes this to the suggestion side; keeps the strict
				# Kael / NPC context isolation intact.
				"public_tell":        String(e.get("public_tell", "")),
			})
	_by_id[npc_id] = out


func _tier_rank(tier: String) -> int:
	match tier:
		"witness": return 4
		"full":    return 3
		"rumor":   return 2
		"digest":  return 1
		_:         return 0
