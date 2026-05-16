extends Node
##
## Orchestrates a single conversation lifecycle.
##
## Phase 5 full pipeline:
##
##   option/free text
##     -> TopicDetector (option topic OR LLM classify)
##     -> StateModifierResolver (resolve flags into effective values)
##     -> CapabilityGate (allowed | blocked | constrained, reveal_ready)
##     -> Retriever (topic-scoped briefings)
##     -> PromptBuilder (assemble request)
##     -> AiService.generate
##     -> ResponseValidator (sanitise, grant facts via FactLedger)
##     -> NpcMemory + PressTracker + PatienceCounter update
##     -> render dialogue + refreshed options (Press surfaces if dodged)
##
## Autoload as `DialogueController`.
##

const DIALOGUE_BOX_SCENE       := preload("res://scenes/ui/DialogueBox.tscn")
const TopicDetectorScript      = preload("res://scripts/dialogue/TopicDetector.gd")
const ResponseValidatorScript  = preload("res://scripts/dialogue/ResponseValidator.gd")
const PromptBuilderScript      = preload("res://scripts/ai/PromptBuilder.gd")
const CapabilityGateScript     = preload("res://scripts/ai/CapabilityGate.gd")
const StateModifierScript      = preload("res://scripts/dialogue/StateModifierResolver.gd")
const ScenePresenceScript      = preload("res://scripts/dialogue/ScenePresence.gd")
const DialogueSessionScript    = preload("res://scripts/dialogue/DialogueSession.gd")
const HaldenScript             = preload("res://scripts/npc/HaldenScript.gd")
const OfferItemScript          = preload("res://scripts/dialogue/OfferItemAction.gd")

const PRESS_DODGE_FALLBACKS := {
	"drunk":          "Don't ask again.",
	"village_child":  "I dunno. Go away.",
	"blacksmith":     "Leave it.",
	"priest":         "Please. Not that.",
	"guard_authority":"Watch your tone.",
	"_default":       "Hmph.",
}

const ANGER_OUT_LINES := {
	"drunk":          "Go bother somebody else.",
	"village_child":  "I'm telling my mother!",
	"blacksmith":     "Out. Now.",
	"priest":         "Peace go with you. Quickly.",
	"guard_authority":"Move along, stranger.",
	"_default":       "We're done.",
}

## When an NPC angers out, AngerCooldownResolver sets a per-NPC cooldown
## (default 3 village interactions). An apology-item offer clears it.


## If `_busy` stays true longer than this (e.g. provider await hangs, runtime
## error mid-turn), the watchdog logs and force-clears it so SaveBlocker and
## the input guards don't lock the player out permanently.
const _BUSY_WATCHDOG_SECONDS := 30.0

var _box: Node = null
var _session: RefCounted = null
var _busy: bool = false
# Bumped on every begin/end. A watchdog only fires if the generation it
# captured at arm-time is still current — so legitimate completions
# invalidate their own watchdog without needing to cancel a timer.
var _busy_gen: int = 0


func _ready() -> void:
	EventBus.dialogue_requested.connect(_on_dialogue_requested)


func is_open() -> bool:
	return _session != null


func _on_dialogue_requested(npc_id: String) -> void:
	if _busy or _session != null:
		return
	_open(npc_id)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ensure_box() -> void:
	if _box != null and is_instance_valid(_box):
		return
	_box = DIALOGUE_BOX_SCENE.instantiate()
	add_child(_box)
	_box.option_chosen.connect(_on_option_chosen)
	_box.text_submitted.connect(_on_text_submitted)
	_box.item_offered.connect(_on_item_offered)
	_box.closed.connect(_on_box_closed)


