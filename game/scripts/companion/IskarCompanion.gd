extends Node
##
## Drake-hatchling companion. State + affinity + stance live here; the
## combat side reads this to decide Iskar's per-turn action.
##
## Autoload as `IskarCompanion`.
##

const STANCE_AGGRESSIVE := "aggressive"
const STANCE_DEFENSIVE  := "defensive"
const STANCE_SUPPORT    := "support"

# Affinity thresholds for tier unlocks. Tier index = unlocked feature.
#   0 (default): Bite
#   1 @ 10 pts:  Ember-Spark (Burn-causing breath)
#   2 @ 25 pts:  reserved for full-game expansion
const TIER_THRESHOLDS := [10, 25, 50]


var bonded: bool = false
var affinity_points: int = 0
var unlocked_tier: int = 0
var stance: String = STANCE_AGGRESSIVE

# Tile presence published by IskarFollower so dialogue / AI prompts can ask
# "is Iskar in the scene and where is he?" without scene-tree probing.
# `present` is false until a follower is in the active scene.
var present_in_scene: bool = false
var current_tile: Vector2i = Vector2i.ZERO


func _ready() -> void:
	# CombatController awards affinity directly on win; we listen for the
	# defeat signal mainly to keep our own bookkeeping coherent.
	EventBus.enemy_defeated.connect(_on_enemy_defeated)


# ---------------------------------------------------------------------------
# Bonding
# ---------------------------------------------------------------------------

func bond() -> void:
	if bonded:
		return
	bonded = true
	print("[Iskar] bonded to Kael")
	EventBus.iskar_bonded.emit()


func set_stance(new_stance: String) -> void:
	if new_stance == stance:
		return
	stance = new_stance
	print("[Iskar] stance -> %s" % new_stance)
	EventBus.iskar_stance_changed.emit(new_stance)


# ---------------------------------------------------------------------------
# Affinity / unlocks
# ---------------------------------------------------------------------------

func add_affinity(points: int) -> void:
	if not bonded or points <= 0:
		return
	var prev := affinity_points
	affinity_points += points
	EventBus.affinity_gained.emit(points, affinity_points)
	print("[Iskar] affinity +%d = %d" % [points, affinity_points])
	for i in TIER_THRESHOLDS.size():
		var thresh: int = TIER_THRESHOLDS[i]
		if prev < thresh and affinity_points >= thresh:
			var tier_id: int = i + 1
			unlocked_tier = max(unlocked_tier, tier_id)
			print("[Iskar] tier %d unlocked" % tier_id)
			EventBus.companion_unlocked.emit(tier_id, _reward_id_for_tier(tier_id))


func has_unlock(tier: int) -> bool:
	return unlocked_tier >= tier


# ---------------------------------------------------------------------------
# Combat actions
# ---------------------------------------------------------------------------

## Picks the action Iskar will take this combat turn. Returns a dict:
##   { kind: "bite" | "ember_spark" | "guard" | "support_buff", target: "enemy" | "kael" }
func pick_action(_rng: RandomNumberGenerator) -> Dictionary:
	match stance:
		STANCE_AGGRESSIVE:
			# At tier 1, half the time he uses Ember-Spark.
			if has_unlock(1) and _rng.randf() < 0.5:
				return {"kind": "ember_spark", "target": "enemy"}
			return {"kind": "bite", "target": "enemy"}
		STANCE_DEFENSIVE:
			return {"kind": "guard", "target": "kael"}
		STANCE_SUPPORT:
			return {"kind": "support_buff", "target": "kael"}
	return {"kind": "bite", "target": "enemy"}


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

func _on_enemy_defeated(_encounter_id: String) -> void:
	# No-op for now; CombatController.award_affinity_after_win does the
	# bookkeeping with combatant_id in hand.
	pass


func _reward_id_for_tier(tier: int) -> String:
	match tier:
		1: return "ember_spark"
		2: return "tier_2_reserved"
		3: return "tier_3_reserved"
	return ""
