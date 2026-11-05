extends Node
## Opens a scene, waits, saves a screenshot. Needs a display:
##   godot --path . --resolution 1920x1080 res://tools/screenshot.tscn -- <scene> <out.png> [seconds]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	add_child(load(args[0]).instantiate())
	await get_tree().create_timer(float(args[2]) if args.size() > 2 else 1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[1])
	get_tree().quit()
