extends Node
##
## Owns the anger-cooldown lifecycle:
##
##   - When an NPC "angers out", DialogueController sets their
##     `anger_cooldown_turns` to COOLDOWN_TURNS. The NPC refuses to engage
##     for that many subsequent village interactions.
##
##   - Each new dialogue opened with a *different* NPC ticks every other
##     NPC's cooldown by 1.
##
##   - Offering an item whose `on_offer[npc_id].apology` is true clears the
##     cooldown immediately AND records a `forgave_player` flag.
##
## Autoload as `AngerCooldownResolver`. Listens to EventBus.
##

const COOLDOWN_TURNS := 3


func _ready() -> void:
	EventBus.dialogue_opened.connect(_on_dialogue_opened)
	EventBus.item_offered.connect(_on_item_offered)


func set_anger_cooldown(npc_id: String) -> void:
	var mem := NpcMemoryStore.memory_for(npc_id)
	mem["anger_cooldown_turns"] = COOLDOWN_TURNS


func _on_dialogue_opened(npc_id: String) -> void:
	# Tick every OTHER NPC's cooldown. When it falls to 0, also clear
	# their stress so the next conversation isn't an immediate re-anger.
	for other in NpcMemoryStore._by_id.keys():
		if other == npc_id:
			continue
		var mem: Dictionary = NpcMemoryStore._by_id[other]
		var t: int = int(mem.get("anger_cooldown_turns", 0))
		if t > 0:
			t -= 1
			mem["anger_cooldown_turns"] = t
			if t == 0:
				mem["stress"] = 0
				print("[AngerCooldown] %s cooled off; stress reset" % other)


func _on_item_offered(npc_id: String, item_id: String) -> void:
	var desc := ItemRegistry.offer_descriptor(item_id, npc_id)
	if not bool(desc.get("apology", false)):
		return
	var mem := NpcMemoryStore.memory_for(npc_id)
	if int(mem.get("anger_cooldown_turns", 0)) > 0:
		mem["anger_cooldown_turns"] = 0
		mem["stress"] = 0
		var flags: Dictionary = mem.get("flags", {})
		flags["forgave_player"] = true
		mem["flags"] = flags
		print("[AngerCooldown] %s forgave Kael (%s apology accepted)" % [npc_id, item_id])
