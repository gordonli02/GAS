extends Node
## Screenshots each room from the table and from the machine.
##   godot --path . --resolution 1920x1080 res://tools/preview_rooms.tscn -- <output dir> [options]
##   --gains=h,k,p     light gains (hemisphere, key, points), for fitting against the web build
##   --table-only      skip the machine views
##   --only=<room>     just that room
##   --dim=f           scale the room's own gains by f (trying brightness steps)

var game: Game


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var table_only := args.has("--table-only")
	for a in args:
		if a.begins_with("--gains="):
			RoomSet.gains_override = Array(a.trim_prefix("--gains=").split(",")).map(func(x): return float(x))
	game = load("res://src/game/game.tscn").instantiate()
	game.use_save = false
	add_child(game)
	await _wait(1.5)
	var only := ""
	for a in args:
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		if a.begins_with("--dim="):
			var f := float(a.trim_prefix("--dim="))
			RoomSet.gains_override = (RoomSet.ROOMS[only].gains as Array).map(func(x): return x * f)
	for id in RoomSet.ORDER:
		if only != "" and id != only:
			continue
		game.set_room(id)
		game.close_machine()
		await _wait(1.0)
		await _shot(out.path_join(id + "_table.png"))
		print("%s table: %d draw calls, %d objects, %d primitives" % [id,
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
		if table_only:
			continue
		game.open_machine()
		await _wait(1.0)
		await _shot(out.path_join(id + "_machine.png"))
	get_tree().quit()


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
