extends Node
##
## Tracks which facts the player has learned. Facts are unlocked here
## (and only here). The model never grants facts directly; validated
## briefing reveals + engine world-events do.
##
## Autoload as `FactLedger`.
##

var _known: Dictionary = {}     # fact_id -> source dict


func has_fact(fact_id: String) -> bool:
	return _known.has(fact_id)


func known_facts() -> Array:
	return _known.keys()


func source_of(fact_id: String) -> Dictionary:
	return _known.get(fact_id, {})


## Grant a fact. `source` is a dict like {kind: "briefing_reveal", briefing_id: ..., npc_id: ...}
## or {kind: "world_event", event_id: ...}. Idempotent: granting a known fact is a no-op.
func grant_fact(fact_id: String, source: Dictionary) -> void:
	if not FactRegistry.has_fact(fact_id):
		push_warning("[FactLedger] grant of unknown fact id '%s'" % fact_id)
		return
	if _known.has(fact_id):
		return
	_known[fact_id] = source
	print("[FactLedger] +%s  (from %s)" % [fact_id, source])
	EventBus.fact_granted.emit(fact_id, source)


func reset() -> void:
	_known.clear()
