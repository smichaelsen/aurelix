extends Node
##
## Generates Kael's reply suggestions after an NPC line resolves.
##
## Sister to the NPC dialogue pipeline, but isolated: the prompt this code
## builds (via PlayerPromptBuilder) contains only Kael's own knowledge. The
## NPC's dossier, memory, and forbidden flags are never read here.
##
## Lifecycle:
##   - cancel(): drops the result of any in-flight call
##   - generate(...): kicks off a new call; previous in-flight is cancelled
##
## Returns Array of {intent, text}. 0..3 entries. Empty array means "no
## suggestions" — callers (DialogueController) should fall back to authored
## options in that case.
##
## Autoload as `PlayerSuggestionGenerator`.
##

const PlayerPromptBuilderScript = preload("res://scripts/ai/PlayerPromptBuilder.gd")

const VALID_INTENTS := ["strategic", "tactical", "dismissive"]
const MAX_SUGGESTIONS    := 3
const MAX_TEXT_CHARS     := 120
const INJECTION_PATTERNS := [
	"system prompt", "system message", "instructions:",
	"as an ai", "language model", "schema", "json",
]

signal suggestions_ready(token: int, npc_id: String, suggestions: Array)


var _next_token: int = 0
var _active_token: int = -1


## Cancel any in-flight call. The next callback to fire will be ignored.
func cancel() -> void:
	_active_token = -1


## Kick off a suggestion call. Returns a token; the matching
## `suggestions_ready` signal carries the same token. Callers should compare
## the token against the one they got back from this call before applying
## results, in case the conversation moved on.
func generate(
	npc_id: String,
	npc_display_name: String,
	npc_archetype: String,
	last_npc_line: String,
	last_turns: Array,
	topic_id: String,
	npc_just_dodged_topic: String = "",
) -> int:
	_next_token += 1
	var token := _next_token
	_active_token = token
	_run(token, npc_id, npc_display_name, npc_archetype, last_npc_line, last_turns,
		 topic_id, npc_just_dodged_topic)
	return token


func _run(
	token: int,
	npc_id: String,
	npc_display_name: String,
	npc_archetype: String,
	last_npc_line: String,
	last_turns: Array,
	topic_id: String,
	npc_just_dodged_topic: String,
) -> void:
	var request := PlayerPromptBuilderScript.build(
		npc_id, npc_display_name, npc_archetype, last_npc_line, last_turns,
		topic_id, npc_just_dodged_topic,
	)
	var raw: Dictionary = await AiService.suggest_player_options(request)
	if _active_token != token:
		# Conversation moved on (player picked / closed / new turn). Drop.
		return
	var validated := _validate(raw)
	suggestions_ready.emit(token, npc_id, validated)


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

# Light validation. Suggestions are player utterances — they never write
# canon, so the guard rail set is small:
#   - drop entries with unknown intents
#   - clip text length
#   - drop entries that leak prompt/schema/system terms
#   - dedupe by intent (keep first)
#   - cap at MAX_SUGGESTIONS
func _validate(raw: Dictionary) -> Array:
	var items: Array = raw.get("suggestions", [])
	if items == null:
		return []
	var seen_intents: Dictionary = {}
	var out: Array = []
	for item in items:
		if not (item is Dictionary):
			continue
		var intent: String = String(item.get("intent", "")).to_lower()
		if not (intent in VALID_INTENTS):
			continue
		if seen_intents.has(intent):
			continue
		var text: String = String(item.get("text", "")).strip_edges()
		if text.is_empty():
			continue
		if _looks_like_injection(text):
			push_warning("[PlayerSuggestionGenerator] dropped injection-like suggestion: %s" % text)
			continue
		if text.length() > MAX_TEXT_CHARS:
			text = text.substr(0, MAX_TEXT_CHARS).strip_edges()
		seen_intents[intent] = true
		out.append({"intent": intent, "text": text})
		if out.size() >= MAX_SUGGESTIONS:
			break
	return out


func _looks_like_injection(text: String) -> bool:
	var lower := text.to_lower()
	for pat in INJECTION_PATTERNS:
		if pat in lower:
			return true
	return false
