extends Node
##
## Current HP for the player party (Kael, Iskar). Persists between fights so
## damage carries over. Saved by SaveManager. Healed in combat via items, out
## of combat via consumables (overworld) or Edda's prayer option.
##
## Max HP comes from CombatantStats (Kael's max includes equipment bonuses
## via kael_stats(); Iskar's max is the raw base block).
##
## Autoload as `PartyHealth`. Loads after CombatantStats; depends on EventBus.
##

var kael_hp: int = -1   # -1 = uninitialised, treated as full on read
var iskar_hp: int = -1


func _ready() -> void:
	# Default to full on game start. SaveManager will overwrite on load.
	kael_hp = kael_max()
	iskar_hp = iskar_max()
	EventBus.iskar_bonded.connect(_on_iskar_bonded)


# ---------------------------------------------------------------------------
# Max HP lookups
# ---------------------------------------------------------------------------

func kael_max() -> int:
	return int(CombatantStats.kael_stats().get("hp", 24))


func iskar_max() -> int:
	return int(CombatantStats.base_stats("iskar").get("hp", 14))


# ---------------------------------------------------------------------------
# Reads
# ---------------------------------------------------------------------------

func get_kael_hp() -> int:
	if kael_hp < 0:
		kael_hp = kael_max()
	return kael_hp


func get_iskar_hp() -> int:
	if iskar_hp < 0:
		iskar_hp = iskar_max()
	return iskar_hp


func kael_is_full() -> bool:
	return get_kael_hp() >= kael_max()


func iskar_is_full() -> bool:
	return get_iskar_hp() >= iskar_max()


# ---------------------------------------------------------------------------
# Writes
# ---------------------------------------------------------------------------

func set_kael_hp(hp: int) -> void:
	var clamped := clampi(hp, 0, kael_max())
	if clamped == kael_hp:
		return
	kael_hp = clamped
	EventBus.party_hp_changed.emit("kael", kael_hp, kael_max())


func set_iskar_hp(hp: int) -> void:
	var clamped := clampi(hp, 0, iskar_max())
	if clamped == iskar_hp:
		return
	iskar_hp = clamped
	EventBus.party_hp_changed.emit("iskar", iskar_hp, iskar_max())


## Heals Kael by `amount` (clamped at max). Returns actual amount healed.
func heal_kael(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := get_kael_hp()
	set_kael_hp(before + amount)
	return kael_hp - before


func heal_iskar(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := get_iskar_hp()
	set_iskar_hp(before + amount)
	return iskar_hp - before


func reset_to_full() -> void:
	set_kael_hp(kael_max())
	set_iskar_hp(iskar_max())


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

# Iskar's pool only matters once he bonds; top him up at that moment so the
# first fight after bonding starts him at full regardless of save lineage.
func _on_iskar_bonded() -> void:
	iskar_hp = iskar_max()
