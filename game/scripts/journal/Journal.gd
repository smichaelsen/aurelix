extends Node
##
## Kael's accrued knowledge. Same data shape as an NPC dossier; events
## populate it as Kael learns / does things.
##
##   - notice board read       -> "marlow_hollow" full
##   - dragon fact granted     -> "tower_smoke" rumor (he heard it from Orren)
##   - bandit note recovered   -> "bandit_note" full + "gold_eyed_one" rumor
##   - Drust defeated          -> "bandits_defeated" witness
##   - Iskar bonded            -> "iskar_rescued" witness + "iskar_drake" full
##   - strange coin recognised -> "strange_coin" full
##
## Autoload as `Journal`.
##

## Starting dossier entries: things Kael already knows when the game begins.
const STARTING_ENTRIES := [
	{"id": "kael_self",        "tier": "full"},
	{"id": "kingdom_overview", "tier": "full"},
	{"id": "marlow_hollow",    "tier": "full"},
]

## Fact -> list of briefings to grant when that fact lands.
const FACT_TO_BRIEFINGS := {
	"notice_board_read": [
		{"id": "marlow_hollow",    "tier": "full"},
	],
	"dragon_seen_near_old_tower": [
		{"id": "tower_smoke",      "tier": "rumor"},
	],
	"bandit_note_recovered": [
		{"id": "bandit_note",      "tier": "full"},
		{"id": "gold_eyed_one",    "tier": "rumor"},
	],
	"drust_dead": [
		{"id": "bandits_defeated", "tier": "witness"},
		{"id": "bandit_camp",      "tier": "full"},
		{"id": "drust_bandit",     "tier": "full"},
	],
	"iskar_bonded": [
		{"id": "iskar_rescued",    "tier": "witness"},
		{"id": "iskar_drake",      "tier": "full"},
	],
	"iskar_named": [
		{"id": "bone_tag",         "tier": "full"},
	],
	"strange_coin_recovered": [
		{"id": "strange_coin",     "tier": "full"},
	],
	"mara_recognized_coin": [
		{"id": "gold_eyed_one",    "tier": "rumor"},
	],
	"smoke_seen_near_old_tower": [
		{"id": "tower_smoke",      "tier": "rumor"},
	],
}


var _entries: Array = []         # ordered list of {id, tier, source}
var _seen: Dictionary = {}       # "id|tier" -> true


func _ready() -> void:
	EventBus.fact_granted.connect(_on_fact_granted)
	# DataLoader populates registries in its own _ready (autoload order).
	# We defer the starting-entry add by one frame so BriefingRegistry is
	# guaranteed loaded.
	call_deferred("_seed_starting_entries")


func _seed_starting_entries() -> void:
	for e in STARTING_ENTRIES:
		add_briefing(e["id"], e["tier"], {"kind": "world_start"})


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func add_briefing(id: String, tier: String, source: Dictionary) -> void:
	# Snap to whatever tier actually exists if requested tier is missing.
	if not BriefingRegistry.has_briefing(id, tier):
		var tiers := BriefingRegistry.tiers_for(id)
		if tiers.is_empty():
			push_warning("[Journal] no briefing for id '%s'" % id)
			return
		tier = tiers[0]
	var key := _key(id, tier)
	if _seen.has(key):
		return
	_seen[key] = true
	_entries.append({"id": id, "tier": tier, "source": source})
	print("[Journal] +%s (%s)" % [id, tier])
	EventBus.journal_briefing_added.emit(id, tier)


func has_briefing(id: String, tier: String) -> bool:
	return _seen.has(_key(id, tier))


func has_id(id: String) -> bool:
	for entry in _entries:
		if entry["id"] == id:
			return true
	return false


func entries() -> Array:
	return _entries.duplicate(true)


func count() -> int:
	return _entries.size()


## Flattened dossier shaped exactly like an NPC's `flatten_dossier()` output,
## so PromptBuilder + Retriever can target Kael with no special-casing.
func flatten_dossier() -> Array:
	var out: Array = []
	for e in _entries:
		out.append({
			"id":   e["id"],
			"tier": e["tier"],
			"category": _category_for(e["id"], e["tier"]),
			"forbidden_to_share": false,
		})
	return out


func entries_by_category() -> Dictionary:
	var out: Dictionary = {
		"people":    [], "locations": [], "events":   [],
		"items":     [], "factions":  [], "world":    [],
	}
	for e in _entries:
		var cat: String = _category_for(e["id"], e["tier"])
		var bucket: String = cat
		match cat:
			"location": bucket = "locations"
			"person":   bucket = "people"
			"event":    bucket = "events"
			"item":     bucket = "items"
			"faction":  bucket = "factions"
			_:          bucket = "world"
		out[bucket].append(e)
	return out


func reset() -> void:
	_entries.clear()
	_seen.clear()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_fact_granted(fact_id: String, _source: Dictionary) -> void:
	if not FACT_TO_BRIEFINGS.has(fact_id):
		return
	for b in FACT_TO_BRIEFINGS[fact_id]:
		add_briefing(b["id"], b["tier"], {"kind": "fact", "fact": fact_id})


func _category_for(id: String, tier: String) -> String:
	var br := BriefingRegistry.get_briefing(id, tier)
	if br.is_empty():
		var tiers := BriefingRegistry.tiers_for(id)
		if not tiers.is_empty():
			br = BriefingRegistry.get_briefing(id, tiers[0])
	return br.get("type", "world")


func _key(id: String, tier: String) -> String:
	return id + "|" + tier
