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
const PressDetectorScript      = preload("res://scripts/dialogue/PressDetector.gd")
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

# Token from PlayerSuggestionGenerator for the in-flight suggestion call.
# Compared on signal arrival to drop stale results (player picked or moved on).
var _suggestion_token: int = -1


func _ready() -> void:
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	PlayerSuggestionGenerator.suggestions_ready.connect(_on_suggestions_ready)


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

	# State-aware opening: pick the greeting line, the opening options
	# topic, and the tone from the same `state` key (cooldown_recovery
	# is one-shot; cracked/drunk/default persist).
	var state := _resolve_open_state(npc_id, profile)
	var greeting := _opening_greeting(profile, archetype, state)
	var tone := _opening_tone(profile, state)
	_box.set_dialogue(greeting, tone)
	# Greeting / scripted intro uses authored options by default. The bank
	# can still mark "default" as ai_suggested to override. When state
	# resolution picks a non-default topic (e.g. "cracked"), that topic's
	# options_source wins — we deliberately default cracked/gratitude to
	# authored in Orren's bank so the post-reveal coda is fully scripted.
	_set_options(npc_id, _opening_topic(profile, state))


func _on_box_closed() -> void:
	if _session != null:
		EventBus.dialogue_closed.emit()
	_session = null
	PlayerSuggestionGenerator.cancel()
	_suggestion_token = -1
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
	# Any pick cancels an in-flight suggestion call — the conversation has
	# moved on before the model could finish.
	PlayerSuggestionGenerator.cancel()
	_suggestion_token = -1
	var topic: String = option.get("topic_id", "small_talk")
	var verb: String = option.get("verb", "ask")
	var action: String = option.get("action", "")
	var press_angle: String = option.get("press_angle", "")

	if topic == "__close":
		_on_box_closed()
		return

	var option_label: String = option.get("label", "")

	if _session.npc_id == HaldenScript.HALDEN_ID:
		_box.set_player_line(option_label)
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

	if action == "pray_heal":
		_box.set_player_line(option_label)
		_apply_pray_heal()
		return

	_box.set_player_line(option_label)
	_session.record_player(option_label)
	_session.last_topic = topic
	await _run_ai_turn(option_label, verb, topic, press_angle)


func _on_item_offered(item_id: String) -> void:
	if _session == null or _busy:
		return
	PlayerSuggestionGenerator.cancel()
	_suggestion_token = -1
	if _session.npc_id == HaldenScript.HALDEN_ID:
		_box.set_dialogue("I'm not for sale, stranger.", "official")
		return
	# Apply the lever first; this may flip a flag on the NPC's memory.
	var result := OfferItemScript.apply(item_id, _session.npc_id)
	# Use a synthesised player_input describing the offer.
	var offer_input: String = result.get("player_input", "*offers an item*")
	_box.set_player_line(offer_input)
	_session.record_player(offer_input)
	# If the offer added a briefing to the NPC's dossier, pivot the
	# topic to that briefing so the response can speak to it.
	var topic: String = result.get("topic", "")
	if topic.is_empty():
		topic = _session.last_topic if not _session.last_topic.is_empty() else "default"
	_session.last_topic = topic

	# Authored acknowledgement short-circuits the AI turn: gives the player
	# instant visible confirmation that the lever landed (e.g. drunk flag
	# set on Orren) instead of waiting for the next ask to land in a new
	# tone. The flag itself was already flipped by OfferItemAction.apply,
	# so subsequent turns see the new state.
	var ack: Dictionary = result.get("acknowledgement", {})
	if not ack.is_empty():
		var line: String = String(ack.get("dialogue", ""))
		var tone: String = String(ack.get("tone", "neutral"))
		_session.record_npc(line)
		_box.set_dialogue(line, tone)
		_set_options(_session.npc_id, topic)
		return

	await _run_ai_turn(offer_input, "offer_item", topic, "")


