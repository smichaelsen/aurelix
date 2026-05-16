extends Node
##
## Resolves a player input to a topic_id.
##
## Two paths:
##   - Authored option chosen: the option carries `topic_id`; nothing to do.
##   - Free text submitted: ask AiService.classify_topic against the topic
##     taxonomy.
##
## Pure helper, not an autoload.
##


static func from_option(option: Dictionary) -> String:
	return option.get("topic_id", "small_talk")


static func detect_free_text(text: String) -> String:
	if text.strip_edges().is_empty():
		return "small_talk"
	var known: Array = TopicRegistry.all_ids()
	var resp: Dictionary = await AiService.classify_topic(text, known)
	return resp.get("topic_id", "small_talk")
