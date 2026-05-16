extends Node
##
## Opens / closes the journal panel and routes queries through AiService
## targeting Kael's `kael_self` profile.
##
## Hotkey: `journal_toggle` (J).
##
## Autoload as `JournalController`.
##

const PANEL_SCENE             := preload("res://scenes/ui/JournalPanel.tscn")
const PromptBuilderScript     = preload("res://scripts/ai/PromptBuilder.gd")
const ResponseValidatorScript = preload("res://scripts/dialogue/ResponseValidator.gd")
const TopicDetectorScript     = preload("res://scripts/dialogue/TopicDetector.gd")

var _panel: Node = null
var _open: bool = false
var _busy: bool = false
var _last_topic: String = "default"
var _last_turns: Array = []


func _ready() -> void:
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore the hotkey while dialogue or combat is up.
	if DialogueController.is_open():
		return
	if CombatController.is_active():
		return
	if event.is_action_pressed("journal_toggle"):
		toggle()


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	_ensure_panel()
	_open = true
	_last_topic = "default"
	_last_turns.clear()
	_panel.show_for(Journal.entries_by_category())
	_set_options("default")


func close() -> void:
	_open = false
	if _panel != null:
		_panel.hide_panel()


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _ensure_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		return
	_panel = PANEL_SCENE.instantiate()
	add_child(_panel)
	_panel.option_chosen.connect(_on_option_chosen)
	_panel.text_submitted.connect(_on_text_submitted)
	_panel.closed.connect(close)


func _on_option_chosen(option: Dictionary) -> void:
	if _busy:
		return
	var topic: String = option.get("topic_id", "small_talk")
	if topic == "__close":
		close()
		return
	# Special non-AI topics: switching authored option banks.
	if topic in ["default", "the_tower", "gold_eyed_one", "the_drake", "the_kingdom"]:
		_last_topic = topic
		_set_options(topic)
		# Also fire an AI summary unless the user just navigated.
		if option.get("label", "").begins_with("Back") or option.get("label", "").begins_with("Close"):
			return
		_run_query(option.get("label", ""), topic)
		return
	# Default: treat as an AI query.
	_run_query(option.get("label", ""), topic)


func _on_text_submitted(text: String) -> void:
	if _busy:
		return
	if text.strip_edges().is_empty():
		return
	var topic: String = await TopicDetectorScript.detect_free_text(text)
	_last_topic = topic
	_run_query(text, topic)


func _run_query(player_input: String, topic: String) -> void:
	_busy = true
	_panel.set_pending()

	# Capability gate: pass "allowed" -- Kael isn't dodging himself.
	var gate := {
		"decision":      "allowed",
		"reason":        "",
		"failure_style": "",
		"reveal_ready":  false,
	}

	var request := PromptBuilderScript.build(
		"kael_self", player_input, "ask", topic,
		"Kael is alone with his journal. He answers honestly to himself.",
		"",
		_last_turns.duplicate(),
		gate,
	)
	var raw: Dictionary = await AiService.generate(request)
	var v: Dictionary = ResponseValidatorScript.validate(raw, "kael_self", false)
	var response: Dictionary = v["response"]
	var line: String = response.get("dialogue", "...")
	_last_turns.append({"role": "player", "text": player_input})
	_last_turns.append({"role": "npc",    "text": line})
	# Keep last six turns only.
	while _last_turns.size() > 6:
		_last_turns.pop_front()

	_panel.set_answer(line)
	# After a query, surface the same topic's authored follow-ups.
	_set_options(_last_topic)
	_busy = false


func _set_options(topic: String) -> void:
	var opts: Array = AuthoredOptionLibrary.options_for("kael_self", topic)
	if opts.is_empty():
		opts = AuthoredOptionLibrary.options_for("kael_self", "default")
	_panel.set_options(opts)