func _on_text_submitted(text: String) -> void:
	if _session == null or _busy:
		return
	PlayerSuggestionGenerator.cancel()
	_suggestion_token = -1
	if text.strip_edges().is_empty():
		return
	if _session.npc_id == HaldenScript.HALDEN_ID:
		_box.set_dialogue("Speak plainly, stranger.", "official")
		return
	# Echo the player's line instantly so the panel reflects the commit while
	# the classifier + AI turn run. Without this, "Kael: <text>" only lands
	# after detect_free_text returns (~1s on a network call).
	_box.set_player_line(text)
	_box.set_pending()
	var classified: Dictionary = await TopicDetectorScript.detect_free_text(text)
	var topic: String = String(classified.get("topic_id", "small_talk"))
	var category: String = String(classified.get("category", "in_game"))

	# Layer-1 guardrails: short-circuit before the generate call. Authored
	# options never reach this branch (they carry a fixed topic), so only
	# free text can trip these. `out_of_context` is a no-op turn (no state
	# change, no last_turns entry — the model never sees the player typed
	# something the world can't answer). `offensive` triggers the same
	# anger-out flow as stress_at_limit.
	if category == "out_of_context":
		print("[DialogueController] free text classified out_of_context — short-circuit")
		_handle_out_of_context()
		return
	if category == "offensive":
		print("[DialogueController] free text classified offensive — anger out")
		_handle_offensive()
		return

	# Press detection: if the NPC has dodged a topic and this line presses
	# on it, route as verb=press with the matching angle. Prefer the dodged
	# topic over the classifier's verdict — "I won't tell anyone" is a
	# pressure on whatever the NPC just evaded, not on its small-talk class.
	var press_topic: String = topic
	if not _session.last_topic.is_empty() and _session.is_pressable(_session.last_topic):
		press_topic = _session.last_topic
	var press := PressDetectorScript.detect(_session.npc_id, press_topic, text)
	var verb := "ask"
	var press_angle := ""
	if press.get("is_press", false):
		verb = "press"
		press_angle = String(press.get("angle", ""))
		topic = press_topic
		print("[DialogueController] free text detected as press: angle=%s topic=%s" % [press_angle, topic])
	_session.record_player(text)
	_session.last_topic = topic
	print("[DialogueController] free text classified -> %s" % topic)
	await _run_ai_turn(text, verb, topic, press_angle)


# ---------------------------------------------------------------------------
# Guardrail short-circuits
# ---------------------------------------------------------------------------

# out_of_context: input that cannot be answered in-world (modern tech,
# real-world places). The NPC's prose response would either be confused
# improvisation or a refusal — both worse than a clean authored "didn't
# catch that." Deliberately a no-op turn: no state mutation, no entry in
# `last_turns`, no patience/stress decrement. The player line was already
# echoed to the UI by `_box.set_player_line(text)`; we do not call
# `_session.record_player` so the next turn's model context is clean.
func _handle_out_of_context() -> void:
	var profile := NpcProfileRegistry.get_profile(_session.npc_id)
	var resp := FallbackProvider.out_of_context_response(_session.npc_id, profile)
	_box.set_dialogue(resp.get("dialogue", "..."), resp.get("tone", "neutral"))
	# Keep the existing options active — the player simply tries again.
	_set_options(_session.npc_id, _session.last_topic if not _session.last_topic.is_empty() else "default")


