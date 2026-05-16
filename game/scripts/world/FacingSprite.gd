extends Node
##
## Swaps a Sprite2D's texture (or AnimatedSprite2D's animation) when the
## owning character's facing changes. The mechanic-side wiring of 4-direction
## facing — independent of which directional artwork actually exists.
##
## Configure via @export:
##   - subject:        "player" | "iskar" | "npc:<npc_id>"
##   - sprite_path:    path to the Sprite2D to retexture
##   - textures:       Dictionary { "north": Texture2D, "south": ..., "east": ..., "west": ... }
##                     The idle/standing pose. Missing directions fall back to
##                     the current texture (no-op).
##   - step_textures:  Dictionary, same keys. The mid-stride pose shown while
##                     the character is moving between tiles. Optional — if a
##                     direction is missing, the standing sprite stays on screen
##                     while moving. Currently only wired for `subject = "player"`.
##
## If no textures are provided, this node still runs harmlessly — useful as
## the data plumbing lands before the directional art does.
##

@export var subject: String = "player"
@export var sprite_path: NodePath
@export var textures: Dictionary = {}
@export var step_textures: Dictionary = {}

var _last_facing: String = ""
var _stepping: bool = false


func _ready() -> void:
	match _subject_kind():
		"player":
			EventBus.player_facing_changed.connect(_on_player_facing)
			EventBus.player_step_changed.connect(_on_player_step)
		"iskar":
			EventBus.iskar_facing_changed.connect(_on_iskar_facing)
		"npc":
			EventBus.npc_facing_changed.connect(_on_npc_facing)


func _subject_kind() -> String:
	if subject == "player":
		return "player"
	if subject == "iskar":
		return "iskar"
	if subject.begins_with("npc:"):
		return "npc"
	return ""


func _expected_npc_id() -> String:
	if subject.begins_with("npc:"):
		return subject.substr(4)
	return ""


func _on_player_facing(facing: String) -> void:
	_last_facing = facing
	_apply(facing)


func _on_player_step(stepping: bool) -> void:
	_stepping = stepping
	if _last_facing != "":
		_apply(_last_facing)


func _on_iskar_facing(facing: String) -> void:
	_last_facing = facing
	_apply(facing)


func _on_npc_facing(npc_id: String, facing: String) -> void:
	if npc_id != _expected_npc_id():
		return
	_last_facing = facing
	_apply(facing)


func _apply(facing: String) -> void:
	if sprite_path.is_empty():
		return
	var pool: Dictionary = step_textures if (_stepping and step_textures.has(facing)) else textures
	if not pool.has(facing):
		return
	var node := get_node_or_null(sprite_path)
	if node == null:
		return
	if node is Sprite2D:
		(node as Sprite2D).texture = pool[facing]
	elif node is AnimatedSprite2D:
		(node as AnimatedSprite2D).play(String(pool[facing]))
