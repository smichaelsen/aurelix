extends RefCounted
##
## Templated dialogue handler for Reeve Halden.
##
## DialogueController routes Halden here (because his profile says
## `dialogue_mode: templated`). Halden does not consult AiService; his
## lines come from authored templated_lines + quest state.
##
## Returns a dict with the same shape DialogueController expects from the
## AI pipeline so the UI rendering layer doesn't branch.
##

const HALDEN_ID := "halden_reeve"
const QUEST     := "dragon_sighting"


## Pick the line + options for a fresh turn.
## Returns { "dialogue", "tone", "topic_addressed", "options" }.
static func start_turn() -> Dictionary:
	var state := QuestState.get_state(QUEST)
	match state:
		QuestState.STATE_NOT_STARTED:
			return _frame("not_started_brief", "not_started", "official")
		QuestState.STATE_ACTIVE:
			return _frame("active_progress", "active", "official")
		QuestState.STATE_COMPLETE:
			# Kael has come back to claim the reward. Fire once.
			EventBus.quest_paid.emit(QUEST)
			return _frame("complete_turn_in", "complete", "warm")
	return _frame("not_started_brief", "not_started", "official")


## Apply the side-effect of a chosen option (if any), and return the next
## turn's content. If the option closes the conversation, returns an
## empty dict.
static func apply_option(option: Dictionary) -> Dictionary:
	var action: String = option.get("action", "")
	var topic: String  = option.get("topic_id", "")
	if topic == "__close":
		return {}
	match action:
		"accept_quest":
			QuestState.set_state(QUEST, QuestState.STATE_ACTIVE)
			return _frame("active_progress", "active", "official")
		"tell_more":
			var state := QuestState.get_state(QUEST)
			if state == QuestState.STATE_NOT_STARTED:
				return _frame("not_started_more", "not_started", "official")
			return _frame("active_more", "active", "official")
	# fall through: just play the current state's line again
	return start_turn()


static func _frame(line_id: String, options_key: String, tone: String) -> Dictionary:
	var line := AuthoredOptionLibrary.templated_line(HALDEN_ID, line_id).strip_edges()
	var bank: Array = AuthoredOptionLibrary.options_for(HALDEN_ID, options_key)
	return {
		"dialogue":       line,
		"tone":           tone,
		"topic_addressed": "quest_status",
		"options":        bank,
		"templated":      true,
	}