# offensive: grave slurs / explicit content. Mirrors the stress_at_limit
# anger-out flow — one shot, conversation ends, AngerCooldownResolver
# locks the NPC for a few interactions. We deliberately do NOT record
# the player line in last_turns or memory_update so the slur cannot
# resurface in a later prompt via recent_summary or turn history.
func _handle_offensive() -> void:
	var profile := NpcProfileRegistry.get_profile(_session.npc_id)
	var resp := FallbackProvider.offensive_response(_session.npc_id, profile)
	AngerCooldownResolver.set_anger_cooldown(_session.npc_id)
	_box.set_dialogue(resp.get("dialogue", "..."), resp.get("tone", "hostile"))
	_box.set_options([])
	await get_tree().create_timer(2.0).timeout
	_on_box_closed()


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

	# Player can close the dialog (ESC -> _on_box_closed -> _session=null)
	# while the proxy call is in flight. If they did, drop the response —
	# the session it belonged to is gone, and accessing _session.npc_id
	# below would crash.
	if _session == null:
		print("[DialogueController] generate completed but session closed; dropping response")
		return

	# Layer-2 guardrail: the model can raise a safety_flag when it judges
	# the player input out-of-context / offensive even though the cheap
	# classify pass let it through. Substitute a scripted line in both
	# cases; for "offensive" also anger out, mirroring Layer 1. The player
	# line was already appended to `last_turns` by the option/free-text
	# handler, so we pop it back off — the model's next prompt must not
	# see the offending input either.
	var safety_flag: String = String(raw.get("safety_flag", ""))
	if safety_flag == "out_of_context":
		print("[DialogueController] generate raised safety_flag=out_of_context — short-circuit")
		_session.pop_trailing_player()
		var profile_oc := NpcProfileRegistry.get_profile(_session.npc_id)
		var resp_oc := FallbackProvider.out_of_context_response(_session.npc_id, profile_oc)
		_box.set_dialogue(resp_oc.get("dialogue", "..."), resp_oc.get("tone", "neutral"))
		_set_options(_session.npc_id, _session.last_topic if not _session.last_topic.is_empty() else "default")
		return
	if safety_flag == "offensive":
		print("[DialogueController] generate raised safety_flag=offensive — anger out")
		_session.pop_trailing_player()
		var profile_off := NpcProfileRegistry.get_profile(_session.npc_id)
		var resp_off := FallbackProvider.offensive_response(_session.npc_id, profile_off)
		AngerCooldownResolver.set_anger_cooldown(_session.npc_id)
		_box.set_dialogue(resp_off.get("dialogue", "..."), resp_off.get("tone", "hostile"))
		_box.set_options([])
		_end_busy_turn()
		await get_tree().create_timer(2.0).timeout
		_on_box_closed()
		return

	var v: Dictionary = ResponseValidatorScript.validate(
		raw,
		_session.npc_id,
		gate.get("reveal_ready", false),
		String(gate.get("decision", "allowed")),
	)
	var response: Dictionary = v["response"]
	var issues: Array = v["issues"]
	var granted: Array = v["granted_facts"]
	if not issues.is_empty():
		print("[DialogueController] validation: ", issues)
	if not granted.is_empty():
		print("[DialogueController] facts granted via reveal: %s" % granted)

	# Apply per-NPC reveal-driven flags. Generic mechanism: the profile may
	# map a briefing id to a flag set; when that reveal is approved by the
	# validator, the listed flags flip on. Drives the cracked-state arc on
	# Orren after tower_smoke lands, without hardcoding the briefing id
	# anywhere in the controller.
	var on_reveal_flags: Dictionary = profile.get("on_reveal_flags", {})
	if not on_reveal_flags.is_empty():
		for bid in response.get("revealed_briefing_ids", []):
			var to_set: Dictionary = on_reveal_flags.get(bid, {})
			for fk in to_set.keys():
				NpcMemoryStore.set_flag(_session.npc_id, fk, to_set[fk])
				print("[DialogueController] reveal '%s' set flag %s.%s=%s" % [
					bid, _session.npc_id, fk, to_set[fk]
				])

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
	# On a gate-driven dodge, surface the NPC's public_tell for this topic
	# as italic stage direction below the dialogue. Same data the
	# suggestion model gets (`PlayerPromptBuilder.public_tells`) but
	# rendered for the player so the lever isn't invisible. Only fires
	# when the gate reason indicates a dodge — not on ordinary blocks.
	var dodge_reasons := ["forbidden_topic", "press_unlocked_no_match"]
	if reason in dodge_reasons:
		var tells: Array = NpcProfileRegistry.public_tells_for(_session.npc_id, topic)
		if not tells.is_empty():
			_box.set_stage_direction(String(tells[0]))
	# Re-resolve state after the turn — a reveal in this turn may have just
	# flipped a flag (e.g. cracked). When the profile maps that state to a
	# locked options topic, surface those options instead of the turn's
	# topic so the player can't re-press a topic the NPC has just opened on.
	var post_state := _resolve_open_state(_session.npc_id, profile, false)
	_set_options(_session.npc_id, _post_turn_topic(profile, topic, post_state))

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


# Edda's pray-for-healing action: authored response only, no AI turn. Lines
# live in her bank's templated_lines so the priest's voice stays scripted.
# The dialogue stays open so the player can keep talking afterward.
func _apply_pray_heal() -> void:
	var npc_id: String = _session.npc_id
	var line_id: String = "pray_heal_full" if PartyHealth.kael_is_full() else "pray_heal_done"
	var line: String = AuthoredOptionLibrary.templated_line(npc_id, line_id)
	if line.is_empty():
		line = "The Light is with you." if line_id == "pray_heal_full" else "Be still. The Light steadies you."
	if not PartyHealth.kael_is_full():
		PartyHealth.reset_to_full()
		print("[DialogueController] Edda heals party to full.")
	_session.record_npc(line)
	_box.set_dialogue(line, "warm")
	_set_options(npc_id, "greeting")


# ---------------------------------------------------------------------------
# Option presentation
# ---------------------------------------------------------------------------

func _set_options(npc_id: String, topic: String) -> void:
	var source := AuthoredOptionLibrary.options_source(npc_id, topic)
	# Mock mode keeps authored options across the board: the in-game free-text
	# row is hidden in mock anyway, and mock suggestions on top of mock NPC
	# lines would be canned-on-canned with no real value.
	#
	# Note: when a topic is opted into ai_suggested, AI wins even after the
	# NPC dodges — the authored Press options for the topic don't surface in
	# this mode. If we ever want the canonical Press shortcut back, the AI
	# prompt is the place to teach the model to produce a Press-style line,
	# not the UI selection rule. (Per-topic opt-in lives in
	# data/options/<npc>.yaml under `options_source`.)
	if source == "ai_suggested" and not Config.use_mock_ai:
		_box.set_options_pending(3)
		_kick_player_suggestions(npc_id, topic)
		return
	_set_options_authored(npc_id, topic)


