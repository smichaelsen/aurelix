extends Node
##
## Picks the briefings to inject into the prompt for a given NPC + topic.
## Replaces Phase 4's "send everything." Always includes universals as
## digests; pulls topic-matching briefings (witness first), preserves the
## NPC's `forbidden_to_share` flag.
##
## Pure helper, not an autoload.
##

const _UNIVERSAL_CATEGORIES := {
	"universal": true,
}
const _BUDGET_CHARS := 4000   # generous; trim if a prompt gets too big


static func retrieve(npc_id: String, topic_id: String) -> Array:
	var out: Array = []
	var entries := NpcProfileRegistry.flatten_dossier(npc_id)
	var seen: Dictionary = {}

	# 1. Universals first (digest tier, low priority).
	for e in entries:
		if not _UNIVERSAL_CATEGORIES.has(e.get("category", "")):
			continue
		var b := _resolve_briefing(e)
		if b.is_empty():
			continue
		out.append(_slice(b, e))
		seen[b.get("id", "")] = true

	# 2. Topic-tagged briefings, witness tier preferred.
	var topic_matches := []
	for e in entries:
		if _UNIVERSAL_CATEGORIES.has(e.get("category", "")):
			continue
		var b := _resolve_briefing(e)
		if b.is_empty():
			continue
		if topic_id in b.get("topic_tags", []):
			topic_matches.append({"e": e, "b": b})

	# Witness first, then rumor/full/etc.
	topic_matches.sort_custom(_witness_first)
	for item in topic_matches:
		var b: Dictionary = item.b
		var id: String = b.get("id", "")
		if seen.has(id):
			continue
		out.append(_slice(b, item.e))
		seen[id] = true

	return _trim_to_budget(out, _BUDGET_CHARS)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _resolve_briefing(dossier_entry: Dictionary) -> Dictionary:
	var bid: String = dossier_entry.get("id", "")
	var tier: String = dossier_entry.get("tier", "")
	var br := BriefingRegistry.get_briefing(bid, tier)
	if not br.is_empty():
		return br
	var tiers := BriefingRegistry.tiers_for(bid)
	if tiers.is_empty():
		return {}
	return BriefingRegistry.get_briefing(bid, tiers[0])


static func _slice(briefing: Dictionary, dossier_entry: Dictionary) -> Dictionary:
	return {
		"id":   briefing.get("id", ""),
		"tier": briefing.get("tier", ""),
		"body": briefing.get("body", ""),
		"forbidden_to_share": dossier_entry.get("forbidden_to_share", false),
		# reveal_note is authored on the dossier entry, not the briefing
		# itself: the condition is how THIS NPC guards the secret, not
		# the secret's content. Empty string when not authored.
		"reveal_note": String(dossier_entry.get("reveal_note", "")),
	}


static func _witness_first(a: Dictionary, b: Dictionary) -> bool:
	var ta: String = a.b.get("tier", "")
	var tb: String = b.b.get("tier", "")
	return _tier_rank(ta) > _tier_rank(tb)


static func _tier_rank(tier: String) -> int:
	match tier:
		"witness": return 4
		"full":    return 3
		"rumor":   return 2
		"digest":  return 1
		_:         return 0


static func _trim_to_budget(items: Array, char_budget: int) -> Array:
	var total := 0
	var out: Array = []
	for it in items:
		var size: int = String(it.get("body", "")).length()
		if total + size > char_budget and not out.is_empty():
			break
		out.append(it)
		total += size
	return out
