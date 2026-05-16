extends CanvasLayer
##
## Small bottom-of-screen "[E] Talk to <NAME>" prompt. Listens on EventBus.
## No state of its own; it just shows or hides a label.
##

@onready var _label: Label = $Label


func _ready() -> void:
	_label.visible = false
	EventBus.interaction_available.connect(_on_available)
	EventBus.interaction_unavailable.connect(_on_unavailable)


func _on_available(_target_id: String, _target_type: String, label: String) -> void:
	_label.text = "[E] %s" % label
	_label.visible = true


func _on_unavailable() -> void:
	_label.visible = false
