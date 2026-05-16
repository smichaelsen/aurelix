extends Node
##
## Swaps a Sprite2D's texture (or AnimatedSprite2D's animation) when the
## owning character's facing changes. The mechanic-side wiring of 4-direction
## facing — independent of which directional artwork actually exists.
##
## Configure via @export:
##   - subject:   "player" | "iskar" | "npc:<npc_id>"
##   - sprite_path: path to the Sprite2D to retexture
##   - textures:  Dictionary  { "north": Texture2D, "south": ..., "east": ..., "west": ... }
##                Missing directions fall back to the current texture (no-op).
##
## If no `textures` are provided, this node still runs harmlessly — useful as
## the data plumbing lands before the directional art does.
##

@export var subject: String = "player"
@export var sprite_path: NodePath
@export var textures: Dictionary = {}


func _ready() -> void:
	match _subject_kind():
		"player":
			EventBus.player_facing_changed.connect(_on_player_facing)
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
	_apply(facing)


func _on_iskar_facing(facing: String) -> void:
	_apply(facing)


func _on_npc_facing(npc_id: String, facing: String) -> void:
	if npc_id != _expected_npc_id():
		return
	_apply(facing)


func _apply(facing: String) -> void:
	if sprite_path.is_empty():
		return
	if not textures.has(facing):
		return
	var node := get_node_or_null(sprite_path)
	if node == null:
		return
	if node is Sprite2D:
		(node as Sprite2D).texture = textures[facing]
	elif node is AnimatedSprite2D:
		(node as AnimatedSprite2D).play(String(textures[facing]))
