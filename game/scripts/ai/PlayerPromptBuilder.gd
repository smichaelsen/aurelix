extends Node
##
## Assembles a PlayerSuggestionsRequest from the engine's view of what KAEL
## knows. Strict isolation from PromptBuilder: this side never reads the
## NPC's profile, dossier, memory, or any field with `forbidden_to_share`.
## Mixing the two contexts would let an NPC's secret leak into Kael's mouth.
##
## Inputs come from public-knowledge stores only:
##   - FactLedger.known_facts()
##   - QuestState.get_state(...)
##   - Journal._entries (Kael's own dossier)
##   - DialogueSession.last_turns (public conversation log)
##   - The NPC's public display_name + archetype
##   - `NpcProfileRegistry.public_tells_for(npc_id, topic)`: narrow
##     accessor that returns ONLY authored `public_tell` strings from
##     the NPC's dossier — observable body-language cues, by design
##     Kael-visible. No briefing body, no reveal_note, no memory.
##
## Pure helper, not an autoload.
##

const MAX_JOURNAL_EXCERPTS := 6
const MAX_EXCERPT_CHARS    := 200


static func build(
	npc_id: String,
	npc_display_name: String,
	npc_archetype: String,
	last_npc_line: String,
	last_turns: Array,
	topic_id: String,
	npc_just_dodged_topic: String = "",
) -> Dictionary:
	# Tells only fire when the NPC actually dodged — they exist to point
	# the player at the lever for a topic the NPC is guarding.
	var tells: Array = []
	if not npc_just_dodged_topic.is_empty():
		tells = NpcProfileRegistry.public_tells_for(npc_id, npc_just_dodged_topic)
	return {
		"npc_display_name":      npc_display_name,
		"npc_archetype":         npc_archetype,
		"last_npc_line":         last_npc_line,
		"last_turns":            last_turns,
		"kael_context":          _build_kael_context(),
		"topic_addressed":       topic_id,
		"npc_just_dodged_topic": npc_just_dodged_topic,
		"public_tells":          tells,
	}


static func _build_kael_context() -> Dictionary:
	return {
		"known_facts":      FactLedger.known_facts(),
		"quest_summary":    _quest_summary(),
		"journal_excerpts": _journal_excerpts(),
	}


static func _quest_summary() -> String:
	var lines: Array = []
	var dragon: String = QuestState.get_state(QuestState.DRAGON_SIGHTING)
	if dragon != QuestState.STATE_NOT_STARTED:
		lines.append("dragon_sighting: %s" % dragon)
	return ", ".join(lines)


# Pull up to MAX_JOURNAL_EXCERPTS short bodies from Kael's journal. The
# briefing body is authored markdown; we strip frontmatter-free leading lines
# and clip to MAX_EXCERPT_CHARS so the prompt stays compact.
static func _journal_excerpts() -> Array:
	var out: Array = []
	var entries: Array = Journal.entries()
	# Most recent first so the prompt biases toward what Kael just learned.
	for i in range(entries.size() - 1, -1, -1):
		if out.size() >= MAX_JOURNAL_EXCERPTS:
			break
		var e: Dictionary = entries[i]
		var briefing: Dictionary = BriefingRegistry.get_briefing(e["id"], e["tier"])
		if briefing.is_empty():
			continue
		var body: String = String(briefing.get("body", "")).strip_edges()
		if body.is_empty():
			continue
		if body.length() > MAX_EXCERPT_CHARS:
			body = body.substr(0, MAX_EXCERPT_CHARS).strip_edges() + "..."
		out.append("%s [%s]: %s" % [e["id"], e["tier"], body])
	return out