func _open(npc_id: String) -> void:
	_ensure_box()
	_session = DialogueSessionScript.new(npc_id)
	var profile := NpcProfileRegistry.get_profile(npc_id)

	# Patience + stress reset at the start of each conversation (per
	# design comment in NpcMemoryStore). Baseline from
	# profile.memory_defaults; ale, fed, etc. add patience_bonus via
	# state modifiers. Anger cooldown enforces the cross-session throttle.
	var defaults: Dictionary = profile.get("memory_defaults", {})
	var resolved_now := StateModifierScript.resolve(
		profile, _session.npc_memory.get("flags", {})
	)
	_session.npc_memory["patience"] = (
		int(defaults.get("patience", 10))
		+ int(resolved_now.get("patience_bonus", 0))
	)
	_session.npc_memory["stress"] = int(defaults.get("stress", 0))

	# Anger cooldown: NPC refuses to engage.
	if int(_session.npc_memory.get("anger_cooldown_turns", 0)) > 0:
		_box.show_for(profile.get("display_name", npc_id), profile.get("archetype", ""))
		_box.set_dialogue(_anger_out_line(profile.get("archetype", "")), "cold")
		_box.set_options([{"label": "Leave.", "topic_id": "__close"}])
		_apply_face_each_other(npc_id)
		EventBus.dialogue_opened.emit(npc_id)
		return

	var display_name: String = profile.get("display_name", npc_id)
	var archetype: String = profile.get("archetype", "")
	_box.show_for(display_name, archetype)
	_apply_face_each_other(npc_id)
	EventBus.dialogue_opened.emit(npc_id)

	var mode: String = profile.get("dialogue_mode", "full_ai")
	if mode == "templated" and npc_id == HaldenScript.HALDEN_ID:
		_render_templated(HaldenScript.start_turn())
		return

	_box.set_dialogue(_archetype_greeting(profile), "neutral")
	_set_options(npc_id, "default")


func _on_box_closed() -> void:
	if _session != null:
		EventBus.dialogue_closed.emit()
	_session = null
	if _box != null:
		_box.hide_box()