func _set_options_authored(npc_id: String, topic: String) -> void:
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


func _kick_player_suggestions(npc_id: String, topic: String) -> void:
	var profile := NpcProfileRegistry.get_profile(npc_id)
	var last_line := ""
	if _session != null:
		last_line = _session.last_npc_line()
	var turns: Array = []
	if _session != null:
		turns = _session.last_turns.duplicate()
	# When the topic was just dodged, surface the cue to the model so it can
	# include one pressing suggestion. Dodge state is set by _run_ai_turn_body
	# after a forbidden/unlocked-no-match capability gate; it persists across
	# turns within the conversation.
	var dodged_topic := ""
	if _session != null and _session.is_pressable(topic):
		dodged_topic = topic
	_suggestion_token = PlayerSuggestionGenerator.generate(
		npc_id,
		profile.get("display_name", npc_id),
		profile.get("archetype", ""),
		last_line,
		turns,
		topic,
		dodged_topic,
	)


func _on_suggestions_ready(token: int, npc_id: String, suggestions: Array) -> void:
	# Stale: conversation moved on, or player picked something before the
	# call finished. Drop silently.
	if token != _suggestion_token:
		return
	if _session == null or _session.npc_id != npc_id:
		return
	if _box == null or not is_instance_valid(_box):
		return
	_suggestion_token = -1
	if suggestions.is_empty():
		# Empty result (provider down, validator stripped everything, etc.) —
		# fall through to authored options so the player isn't stranded with
		# only "..." rows.
		_set_options_authored(npc_id, _session.last_topic)
		return
	_box.apply_suggestions(suggestions)


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


# State key for the opening line / options / tone. One-shot
# cooldown_recovery wins so the apology beat fires once and never again.
# After that, persistent flags resolve in narrative priority:
# cracked (the loaded post-reveal state) before drunk before default.
#
# `consume_oneshot`: when true (open path), pending_cooldown_recovery is
# cleared as it is read. Post-turn callers pass false to peek without
# burning the one-shot — the recovery greeting should fire on the next
# real conversation open, not be eaten mid-turn.
func _resolve_open_state(npc_id: String, profile: Dictionary, consume_oneshot: bool = true) -> String:
	var mem := NpcMemoryStore.memory_for(npc_id)
	var flags: Dictionary = mem.get("flags", {})
	if bool(flags.get("pending_cooldown_recovery", false)):
		if consume_oneshot:
			NpcMemoryStore.set_flag(npc_id, "pending_cooldown_recovery", false)
		return "cooldown_recovery"
	if bool(flags.get("cracked", false)):
		return "cracked"
	if bool(flags.get("drunk", false)):
		return "drunk"
	if bool(flags.get("fed", false)):
		return "fed"
	return "default"


func _opening_greeting(profile: Dictionary, archetype: String, state: String) -> String:
	var greetings: Dictionary = profile.get("greetings", {})
	if greetings.has(state):
		return String(greetings[state])
	if greetings.has("default"):
		return String(greetings["default"])
	return _archetype_greeting(profile)


func _opening_tone(profile: Dictionary, state: String) -> String:
	# Anchor opening tone to the same state_modifier the rest of the
	# pipeline uses, so the drunk/cracked greetings render in the right
	# voice. Falls back to "neutral".
	var mods: Dictionary = profile.get("state_modifiers", {})
	var rule: Dictionary = mods.get(state, {})
	var tone: String = String(rule.get("tone_default", ""))
	if tone.is_empty():
		return "neutral"
	return tone


func _opening_topic(profile: Dictionary, state: String) -> String:
	var by_state: Dictionary = profile.get("default_options_by_state", {})
	if by_state.has(state):
		return String(by_state[state])
	return "default"


# After an AI turn, if the resolved state maps to a locked options topic
# (default_options_by_state), prefer that over the turn's natural topic.
# Lets the cracked-state coda persist regardless of which option the
# player picked to land in it.
func _post_turn_topic(profile: Dictionary, turn_topic: String, state: String) -> String:
	var by_state: Dictionary = profile.get("default_options_by_state", {})
	if by_state.has(state):
		return String(by_state[state])
	return turn_topic


func _anger_out_line(archetype: String) -> String:
	return ANGER_OUT_LINES.get(archetype, ANGER_OUT_LINES["_default"])
