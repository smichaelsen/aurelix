extends Node
##
## Listens for fact_granted events and advances quest states when required
## facts have been collected. Phase 5 ships the `dragon_sighting` quest:
##
##   dragon_sighting:
##     not_started --(player accepts at Halden, see HaldenScript)--> active
##     active --(fact 'dragon_seen_near_old_tower' granted)--> complete
##
## Phase 7 will add forest-related quests; Phase 9 wires dossier mutations
## off the same fact_granted signal.
##
## Autoload as `QuestRuleEngine`.
##

const QUESTS := {
	"dragon_sighting": {
		"required_fact_for_completion": "dragon_seen_near_old_tower",
		"completes_from": "active",
	},
}


func _ready() -> void:
	EventBus.fact_granted.connect(_on_fact_granted)
	# Also re-evaluate when a quest changes state, so a fact granted *before*
	# the quest was active still lands the player at completion. Without this
	# the order "press Orren -> accept Halden" leaves the quest stuck at
	# active because the fact_granted signal already fired (and is idempotent).
	EventBus.quest_state_changed.connect(_on_quest_state_changed)


func _on_fact_granted(fact_id: String, _source: Dictionary) -> void:
	for quest_id in QUESTS.keys():
		var rule: Dictionary = QUESTS[quest_id]
		if rule.get("required_fact_for_completion", "") != fact_id:
			continue
		var current := QuestState.get_state(quest_id)
		if current == rule.get("completes_from", "active"):
			QuestState.set_state(quest_id, QuestState.STATE_COMPLETE)


func _on_quest_state_changed(quest_id: String, new_state: String) -> void:
	if not QUESTS.has(quest_id):
		return
	var rule: Dictionary = QUESTS[quest_id]
	if new_state != rule.get("completes_from", "active"):
		return
	var fact_id: String = rule.get("required_fact_for_completion", "")
	if fact_id.is_empty():
		return
	if FactLedger.has_fact(fact_id):
		# Defer one frame so we don't recurse into set_state while it's
		# still emitting the prior signal.
		call_deferred("_complete", quest_id)


func _complete(quest_id: String) -> void:
	QuestState.set_state(quest_id, QuestState.STATE_COMPLETE)