# Rotate Kael and the NPC to face each other. Both keep this facing after
# the dialogue closes — a conversation just happened, they're not snapping
# back to wherever they were looking before. Dominant-axis collapse; ties
# favour horizontal (one shared rule across follower + dialogue).
func _apply_face_each_other(npc_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player_grid")
	if player == null or not ("grid_pos" in player) or not ("facing" in player):
		return
	if not WorldState.npc_locations.has(npc_id):
		return
	var kael_pos: Vector2i = player.grid_pos
	var npc_pos:  Vector2i = WorldState.npc_locations[npc_id]
	var to_npc:  String = _cardinal(npc_pos - kael_pos)
	var to_kael: String = _cardinal(kael_pos - npc_pos)
	if to_npc != "" and player.has_method("_set_facing"):
		player._set_facing(to_npc)
	if to_kael != "":
		WorldState.set_npc_facing(npc_id, to_kael)


func _cardinal(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return ""
	if abs(delta.x) >= abs(delta.y):
		return "east" if delta.x > 0 else "west"
	return "south" if delta.y > 0 else "north"


# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_option_chosen(option: Dictionary) -> void:
	if _session == null or _busy:
		return
	var topic: String = option.get("topic_id", "small_talk")
	var verb: String = option.get("verb", "ask")
	var action: String = option.get("action", "")
	var press_angle: String = option.get("press_angle", "")

	if topic == "__close":
		_on_box_closed()
		return

	if _session.npc_id == HaldenScript.HALDEN_ID:
		var turn := HaldenScript.apply_option(option)
		if turn.is_empty():
			_on_box_closed()
		else:
			_render_templated(turn)
		return

	if action == "open_shop":
		print("[DialogueController] Mara's shop placeholder (Phase 6)")
		_on_box_closed()
		return

	var label: String = option.get("label", "")
	_session.record_player(label)
	_session.last_topic = topic
	await _run_ai_turn(label, verb, topic, press_angle)


func _on_item_offered(item_id: String) -> void:
	if _session == null or _busy:
		return
	if _session.npc_id == HaldenScript.HALDEN_ID:
		_box.set_dialogue("I'm not for sale, stranger.", "official")
		return
	# Apply the lever first; this may flip a flag on the NPC's memory.
	var result := OfferItemScript.apply(item_id, _session.npc_id)
	# Use a synthesised player_input describing the offer.
	_session.record_player(result.get("player_input", "*offers an item*"))
	# If the offer added a briefing to the NPC's dossier, pivot the
	# topic to that briefing so the response can speak to it.
	var topic: String = result.get("topic", "")
	if topic.is_empty():
		topic = _session.last_topic if not _session.last_topic.is_empty() else "default"
	_session.last_topic = topic
	await _run_ai_turn(result.get("player_input", "*offers an item*"), "offer_item", topic, "")


func _on_text_submitted(text: String) -> void:
	if _session == null or _busy:
		return
	if text.strip_edges().is_empty():
		return
	if _session.npc_id == HaldenScript.HALDEN_ID:
		_box.set_dialogue("Speak plainly, stranger.", "official")
		return
	var topic: String = await TopicDetectorScript.detect_free_text(text)
	_session.record_player(text)
	_session.last_topic = topic
	print("[DialogueController] free text classified -> %s" % topic)
	await _run_ai_turn(text, "ask", topic, "")


# ---------------------------------------------------------------------------
# AI turn pipeline
# ---------------------------------------------------------------------------

func _run_ai_turn(player_input: String, verb: String, topic: String, press_angle: String) -> void:
	# Single _busy lifecycle owner. The body has multiple early-return
	# paths and a long await chain; routing through this wrapper means a
	# runtime error or hung provider await never leaves _busy stuck true
	# (which would brick SaveBlocker and every input guard).
	_begin_busy_turn()
	await _run_ai_turn_body(player_input, verb, topic, press_angle)
	_end_busy_turn()


func _run_ai_turn_body(player_input: String, verb: String, topic: String, press_angle: String) -> void:
	_box.set_pending()

	var profile := NpcProfileRegistry.get_profile(_session.npc_id)
	var resolved := StateModifierScript.resolve(profile, _session.npc_memory.get("flags", {}))

	# Capability gate runs FIRST, deterministically.
	var gate := CapabilityGateScript.decide(topic, verb, press_angle, profile, resolved)
	print("[DialogueController] gate(%s, %s) -> %s (%s)" % [
		_session.npc_id, topic, gate.get("decision"), gate.get("reason"),
	])

	# Patience / stress accounting -- always.
	_session.decrement_patience(verb)
	if gate.get("decision") == "blocked" and verb == "press":
		_session.increment_stress()
	if _session.stress_at_limit():
		var line := _anger_out_line(profile.get("archetype", ""))
		AngerCooldownResolver.set_anger_cooldown(_session.npc_id)
		_box.set_dialogue(line, "hostile")
		_box.set_options([])
		# Release the turn lock before the read-window timer so saves
		# aren't blocked during the 2s parting line. The wrapper's
		# _end_busy_turn() is idempotent.
		_end_busy_turn()
		await get_tree().create_timer(2.0).timeout
		_on_box_closed()
		return
	if _session.patience_empty():
		_box.set_dialogue(_anger_out_line(profile.get("archetype", "")), "annoyed")
		_box.set_options([])
		_end_busy_turn()
		await get_tree().create_timer(2.0).timeout
		_on_box_closed()
		return

	# Assemble the prompt and call the provider.
	var state_para := StateModifierScript.build_state_paragraph(_session.npc_memory, resolved)
	var presence_lines: Array = ScenePresenceScript.build_lines(_session.npc_id)
	if not presence_lines.is_empty():
		var prefix := "" if state_para.is_empty() else state_para + "\n  "
		state_para = prefix + "\n  ".join(presence_lines)
	var request := PromptBuilderScript.build(
		_session.npc_id, player_input, verb, topic,
		state_para,
		String(_session.npc_memory.get("recent_summary", "")),
		_session.last_turns.duplicate(),
		gate,
	)
	var raw: Dictionary = await AiService.generate(request)

	var v: Dictionary = ResponseValidatorScript.validate(raw, _session.npc_id, gate.get("reveal_ready", false))
	var response: Dictionary = v["response"]
	var issues: Array = v["issues"]
	var granted: Array = v["granted_facts"]
	if not issues.is_empty():
		print("[DialogueController] validation: ", issues)
	if not granted.is_empty():
		print("[DialogueController] facts granted via reveal: %s" % granted)

	# Memory updates.
	_session.record_npc(response.get("dialogue", ""))
	_session.npc_memory["recent_summary"] = response.get("memory_update", _session.npc_memory.get("recent_summary", ""))
	_session.npc_memory["last_topic"]     = topic

	# Mark topic as pressable whenever a forbidden briefing was the
	# limiting factor and the player did not finish the reveal this turn.
	#   - "forbidden_topic" = blocked, NPC isn't even unlocked
	#   - "press_unlocked_no_match" = unlocked but player asked plainly
	# In both cases, Press is the legitimate next step.
	var reason: String = gate.get("reason", "")
	if reason == "forbidden_topic" or reason == "press_unlocked_no_match":
		_session.mark_dodged(topic)

	# Render + refresh options (surface Press entries when applicable).
	_box.set_dialogue(response.get("dialogue", "..."), response.get("tone", resolved.get("tone_default", "neutral")))
	_set_options(_session.npc_id, topic)

	# Publish turn info for the debug overlay.
	EventBus.debug_turn_recorded.emit({
		"npc_id":         _session.npc_id,
		"topic":          topic,
		"verb":           verb,
		"press_angle":    press_angle,
		"gate":           gate,
		"state_paragraph": state_para,
		"prompt_size":    JSON.stringify(request).length(),
		"raw":            raw,
		"validated":      response,
		"issues":         issues,
		"granted_facts":  granted,
	})

	if response.get("request_end_conversation", false):
		_on_box_closed()


# ---------------------------------------------------------------------------
# _busy lifecycle + watchdog
# ---------------------------------------------------------------------------

func _begin_busy_turn() -> void:
	_busy = true
	_busy_gen += 1
	_arm_busy_watchdog(_busy_gen)


func _end_busy_turn() -> void:
	# Bumping the generation invalidates any in-flight watchdog from this
	# turn; subsequent calls within the same turn are idempotent.
	_busy_gen += 1
	_busy = false


func _arm_busy_watchdog(gen: int) -> void:
	await get_tree().create_timer(_BUSY_WATCHDOG_SECONDS).timeout
	if _busy and _busy_gen == gen:
		push_error("[DialogueController] _busy stuck after %.0fs; force-resetting" % _BUSY_WATCHDOG_SECONDS)
		_busy = false
		_busy_gen += 1


func _render_templated(turn: Dictionary) -> void:
	_box.set_dialogue(turn.get("dialogue", ""), turn.get("tone", "official"))
	_box.set_options(turn.get("options", []))


# ---------------------------------------------------------------------------
# Option presentation
# ---------------------------------------------------------------------------

func _set_options(npc_id: String, topic: String) -> void:
	var opts := AuthoredOptionLibrary.options_for(npc_id, topic)
	if opts.is_empty():
		opts = AuthoredOptionLibrary.options_for(npc_id, "default")
	# Filter Press options: keep only those whose topic has been dodged.
	# This means Press options for the current topic appear naturally on
	# the second turn (after the first ask is blocked) without us having
	# to splice them in.
	var filtered: Array = []
	for opt in opts:
		var verb: String = String(opt.get("verb", "ask"))
		if verb == "press" and not _session.is_pressable(opt.get("topic_id", "")):
			continue
		filtered.append(opt)
	_box.set_options(filtered)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _archetype_greeting(profile: Dictionary) -> String:
	var arch: String = profile.get("archetype", "")
	match arch:
		"drunk":           return "Mm. Sit if you sit. Don't talk fast."
		"village_child":   return "Are you a knight? You don't look like one."
		"blacksmith":      return "Don't lean on the bellows. What do you need?"
		"priest":          return "Peace travels with you, stranger."
		"guard_authority": return "Stranger. Speak plainly."
	return "Yes?"


func _anger_out_line(archetype: String) -> String:
	return ANGER_OUT_LINES.get(archetype, ANGER_OUT_LINES["_default"])
