extends Node
##
## Returns whether the engine is in a state safe to serialise.
## Concept rule: save anywhere *outside* combat; do not save during an
## in-flight LLM request (between turns is fine).
##
## Autoload as `SaveBlocker`. Depends on CombatController + DialogueController
## + JournalController.
##

var _last_reason: String = ""


func can_save() -> bool:
	_last_reason = ""
	if CombatController.is_active():
		_last_reason = "in combat"
		return false
	if DialogueController.is_open() and bool(DialogueController.get("_busy")):
		_last_reason = "dialog turn in flight"
		return false
	if JournalController.is_open() and bool(JournalController.get("_busy")):
		_last_reason = "journal turn in flight"
		return false
	return true


func reason() -> String:
	return _last_reason
