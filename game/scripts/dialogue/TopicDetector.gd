extends Node
##
## Resolves a player input to a topic_id plus a guardrail category.
##
## Two paths:
##   - Authored option chosen: the option carries `topic_id`; nothing to do.
##     Authored options are designer-controlled and skip the classifier.
##   - Free text submitted: ask AiService.classify_topic against the topic
##     taxonomy. The classifier also tags the input with `category`:
##     "in_game" (normal flow), "out_of_context" (real-world references the
##     game can't answer), or "offensive" (grave slurs / explicit content).
##     The latter two short-circuit the generate call in DialogueController.
##
## Pure helper, not an autoload.
##


static func from_option(option: Dictionary) -> String:
	return option.get("topic_id", "small_talk")


## Returns {"topic_id": String, "category": String}. category is one of
## "in_game" / "out_of_context" / "offensive". topic_id is empty when
## category is not "in_game".
static func detect_free_text(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {"topic_id": "small_talk", "category": "in_game"}
	var known: Array = TopicRegistry.all_ids()
	var resp: Dictionary = await AiService.classify_topic(text, known)
	return {
		"topic_id": String(resp.get("topic_id", "small_talk")),
		"category": String(resp.get("category", "in_game")),
	}
