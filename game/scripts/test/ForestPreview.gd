extends Node
##
## One-shot screenshot of the forest scene for visual review.
##

const FOREST_PATH := "res://scenes/forest_edge.tscn"
const OUT         := "/tmp/aurelix_forest.png"


func _ready() -> void:
	add_child((load(FOREST_PATH) as PackedScene).instantiate())
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT)
	print("[ForestPreview] saved ", OUT)
	get_tree().quit(0)
