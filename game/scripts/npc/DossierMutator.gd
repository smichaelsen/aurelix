extends Node
##
## Central dispatcher that mutates NPC dossiers in response to engine events:
##
##   - item_offered(npc_id, item_id):
##       look up items.json[item_id].on_offer[npc_id].adds_briefing
##       add (briefing_id, tier) to that NPC's dossier
##
##   - iskar_entered_location(location_id):
##       for every NPC whose `location` matches, add kael_has_drake (witness)
##       Edda specifically gets it witness + forbidden_to_share=true
##
##   - fact_granted(fact_id) world-state propagation:
##       drust_dead             -> village NPCs Mara, Halden gain
##                                 bandits_defeated (rumor)
##
## Autoload as `DossierMutator`.
##

const VILLAGE_NPC_IDS := [
	"mara_blacksmith", "orren_drunk", "edda_priest",
	"halden_reeve",    "toma_child",
]


func _ready() -> void:
	EventBus.item_offered.connect(_on_item_offered)
	EventBus.iskar_entered_location.connect(_on_iskar_entered_location)
	EventBus.fact_granted.connect(_on_fact_granted)


# ---------------------------------------------------------------------------
# Item offered
# ---------------------------------------------------------------------------

func _on_item_offered(npc_id: String, item_id: String) -> void:
	var desc: Dictionary = ItemRegistry.offer_descriptor(item_id, npc_id)
	if desc.is_empty():
		return
	var add: Dictionary = desc.get("adds_briefing", {})
	if add.is_empty():
		return
	var briefing_id: String = add.get("id", "")
	var tier: String = add.get("tier", "rumor")
	if briefing_id.is_empty():
		return
	var opts := {}
	if add.has("forbidden_to_share"):
		opts["forbidden_to_share"] = bool(add["forbidden_to_share"])
	NpcDossierStore.add(npc_id, briefing_id, tier, opts)


# ---------------------------------------------------------------------------
# Iskar visible in a scene
# ---------------------------------------------------------------------------

func _on_iskar_entered_location(location_id: String) -> void:
	var npcs: Array = _npcs_at_location(location_id)
	for npc_id in npcs:
		var forbidden: bool = (npc_id == "edda_priest")
		NpcDossierStore.add(
			npc_id, "kael_has_drake", "witness",
			{"forbidden_to_share": forbidden},
		)


func _npcs_at_location(location_id: String) -> Array:
	# Most villager NPC profiles have location strings rooted in a region
	# (e.g. "tavern_interior", "smithy_interior", "village_square"). For
	# Phase 9 demo, treat all village NPCs as "in the village" since the
	# village_square is the only village scene.
	if location_id == "village_square":
		var found: Array = []
		for npc_id in VILLAGE_NPC_IDS:
			if NpcProfileRegistry.has_profile(npc_id):
				found.append(npc_id)
		return found
	return []


# ---------------------------------------------------------------------------
# Facts that ripple to villager dossiers
# ---------------------------------------------------------------------------

func _on_fact_granted(fact_id: String, _source: Dictionary) -> void:
	match fact_id:
		"drust_dead":
			# Village hears about the cleared bandit camp as rumor.
			for npc_id in ["mara_blacksmith", "halden_reeve"]:
				if NpcProfileRegistry.has_profile(npc_id):
					NpcDossierStore.add(npc_id, "bandits_defeated", "rumor")
		"bandits_present_in_marlow_region":
			# Already known to most villagers in the seed dossier; no-op.
			pass
