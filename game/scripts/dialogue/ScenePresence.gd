extends Node
##
## Builds presence lines for the dialogue state paragraph: who else is in
## the scene with the speaker, partitioned into near (Chebyshev distance
## <= NEAR_TILES) and far, each tagged with a cardinal direction (N/S/E/W)
## from the speaker's tile. Lets NPCs later "shout" to a rough direction.
##
## Pure helper, not an autoload. Reads WorldState.npc_locations and
## IskarCompanion presence state.
##

const NEAR_TILES := 3

const _ISKAR_DISPLAY_NAME := "Iskar"


## Returns up to two lines for the state paragraph. Empty Array if the
## speaker is alone in the scene. Speaker is excluded; the player is
## excluded (face-to-face with the speaker is implied by the dialogue).
static func build_lines(speaker_npc_id: String) -> Array:
	if not WorldState.npc_locations.has(speaker_npc_id):
		return []
	var speaker_tile: Vector2i = WorldState.npc_locations[speaker_npc_id]

	var near: Array = []   # [{name, dir, dist}]
	var far:  Array = []

	for npc_id in WorldState.npc_locations.keys():
		if npc_id == speaker_npc_id:
			continue
		var tile: Vector2i = WorldState.npc_locations[npc_id]
		var profile: Dictionary = NpcProfileRegistry.get_profile(npc_id)
		var name: String = profile.get("display_name", npc_id)
		_classify(name, speaker_tile, tile, near, far)

	if IskarCompanion.bonded and IskarCompanion.present_in_scene:
		_classify(_ISKAR_DISPLAY_NAME, speaker_tile, IskarCompanion.current_tile, near, far)

	var lines: Array = []
	if not near.is_empty():
		near.sort_custom(_by_distance_then_name)
		lines.append("Within %d tiles: %s" % [NEAR_TILES, _format(near)])
	if not far.is_empty():
		far.sort_custom(_by_distance_then_name)
		lines.append("Elsewhere in scene: %s" % _format(far))
	return lines


static func _classify(
	name: String,
	speaker: Vector2i,
	other: Vector2i,
	near: Array,
	far: Array,
) -> void:
	var delta := other - speaker
	if delta == Vector2i.ZERO:
		return   # same tile shouldn't happen; if it does, no direction
	var dist: int = max(abs(delta.x), abs(delta.y))   # Chebyshev
	var dir := _cardinal(delta)
	var entry := {"name": name, "dir": dir, "dist": dist}
	if dist <= NEAR_TILES:
		near.append(entry)
	else:
		far.append(entry)


# Dominant axis wins; ties favour horizontal. Matches IskarFollower's rule.
static func _cardinal(delta: Vector2i) -> String:
	if abs(delta.x) >= abs(delta.y):
		return "E" if delta.x > 0 else "W"
	return "S" if delta.y > 0 else "N"


static func _by_distance_then_name(a: Dictionary, b: Dictionary) -> bool:
	if a["dist"] != b["dist"]:
		return a["dist"] < b["dist"]
	return String(a["name"]) < String(b["name"])


static func _format(entries: Array) -> String:
	var parts: Array = []
	for e in entries:
		parts.append("%s (%s)" % [e["name"], e["dir"]])
	return ", ".join(parts)
