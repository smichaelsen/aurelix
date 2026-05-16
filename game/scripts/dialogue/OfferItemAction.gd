extends RefCounted
##
## Applies the Offer-item lever.
##
## When the player offers an item to an NPC during dialogue:
##   1. Look up items.yaml.on_offer[npc_id] for the chosen item.
##   2. If present, flip the named flag on the NPC's memory.
##   3. Record a memory_update for the prompt's recent_summary.
##   4. Consume the item from the inventory (unless on_offer says otherwise).
##
## Returns a small descriptor for DialogueController to fold into the next
## turn: { flag, memory_update, consumed, player_input }.
##

static func apply(item_id: String, npc_id: String) -> Dictionary:
	var item: Dictionary = ItemRegistry.get_item(item_id)
	var name: String = item.get("name", item_id)
	var desc: Dictionary = ItemRegistry.offer_descriptor(item_id, npc_id)

	var result := {
		"item_id":       item_id,
		"item_name":     name,
		"player_input":  "*offers %s*" % name,
		"flag":          "",
		"memory_update": "",
		"consumed":      true,
		"npc_reacted":   false,
		"topic":         "",
		# When non-empty, the dialogue controller fires this as an authored
		# beat (skipping the AI turn entirely) so the player sees the lever
		# land immediately. Shape: {dialogue: String, tone: String}.
		"acknowledgement": {},
	}

	if desc.is_empty():
		return result

	result["npc_reacted"] = true
	result["flag"]          = desc.get("flag", "")
	result["memory_update"] = desc.get("memory_update", "")
	result["consumed"]      = bool(desc.get("consume", true))
	result["acknowledgement"] = desc.get("acknowledgement", {})

	# When the offer adds a briefing to the NPC's dossier, pivot the
	# conversation onto that briefing's topic so the AI turn (and the
	# mock-response lookup) can address what was just shown.
	var add: Dictionary = desc.get("adds_briefing", {})
	if not add.is_empty():
		var briefing_id: String = add.get("id", "")
		var tier: String        = add.get("tier", "rumor")
		var briefing: Dictionary = BriefingRegistry.get_briefing(briefing_id, tier)
		if briefing.is_empty():
			var tiers := BriefingRegistry.tiers_for(briefing_id)
			if not tiers.is_empty():
				briefing = BriefingRegistry.get_briefing(briefing_id, tiers[0])
		var tags: Array = briefing.get("topic_tags", [])
		if not tags.is_empty():
			result["topic"] = String(tags[0])

	if not result["flag"].is_empty():
		NpcMemoryStore.set_flag(npc_id, result["flag"], true)
		print("[OfferItemAction] %s -> %s.flags.%s = true" % [item_id, npc_id, result["flag"]])

	if not result["memory_update"].is_empty():
		NpcMemoryStore.set_recent_summary(npc_id, result["memory_update"])

	if result["consumed"]:
		Inventory.remove(item_id, 1)

	EventBus.item_offered.emit(npc_id, item_id)
	return result
