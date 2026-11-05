extends Node
## Renders the machine view and the menu in English and in Chinese from the same
## game state, for comparing them.
##   godot --path . --resolution 1920x1080 res://tools/preview_cjk.tscn -- <output dir>
## Writes <language>_machine.png and <language>_menu.png for en and zh.

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var game: Game = load("res://src/game/game.tscn").instantiate()
	game.use_save = false
	add_child(game)
	await get_tree().create_timer(1.8).timeout
	for v in [["en", "en"], ["zh", "zh"]]:
		Lang.set_language(v[1])
		game.hud.set_status("ONE MORE?")
		await get_tree().create_timer(0.4).timeout
		await _shot(out.path_join(v[0] + "_machine.png"))
		game.menu.open(Save.settings, game.rooms.id, Lang.current)
		await get_tree().create_timer(0.3).timeout
		await _shot(out.path_join(v[0] + "_menu.png"))
		game.menu.close()
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
