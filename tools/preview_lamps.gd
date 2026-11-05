extends Node
## Renders the machine's button area with each lamp preset, for picking one:
##   godot --path . --resolution 1920x1080 res://tools/preview_lamps.tscn -- <out dir>


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for i in MachineView.LAMP_STEPS:
		MachineView.lamp_preset = i
		var game: Game = load("res://src/game/game.tscn").instantiate()
		add_child(game)
		await get_tree().create_timer(1.6).timeout
		game.hud.visible = false
		while sin(game._time * 4.0) < 0.6:   # catch PLAY ALL in its lit phase
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("lamp_%d.png" % i))
		game.queue_free()
		await get_tree().create_timer(0.2).timeout
	get_tree().quit()
