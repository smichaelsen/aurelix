extends Node
##
## Single entry point the rest of the game uses to talk to "the AI."
##
## - When Config.use_mock_ai is true, the in-process MockProvider is used
##   directly. Proxy is ignored entirely. Game runs offline.
## - When Config.use_mock_ai is false, calls go through LocalProxyProvider
##   (HTTP to localhost). If the proxy fails (down, timeout, bad response),
##   the call automatically falls back to the in-process Mock so the demo
##   never stalls.
##
## Autoload as `AiService` (Phase 2 wires this; see project.godot).
##

const MockProviderScript  = preload("res://scripts/ai/MockProvider.gd")
const LocalProxyScript    = preload("res://scripts/ai/LocalProxyProvider.gd")
const MAX_CONSECUTIVE_FAILURES := 2


var _mock: Node
var _proxy: Node
var _failures: Dictionary = {}     # npc_id -> int


func _ready() -> void:
	_mock = MockProviderScript.new()
	add_child(_mock)
	_proxy = LocalProxyScript.new()
	add_child(_proxy)


## Run a single NPC dialogue turn. Returns the response dict; on every kind
## of failure, returns a canned response so callers never need to handle
## empty results.
func generate(request: Dictionary) -> Dictionary:
	# DebugOverlay can force the authored fallback bank regardless of mode,
	# so QA can verify the canned content without unplugging the network.
	if FallbackProvider.force_active:
		return FallbackProvider.generate(
			request.get("npc_id", ""),
			request.get("topic_addressed", ""),
			request.get("npc_profile", {}),
		)

	var npc_id: String = request.get("npc_id", "")
	if Config.use_mock_ai:
		_failures[npc_id] = 0
		return _mock.generate(request)

	var response: Dictionary = await _proxy.generate(request)
	if not response.is_empty():
		_failures[npc_id] = 0
		return response

	# Proxy or network failed. Count it. After enough consecutive failures,
	# route this NPC to the authored fallback bank; until then, the mock is
	# a soft fallback that keeps the demo flowing.
	var fails: int = int(_failures.get(npc_id, 0)) + 1
	_failures[npc_id] = fails
	if fails >= MAX_CONSECUTIVE_FAILURES:
		push_warning("[AiService] %s: %d consecutive failures, using FallbackProvider" % [
			npc_id, fails,
		])
		return FallbackProvider.generate(
			npc_id,
			request.get("topic_addressed", ""),
			request.get("npc_profile", {}),
		)
	push_warning("[AiService] proxy generate failed; falling back to mock")
	return _mock.generate(request)


func note_validation_failure(npc_id: String) -> void:
	var fails: int = int(_failures.get(npc_id, 0)) + 1
	_failures[npc_id] = fails


func clear_failures_for(npc_id: String) -> void:
	_failures[npc_id] = 0


## Generate Kael's reply suggestions for the current dialogue turn.
##
## Returns {"suggestions": [{intent, text}, ...]}. Empty list means the
## caller should fall back to authored options.
##
## Unlike `generate`, there is no FallbackProvider for suggestions: the
## authored option bank is itself the "fallback" surface, and is owned by
## DialogueController (which decides whether to display authored vs. AI
## suggestions based on the per-topic `player_options_source` flag).
func suggest_player_options(request: Dictionary) -> Dictionary:
	if Config.use_mock_ai:
		return _mock.suggest_player_options(request)
	var response: Dictionary = await _proxy.suggest_player_options(request)
	if not response.is_empty():
		return response
	push_warning("[AiService] proxy suggest failed; falling back to mock")
	return _mock.suggest_player_options(request)


## Classify free-text into a topic id from `known_topics`.
func classify_topic(text: String, known_topics: Array = []) -> Dictionary:
	if Config.use_mock_ai:
		return _mock.classify_topic(text, known_topics)

	var response: Dictionary = await _proxy.classify_topic(text, known_topics)
	if not response.is_empty():
		return response

	push_warning("[AiService] proxy classify_topic failed; falling back to mock")
	return _mock.classify_topic(text, known_topics)
