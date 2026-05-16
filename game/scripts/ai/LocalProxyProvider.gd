extends "res://scripts/ai/AiProvider.gd"
##
## Talks to the localhost FastAPI proxy. The proxy hides whether it's the
## Mock or Anthropic provider; this class doesn't know or care.
##
## Returns empty Dictionary on failure so AiService can fall back to the
## in-process MockProvider.
##

const DEFAULT_HOST    := "http://127.0.0.1:8421"
# Long enough to cover local Ollama cold-loads (first call after model swap
# can take 20-30s on M-series). Anthropic Haiku responses come back in 1-3s,
# so this only matters as a worst-case ceiling, not a per-turn wait.
const TIMEOUT_SECONDS := 60.0


var host: String = DEFAULT_HOST


func generate(request: Dictionary) -> Dictionary:
	var body := JSON.stringify(request)
	var result := await _http_post("%s/v1/generate" % host, body)
	if result.is_empty():
		return {}
	return result


func classify_topic(text: String, known_topics: Array) -> Dictionary:
	var body := JSON.stringify({
		"text": text,
		"known_topics": known_topics,
	})
	var result := await _http_post("%s/v1/classify_topic" % host, body)
	if result.is_empty():
		return {}
	return result


func suggest_player_options(request: Dictionary) -> Dictionary:
	var body := JSON.stringify(request)
	var result := await _http_post("%s/v1/suggest_player_options" % host, body)
	if result.is_empty():
		return {}
	return result


func health() -> bool:
	var result := await _http_get("%s/health" % host)
	return result.get("ok", false) == true


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

# Each call uses its own HTTPRequest node. A single shared node would let
# overlapping calls (e.g. classify_topic then generate, or two NPCs talking
# in tests) collide on `request_completed`, scrambling responses.
func _make_request() -> HTTPRequest:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SECONDS
	add_child(req)
	return req


func _http_get(url: String) -> Dictionary:
	var req := _make_request()
	var err := req.request(url)
	if err != OK:
		push_warning("[LocalProxyProvider] request err: %d" % err)
		req.queue_free()
		return {}
	var result = await req.request_completed
	req.queue_free()
	return _parse(result)


func _http_post(url: String, body: String) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var req := _make_request()
	var err := req.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		push_warning("[LocalProxyProvider] request err: %d" % err)
		req.queue_free()
		return {}
	var result = await req.request_completed
	req.queue_free()
	return _parse(result)


func _parse(result: Array) -> Dictionary:
	# result: [result_code, response_code, headers, body]
	var result_code: int = result[0]
	var response_code: int = result[1]
	var body: PackedByteArray = result[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		push_warning("[LocalProxyProvider] HTTP failed (result=%d)" % result_code)
		return {}
	if response_code < 200 or response_code >= 300:
		push_warning("[LocalProxyProvider] HTTP %d" % response_code)
		return {}
	var text := body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("[LocalProxyProvider] non-JSON response: %s" % text.substr(0, 200))
		return {}
	return parsed
