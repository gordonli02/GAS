extends Node
## Renders the machine view with different numbers of columns, for choosing one:
##   godot --path . --resolution 1920x1080 res://tools/preview_machine.tscn -- <out dir> [--columns=8,6,4] [--room=bar]
## Writes machine_<n>.png (at the machine, a few tickets bought) and table_<n>.png.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var counts := [8, 6, 4]
	var room := Game.START_ROOM
	for a in args:
		if a.begins_with("--columns="):
			counts = Array(a.trim_prefix("--columns=").split(",")).map(func(x): return int(x))
		if a.begins_with("--room="):
			room = a.trim_prefix("--room=")
	for n in counts:
		var game: Game = load("res://src/game/game.tscn").instantiate()
		game.use_save = false
		game.form_uids = Game.FORM_UIDS.slice(0, clampi(n, 1, Game.FORM_UIDS.size()))
		add_child(game)
		await get_tree().create_timer(2.0).timeout
		await game.set_room(room, false)
		game.insert_bill(20)
		await get_tree().create_timer(3.0).timeout
		# A ticket from the first and the last column, so both trays hold something.
		game.press_machine(0)
		game.press_machine(game.columns.size() - 1)
		game.hover_column = game.columns.size() - 1
		await get_tree().create_timer(0.7).timeout
		await _shot(out.path_join("machine_%d.png" % n))
		game.close_machine()
		game.hud.visible = false
		await get_tree().create_timer(1.2).timeout
		await _shot(out.path_join("table_%d.png" % n))
		game.queue_free()
		await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
